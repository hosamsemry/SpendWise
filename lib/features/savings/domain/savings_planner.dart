import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';

enum GoalPace {
  /// Saving fast enough to reach the target by its date (or already there).
  onTrack,
  behind,

  /// No target date, so there is nothing to be on track for.
  noTargetDate,
}

class GoalForecast {
  /// What each remaining cycle needs to reach the target by its date.
  final Money? requiredPerCycle;

  /// Average new saving per cycle over the recent window.
  final Money averagePerCycle;
  final GoalPace pace;

  /// When the target is reached at [averagePerCycle]; null if already
  /// reached or nothing is being saved.
  final DateTime? projectedDate;

  const GoalForecast({
    this.requiredPerCycle,
    required this.averagePerCycle,
    required this.pace,
    this.projectedDate,
  });
}

/// Pure savings-goal maths: splitting a cycle's surplus between goals and
/// forecasting each goal. Cycles follow [calculator] (the user's start day).
class SavingsPlanner {
  final BudgetCycleCalculator calculator;

  /// Cycles (including the current one) averaged for the saving pace.
  static const int paceWindowCycles = 3;

  const SavingsPlanner(this.calculator);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Splits [surplus] for the cycle closeout: goals in priority order each
  /// get their monthly plan (never more than they still need), and the rest
  /// goes to Unassigned (key `null`). Goals without a plan, and goals that are
  /// achieved or already reached, get nothing. Only non-zero shares are
  /// returned, in fill order.
  Map<String?, Money> splitSurplus(Money surplus, List<GoalWithBalance> goals) {
    final result = <String?, Money>{}; // insertion-ordered
    var left = surplus.inMinorUnits;
    final ordered = [...goals]..sort((a, b) {
        final byPriority = a.goal.priority.compareTo(b.goal.priority);
        return byPriority != 0 ? byPriority : a.goal.createdAt.compareTo(b.goal.createdAt);
      });
    for (final g in ordered) {
      if (left <= 0) break;
      final plan = g.goal.monthlyPlan?.inMinorUnits ?? 0;
      if (plan <= 0 || g.goal.isAchieved || g.isReached) continue;
      var share = plan;
      if (share > g.remaining.inMinorUnits) share = g.remaining.inMinorUnits;
      if (share > left) share = left;
      if (share <= 0) continue;
      result[g.goal.id] = Money.fromMinorUnits(share);
      left -= share;
    }
    if (left > 0) result[null] = Money.fromMinorUnits(left);
    return result;
  }

  /// Number of cycle closeouts after [today] up to [targetDate] (at least 1,
  /// so an overdue or same-cycle target still asks for the full remainder).
  int cyclesLeft(DateTime today, DateTime targetDate) {
    final t = _day(today);
    final end = _day(targetDate);
    var count = 0;
    var cycle = calculator.getNextCycle(calculator.getCycleForDate(t));
    while (!cycle.startDate.isAfter(end) && count < 1200) {
      count++;
      cycle = calculator.getNextCycle(cycle);
    }
    return count < 1 ? 1 : count;
  }

  /// Per-cycle saving needed to cover [remaining] by [targetDate], rounded up.
  Money requiredPerCycle(Money remaining, DateTime targetDate, DateTime today) {
    final n = cyclesLeft(today, targetDate);
    final r = remaining.inMinorUnits;
    return Money.fromMinorUnits(r <= 0 ? 0 : (r + n - 1) ~/ n);
  }

  /// Average new saving per cycle for a goal over the last
  /// [paceWindowCycles] cycles (current included), or fewer if the goal is
  /// younger. Sweeps, deposits and withdrawals count; moving existing
  /// savings between goals (transfers) is not new saving, so it doesn't.
  Money averagePerCycle(SavingsGoal goal, List<SavingsMovement> movements, DateTime today) {
    var windowStart = calculator.getCycleForDate(_day(today));
    var cycles = 1;
    final created = _day(goal.createdAt);
    while (cycles < paceWindowCycles) {
      final prev = calculator.getPreviousCycle(windowStart);
      if (prev.endDate.isBefore(created)) break;
      windowStart = prev;
      cycles++;
    }
    var total = 0;
    for (final m in movements) {
      if (m.goalId != goal.id) continue;
      if (m.kind == SavingsMovementKind.transfer || m.kind == SavingsMovementKind.opening) continue;
      if (_day(m.createdAt).isBefore(windowStart.startDate)) continue;
      total += m.amount.inMinorUnits;
    }
    return Money.fromMinorUnits(total ~/ cycles);
  }

  GoalForecast forecast(GoalWithBalance g, List<SavingsMovement> movements, DateTime today) {
    final average = averagePerCycle(g.goal, movements, today);
    if (g.isReached) {
      return GoalForecast(
        averagePerCycle: average,
        pace: g.goal.targetDate == null ? GoalPace.noTargetDate : GoalPace.onTrack,
      );
    }

    DateTime? projected;
    final avg = average.inMinorUnits;
    if (avg > 0) {
      final needed = (g.remaining.inMinorUnits + avg - 1) ~/ avg;
      var cycle = calculator.getCycleForDate(_day(today));
      for (var i = 0; i < needed && i < 1200; i++) {
        cycle = calculator.getNextCycle(cycle);
      }
      projected = cycle.startDate;
    }

    final targetDate = g.goal.targetDate;
    if (targetDate == null) {
      return GoalForecast(
        averagePerCycle: average,
        pace: GoalPace.noTargetDate,
        projectedDate: projected,
      );
    }
    final required = requiredPerCycle(g.remaining, targetDate, today);
    return GoalForecast(
      requiredPerCycle: required,
      averagePerCycle: average,
      pace: avg >= required.inMinorUnits ? GoalPace.onTrack : GoalPace.behind,
      projectedDate: projected,
    );
  }
}
