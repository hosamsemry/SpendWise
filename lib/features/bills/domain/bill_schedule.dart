import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/date/budget_cycle_timeline.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/categories/domain/category.dart';

/// Pure date logic for recurring bills: when they fall due, which due dates
/// are still unpaid, how much is committed before the cycle ends, and when to
/// remind.
///
/// "Every cycle" bills fall due on each cycle's start date. Past cycles come
/// from [recordedCycles] (see [BudgetCycleTimeline]), so a start-day change
/// doesn't rewrite history; cycles not recorded yet follow [cycleCalculator]
/// (the user's start day). Without recorded cycles, everything is computed.
class BillSchedule {
  final BudgetCycleCalculator cycleCalculator;
  final List<BudgetCycle> recordedCycles;

  /// How far back unpaid due dates are still shown (and counted) as overdue.
  static const int overdueLookbackDays = 366;

  const BillSchedule(this.cycleCalculator, {this.recordedCycles = const []});

  /// This schedule with the cycles recorded in the database.
  BillSchedule withRecordedCycles(List<BudgetCycle> cycles) =>
      BillSchedule(cycleCalculator, recordedCycles: cycles);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Key used to match a due date with its handled occurrence.
  static String dateKey(DateTime d) => BudgetCycleCalculator.formatDate(d);

  /// All due dates of [bill] between [from] and [to] (inclusive, date only),
  /// oldest first and never before the bill's anchor date.
  List<DateTime> dueDatesBetween(RecurringBill bill, DateTime from, DateTime to) {
    final anchor = _day(bill.anchorDate);
    var start = _day(from);
    final end = _day(to);
    if (start.isBefore(anchor)) start = anchor;
    if (end.isBefore(start)) return const [];

    final result = <DateTime>[];
    switch (bill.frequency) {
      case BillFrequency.weekly:
        final weeksAhead = (start.difference(anchor).inDays / 7).floor();
        for (var k = weeksAhead < 0 ? 0 : weeksAhead;; k++) {
          final d = DateTime(anchor.year, anchor.month, anchor.day + 7 * k);
          if (d.isAfter(end)) break;
          if (!d.isBefore(start)) result.add(d);
        }
      case BillFrequency.monthly:
        final firstOffset =
            (start.year - anchor.year) * 12 + start.month - anchor.month - 1;
        for (var m = firstOffset < 0 ? 0 : firstOffset;; m++) {
          final first = DateTime(anchor.year, anchor.month + m, 1);
          final d = DateTime(
            first.year,
            first.month,
            BudgetCycleCalculator.clampedDay(first.year, first.month, anchor.day),
          );
          if (d.isAfter(end)) break;
          if (!d.isBefore(start)) result.add(d);
        }
      case BillFrequency.yearly:
        for (var y = start.year - 1 < anchor.year ? anchor.year : start.year - 1;; y++) {
          final d = DateTime(
            y,
            anchor.month,
            BudgetCycleCalculator.clampedDay(y, anchor.month, anchor.day),
          );
          if (d.isAfter(end)) break;
          if (!d.isBefore(start)) result.add(d);
        }
      case BillFrequency.everyCycle:
        final timeline = BudgetCycleTimeline(cycleCalculator, recordedCycles);
        var cycle = timeline.cycleContaining(start);
        while (!cycle.startDate.isAfter(end)) {
          final d = _day(cycle.startDate);
          if (!d.isBefore(start)) result.add(d);
          cycle = timeline.next(cycle);
        }
    }
    return result;
  }

  /// The first due date of [bill] on or after [date] (within two years).
  DateTime? nextDueOnOrAfter(RecurringBill bill, DateTime date) {
    final from = _day(date);
    final dues = dueDatesBetween(bill, from, DateTime(from.year + 2, from.month, from.day));
    return dues.isEmpty ? null : dues.first;
  }

  /// Unpaid due dates of active [bills] from the overdue lookback window up to
  /// [until], sorted by due date. [handled] maps bill id to the [dateKey]s
  /// already paid or skipped.
  List<BillDue> unpaidDues({
    required List<RecurringBill> bills,
    required Map<String, Set<String>> handled,
    required DateTime today,
    required DateTime until,
  }) {
    final from = _day(today).subtract(const Duration(days: overdueLookbackDays));
    final dues = <BillDue>[];
    for (final bill in bills) {
      if (!bill.isActive) continue;
      final done = handled[bill.id] ?? const <String>{};
      for (final d in dueDatesBetween(bill, from, until)) {
        if (!done.contains(dateKey(d))) dues.add(BillDue(bill: bill, dueDate: d));
      }
    }
    dues.sort((a, b) {
      final byDate = a.dueDate.compareTo(b.dueDate);
      return byDate != 0 ? byDate : a.bill.title.compareTo(b.bill.title);
    });
    return dues;
  }

  /// Money already promised to unpaid expense bills due by [cycleEnd]
  /// (overdue ones included), which daily safe-to-spend must set aside.
  /// Bills in the Savings envelope are left out, like safe-to-spend itself.
  Money committedUntil({
    required List<RecurringBill> bills,
    required Map<String, Set<String>> handled,
    required DateTime today,
    required DateTime cycleEnd,
  }) {
    var total = 0;
    for (final due in unpaidDues(bills: bills, handled: handled, today: today, until: cycleEnd)) {
      final bill = due.bill;
      if (!bill.isExpense) continue;
      if (bill.categoryName != null && isSavingsCategoryName(bill.categoryName!)) continue;
      total += bill.amount.inMinorUnits;
    }
    return Money.fromMinorUnits(total);
  }

  /// Average cost of [bill] per month, rounded to the nearest minor unit.
  /// "Every cycle" counts as monthly.
  static Money monthlyEquivalent(RecurringBill bill) {
    final minor = bill.amount.inMinorUnits;
    return switch (bill.frequency) {
      BillFrequency.weekly => Money.fromMinorUnits((minor * 52 + 6) ~/ 12),
      BillFrequency.yearly => Money.fromMinorUnits((minor + 6) ~/ 12),
      BillFrequency.monthly || BillFrequency.everyCycle => Money.fromMinorUnits(minor),
    };
  }

  /// When to remind about [bill]'s next unpaid due date: [hour]:00,
  /// `remindDaysBefore` days before it. Returns the first such time after
  /// [now], or `null` if the bill has no reminder or is paused.
  ({DateTime at, DateTime dueDate})? nextReminder({
    required RecurringBill bill,
    required Set<String> handled,
    required DateTime now,
    int hour = 9,
  }) {
    final daysBefore = bill.remindDaysBefore;
    if (daysBefore == null || !bill.isActive) return null;
    final today = _day(now);
    final dues = dueDatesBetween(
      bill,
      today,
      DateTime(today.year + 1, today.month, today.day + daysBefore),
    );
    for (final due in dues) {
      if (handled.contains(dateKey(due))) continue;
      final at = DateTime(due.year, due.month, due.day - daysBefore, hour);
      if (at.isAfter(now)) return (at: at, dueDate: due);
    }
    return null;
  }
}
