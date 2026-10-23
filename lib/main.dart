import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_tracker/app/main_navigation_shell.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';
import 'package:money_tracker/core/providers/theme_provider.dart';
import 'package:money_tracker/core/security/presentation/pin_lock_screen.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/budgets/presentation/initial_cycle_setup_screen.dart';
import 'package:money_tracker/features/onboarding/presentation/language_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ProviderScope(child: MoneyTrackerApp()));
}

class MoneyTrackerApp extends ConsumerStatefulWidget {
  const MoneyTrackerApp({super.key});

  @override
  ConsumerState<MoneyTrackerApp> createState() => _MoneyTrackerAppState();
}

class _MoneyTrackerAppState extends ConsumerState<MoneyTrackerApp>
    with WidgetsBindingObserver {
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialSecurity();
    _reconcileLifecycle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialSecurity() async {
    final security = ref.read(securityServiceProvider);
    final hasPin = await security.isPinEnabled();
    if (hasPin) {
      ref.read(isAppLockedProvider.notifier).state = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasInBackground) {
        _wasInBackground = false;
        _checkInitialSecurity();
      }
      _reconcileLifecycle();
    }
  }

  Future<void> _reconcileLifecycle() async {
    try {
      final startDayAsync = ref.read(budgetCycleStartDayProvider);
      final startDay = startDayAsync.asData?.value;
      // Do not create cycles or schedule cycle reminders until user configures cycle!
      if (startDay == null) return;

      final cycleRepo = ref.read(budgetCycleRepositoryProvider);
      final catRepo = ref.read(categoryRepositoryProvider);
      final notificationService = ref.read(notificationServiceProvider);

      // 1. Seed default categories if none exist and unarchive any previously archived categories
      final lang = ref.read(appLanguageProvider).value?.languageCode ?? 'en';
      await catRepo.seedDefaultCategories(languageCode: lang);
      await catRepo.unarchiveAllCategories();

      // 2. Reconcile current cycle for today's local date
      final now = DateTime.now();
      await cycleRepo.getOrCreateCycleForDate(now);

      // 3. Reconcile 25th reminder
      await notificationService.initialize();
      await notificationService.scheduleNext25thReminder(now);

      // 4. Trigger reactive refresh
      ref.read(refreshTriggerProvider.notifier).trigger();
    } catch (_) {
      // Graceful fallback: app continues offline
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isLocked = ref.watch(isAppLockedProvider);
    final languageAsync = ref.watch(appLanguageProvider);
    final startDayAsync = ref.watch(budgetCycleStartDayProvider);

    return MaterialApp(
      title: 'SpendWise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: languageAsync.asData?.value,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      home: isLocked
          ? PinLockScreen(
              mode: PinMode.unlock,
              onUnlocked: () {
                ref.read(isAppLockedProvider.notifier).state = false;
              },
            )
          : languageAsync.when(
              data: (locale) {
                if (locale == null) {
                  return const LanguageSelectionScreen();
                }
                return startDayAsync.when(
                  data: (startDay) {
                    if (startDay == null) {
                      return const InitialCycleSetupScreen();
                    }
                    return const MainNavigationShell();
                  },
                  loading: () => const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, stack) => const InitialCycleSetupScreen(),
                );
              },
              loading: () => const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, stack) => const LanguageSelectionScreen(),
            ),
    );
  }
}
