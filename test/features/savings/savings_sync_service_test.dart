import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/savings/domain/savings_sync_service.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late BudgetCycleRepository cycleRepo;
  late TransactionRepository txRepo;
  late SavingsSyncService syncService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    cycleRepo = BudgetCycleRepository(db);
    txRepo = TransactionRepository(db);
    syncService = SavingsSyncService(
      db: db,
      categoryRepo: categoryRepo,
      cycleRepo: cycleRepo,
      txRepo: txRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SavingsSyncService Tests', () {
    test('ensureSavingsCategory creates Savings category if absent and reuses existing', () async {
      final cat1 = await syncService.ensureSavingsCategory();
      expect(cat1.name, 'Savings');
      expect(cat1.type, CategoryType.expense);
      expect(cat1.color, '#10B981');
      expect(cat1.isActive, isTrue);

      // Re-calling returns the same category without creating duplicates
      final cat2 = await syncService.ensureSavingsCategory();
      expect(cat2.id, cat1.id);

      final allCats = await categoryRepo.getAllCategories(includeInactive: true);
      final savingsList = allCats.where((c) => c.name.toLowerCase() == 'savings').toList();
      expect(savingsList.length, 1);
    });

    test('ensureSavingsCategory unarchives inactive Savings category', () async {
      final cat = await syncService.ensureSavingsCategory();
      await categoryRepo.archiveCategory(cat.id);

      final catArchived = await categoryRepo.getCategoryById(cat.id);
      expect(catArchived!.isActive, isFalse);

      final restored = await syncService.ensureSavingsCategory();
      expect(restored.id, cat.id);
      expect(restored.isActive, isTrue);
    });

    test('syncSavingsBudgetForCycle allocates unallocated income to Savings', () async {
      // 1. Create a budget cycle for Jan 26, 2026
      final cycle = await cycleRepo.getOrCreateCycleForDate(DateTime(2026, 1, 26));

      // 2. Create categories and set budgets
      final foodCat = await categoryRepo.createCategory(
        name: 'Food',
        type: CategoryType.expense,
        defaultBudget: Money.fromMajorUnits(5000),
      );
      final rentCat = await categoryRepo.createCategory(
        name: 'Rent',
        type: CategoryType.expense,
        defaultBudget: Money.fromMajorUnits(3000),
      );

      await cycleRepo.updateCategoryBudget(
        cycleId: cycle.id,
        categoryId: foodCat.id,
        budgetAmount: Money.fromMajorUnits(5000),
      );
      await cycleRepo.updateCategoryBudget(
        cycleId: cycle.id,
        categoryId: rentCat.id,
        budgetAmount: Money.fromMajorUnits(3000),
      );
      // Other budgets total = 8,000 EGP

      // 3. Add 10,000 EGP income transaction
      await txRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(10000),
        date: DateTime(2026, 1, 26),
        note: 'January Salary',
      );

      // 4. Run sync: 10,000 - 8,000 = 2,000 EGP Savings
      final savingsBudget = await syncService.syncSavingsBudgetForCycle(
        cycleId: cycle.id,
      );
      expect(savingsBudget.inMajorUnits, 2000.0);

      final cycleBudgets = await cycleRepo.getCycleBudgets(cycle.id);
      final savingsCat = await syncService.ensureSavingsCategory();
      expect(cycleBudgets[savingsCat.id]?.inMajorUnits, 2000.0);

      // 5. Increasing Food budget by 500 decreases Savings to 1,500 EGP
      await cycleRepo.updateCategoryBudget(
        cycleId: cycle.id,
        categoryId: foodCat.id,
        budgetAmount: Money.fromMajorUnits(5500),
      );
      final updatedSavingsBudget = await syncService.syncSavingsBudgetForCycle(
        cycleId: cycle.id,
      );
      expect(updatedSavingsBudget.inMajorUnits, 1500.0);

      final cycleBudgets2 = await cycleRepo.getCycleBudgets(cycle.id);
      expect(cycleBudgets2[savingsCat.id]?.inMajorUnits, 1500.0);

      // 6. Adding 2,000 EGP income increases Savings to 3,500 EGP
      await txRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(2000),
        date: DateTime(2026, 1, 27),
        note: 'Freelance Bonus',
      );
      final increasedSavings = await syncService.syncSavingsBudgetForCycle(
        cycleId: cycle.id,
      );
      expect(increasedSavings.inMajorUnits, 3500.0);

      // 7. If other budgets exceed total income, Savings is clamped at 0
      await cycleRepo.updateCategoryBudget(
        cycleId: cycle.id,
        categoryId: rentCat.id,
        budgetAmount: Money.fromMajorUnits(10000),
      ); // Total other budgets = 5500 + 10000 = 15500 > 12000
      final clampedSavings = await syncService.syncSavingsBudgetForCycle(
        cycleId: cycle.id,
      );
      expect(clampedSavings.inMajorUnits, 0.0);

      final cycleBudgets3 = await cycleRepo.getCycleBudgets(cycle.id);
      expect(cycleBudgets3[savingsCat.id]?.inMajorUnits, 0.0);
    });

    test('syncSavingsBudgetForCycle handles cycle with zero income gracefully', () async {
      final cycle = await cycleRepo.getOrCreateCycleForDate(DateTime(2026, 3, 26));

      final foodCat = await categoryRepo.createCategory(
        name: 'Dining',
        type: CategoryType.expense,
        defaultBudget: Money.fromMajorUnits(2000),
      );
      await cycleRepo.updateCategoryBudget(
        cycleId: cycle.id,
        categoryId: foodCat.id,
        budgetAmount: Money.fromMajorUnits(2000),
      );

      final savingsBudget = await syncService.syncSavingsBudgetForCycle(
        cycleId: cycle.id,
      );
      expect(savingsBudget.inMajorUnits, 0.0);
    });
  });
}
