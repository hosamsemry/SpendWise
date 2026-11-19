import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/main_navigation_shell.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/reports/presentation/reports_screen.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  Future<AppDatabase> createSeededDb() async {
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
      defaultBudget: const Money.fromMinorUnits(300000), // 3,000 EGP
    );
    final salary = await catRepo.createCategory(
      name: 'Salary',
      type: CategoryType.income,
      defaultBudget: const Money.fromMinorUnits(1500000), // 15,000 EGP
    );

    final cycleRepo = BudgetCycleRepository(db);
    await cycleRepo.getOrCreateCycleForDate(DateTime.now());

    final txRepo = TransactionRepository(db);
    await txRepo.addTransaction(
      type: TransactionType.income,
      amount: const Money.fromMinorUnits(1500000),
      categoryId: salary.id,
      date: DateTime.now(),
      note: 'Salary received',
    );
    await txRepo.addTransaction(
      type: TransactionType.expense,
      amount: const Money.fromMinorUnits(50000), // 500 EGP
      categoryId: food.id,
      date: DateTime.now(),
      note: 'Dinner',
    );

    return db;
  }

  testWidgets(
    'MainNavigationShell elevates Insights to primary nav and renders flattened fluid reports',
    (tester) async {
      final db = await createSeededDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: [Locale('en'), Locale('ar')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MainNavigationShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 4 primary bottom nav destinations exist
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);

      // Verify Settings is accessible from Dashboard header gear icon
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Tap Insights in bottom navigation bar
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // ReportsScreen is rendered
      expect(find.byType(ReportsScreen), findsOneWidget);

      // Verify flattened filter chips exist on the fluid page
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Cash Flow'), findsWidgets);
      expect(find.text('Categories'), findsWidgets);
      expect(find.text('MoM Comparison'), findsOneWidget);
      expect(find.text('Budget vs Actual'), findsWidgets);

      // Scroll fluid page down to verify subsequent sections render on the same page
      await tester.scrollUntilVisible(
        find.text('Total Cycle Expenses'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Total Cycle Expenses'), findsOneWidget);
      expect(find.text('Food'), findsWidgets); // Category in breakdown

      // Filter to Categories section using the FilterChip
      await tester.tap(find.widgetWithText(FilterChip, 'Categories'));
      await tester.pumpAndSettle();

      // Expense breakdown is visible in focused view
      expect(find.text('Total Cycle Expenses'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);
    },
  );
}
