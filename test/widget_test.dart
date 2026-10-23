import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/presets/data/preset_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/main.dart';
import 'test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  testWidgets(
    'First launch prompts user to determine budget cycle with no default value',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MoneyTrackerApp(),
        ),
      );

      // Initial pump and settle
      await tester.pumpAndSettle();

      // First launch prompts user to select language
      expect(find.text('English'), findsOneWidget);
      expect(find.text('عربي'), findsWidgets);

      // Select English and continue
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm & Continue'));
      await tester.pumpAndSettle();

      // Verify InitialCycleSetupScreen is shown
      expect(find.text('Welcome to SpendWise'), findsOneWidget);
      expect(
        find.text(
          'Determine your monthly budget cycle start and end days to begin tracking your finances.',
        ),
        findsOneWidget,
      );
      expect(find.text('Calendar Month'), findsOneWidget);
      expect(find.text('Custom Payday Cycle'), findsOneWidget);

      // Verify button is disabled by default (no default value)
      final initialButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      expect(initialButton.onPressed, isNull);

      // Select Calendar Month mode
      await tester.tap(find.text('Calendar Month'));
      await tester.pumpAndSettle();

      // Verify button is now enabled
      final enabledButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      expect(enabledButton.onPressed, isNotNull);

      // Tap Confirm & Continue
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      await tester.pumpAndSettle();

      // Verify transition into MainNavigationShell
      expect(find.text('SpendWise'), findsOneWidget);
      expect(find.text('CURRENT BUDGET CYCLE'), findsOneWidget);
      expect(find.text("TODAY'S SPENDING"), findsOneWidget);

      // Verify default categories are visible
      expect(find.text('Food'), findsWidgets);

      // Navigate to Budgets tab
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();

      // Verify dual tabs: Cycle Budgets and Categories
      expect(find.text('Cycle Budgets'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);

      // Switch to Categories tab alongside Budgets
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Verify default categories are displayed
      expect(find.text('Food'), findsWidgets);
      expect(find.text('AI Subscription'), findsWidgets);
      expect(find.text('Social Life'), findsWidgets);
      expect(find.text('Savings'), findsWidgets);
      await tester.drag(find.byType(ListView).last, const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('Transportation'), findsWidgets);
      expect(find.byTooltip('Add Category'), findsOneWidget);

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Category Management is NO LONGER in Settings screen
      expect(find.text('Category Management'), findsNothing);
      expect(find.text('QUICK PRESETS'), findsOneWidget);
      expect(find.text('Quick Transaction Presets'), findsOneWidget);
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Verify Budget Cycle section is visible
      expect(find.text('BUDGET CYCLE'), findsOneWidget);
      expect(find.text('Cycle Start Day'), findsOneWidget);

      // Scroll down to verify Notifications & Reminders section
      await tester.scrollUntilVisible(
        find.text('Daily Evening Reminder'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('NOTIFICATIONS & REMINDERS'), findsOneWidget);
      expect(find.text('Daily Evening Reminder'), findsOneWidget);

      await db.close();
    },
  );

  testWidgets(
    'First launch allows selecting Custom Payday Cycle and persists start and end days',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MoneyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // First launch prompts user to select language
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm & Continue'));
      await tester.pumpAndSettle();

      // Select Custom Payday Cycle
      await tester.tap(find.text('Custom Payday Cycle'));
      await tester.pumpAndSettle();

      expect(find.text('SELECT CYCLE START DAY (1 - 31)'), findsOneWidget);

      // Tap Confirm & Continue
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      await tester.pumpAndSettle();

      // Main app reached
      expect(find.text('SpendWise'), findsOneWidget);

      // Check DB value was persisted
      final setting = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals('budget_cycle_start_day')))
          .getSingleOrNull();
      expect(setting, isNotNull);
      expect(setting!.value, '25');

      await db.close();
    },
  );

  testWidgets(
    'Quick preset chip directly adds transaction without opening dialog and supports Undo',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      // Seed language and budget cycle setting so it starts directly at main screen
      await db.into(db.appSettingsTable).insert(
        AppSettingsTableCompanion.insert(
          key: 'app_language',
          value: 'en',
        ),
      );
      await db.into(db.appSettingsTable).insert(
        AppSettingsTableCompanion.insert(
          key: 'budget_cycle_start_day',
          value: '25',
        ),
      );

      final catRepo = CategoryRepository(db);
      final presetRepo = PresetRepository(db);
      final txRepo = TransactionRepository(db);

      final coffeeCat = await catRepo.createCategory(
        name: 'Coffee',
        type: CategoryType.expense,
      );

      // Create a preset
      await presetRepo.createPreset(
        title: 'Morning Espresso',
        type: TransactionType.expense,
        categoryId: coffeeCat.id,
        amount: Money.fromMajorUnits(45),
        note: 'Daily espresso',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MoneyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning Espresso • 45.00 EGP'), findsOneWidget);

      // Tap preset chip directly
      await tester.tap(find.text('Morning Espresso • 45.00 EGP'));
      await tester.pumpAndSettle();

      // Verify transaction added to DB directly
      var txs = await txRepo.getAllTransactions();
      expect(txs.length, 1);
      expect(txs.first.amount.inMinorUnits, 4500);

      // Verify confirmation SnackBar is displayed with Undo
      expect(find.text('Added "Morning Espresso" (45.00 EGP)'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Verify transaction deleted
      txs = await txRepo.getAllTransactions();
      expect(txs.isEmpty, true);

      await db.close();
    },
  );

  testWidgets(
    'PIN lock does not trigger on inactive (swiping head bar), only when paused (leaving app or screen lock)',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      // Seed language and budget cycle setting
      await db.into(db.appSettingsTable).insert(
        AppSettingsTableCompanion.insert(
          key: 'app_language',
          value: 'en',
        ),
      );
      await db.into(db.appSettingsTable).insert(
        AppSettingsTableCompanion.insert(
          key: 'budget_cycle_start_day',
          value: '25',
        ),
      );

      final security = SecurityService(db);
      await security.setPin('1234');

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MoneyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // App starts locked
      expect(find.text('Enter App PIN'), findsOneWidget);

      // Unlock it
      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('3'));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Verify app is now unlocked
      expect(find.text('SpendWise'), findsOneWidget);
      expect(find.text('Enter App PIN'), findsNothing);

      // Simulate pulling down the status bar (inactive -> resumed)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify app is STILL unlocked (NOT locked by status bar swipe)
      expect(find.text('SpendWise'), findsOneWidget);
      expect(find.text('Enter App PIN'), findsNothing);

      // Simulate leaving app / locking screen (inactive -> hidden -> paused -> hidden -> inactive -> resumed)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Verify app IS now locked
      expect(find.text('Enter App PIN'), findsOneWidget);

      await db.close();
    },
  );
}
