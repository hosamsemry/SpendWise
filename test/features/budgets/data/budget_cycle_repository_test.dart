import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late BudgetCycleRepository cycleRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    cycleRepo = BudgetCycleRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BudgetCycleRepository Tests — Spec Section 16', () {
    test('Creating a cycle snapshots active category defaults', () async {
      final food = await categoryRepo.createCategory(
        name: 'Food',
        defaultBudget: Money.fromMajorUnits(2000),
      );
      final transport = await categoryRepo.createCategory(
        name: 'Transport',
        defaultBudget: Money.fromMajorUnits(1000),
      );

      final cycle = await cycleRepo.getOrCreateCycleForDate(
        DateTime(2026, 10, 25),
      );
      expect(cycle.startDateString, '2026-10-25');
      expect(cycle.endDateString, '2026-11-24');

      final budgets = await cycleRepo.getCycleBudgets(cycle.id);
      expect(budgets[food.id], Money.fromMajorUnits(2000));
      expect(budgets[transport.id], Money.fromMajorUnits(1000));
    });

    test(
      'Re-running cycle creation does not duplicate records (Idempotency)',
      () async {
        await categoryRepo.createCategory(
          name: 'Food',
          defaultBudget: Money.fromMajorUnits(2000),
        );

        final cycle1 = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 10, 26),
        );
        final cycle2 = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 11, 2),
        );

        expect(cycle1.id, cycle2.id);

        final allCycles = await cycleRepo.getAllCycles();
        expect(allCycles.length, 1);

        final budgets = await cycleRepo.getCycleBudgets(cycle1.id);
        expect(budgets.length, 1);
      },
    );

    test(
      'Updating a category default affects future cycles only (Historical cycle preserved)',
      () async {
        final food = await categoryRepo.createCategory(
          name: 'Food',
          defaultBudget: Money.fromMajorUnits(2000),
        );

        // 1. Create first cycle (Oct 2026)
        final cycle1 = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 10, 25),
        );
        expect(
          (await cycleRepo.getCycleBudgets(cycle1.id))[food.id],
          Money.fromMajorUnits(2000),
        );

        // 2. Change category default allocation
        await categoryRepo.updateCategory(
          id: food.id,
          defaultBudget: Money.fromMajorUnits(3000),
        );

        // 3. Historical cycle 1 budget remains 2,000 EGP!
        expect(
          (await cycleRepo.getCycleBudgets(cycle1.id))[food.id],
          Money.fromMajorUnits(2000),
        );

        // 4. Create second cycle (Nov 2026) -> uses the new default of 3,000 EGP
        final cycle2 = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 11, 25),
        );
        expect(
          (await cycleRepo.getCycleBudgets(cycle2.id))[food.id],
          Money.fromMajorUnits(3000),
        );
      },
    );

    test(
      'Editing a cycle budget directly affects only that cycle unless default is explicitly updated',
      () async {
        final food = await categoryRepo.createCategory(
          name: 'Food',
          defaultBudget: Money.fromMajorUnits(2000),
        );

        final cycle = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 10, 25),
        );

        // Edit this cycle's budget to 2500 without updating default allocation
        await cycleRepo.updateCategoryBudget(
          cycleId: cycle.id,
          categoryId: food.id,
          budgetAmount: Money.fromMajorUnits(2500),
          updateDefaultAllocation: false,
        );

        // Cycle budget is updated
        expect(
          (await cycleRepo.getCycleBudgets(cycle.id))[food.id],
          Money.fromMajorUnits(2500),
        );

        // Category default is STILL 2000
        final refreshedCat = await categoryRepo.getCategoryById(food.id);
        expect(refreshedCat!.defaultBudget, Money.fromMajorUnits(2000));

        // Now edit with updateDefaultAllocation = true
        await cycleRepo.updateCategoryBudget(
          cycleId: cycle.id,
          categoryId: food.id,
          budgetAmount: Money.fromMajorUnits(2800),
          updateDefaultAllocation: true,
        );

        expect(
          (await cycleRepo.getCycleBudgets(cycle.id))[food.id],
          Money.fromMajorUnits(2800),
        );
        final updatedCat = await categoryRepo.getCategoryById(food.id);
        expect(updatedCat!.defaultBudget, Money.fromMajorUnits(2800));
      },
    );

    test(
      'getCycleForDateOrNull finds recorded historical cycle even when calculator startDay changes',
      () async {
        // 1. Initially cycle created with startDay = 1 (1 May 2026 to 31 May 2026)
        final repoDay1 = BudgetCycleRepository(
          db,
          calculator: const BudgetCycleCalculator(startDay: 1),
        );
        final cycleMay = await repoDay1.getOrCreateCycleForDate(
          DateTime(2026, 5, 10),
        );
        expect(cycleMay.startDateString, '2026-05-01');
        expect(cycleMay.endDateString, '2026-05-31');

        // 2. Later user changes startDay to 25
        final repoDay25 = BudgetCycleRepository(
          db,
          calculator: const BudgetCycleCalculator(startDay: 25),
        );

        // 3. Querying for 10 May 2026 should still return the recorded May cycle (2026-05-01 to 2026-05-31)
        final found = await repoDay25.getCycleForDateOrNull(
          DateTime(2026, 5, 10),
        );
        expect(found, isNotNull);
        expect(found!.id, cycleMay.id);
        expect(found.startDateString, '2026-05-01');
        expect(found.endDateString, '2026-05-31');
      },
    );
  });
}
