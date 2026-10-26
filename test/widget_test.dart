import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/language_provider.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';
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

  testWidgets(
    'Full normal user simulation: onboarding, income, budgets, categories, expenses, savings vault, backup export & fresh-install restore, and post-restore budget edits',
    (tester) async {
      // =========================================================================
      // PART 1: Device 1 — Normal User Journey from Onboarding to Backup Export
      // =========================================================================
      final db1 = AppDatabase(NativeDatabase.memory());
      final container1 = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db1)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container1,
          child: const MoneyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Onboarding: Select English & Calendar Month (Start Day 1)
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm & Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar Month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('SpendWise'), findsOneWidget);

      // 2. Record Salary Income (10,000 EGP) and rebalance Savings
      final catRepo1 = container1.read(categoryRepositoryProvider);
      final txRepo1 = container1.read(transactionRepositoryProvider);
      final cycleRepo1 = container1.read(budgetCycleRepositoryProvider);
      final savingsSync1 = container1.read(savingsSyncServiceProvider);

      final categories1 = await catRepo1.getAllCategories();
      final salaryCat1 = categories1.firstWhere((c) => c.name == 'Salary');
      final foodCat1 = categories1.firstWhere((c) => c.name == 'Food');

      final cycle1 = await cycleRepo1.getOrCreateCycleForDate(DateTime.now());
      await txRepo1.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(10000),
        categoryId: salaryCat1.id,
        date: DateTime.now(),
        note: 'Monthly Salary',
      );
      await savingsSync1.syncSavingsBudgetForCycle(cycleId: cycle1.id);
      container1.read(refreshTriggerProvider.notifier).trigger();
      await tester.pumpAndSettle();

      // Verify Home screen displays 10,000.00 EGP total budget and +10,000.00 EGP remaining
      expect(find.text('+10,000.00 EGP'), findsOneWidget);
      expect(find.text('of 10,000.00 EGP'), findsOneWidget);

      // 3. Navigate to Budgets screen and set Food budget to 2,000 EGP via UI dialog
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();

      // Tap edit icon on Food card in Cycle Budgets tab
      final foodEditFinder = find.descendant(
        of: find.ancestor(of: find.text('Food'), matching: find.byType(Card)).first,
        matching: find.byIcon(Icons.edit_outlined),
      );
      await tester.tap(foodEditFinder);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '2000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Verify Food budget is 2,000 EGP and Savings auto-rebalanced to 8,000 EGP
      var summary1 = await container1.read(cycleSummaryProvider(cycle1).future);
      expect(summary1.totalBudgeted, Money.fromMajorUnits(10000));
      expect(
        summary1.categoryBudgets.firstWhere((b) => b.categoryName == 'Food').budgetedAmount,
        Money.fromMajorUnits(2000),
      );
      expect(
        summary1.categoryBudgets.firstWhere((b) => b.categoryName == 'Savings').budgetedAmount,
        Money.fromMajorUnits(8000),
      );

      // 4. Switch to Categories tab, edit Transportation default budget to 1,000 EGP via UI dialog,
      //    and add a new expense category "Gym" with initial budget 200 EGP via UI dialog
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Add new Expense category "Gym" with 200 EGP initial budget
      await tester.tap(find.byTooltip('Add Expense Category'));
      await tester.pumpAndSettle();
      final addDialogFields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(addDialogFields.at(0), 'Gym');
      await tester.enterText(addDialogFields.at(1), '200');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Verify total budget on Home screen is STILL 10,000 EGP (did NOT increase by 200!)
      // and Savings rebalanced to 7,800 EGP (10,000 - 2,000 - 200)
      summary1 = await container1.read(cycleSummaryProvider(cycle1).future);
      expect(summary1.totalBudgeted, Money.fromMajorUnits(10000));
      expect(
        summary1.categoryBudgets.firstWhere((b) => b.categoryName == 'Gym').budgetedAmount,
        Money.fromMajorUnits(200),
      );
      expect(
        summary1.categoryBudgets.firstWhere((b) => b.categoryName == 'Savings').budgetedAmount,
        Money.fromMajorUnits(7800),
      );

      // 5. Record an expense of 1,600 EGP on Food (80% of 2,000 EGP) and insert a threshold notification event
      await txRepo1.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(1600),
        categoryId: foodCat1.id,
        date: DateTime.now(),
        note: 'Weekly groceries',
      );
      await db1.into(db1.notificationEventsTable).insert(
        NotificationEventsTableCompanion.insert(
          id: 'notif-food-80',
          cycleId: cycle1.id,
          categoryId: foodCat1.id,
          eventType: 'reached_80_percent',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      container1.read(refreshTriggerProvider.notifier).trigger();
      await tester.pumpAndSettle();

      // Verify Home screen metrics: Remaining Budget is +8,400.00 EGP of 10,000.00 EGP
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('+8,400.00 EGP'), findsOneWidget);
      expect(find.text('of 10,000.00 EGP'), findsOneWidget);

      // 6. Export full backup JSON from Device 1
      final backupService1 = BackupService(db1);
      final backupPayload = await backupService1.createBackupData();
      final backupJson = backupPayload.toFormattedJsonString();

      await db1.close();

      // =========================================================================
      // PART 2: Device 2 — Fresh Install, Onboarding, Backup Import, & Manual Edit
      // =========================================================================
      final db2 = AppDatabase(NativeDatabase.memory());
      final container2 = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db2)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container2,
          child: const MoneyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Fresh install onboarding on Device 2 (creates a fresh cycle with a different UUID!)
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm & Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Calendar Month'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm & Continue'));
      await tester.pumpAndSettle();

      // Before restore: Device 2 has 0.00 EGP budget and a fresh cycle UUID in Riverpod's cache
      final preRestoreCycle = await container2.read(currentCycleProvider.future);
      expect(preRestoreCycle.id, isNot(equals(cycle1.id)));
      expect(find.text('of 0.00 EGP'), findsOneWidget);

      // Also insert a notification event on Device 2 before restoring to verify FK deletion order
      final dev2Cats = await container2.read(categoryRepositoryProvider).getAllCategories();
      await db2.into(db2.notificationEventsTable).insert(
        NotificationEventsTableCompanion.insert(
          id: 'notif-dev2',
          cycleId: preRestoreCycle.id,
          categoryId: dev2Cats.first.id,
          eventType: 'reached_80_percent',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );

      // 2. Import the backup on Device 2 (exact same flow as SettingsScreen._restoreBackup)
      final backupService2 = BackupService(db2);
      final parsedBackup = backupService2.parseBackupString(backupJson);
      await backupService2.restoreFromBackup(parsedBackup, keepCurrentPin: true);

      container2.read(selectedCycleProvider.notifier).select(null);
      container2.invalidate(budgetCycleStartDayProvider);
      container2.invalidate(appLanguageProvider);
      container2.invalidate(currentCycleProvider);
      container2.invalidate(allCyclesProvider);
      container2.invalidate(cycleSummaryProvider);
      container2.invalidate(transactionsForCycleProvider);

      final cycleRepo2 = container2.read(budgetCycleRepositoryProvider);
      final restoredCycle = await cycleRepo2.getCycleForDateOrNull(DateTime.now());
      expect(restoredCycle, isNotNull);
      expect(restoredCycle!.id, equals(cycle1.id));

      await cycleRepo2.syncCategoriesForCycle(restoredCycle.id);
      await container2
          .read(savingsSyncServiceProvider)
          .syncSavingsBudgetForCycle(cycleId: restoredCycle.id);
      container2.read(refreshTriggerProvider.notifier).trigger();
      await tester.pumpAndSettle();

      // 3. Verify Dashboard immediately shows restored budgets (+8,400.00 EGP of 10,000.00 EGP, NOT 0.00!)
      expect(find.text('+8,400.00 EGP'), findsOneWidget);
      expect(find.text('of 10,000.00 EGP'), findsOneWidget);

      // 4. Navigate to Budgets screen and verify restored category budgets are displayed
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();

      var summary2 = await container2.read(cycleSummaryProvider(restoredCycle).future);
      expect(
        summary2.categoryBudgets.firstWhere((b) => b.categoryName == 'Food').budgetedAmount,
        Money.fromMajorUnits(2000),
      );
      expect(
        summary2.categoryBudgets.firstWhere((b) => b.categoryName == 'Gym').budgetedAmount,
        Money.fromMajorUnits(200),
      );
      expect(
        summary2.categoryBudgets.firstWhere((b) => b.categoryName == 'Savings').budgetedAmount,
        Money.fromMajorUnits(7800),
      );

      // 5. Manually edit Food budget from 2,000 EGP to 2,500 EGP after restore via UI dialog
      final foodEditFinder2 = find.descendant(
        of: find.ancestor(of: find.text('Food'), matching: find.byType(Card)).first,
        matching: find.byIcon(Icons.edit_outlined),
      );
      await tester.tap(foodEditFinder2);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '2500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Verify Food budget immediately updates to 2,500.00 EGP and Savings rebalances to 7,300.00 EGP
      summary2 = await container2.read(cycleSummaryProvider(restoredCycle).future);
      expect(
        summary2.categoryBudgets.firstWhere((b) => b.categoryName == 'Food').budgetedAmount,
        Money.fromMajorUnits(2500),
      );
      expect(
        summary2.categoryBudgets.firstWhere((b) => b.categoryName == 'Savings').budgetedAmount,
        Money.fromMajorUnits(7300),
      );
      expect(summary2.totalBudgeted, Money.fromMajorUnits(10000));
      expect(find.text('2,500.00 EGP'), findsWidgets);

      await db2.close();
    },
  );
}
