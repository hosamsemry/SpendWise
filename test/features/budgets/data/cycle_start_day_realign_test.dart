import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late Category food;
  final today = DateTime(2026, 11, 21);

  BudgetCycleRepository repo(int startDay) => BudgetCycleRepository(
        db,
        calculator: BudgetCycleCalculator(startDay: startDay),
      );

  /// Recorded cycles as sorted `start..end` strings.
  Future<List<String>> ranges() async {
    final rows = await db.select(db.budgetCyclesTable).get();
    return (rows.map((r) => '${r.startDate}..${r.endDate}').toList())..sort();
  }

  Future<void> expectNoOverlaps() async {
    final rows = (await db.select(db.budgetCyclesTable).get())
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    for (var i = 1; i < rows.length; i++) {
      expect(
        rows[i].startDate.compareTo(rows[i - 1].endDate) > 0,
        isTrue,
        reason: '${rows[i - 1].startDate}..${rows[i - 1].endDate} overlaps '
            '${rows[i].startDate}..${rows[i].endDate}',
      );
    }
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    food = await CategoryRepository(db).createCategory(
      name: 'Food',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(100000),
    );
  });

  tearDown(() => db.close());

  test('start day 1 -> 25 reuses the current cycle instead of overlapping it',
      () async {
    final old = await repo(1).getOrCreateCycleForDate(today); // Nov 1..30
    await repo(1).updateCategoryBudget(
      cycleId: old.id,
      categoryId: food.id,
      budgetAmount: const Money.fromMinorUnits(77700),
    );

    final current = await repo(25).realignCyclesOnStartDayChange(25, today: today);

    expect(await ranges(), ['2026-10-25..2026-11-24']);
    expect(current.id, old.id, reason: 'same row moved onto the new range');
    expect(
      (await repo(25).getCycleBudgets(current.id))[food.id]?.inMinorUnits,
      77700,
      reason: 'custom budget of the current cycle is kept',
    );

    final dec = await repo(25).getOrCreateCycleForDate(DateTime(2026, 12, 2));
    expect(dec.startDateString, '2026-11-25');
    expect(dec.endDateString, '2026-12-24');
    expect(dec.contains(DateTime(2026, 12, 2)), isTrue);
    await expectNoOverlaps();
  });

  test('start day 25 -> 1 truncates the old cycle and carries its budgets',
      () async {
    final sep = await repo(25).getOrCreateCycleForDate(DateTime(2026, 10, 1));
    final old = await repo(25).getOrCreateCycleForDate(today); // Oct 25..Nov 24
    await repo(25).updateCategoryBudget(
      cycleId: old.id,
      categoryId: food.id,
      budgetAmount: const Money.fromMinorUnits(55500),
    );

    final current = await repo(1).realignCyclesOnStartDayChange(1, today: today);

    expect(await ranges(), [
      '2026-09-25..2026-10-24', // untouched history
      '2026-10-25..2026-10-31', // truncated old current cycle
      '2026-11-01..2026-11-30', // new current cycle
    ]);
    expect(current.startDateString, '2026-11-01');
    expect(current.id, isNot(old.id));
    expect(
      (await repo(1).getCycleBudgets(current.id))[food.id]?.inMinorUnits,
      55500,
      reason: 'new current cycle inherits the budgets that were current',
    );
    expect(
      (await repo(1).getCycleBudgets(sep.id))[food.id]?.inMinorUnits,
      100000,
      reason: 'past cycles keep their own snapshot',
    );
    await expectNoOverlaps();
  });

  test('future cycles on the old schedule are removed with their rows',
      () async {
    await repo(1).getOrCreateCycleForDate(today); // Nov
    final jan = await repo(1).getOrCreateCycleForDate(DateTime(2027, 1, 10));
    await db.into(db.notificationEventsTable).insert(
          NotificationEventsTableCompanion.insert(
            id: 'evt',
            cycleId: jan.id,
            categoryId: food.id,
            eventType: 'over_budget',
            createdAt: today.toIso8601String(),
          ),
        );

    await repo(25).realignCyclesOnStartDayChange(25, today: today);

    expect(await ranges(), ['2026-10-25..2026-11-24']);
    expect(await repo(25).getCycleBudgets(jan.id), isEmpty);
    expect(await db.select(db.notificationEventsTable).get(), isEmpty);

    final newJan = await repo(25).getOrCreateCycleForDate(DateTime(2027, 1, 10));
    expect(newJan.startDateString, '2026-12-25');
    await expectNoOverlaps();
  });

  test('realigning to the same start day is a no-op', () async {
    final cycle = await repo(25).getOrCreateCycleForDate(today);
    final again = await repo(25).realignCyclesOnStartDayChange(25, today: today);
    expect(again.id, cycle.id);
    expect(await ranges(), ['2026-10-25..2026-11-24']);
  });

  test('getOrCreate fills the gap next to a truncated cycle without overlap',
      () async {
    // Truncated cycle Oct 25..Oct 31 left over, calculator still on day 25.
    await db.into(db.budgetCyclesTable).insert(
          BudgetCyclesTableCompanion.insert(
            id: 'truncated',
            startDate: '2026-10-25',
            endDate: '2026-10-31',
            createdAt: today.toIso8601String(),
          ),
        );

    final nov = await repo(25).getOrCreateCycleForDate(DateTime(2026, 11, 5));
    expect(nov.contains(DateTime(2026, 11, 5)), isTrue);
    expect(nov.startDateString, '2026-11-01');
    expect(nov.endDateString, '2026-11-24');
    await expectNoOverlaps();
  });

  test('a cycle found by lookup always contains the requested date', () async {
    await db.into(db.budgetCyclesTable).insert(
          BudgetCyclesTableCompanion.insert(
            id: 'short',
            startDate: '2026-11-25',
            endDate: '2026-11-27',
            createdAt: today.toIso8601String(),
          ),
        );
    // Same computed start (Nov 25) but the stored cycle ends earlier.
    final c = await repo(25).getOrCreateCycleForDate(DateTime(2026, 12, 2));
    expect(c.contains(DateTime(2026, 12, 2)), isTrue);
    expect(c.id, isNot('short'));
    await expectNoOverlaps();
  });
}
