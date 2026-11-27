import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/settings/presentation/settings_screen.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);
  setUp(() => PackageInfo.setMockInitialValues(
        appName: 'Paydial',
        packageName: 'com.paydial.app',
        version: '1.0.2',
        buildNumber: '3',
        buildSignature: '',
      ));

  const groups = {
    'settings_nav_budget_money': 'Cycle & Currency',
    'settings_nav_language_appearance': 'Language & Appearance',
    'settings_nav_security': 'Privacy & Security',
    'settings_nav_smart_detection': 'Smart Detection',
    'settings_nav_reminders': 'Reminders',
    'settings_nav_backup': 'Backup & Export',
    'settings_nav_about': 'About Paydial',
  };

  Future<AppDatabase> pumpHub(
    WidgetTester tester,
    Locale locale, {
    Map<String, String> settings = const {},
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final e in {'budget_cycle_start_day': '25', ...settings}.entries) {
      await db.into(db.appSettingsTable).insertOnConflictUpdate(
            AppSettingsTableCompanion.insert(key: e.key, value: e.value),
          );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> pumpHubWith(WidgetTester tester, AppDatabase db) async {
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '25'),
        );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every hub row opens its page and comes back', (tester) async {
    await pumpHub(tester, const Locale('en'));
    for (final entry in groups.entries) {
      final row = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(entry.value)),
        findsOneWidget,
        reason: entry.key,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }
  });

  testWidgets('hub and pages render in Arabic (RTL)', (tester) async {
    await pumpHub(tester, const Locale('ar'));
    expect(find.text('الخصوصية والأمان'), findsOneWidget);
    for (final key in groups.keys) {
      final row = find.byKey(ValueKey(key));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: key);
      expect(find.byType(BackButton), findsOneWidget, reason: key);
      // pageBack() looks for the English 'Back' tooltip, so tap it directly.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }
  });

  testWidgets('rows summarize the current settings', (tester) async {
    await pumpHub(tester, const Locale('en'), settings: {
      'primary_currency': 'SAR',
      'theme_mode': 'dark',
    });
    expect(find.text('Cycle starts on day 25 · SAR (ر.س)'), findsOneWidget);
    expect(find.text('English · Dark'), findsOneWidget);
    expect(find.text('No PIN lock'), findsOneWidget);
    // Smart detection and reminders are off by default.
    expect(find.text('Off'), findsNWidgets(2));
  });

  testWidgets('calendar-month cycles and PIN + biometrics are summarized',
      (tester) async {
    await pumpHub(tester, const Locale('en'), settings: {
      'budget_cycle_start_day': '1',
      'pin_enabled': 'true',
      'pin_hash': 'x',
      'biometrics_enabled': 'true',
    });
    expect(find.text('Calendar Month · EGP (ج.م)'), findsOneWidget);
    expect(find.text('PIN lock on · Fingerprint / face'), findsOneWidget);
  });

  testWidgets('summary refreshes after returning from a page', (tester) async {
    final db = await pumpHub(tester, const Locale('en'));
    expect(find.text('No PIN lock'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings_nav_security')));
    await tester.pumpAndSettle();
    // Simulate the security page enabling the PIN.
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: 'pin_enabled', value: 'true'),
        );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('PIN lock on'), findsOneWidget);
  });

  group('backup nudge', () {
    Future<void> addTransaction(AppDatabase db) =>
        TransactionRepository(db).addTransaction(
          type: TransactionType.income,
          amount: const Money.fromMinorUnits(1000),
          date: DateTime.now(),
        );

    testWidgets('hidden for a new user with no data', (tester) async {
      await pumpHub(tester, const Locale('en'));
      expect(find.byKey(const ValueKey('backup_nudge_card')), findsNothing);
      expect(find.text('Never backed up'), findsOneWidget);
    });

    testWidgets('shown when there is data and no backup; opens the backup page',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await addTransaction(db);
      await pumpHubWith(tester, db);

      expect(find.byKey(const ValueKey('backup_nudge_card')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('backup_nudge_action')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Backup & Export')),
        findsOneWidget,
      );
    });

    testWidgets('hidden after a recent backup, shown again after 30 days',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await addTransaction(db);
      await BackupService(db)
          .markBackedUp(at: DateTime.now().subtract(const Duration(days: 3)));
      await pumpHubWith(tester, db);
      expect(find.byKey(const ValueKey('backup_nudge_card')), findsNothing);
      expect(find.text('Backed up 3 days ago'), findsOneWidget);

      await BackupService(db)
          .markBackedUp(at: DateTime.now().subtract(const Duration(days: 31)));
      await pumpHubWith(tester, db);
      expect(find.byKey(const ValueKey('backup_nudge_card')), findsOneWidget);
    });
  });

  testWidgets('About shows the version name only, without licences',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Paydial',
      packageName: 'com.paydial.app',
      version: '1.0.2',
      buildNumber: '2003', // split-per-ABI build number on device
      buildSignature: '',
    );
    await pumpHub(tester, const Locale('en'));
    expect(find.text('Version 1.0.2'), findsOneWidget);
    expect(find.textContaining('2003'), findsNothing);

    final about = find.byKey(const ValueKey('settings_nav_about'));
    await tester.ensureVisible(about);
    await tester.pumpAndSettle();
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about_version')), findsOneWidget);
    expect(find.textContaining('no internet access'), findsOneWidget);
    expect(find.textContaining('2003'), findsNothing);
    expect(find.byKey(const ValueKey('about_licenses')), findsNothing);
    expect(find.text('Open-source licenses'), findsNothing);
  });
}
