import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/domain/budget_calculation_service.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late BudgetCycleRepository cycleRepo;
  late TransactionRepository txRepo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    cycleRepo = BudgetCycleRepository(db);
    txRepo = TransactionRepository(db);

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        categoryRepositoryProvider.overrideWithValue(categoryRepo),
        budgetCycleRepositoryProvider.overrideWithValue(cycleRepo),
        transactionRepositoryProvider.overrideWithValue(txRepo),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Category Type Splitting (Expense vs Income) Tests', () {
    test(
      'Can create expense and income categories with distinct types',
      () async {
        final expenseCat = await categoryRepo.createCategory(
          name: 'Groceries',
          type: CategoryType.expense,
          defaultBudget: const Money.fromMinorUnits(200000),
        );

        final incomeCat = await categoryRepo.createCategory(
          name: 'Salary',
          type: CategoryType.income,
        );

        expect(expenseCat.type, CategoryType.expense);
        expect(expenseCat.type.isExpense, isTrue);
        expect(expenseCat.type.isIncome, isFalse);

        expect(incomeCat.type, CategoryType.income);
        expect(incomeCat.type.isIncome, isTrue);
        expect(incomeCat.type.isExpense, isFalse);
      },
    );

    test('getAllCategories filters accurately by CategoryType', () async {
      await categoryRepo.createCategory(
        name: 'Rent',
        type: CategoryType.expense,
      );
      await categoryRepo.createCategory(
        name: 'Food',
        type: CategoryType.expense,
      );
      await categoryRepo.createCategory(
        name: 'Salary',
        type: CategoryType.income,
      );
      await categoryRepo.createCategory(
        name: 'Freelance',
        type: CategoryType.income,
      );

      final expenses = await categoryRepo.getAllCategories(
        type: CategoryType.expense,
      );
      final incomes = await categoryRepo.getAllCategories(
        type: CategoryType.income,
      );
      final all = await categoryRepo.getAllCategories();

      expect(expenses.length, 2);
      expect(expenses.every((c) => c.type == CategoryType.expense), isTrue);

      expect(incomes.length, 2);
      expect(incomes.every((c) => c.type == CategoryType.income), isTrue);

      expect(all.length, 4);
    });

    test('Category name uniqueness is scoped to its CategoryType', () async {
      // Allowed: same name across different types (e.g. Investments expense vs Investments income)
      final expInvest = await categoryRepo.createCategory(
        name: 'Investments',
        type: CategoryType.expense,
      );
      final incInvest = await categoryRepo.createCategory(
        name: 'Investments',
        type: CategoryType.income,
      );

      expect(expInvest.id, isNot(incInvest.id));
      expect(expInvest.name, 'Investments');
      expect(incInvest.name, 'Investments');

      // Rejected: duplicate name within the same type
      expect(
        () => categoryRepo.createCategory(
          name: '  investments  ',
          type: CategoryType.expense,
        ),
        throwsA(isA<DuplicateCategoryNameException>()),
      );

      expect(
        () => categoryRepo.createCategory(
          name: 'INVESTMENTS',
          type: CategoryType.income,
        ),
        throwsA(isA<DuplicateCategoryNameException>()),
      );
    });
  });

  group('Budget Cycle Snapshot & Calculation Isolation Tests', () {
    test(
      'getOrCreateCycleForDate snapshots ONLY active expense categories',
      () async {
        await categoryRepo.createCategory(
          name: 'Dining',
          type: CategoryType.expense,
          defaultBudget: const Money.fromMinorUnits(50000),
        );
        await categoryRepo.createCategory(
          name: 'Salary',
          type: CategoryType.income,
        );

        final cycle = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 10, 16),
        );
        final budgets = await cycleRepo.getCycleBudgets(cycle.id);

        // Only the expense category should be in category_budgets
        expect(budgets.length, 1);
        final allCats = await categoryRepo.getAllCategories();
        final diningCat = allCats.firstWhere((c) => c.name == 'Dining');
        final salaryCat = allCats.firstWhere((c) => c.name == 'Salary');

        expect(budgets.containsKey(diningCat.id), isTrue);
        expect(budgets.containsKey(salaryCat.id), isFalse);
      },
    );

    test(
      'BudgetCalculationService excludes income categories from categoryBudgets',
      () async {
        final expCat = await categoryRepo.createCategory(
          name: 'Shopping',
          type: CategoryType.expense,
          defaultBudget: const Money.fromMinorUnits(30000),
        );
        final incCat = await categoryRepo.createCategory(
          name: 'Dividends',
          type: CategoryType.income,
        );

        final cycle = BudgetCycle(
          id: 'cycle-1',
          startDate: DateTime(2026, 9, 25),
          endDate: DateTime(2026, 10, 24),
        );

        final allCategories = [expCat, incCat];
        final budgetMap = {expCat.id: const Money.fromMinorUnits(30000)};
        final transactions = [
          TransactionModel(
            id: 'tx-1',
            type: TransactionType.income,
            amount: const Money.fromMinorUnits(150000),
            categoryId: incCat.id,
            date: DateTime(2026, 10, 1),
            createdAt: DateTime(2026, 10, 1),
            updatedAt: DateTime(2026, 10, 1),
          ),
          TransactionModel(
            id: 'tx-2',
            type: TransactionType.expense,
            amount: const Money.fromMinorUnits(10000),
            categoryId: expCat.id,
            date: DateTime(2026, 10, 5),
            createdAt: DateTime(2026, 10, 5),
            updatedAt: DateTime(2026, 10, 5),
          ),
        ];

        const calcService = BudgetCalculationService();
        final summary = calcService.calculateCycleSummary(
          cycle: cycle,
          categories: allCategories,
          budgetMap: budgetMap,
          transactions: transactions,
        );

        expect(summary.totalIncome.inMinorUnits, 150000);
        expect(summary.totalSpent.inMinorUnits, 10000);
        expect(summary.totalBudgeted.inMinorUnits, 30000);

        // categoryBudgets must contain ONLY the expense category
        expect(summary.categoryBudgets.length, 1);
        expect(summary.categoryBudgets.first.categoryId, expCat.id);
        expect(summary.categoryBudgets.first.categoryName, 'Shopping');
      },
    );
  });

  group('Navigation & Tab Persistence Tests', () {
    test(
      'currentNavigationIndexProvider retains selected tab across refreshTrigger updates',
      () {
        // Default tab is 0 (Dashboard)
        expect(container.read(currentNavigationIndexProvider), 0);

        // Switch to Budgets tab (index 2)
        container.read(currentNavigationIndexProvider.notifier).setIndex(2);
        expect(container.read(currentNavigationIndexProvider), 2);

        // Simulate database mutation triggering refresh
        container.read(refreshTriggerProvider.notifier).trigger();
        container.read(refreshTriggerProvider.notifier).trigger();

        // Tab index must still be 2 (Budgets)
        expect(container.read(currentNavigationIndexProvider), 2);
      },
    );
  });

  group('Category Deletion, Renaming Cascade, and Zero-Category Lifecycle', () {
    test('Zero-category launch creates cycle without errors', () async {
      final categories = await categoryRepo.getAllCategories();
      expect(categories, isEmpty);

      final cycle = await cycleRepo.getOrCreateCycleForDate(
        DateTime(2026, 10, 16),
      );
      expect(cycle, isNotNull);

      final budgets = await cycleRepo.getCycleBudgets(cycle.id);
      expect(budgets, isEmpty);
    });

    test(
      'Deleting category preserves transaction history and categoryName',
      () async {
        final cat = await categoryRepo.createCategory(
          name: 'Coffee & Snacks',
          type: CategoryType.expense,
        );

        final tx = await txRepo.addTransaction(
          type: TransactionType.expense,
          amount: const Money.fromMinorUnits(7500),
          categoryId: cat.id,
          date: DateTime(2026, 10, 16),
          note: 'Morning espresso',
        );

        expect(tx.categoryName, 'Coffee & Snacks');

        // Delete category
        await categoryRepo.deleteCategory(cat.id);

        // Category record is gone
        expect(await categoryRepo.getCategoryById(cat.id), isNull);

        // Transaction is still intact and keeps Coffee & Snacks name
        final allTxs = await txRepo.getAllTransactions();
        expect(allTxs.length, 1);
        expect(allTxs.first.id, tx.id);
        expect(allTxs.first.categoryId, isNull);
        expect(allTxs.first.categoryName, 'Coffee & Snacks');
        expect(allTxs.first.amount, const Money.fromMinorUnits(7500));
        expect(allTxs.first.note, 'Morning espresso');
      },
    );

    test('Renaming category cascades to existing transactions', () async {
      final cat = await categoryRepo.createCategory(
        name: 'Gym',
        type: CategoryType.expense,
      );

      final tx = await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(150000),
        categoryId: cat.id,
        date: DateTime(2026, 10, 16),
      );
      expect(tx.categoryName, 'Gym');

      // Rename Gym -> Fitness Center
      await categoryRepo.updateCategory(id: cat.id, name: 'Fitness Center');

      final updatedTxs = await txRepo.getAllTransactions();
      expect(updatedTxs.first.id, tx.id);
      expect(updatedTxs.first.categoryName, 'Fitness Center');
    });
  });
}
