import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';

void main() {
  DateTime at(int startDay, DateTime now) =>
      nextCycleReminderTime(BudgetCycleCalculator(startDay: startDay), now);

  test('follows the user start day, not a hardcoded 25th', () {
    expect(at(1, DateTime(2026, 11, 21, 12)), DateTime(2026, 12, 1, 9));
    expect(at(10, DateTime(2026, 11, 21, 12)), DateTime(2026, 12, 10, 9));
    expect(at(25, DateTime(2026, 11, 21, 12)), DateTime(2026, 11, 25, 9));
  });

  test('fires today when the cycle starts today and 9:00 is still ahead', () {
    expect(at(21, DateTime(2026, 11, 21, 7)), DateTime(2026, 11, 21, 9));
    expect(at(21, DateTime(2026, 11, 21, 10)), DateTime(2026, 12, 21, 9));
  });

  test('respects short-month clamping and year rollover', () {
    // Start day 31: next start after Jan 31 cycle is Feb 28 (2027 is not leap).
    expect(at(31, DateTime(2027, 2, 2, 12)), DateTime(2027, 2, 28, 9));
    expect(at(1, DateTime(2026, 12, 15)), DateTime(2027, 1, 1, 9));
  });
}
