import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:money_tracker/features/savings/domain/savings_planner.dart';

GoalWithBalance goal(
  String id, {
  int target = 1000000,
  int saved = 0,
  int? plan,
  int priority = 0,
  DateTime? targetDate,
  DateTime? achievedAt,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2025, 1, 1);
  return GoalWithBalance(
    goal: SavingsGoal(
      id: id,
      name: id,
      target: Money.fromMinorUnits(target),
      targetDate: targetDate,
      monthlyPlan: plan == null ? null : Money.fromMinorUnits(plan),
      priority: priority,
      achievedAt: achievedAt,
      createdAt: created,
      updatedAt: created,
    ),
    balance: Money.fromMinorUnits(saved),
  );
}

SavingsMovement move(String goalId, int amount, DateTime at, {SavingsMovementKind kind = SavingsMovementKind.sweep}) =>
    SavingsMovement(
      id: '$goalId-$at-$amount',
      goalId: goalId,
      amount: Money.fromMinorUnits(amount),
      kind: kind,
      groupId: 'g',
      createdAt: at,
    );

void main() {
  const planner = SavingsPlanner(BudgetCycleCalculator(startDay: 1));

  group('splitSurplus', () {
    test('fills monthly plans in priority order, rest to Unassigned', () {
      final split = planner.splitSurplus(const Money.fromMinorUnits(300000), [
        goal('car', plan: 200000, priority: 1),
        goal('eid', plan: 50000, priority: 0),
        goal('trip'), // no plan
      ]);
      expect(split.keys.toList(), ['eid', 'car', null]);
      expect(split.values.map((m) => m.inMinorUnits).toList(), [50000, 200000, 50000]);
    });

    test('stops when the surplus runs out and never overfills a goal', () {
      final split = planner.splitSurplus(const Money.fromMinorUnits(120000), [
        goal('almost', target: 100000, saved: 90000, plan: 50000, priority: 0),
        goal('big', plan: 200000, priority: 1),
        goal('last', plan: 10000, priority: 2),
      ]);
      expect(split.map((k, v) => MapEntry(k, v.inMinorUnits)), {'almost': 10000, 'big': 110000});
    });

    test('skips achieved and reached goals', () {
      final split = planner.splitSurplus(const Money.fromMinorUnits(10000), [
        goal('done', plan: 5000, achievedAt: DateTime(2026, 1, 1)),
        goal('full', target: 5000, saved: 5000, plan: 5000),
      ]);
      expect(split.map((k, v) => MapEntry(k, v.inMinorUnits)), {null: 10000});
    });
  });

  group('forecast', () {
    final today = DateTime(2026, 6, 10);

    test('counts the closeouts left before the target date', () {
      expect(planner.cyclesLeft(today, DateTime(2026, 12, 31)), 6); // Jul..Dec 1st
      expect(planner.cyclesLeft(today, DateTime(2026, 6, 30)), 1); // same cycle
      expect(planner.cyclesLeft(today, DateTime(2026, 1, 1)), 1); // already passed
      expect(
        planner.requiredPerCycle(const Money.fromMinorUnits(1000000), DateTime(2026, 12, 31), today).inMinorUnits,
        166667,
      );
    });

    test('average uses the last 3 cycles and ignores transfers', () {
      final g = goal('car');
      final movements = [
        move('car', 300000, DateTime(2026, 6, 2)),
        move('car', 300000, DateTime(2026, 5, 2)),
        move('car', 300000, DateTime(2026, 4, 2)),
        move('car', 900000, DateTime(2026, 3, 2)), // outside the window
        move('car', 500000, DateTime(2026, 6, 3), kind: SavingsMovementKind.transfer),
        move('car', -150000, DateTime(2026, 5, 20), kind: SavingsMovementKind.withdraw),
        move('eid', 999, DateTime(2026, 6, 2)),
      ];
      expect(planner.averagePerCycle(g.goal, movements, today).inMinorUnits, 250000);
    });

    test('a young goal averages over the cycles it has existed', () {
      final g = goal('new', createdAt: DateTime(2026, 6, 1));
      final avg = planner.averagePerCycle(g.goal, [move('new', 200000, DateTime(2026, 6, 2))], today);
      expect(avg.inMinorUnits, 200000);
    });

    test('on track, behind, and the projected date', () {
      final movements = [
        move('car', 200000, DateTime(2026, 6, 2)),
        move('car', 200000, DateTime(2026, 5, 2)),
        move('car', 200000, DateTime(2026, 4, 2)),
      ];
      final onTrack = planner.forecast(
        goal('car', target: 2000000, saved: 1000000, targetDate: DateTime(2026, 12, 31)),
        movements,
        today,
      );
      expect(onTrack.requiredPerCycle!.inMinorUnits, 166667);
      expect(onTrack.pace, GoalPace.onTrack);
      // 1,000,000 left at 200,000 a cycle = 5 closeouts: 1 Jul .. 1 Nov.
      expect(onTrack.projectedDate, DateTime(2026, 11, 1));

      final behind = planner.forecast(
        goal('car', target: 2000000, saved: 1000000, targetDate: DateTime(2026, 8, 31)),
        movements,
        today,
      );
      expect(behind.pace, GoalPace.behind);
      expect(behind.requiredPerCycle!.inMinorUnits, 500000);

      final noDate = planner.forecast(goal('car', target: 2000000, saved: 1000000), movements, today);
      expect(noDate.pace, GoalPace.noTargetDate);
      expect(noDate.requiredPerCycle, isNull);

      final stalled = planner.forecast(goal('car', target: 2000000, saved: 1000000), const [], today);
      expect(stalled.projectedDate, isNull);
    });
  });
}
