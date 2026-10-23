import 'budget_cycle.dart';

/// Pure calculator service for determining budget cycle boundaries and transitions.
///
/// Supports any start day between 1 and 28.
/// - If [startDay] is 1: Cycles run strictly from the 1st of the month to the last day of that month (Calendar Month).
/// - If [startDay] > 1: Cycles run from day [startDay] of month M to day [startDay - 1] of month M+1.
class BudgetCycleCalculator {
  final int startDay;

  const BudgetCycleCalculator({this.startDay = 25})
      : assert(startDay >= 1 && startDay <= 31, 'startDay must be between 1 and 31');

  /// Returns the number of days in [month] of [year].
  static int daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// Clamps [targetDay] to the maximum number of days in [month] of [year].
  static int clampedDay(int year, int month, int targetDay) {
    final maxDays = daysInMonth(year, month);
    return targetDay > maxDays ? maxDays : targetDay;
  }

  /// Calculates the [BudgetCycle] that contains the given [date].
  BudgetCycle getCycleForDate(DateTime date) {
    if (startDay == 1) {
      final startDate = DateTime(date.year, date.month, 1);
      final endDate = DateTime(date.year, date.month + 1, 0);
      final id = '${formatDate(startDate)}_${formatDate(endDate)}';
      return BudgetCycle(id: id, startDate: startDate, endDate: endDate);
    }

    final currentMonthStartDay = clampedDay(date.year, date.month, startDay);
    final int startYear;
    final int startMonth;
    final int actualStartDay;

    if (date.day >= currentMonthStartDay) {
      startYear = date.year;
      startMonth = date.month;
      actualStartDay = currentMonthStartDay;
    } else {
      if (date.month == 1) {
        startYear = date.year - 1;
        startMonth = 12;
      } else {
        startYear = date.year;
        startMonth = date.month - 1;
      }
      actualStartDay = clampedDay(startYear, startMonth, startDay);
    }

    final int nextStartYear = startMonth == 12 ? startYear + 1 : startYear;
    final int nextStartMonth = startMonth == 12 ? 1 : startMonth + 1;
    final int nextStartDay = clampedDay(nextStartYear, nextStartMonth, startDay);

    final startDate = DateTime(startYear, startMonth, actualStartDay);
    final endDate = DateTime(nextStartYear, nextStartMonth, nextStartDay - 1);
    final id = '${formatDate(startDate)}_${formatDate(endDate)}';

    return BudgetCycle(id: id, startDate: startDate, endDate: endDate);
  }

  /// Calculates the next consecutive [BudgetCycle] after [current].
  BudgetCycle getNextCycle(BudgetCycle current) {
    if (startDay == 1) {
      final nextStartDate = DateTime(current.startDate.year, current.startDate.month + 1, 1);
      final nextEndDate = DateTime(current.startDate.year, current.startDate.month + 2, 0);
      final id = '${formatDate(nextStartDate)}_${formatDate(nextEndDate)}';
      return BudgetCycle(id: id, startDate: nextStartDate, endDate: nextEndDate);
    }

    final nextStartDate = DateTime(current.endDate.year, current.endDate.month, current.endDate.day + 1);
    final nextStartYear = nextStartDate.year;
    final nextStartMonth = nextStartDate.month;

    final followingYear = nextStartMonth == 12 ? nextStartYear + 1 : nextStartYear;
    final followingMonth = nextStartMonth == 12 ? 1 : nextStartMonth + 1;
    final followingStartDay = clampedDay(followingYear, followingMonth, startDay);
    final nextEndDate = DateTime(followingYear, followingMonth, followingStartDay - 1);

    final id = '${formatDate(nextStartDate)}_${formatDate(nextEndDate)}';
    return BudgetCycle(id: id, startDate: nextStartDate, endDate: nextEndDate);
  }

  /// Calculates the previous consecutive [BudgetCycle] before [current].
  BudgetCycle getPreviousCycle(BudgetCycle current) {
    if (startDay == 1) {
      final prevStartDate = DateTime(current.startDate.year, current.startDate.month - 1, 1);
      final prevEndDate = DateTime(current.startDate.year, current.startDate.month, 0);
      final id = '${formatDate(prevStartDate)}_${formatDate(prevEndDate)}';
      return BudgetCycle(id: id, startDate: prevStartDate, endDate: prevEndDate);
    }

    final prevEndDate = DateTime(current.startDate.year, current.startDate.month, current.startDate.day - 1);
    return getCycleForDate(prevEndDate);
  }

  /// Normalizes any Eastern Arabic digits (٠-٩) or Persian digits (۰-۹) to standard ASCII (0-9).
  static String normalizeDigits(String input) {
    const arabicEastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result
          .replaceAll(arabicEastern[i], '$i')
          .replaceAll(persian[i], '$i');
    }
    return result;
  }

  /// Formats a [DateTime] into a calendar ISO string (`YYYY-MM-DD`) strictly in ASCII digits.
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses an ISO calendar date (`YYYY-MM-DD`) into a local [DateTime] at midnight,
  /// safely converting any localized Eastern Arabic numerals to standard ASCII.
  static DateTime parseDate(String isoDate) {
    final normalized = normalizeDigits(isoDate.trim());
    final parts = normalized.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid ISO date string: "$isoDate"');
    }
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetCycleCalculator &&
          runtimeType == other.runtimeType &&
          startDay == other.startDay;

  @override
  int get hashCode => startDay.hashCode;
}
