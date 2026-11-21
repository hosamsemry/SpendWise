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

        // Verify UTF-8 BOM is present for Excel compatibility
        expect(csv.startsWith('\uFEFF'), isTrue);
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
    test('buildTransactionsCsv localizes category names when categoryLocalizer is provided', () async {
      final cat = await categoryRepo.createCategory(
        name: 'راتب',
        type: CategoryType.income,
      );

      await txRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(8000),
        date: DateTime(2026, 10, 25),
        categoryId: cat.id,
      );

      final csvEnglish = await csvService.buildTransactionsCsv(
        categoryLocalizer: (name) => name == 'راتب' ? 'Salary' : (name ?? ''),
      );

      expect(csvEnglish.startsWith('\uFEFF'), isTrue);
      expect(csvEnglish.contains('Salary'), isTrue);
      expect(csvEnglish.contains('راتب'), isFalse);
    });

    test('CSV headers dynamically reflect active primary currency and omit symbol for None', () async {
      addTearDown(() => Money.applyCurrency(AppCurrency.egp, isArabic: false));

      Money.applyCurrency(AppCurrency.sar, isArabic: false);
      final sarCsv = await csvService.buildTransactionsCsv();
      expect(sarCsv.contains('Amount (SAR)'), isTrue);

      Money.applyCurrency(AppCurrency.none, isArabic: false);
      final plainCsv = await csvService.buildTransactionsCsv();
      expect(plainCsv.contains('ID,Date,Type,Category,Amount,Note,Created At'), isTrue);
    });

    test('neutralizes formula-like text cells (CSV injection)', () async {
      final cat = await categoryRepo.createCategory(
        name: '=cmd|calc',
        type: CategoryType.expense,
      );
      final payloads = [
        '=HYPERLINK("http://evil.example","click")',
        '+SUM(1,2)',
        '-2+3',
        '@SUM(A1)',
        '\tTAB',
        'Normal note',
      ];
      for (final note in payloads) {
        await txRepo.addTransaction(
          type: TransactionType.expense,
          amount: const Money.fromMinorUnits(1000),
          categoryId: cat.id,
          date: DateTime(2026, 11, 1),
          note: note,
        );
      }

      final csv = await csvService.buildTransactionsCsv();
      final rows = csv.split('\n').skip(1).where((l) => l.isNotEmpty).toList();
      for (final row in rows) {
        // Category cell is the 4th column: neutralized with a leading quote.
        expect(row, contains(",'=cmd|calc,"));
      }
      expect(csv, contains('"\'=HYPERLINK(""http://evil.example"",""click"")"'));
      expect(csv, contains("'+SUM(1"));
      expect(csv, contains(",'-2+3,"));
      expect(csv, contains(",'@SUM(A1),"));
      expect(csv, contains(",Normal note,"));
      // Amounts stay numeric.
      expect(csv, contains(',10.00,'));
      expect(csv, isNot(contains(",'10.00")));
    });

    test('negative numeric cells in the summary are not neutralized', () {
      final cycle = BudgetCycle(
        id: 'c',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );
      final summary = CycleSummary(
        cycle: cycle,
        totalIncome: const Money.zero(),
        totalBudgeted: const Money.fromMinorUnits(10000),
        totalSpent: const Money.fromMinorUnits(30000),
        positiveUnusedTotal: const Money.zero(),
        netRemainingTotal: const Money.fromMinorUnits(-20000),
        overspentCategoriesCount: 1,
        categoryBudgets: const [
          CategoryBudget(
            categoryId: 'x',
            categoryName: '-Overspent',
            budgetedAmount: Money.fromMinorUnits(10000),
            spentAmount: Money.fromMinorUnits(30000),
          ),
        ],
      );
      final csv = csvService.buildCycleSummaryCsv(summary);
      expect(csv, contains("'-Overspent,100.00,300.00,-200.00,300.0%"));
    });
  });
}
