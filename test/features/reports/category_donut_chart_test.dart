import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/reports/presentation/reports_screen.dart';
import 'package:money_tracker/features/reports/presentation/widgets/category_donut_chart.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  tearDown(() {
    Money.applyCurrency(AppCurrency.egp, isArabic: false);
  });

  Future<({AppDatabase db, Category food, Category transport})>
      createSeededDb() async {
    final db = AppDatabase(NativeDatabase.memory());
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
      defaultBudget: const Money.fromMinorUnits(300000),
    );
    final transport = await catRepo.createCategory(
      name: 'Transportation',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(150000),
    );

    final cycleRepo = BudgetCycleRepository(db);
    await cycleRepo.getOrCreateCycleForDate(DateTime.now());

    final txRepo = TransactionRepository(db);
    // Food: 750.00 (75%) across 2 transactions
    await txRepo.addTransaction(
      type: TransactionType.expense,
      amount: const Money.fromMinorUnits(50000),
      categoryId: food.id,
      date: DateTime.now(),
      note: 'Weekly Groceries',
    );
    await txRepo.addTransaction(
      type: TransactionType.expense,
      amount: const Money.fromMinorUnits(25000),
      categoryId: food.id,
      date: DateTime.now(),
      note: 'Lunch Bento',
    );
    // Transportation: 250.00 (25%) across 1 transaction
    await txRepo.addTransaction(
      type: TransactionType.expense,
      amount: const Money.fromMinorUnits(25000),
      categoryId: transport.id,
      date: DateTime.now(),
      note: 'Metro Pass',
    );

    return (db: db, food: food, transport: transport);
  }

  testWidgets(
    'CategoryDonutChart renders at top of Category Report, supports tap-to-inspect slices, and dynamically filters transactions',
    (tester) async {
      final setup = await createSeededDb();
      addTearDown(setup.db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(setup.db)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const ReportsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to focused Categories filter view so the donut chart is right at the top
      await tester.tap(find.widgetWithText(FilterChip, 'Categories'));
      await tester.pumpAndSettle();

      // 1. Verify Donut Chart is rendered with Total Cycle Expenses callout
      expect(find.byType(CategoryDonutChart), findsOneWidget);
      expect(find.byKey(const ValueKey('donut_callout_total')), findsOneWidget);
      expect(find.text('Total Cycle Expenses'), findsOneWidget);
      expect(find.text('1,000.00 EGP'), findsOneWidget);

      // All 3 transactions are listed initially (unfiltered)
      expect(find.text('Weekly Groceries', skipOffstage: false), findsOneWidget);
      expect(find.text('Lunch Bento', skipOffstage: false), findsOneWidget);
      expect(find.text('Metro Pass', skipOffstage: false), findsOneWidget);

      // 2. Tap directly on the Food slice (largest slice = first 75%, so 3 o'clock / right side of ring hits Food)
      final chartGesture = find.byKey(const ValueKey('category_donut_chart_gesture'));
      final chartCenter = tester.getCenter(chartGesture);
      // Base radius is ~91px; tapping +90px to the right (3 o'clock = 25% angle) hits Food (0%..75%)
      await tester.tapAt(chartCenter + const Offset(90, 0));
      await tester.pumpAndSettle();

      // Center callout now shows Food percentage (75.0%) and amount (750.00 EGP)
      expect(
        find.byKey(ValueKey('donut_callout_${setup.food.id}')),
        findsOneWidget,
      );
      expect(find.text('75.0%'), findsOneWidget);
      expect(find.text('750.00 EGP'), findsOneWidget);

      // Transaction list below is dynamically filtered to ONLY Food transactions
      expect(find.text('Food Transactions', skipOffstage: false), findsOneWidget);
      expect(find.text('Weekly Groceries', skipOffstage: false), findsOneWidget);
      expect(find.text('Lunch Bento', skipOffstage: false), findsOneWidget);
      expect(find.text('Metro Pass', skipOffstage: false), findsNothing);

      // 3. Tap directly on the Transportation slice (75%..100% -> top-left / 10:30 o'clock)
      await tester.tapAt(chartCenter + const Offset(-65, -65));
      await tester.pumpAndSettle();

      // Center callout updates to Transportation (25.0%, 250.00 EGP)
      expect(
        find.byKey(ValueKey('donut_callout_${setup.transport.id}')),
        findsOneWidget,
      );
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.text('250.00 EGP'), findsOneWidget);

      // Transaction list below now shows ONLY Transportation transactions
      expect(
        find.text('Transportation Transactions', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Metro Pass', skipOffstage: false), findsOneWidget);
      expect(find.text('Weekly Groceries', skipOffstage: false), findsNothing);
      expect(find.text('Lunch Bento', skipOffstage: false), findsNothing);

      // 4. Tap the center hole of the Donut Chart to clear selection
      await tester.tapAt(chartCenter);
      await tester.pumpAndSettle();

      // Restores Total Cycle Expenses callout and all 3 transactions
      expect(find.byKey(const ValueKey('donut_callout_total')), findsOneWidget);
      expect(find.text('Weekly Groceries', skipOffstage: false), findsOneWidget);
      expect(find.text('Metro Pass', skipOffstage: false), findsOneWidget);
    },
  );
}
