import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:money_tracker/features/dashboard/presentation/widgets/velvet_titanium_hero_card.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/main.dart';
import '../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  tearDown(() {
    Money.applyCurrency(AppCurrency.egp, isArabic: false);
  });

  testWidgets(
    'First-time onboarding lets user pick primary currency and persists it into Dashboard',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MoneyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Select English language
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm & Continue'),
      );
      await tester.pumpAndSettle();

      // Step 2: Select Calendar Month + USD primary currency
      await tester.tap(find.text('Calendar Month'));
      await tester.pumpAndSettle();

      final usdChip = find.byKey(const ValueKey('onboarding_currency_USD'));
      await tester.ensureVisible(usdChip);
      await tester.pumpAndSettle();
      await tester.tap(usdChip);
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(
        ElevatedButton,
        'Confirm & Continue',
      );
      await tester.ensureVisible(confirmBtn);
      await tester.pumpAndSettle();
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify persisted in app_settings
      final savedCurrency = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals(primaryCurrencyKey)))
          .getSingle();
      expect(savedCurrency.value, 'USD');

      // Dashboard Hero Card immediately reflects USD
      expect(find.text('of 0.00 USD'), findsOneWidget);
    },
  );

  testWidgets(
    'Inline Hero Card cycle switcher lets user glance at previous cycle and return to current cycle',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(key: 'app_language', value: 'en'),
          );
      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(
              key: 'budget_cycle_start_day',
              value: '1',
            ),
          );

      final catRepo = CategoryRepository(db);
      final food = await catRepo.createCategory(
        name: 'Food',
        type: CategoryType.expense,
        defaultBudget: const Money.fromMinorUnits(100000), // 1,000.00
      );

      final now = DateTime.now();
      final lastMonthDate = DateTime(now.year, now.month - 1, 15);

      // Match the start day saved above (the repository defaults to 25),
      // otherwise these cycles disagree with the dashboard's on some dates.
      final cycleRepo = BudgetCycleRepository(
        db,
        calculator: const BudgetCycleCalculator(startDay: 1),
      );
      final prevCycle = await cycleRepo.getOrCreateCycleForDate(lastMonthDate);
      final currentCycle = await cycleRepo.getOrCreateCycleForDate(now);

      final txRepo = TransactionRepository(db);
      // Previous cycle: 400.00 spent
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(40000),
        categoryId: food.id,
        date: lastMonthDate,
        note: 'Last month groceries',
      );
      // Current cycle: 100.00 spent
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(10000),
        categoryId: food.id,
        date: now,
        note: 'This month groceries',
      );

      await tester.pumpWidget(
        ProviderScope(
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
            home: DashboardScreen(
              onNavigateToTransactions: () {},
              onNavigateToBudgets: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially showing current cycle with switcher bar positioned ABOVE the Hero Card
      // and NO redundant cycle range inside the Hero Card
      final switcherFinder = find.byKey(
        const ValueKey('dashboard_cycle_switcher_bar'),
      );
      final heroFinder = find.byType(VelvetTitaniumHeroCard);
      expect(switcherFinder, findsOneWidget);
      expect(
        tester.getTopLeft(switcherFinder).dy,
        lessThan(tester.getTopLeft(heroFinder).dy),
      );
      expect(find.text('CURRENT BUDGET CYCLE'), findsOneWidget);
      expect(find.text(currentCycle.formattedRange), findsOneWidget);
      expect(
        find.descendant(
          of: heroFinder,
          matching: find.text(currentCycle.formattedRange),
        ),
        findsNothing,
      );
      expect(find.text('+900.00 EGP'), findsOneWidget);
      expect(find.text('Total Income'), findsNothing);
      expect(find.byKey(const ValueKey('hero_prev_cycle_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('hero_next_cycle_btn')), findsOneWidget);

      // Tap < arrow in switcher above card to glance at previous cycle
      await tester.tap(find.byKey(const ValueKey('hero_prev_cycle_btn')));
      await tester.pumpAndSettle();

      // Now showing historical cycle summary
      expect(find.text('PAST BUDGET CYCLE'), findsOneWidget);
      // The savings closeout card also names the previous cycle (it ended with
      // a 600.00 surplus), so check the range inside the switcher bar.
      expect(
        find.descendant(
          of: switcherFinder,
          matching: find.text(prevCycle.formattedRange),
        ),
        findsOneWidget,
      );
      expect(find.text('+600.00 EGP'), findsOneWidget);
      expect(find.text('400.00 EGP'), findsOneWidget);
      expect(find.text('AVG / DAY'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // Tap > arrow to return to current cycle
      await tester.tap(find.byKey(const ValueKey('hero_next_cycle_btn')));
      await tester.pumpAndSettle();

      expect(find.text('CURRENT BUDGET CYCLE'), findsOneWidget);
      expect(find.text(currentCycle.formattedRange), findsOneWidget);
      expect(find.text('+900.00 EGP'), findsOneWidget);
    },
  );
}
