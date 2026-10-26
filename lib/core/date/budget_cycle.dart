import 'package:intl/intl.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';

/// Represents a budget period with a defined start date and end date, inclusive.
class BudgetCycle {
  final String id;
  final DateTime startDate;
  final DateTime endDate;

  BudgetCycle({
    required this.id,
    required this.startDate,
    required this.endDate,
  }) {
    assert(!startDate.isAfter(endDate), 'startDate cannot be after endDate');
  }

  /// Formatted ISO start date string (`YYYY-MM-DD`).
  String get startDateString => BudgetCycleCalculator.formatDate(startDate);

  /// Formatted ISO end date string (`YYYY-MM-DD`).
  String get endDateString => BudgetCycleCalculator.formatDate(endDate);

  /// Human-readable range display, e.g. "25 Oct 2026 – 24 Nov 2026".
  String get formattedRange {
    final startStr = DateFormat('d MMM yyyy').format(startDate);
    final endStr = DateFormat('d MMM yyyy').format(endDate);
    return '$startStr – $endStr';
  }

  /// Compact title, e.g. "Oct – Nov 2026" or "Dec 2026 – Jan 2027".
  String get shortLabel {
    if (startDate.year == endDate.year) {
      final startMonth = DateFormat('MMM').format(startDate);
      final endMonth = DateFormat('MMM yyyy').format(endDate);
      return '$startMonth – $endMonth';
    } else {
      final start = DateFormat('MMM yyyy').format(startDate);
      final end = DateFormat('MMM yyyy').format(endDate);
      return '$start – $end';
    }
  }

  /// Checks if a given [date] falls into this cycle using pure calendar-day comparison.
  bool contains(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    return (target.isAtSameMomentAs(start) || target.isAfter(start)) &&
        (target.isAtSameMomentAs(end) || target.isBefore(end));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetCycle &&
          id == other.id &&
          startDateString == other.startDateString &&
          endDateString == other.endDateString);

  @override
  int get hashCode => Object.hash(id, startDateString, endDateString);

  @override
  String toString() => 'BudgetCycle($formattedRange)';
}
