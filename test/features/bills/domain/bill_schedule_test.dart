import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/bills/domain/bill_schedule.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

RecurringBill bill({
  String id = 'b1',
  String title = 'Rent',
  TransactionType type = TransactionType.expense,
  String? categoryName = 'Housing',
  int amountMinor = 800000,
  BillFrequency frequency = BillFrequency.monthly,
  required DateTime anchor,
  int? remindDaysBefore,
  bool isActive = true,
}) {
  final now = DateTime(2026, 1, 1);
  return RecurringBill(
    id: id,
    title: title,
    type: type,
    categoryId: 'cat',
    categoryName: categoryName,
    amount: Money.fromMinorUnits(amountMinor),
    frequency: frequency,
    anchorDate: anchor,
    remindDaysBefore: remindDaysBefore,
    isActive: isActive,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  const schedule = BillSchedule(BudgetCycleCalculator(startDay: 25));

  group('dueDatesBetween', () {
    test('monthly on the 31st clamps to short months and leap February', () {
      final dues = schedule.dueDatesBetween(
        bill(anchor: DateTime(2028, 1, 31)),
        DateTime(2028, 1, 1),
        DateTime(2028, 5, 31),
      );
      expect(dues, [
        DateTime(2028, 1, 31),
        DateTime(2028, 2, 29),
        DateTime(2028, 3, 31),
        DateTime(2028, 4, 30),
        DateTime(2028, 5, 31),
      ]);
    });

    test('never returns dates before the anchor', () {
      final dues = schedule.dueDatesBetween(
        bill(anchor: DateTime(2026, 3, 14)),
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 30),
      );
      expect(dues, [DateTime(2026, 3, 14), DateTime(2026, 4, 14)]);
    });

    test('weekly repeats every 7 days from the anchor', () {
      final dues = schedule.dueDatesBetween(
        bill(frequency: BillFrequency.weekly, anchor: DateTime(2026, 2, 26)),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 20),
      );
      expect(dues, [DateTime(2026, 3, 5), DateTime(2026, 3, 12), DateTime(2026, 3, 19)]);
    });

    test('yearly on 29 February falls on the 28th in other years', () {
      final dues = schedule.dueDatesBetween(
        bill(frequency: BillFrequency.yearly, anchor: DateTime(2028, 2, 29)),
        DateTime(2028, 1, 1),
        DateTime(2030, 12, 31),
      );
      expect(dues, [DateTime(2028, 2, 29), DateTime(2029, 2, 28), DateTime(2030, 2, 28)]);
    });

    test('every cycle follows the user start day, clamped in February', () {
      final dues = const BillSchedule(BudgetCycleCalculator(startDay: 30)).dueDatesBetween(
        bill(frequency: BillFrequency.everyCycle, anchor: DateTime(2026, 1, 1)),
        DateTime(2026, 1, 1),
        DateTime(2026, 3, 31),
      );
      expect(dues, [DateTime(2026, 1, 30), DateTime(2026, 2, 28), DateTime(2026, 3, 30)]);
    });

    test('nextDueOnOrAfter includes the given day', () {
      final b = bill(anchor: DateTime(2026, 1, 5));
      expect(schedule.nextDueOnOrAfter(b, DateTime(2026, 6, 5)), DateTime(2026, 6, 5));
      expect(schedule.nextDueOnOrAfter(b, DateTime(2026, 6, 6)), DateTime(2026, 7, 5));
    });
  });

  group('unpaidDues', () {
    test('skips handled dates and paused bills, sorted by due date', () {
      final rent = bill(id: 'rent', anchor: DateTime(2026, 1, 1));
      final gym = bill(id: 'gym', title: 'Gym', anchor: DateTime(2026, 1, 10));
      final paused = bill(id: 'old', anchor: DateTime(2026, 1, 2), isActive: false);
      final dues = schedule.unpaidDues(
        bills: [rent, gym, paused],
        handled: {
          'rent': {'2026-01-01', '2026-02-01'},
        },
        today: DateTime(2026, 2, 15),
        until: DateTime(2026, 3, 5),
      );
      expect(
        dues.map((d) => '${d.bill.id} ${BillSchedule.dateKey(d.dueDate)}'),
        ['gym 2026-01-10', 'gym 2026-02-10', 'rent 2026-03-01'],
      );
      expect(dues.first.isOverdue(DateTime(2026, 2, 15)), isTrue);
      expect(dues.last.daysUntil(DateTime(2026, 2, 15)), 14);
    });

    test('overdue dates older than the lookback window are dropped', () {
      final dues = schedule.unpaidDues(
        bills: [bill(anchor: DateTime(2024, 1, 1))],
        handled: const {},
        today: DateTime(2026, 6, 15),
        until: DateTime(2026, 6, 15),
      );
      expect(dues.first.dueDate, DateTime(2025, 7, 1));
      expect(dues.length, 12);
    });
  });

  test('committedUntil counts unpaid expenses only, without Savings', () {
    final today = DateTime(2026, 3, 10);
    final committed = schedule.committedUntil(
      bills: [
        bill(id: 'rent', anchor: DateTime(2026, 3, 1), amountMinor: 800000), // overdue
        bill(id: 'net', anchor: DateTime(2026, 3, 20), amountMinor: 50000), // due in cycle
        bill(id: 'later', anchor: DateTime(2026, 3, 30), amountMinor: 99900), // after cycle end
        bill(id: 'paid', anchor: DateTime(2026, 3, 12), amountMinor: 10000),
        bill(id: 'salary', type: TransactionType.income, anchor: DateTime(2026, 3, 25)),
        bill(id: 'save', categoryName: 'Savings', anchor: DateTime(2026, 3, 15)),
      ],
      handled: {
        'paid': {'2026-03-12'},
      },
      today: today,
      cycleEnd: DateTime(2026, 3, 24),
    );
    expect(committed.inMinorUnits, 850000);
  });

  test('monthlyEquivalent spreads weekly and yearly costs', () {
    expect(
      BillSchedule.monthlyEquivalent(
        bill(frequency: BillFrequency.weekly, anchor: DateTime(2026, 1, 1), amountMinor: 30000),
      ).inMinorUnits,
      130000,
    );
    expect(
      BillSchedule.monthlyEquivalent(
        bill(frequency: BillFrequency.yearly, anchor: DateTime(2026, 1, 1), amountMinor: 120000),
      ).inMinorUnits,
      10000,
    );
  });

  group('nextReminder', () {
    final b = bill(anchor: DateTime(2026, 1, 15), remindDaysBefore: 1);

    test('fires at 9:00 the day before the next unpaid due date', () {
      final r = schedule.nextReminder(bill: b, handled: const {}, now: DateTime(2026, 3, 10, 12));
      expect(r!.at, DateTime(2026, 3, 14, 9));
      expect(r.dueDate, DateTime(2026, 3, 15));
    });

    test('moves to the following due date once the reminder time has passed', () {
      final r = schedule.nextReminder(bill: b, handled: const {}, now: DateTime(2026, 3, 14, 10));
      expect(r!.dueDate, DateTime(2026, 4, 15));
    });

    test('skips due dates already paid', () {
      final r = schedule.nextReminder(
        bill: b,
        handled: {'2026-03-15'},
        now: DateTime(2026, 3, 10),
      );
      expect(r!.dueDate, DateTime(2026, 4, 15));
    });

    test('is null without a reminder or when paused', () {
      expect(
        schedule.nextReminder(bill: bill(anchor: DateTime(2026, 1, 1)), handled: const {}, now: DateTime(2026, 2, 1)),
        isNull,
      );
      expect(
        schedule.nextReminder(
          bill: bill(anchor: DateTime(2026, 1, 1), remindDaysBefore: 0, isActive: false),
          handled: const {},
          now: DateTime(2026, 2, 1),
        ),
        isNull,
      );
    });
  });
}
