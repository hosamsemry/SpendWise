import 'budget_cycle.dart';
import 'budget_cycle_calculator.dart';

/// The budget cycles as the app actually has them: the [recorded] cycles where
/// they exist, and elsewhere cycles computed from [calculator] and shrunk to
/// fit between the recorded ones, exactly as
/// `BudgetCycleRepository.getOrCreateCycleForDate` creates them.
///
/// History must come from here rather than from [calculator] alone: after the
/// user changes their start day, the calculator describes the new schedule,
/// but past cycles (and anything keyed to their start dates, like "every
/// cycle" bill payments) still follow the old one.
class BudgetCycleTimeline {
  final BudgetCycleCalculator calculator;
  final List<BudgetCycle> recorded;

  const BudgetCycleTimeline(this.calculator, this.recorded);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// The cycle containing [date]: the recorded one if any, otherwise the
  /// computed cycle shrunk so it never overlaps a recorded cycle.
  BudgetCycle cycleContaining(DateTime date) {
    final target = _day(date);
    for (final cycle in recorded) {
      if (cycle.contains(target)) return cycle;
    }
    final computed = calculator.getCycleForDate(target);
    var start = computed.startDate;
    var end = computed.endDate;
    for (final cycle in recorded) {
      if (cycle.endDate.isBefore(target) && !cycle.endDate.isBefore(start)) {
        start = _addDays(cycle.endDate, 1);
      }
      if (cycle.startDate.isAfter(target) && !cycle.startDate.isAfter(end)) {
        end = _addDays(cycle.startDate, -1);
      }
    }
    return BudgetCycle(
      id: '${BudgetCycleCalculator.formatDate(start)}_${BudgetCycleCalculator.formatDate(end)}',
      startDate: start,
      endDate: end,
    );
  }

  /// The cycle right after [cycle].
  BudgetCycle next(BudgetCycle cycle) => cycleContaining(_addDays(cycle.endDate, 1));

  /// The cycle right before [cycle].
  BudgetCycle previous(BudgetCycle cycle) =>
      cycleContaining(_addDays(cycle.startDate, -1));
}
