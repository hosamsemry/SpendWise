import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/export/data/csv_export_service.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late TransactionRepository txRepo;
  late CategoryRepository categoryRepo;
  late CsvExportService csvService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    txRepo = TransactionRepository(db);
    csvService = CsvExportService(txRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('CsvExportService Tests', () {
    test(
      'buildTransactionsCsv formats transactions and escapes commas and quotes',
      () async {
        final cat = await categoryRepo.createCategory(
          name: 'Groceries, Supplies & "Food"',
          type: CategoryType.expense,
        );

        await txRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(150),
          date: DateTime(2026, 10, 1),
          categoryId: cat.id,
          note: 'Supermarket, eggs, "milk"',
        );

        await txRepo.addTransaction(
          type: TransactionType.income,
          amount: Money.fromMajorUnits(10000),
          date: DateTime(2026, 10, 5),
          note: 'Monthly salary',
        );

        final csv = await csvService.buildTransactionsCsv();

        expect(
          csv.contains('ID,Date,Type,Category,Amount (EGP),Note,Created At'),
          isTrue,
        );
        // Verify escaped category with commas and quotes
        expect(csv.contains('"Groceries, Supplies & ""Food"""'), isTrue);
        // Verify escaped note with commas and quotes
        expect(csv.contains('"Supermarket, eggs, ""milk"""'), isTrue);
        expect(csv.contains('150.00'), isTrue);
        expect(csv.contains('10000.00'), isTrue);
        expect(csv.contains('INCOME'), isTrue);
        expect(csv.contains('EXPENSE'), isTrue);
      },
    );

    test('buildCycleSummaryCsv formats cycle summary metrics accurately', () {
      final cycle = BudgetCycle(
        id: 'cycle-1',
        startDate: DateTime(2026, 9, 25),
        endDate: DateTime(2026, 10, 24),
      );

      final summary = CycleSummary(
        cycle: cycle,
        totalIncome: Money.fromMajorUnits(15000),
        totalBudgeted: Money.fromMajorUnits(10000),
        totalSpent: Money.fromMajorUnits(6000),
        positiveUnusedTotal: Money.fromMajorUnits(4000),
        netRemainingTotal: Money.fromMajorUnits(9000),
        overspentCategoriesCount: 0,
        categoryBudgets: [
          CategoryBudget(
            categoryId: 'cat-1',
            categoryName: 'Dining',
            budgetedAmount: Money.fromMajorUnits(3000),
            spentAmount: Money.fromMajorUnits(1500),
          ),
        ],
      );

      final csv = csvService.buildCycleSummaryCsv(summary);

      expect(csv.contains('Budget Cycle:'), isTrue);
      expect(csv.contains('Total Income:'), isTrue);
      expect(csv.contains('Dining,3000.00,1500.00,1500.00,50.0%'), isTrue);
    });
  });
}
