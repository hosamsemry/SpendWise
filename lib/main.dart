import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_tracker/app/main_navigation_shell.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/core/providers/theme_provider.dart';
import 'package:money_tracker/core/security/presentation/pin_lock_screen.dart';
import 'package:money_tracker/core/security/privacy_cover.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/budgets/presentation/initial_cycle_setup_screen.dart';
import 'package:money_tracker/features/onboarding/presentation/language_selection_screen.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';

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
  DateTime? _lastReconciledDay;

  /// False until the first PIN check completes, so no app content can render
  /// before we know whether the app must start locked.
  bool _securityChecked = false;

  /// Current lifecycle state; the privacy cover shows whenever the app is
  /// not resumed, unless Android already hides the recents thumbnail.
  AppLifecycleState? _lifecycle;
  bool _recentsHiddenNatively = false;

  static DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialSecurity();
    _reconcileLifecycle();
    _initSmartDetection();
    PrivacyChannel.isRecentsPreviewHiddenNatively().then((hidden) {
      if (mounted && hidden) setState(() => _recentsHiddenNatively = true);
    });
  }

  void _initSmartDetection() {
    final channel = ref.read(smartDetectionChannelProvider);
    final coordinator = ref.read(smartDetectionCoordinatorProvider);
    channel.onAlertReceived = (alert) {
      coordinator.ingestLiveAlert(alert);
    };
    channel.onSharedTextReceived = (sharedText) {
      coordinator.ingestSharedText(sharedText);
    };
    coordinator.syncFromNative();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialSecurity() async {
    try {
      final hasPin = await ref.read(securityServiceProvider).isPinEnabled();
      if (hasPin && mounted) {
        ref.read(isAppLockedProvider.notifier).state = true;
      }
    } finally {
      if (mounted && !_securityChecked) {
        setState(() => _securityChecked = true);
      }
    }
  }

  /// While locked, swallow the system back gesture so it cannot pop the
  /// (hidden) screens underneath the lock overlay. Registered before
  /// [WidgetsApp], so this observer is consulted first.
  @override
  Future<bool> didPopRoute() async => ref.read(isAppLockedProvider);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_recentsHiddenNatively && state != _lifecycle) {
      setState(() => _lifecycle = state);
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wasInBackground = true;
      // Lock while going to the background, so the first frame after
      // returning is already the lock screen.
      _checkInitialSecurity();
    } else if (state == AppLifecycleState.resumed) {
      final returnedFromBackground = _wasInBackground;
      _wasInBackground = false;

      // Ignore transient inactive -> resumed transitions (e.g. notification shade swipe)
      if (!returnedFromBackground) return;

      _checkInitialSecurity();
      ref.read(smartDetectionCoordinatorProvider).syncFromNative();
      ref.invalidate(notificationAccessStatusProvider);

      // Reconcile cycles/reminders when returning from background only if the calendar day changed
      final today = _dayKey(DateTime.now());
      if (_lastReconciledDay != today) {
        _reconcileLifecycle();
      }
    }
  }

  Future<void> _reconcileLifecycle() async {
    try {
      final startDay = await ref.read(budgetCycleStartDayProvider.future);
      // Do not create cycles or schedule cycle reminders until user configures cycle!
      if (startDay == null || !mounted) return;

      final cycleRepo = ref.read(budgetCycleRepositoryProvider);
      final catRepo = ref.read(categoryRepositoryProvider);
      final notificationService = ref.read(notificationServiceProvider);

      // 1. Seed default categories if none exist and unarchive any previously archived categories
      final lang = ref.read(appLanguageProvider).value?.languageCode ?? 'en';
      await catRepo.seedDefaultCategories(languageCode: lang);
      await catRepo.unarchiveAllCategories();

      // 2. Reconcile current cycle for today's local date
      final now = DateTime.now();
      _lastReconciledDay = _dayKey(now);
      final cycle = await cycleRepo.getOrCreateCycleForDate(now);
      await cycleRepo.syncCategoriesForCycle(cycle.id);
      await ref
          .read(savingsSyncServiceProvider)
          .syncSavingsBudgetForCycle(cycleId: cycle.id);

      // 3. Reconcile the next 'new cycle' reminder for the user's start day
      await notificationService.initialize();
      await notificationService.scheduleCycleStartReminder(
        nextCycleReminderTime(cycleRepo.calculator, now),
      );
      await ref.read(billServiceProvider).rescheduleReminders();

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
    ref.watch(primaryCurrencyProvider);

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
      // The lock is drawn above the root Navigator (not swapped into `home`),
      // so routes, dialogs and sheets opened before locking stay covered.
      // Edge-to-edge: system bar icons follow the theme. App bars set their
      // own status-bar style on top of this; screens without one (lock,
      // onboarding) and the navigation bar use this region.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _systemBarsStyle(Theme.of(context).brightness),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?child,
            if (!_securityChecked)
              ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
            if (isLocked) const _LockOverlay(),
            if (!_recentsHiddenNatively &&
                _lifecycle != null &&
                _lifecycle != AppLifecycleState.resumed)
              const PrivacyCover(),
          ],
        ),
      ),
      home: languageAsync.when(
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

/// Full-screen PIN prompt shown above every route while the app is locked.
/// It has its own Navigator so it works without the app's (covered) one.
class _LockOverlay extends ConsumerWidget {
  const _LockOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HeroControllerScope.none(
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => PinLockScreen(
            mode: PinMode.unlock,
            onUnlocked: () {
              ref.read(isAppLockedProvider.notifier).state = false;
            },
          ),
        ),
      ),
    );
  }
}

/// Transparent system bars with icons that contrast with the theme's
/// background (light icons in dark mode, dark icons in light mode).
SystemUiOverlayStyle _systemBarsStyle(Brightness themeBrightness) {
  final isDark = themeBrightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );
}
