import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/bills/data/bill_reminder_scheduler.dart';
import 'package:money_tracker/features/bills/data/recurring_bill_repository.dart';
import 'package:money_tracker/features/bills/domain/bill_schedule.dart';
import 'package:money_tracker/features/bills/domain/bill_service.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'cycle_providers.dart';
import 'database_providers.dart';
import 'transaction_providers.dart';

final recurringBillRepositoryProvider = Provider<RecurringBillRepository>((ref) {
  return RecurringBillRepository(ref.watch(databaseProvider));
});

/// Bill dates, using the user's cycle start day for "every cycle" bills.
/// Load the recorded cycles into it ([BillSchedule.withRecordedCycles], or
/// [BillService.scheduleFor]) before computing past "every cycle" dates.
final billScheduleProvider = Provider<BillSchedule>((ref) {
  return BillSchedule(ref.watch(budgetCycleRepositoryProvider).calculator);
});

final billReminderSchedulerProvider = Provider<BillReminderScheduler>((ref) {
  return LocalBillReminderScheduler(ref.watch(notificationServiceProvider));
});

/// Use this for every bill write. See [BillService].
final billServiceProvider = Provider<BillService>((ref) {
  return BillService(
    repo: ref.watch(recurringBillRepositoryProvider),
    transactions: ref.watch(transactionServiceProvider),
    schedule: ref.watch(billScheduleProvider),
    reminders: ref.watch(billReminderSchedulerProvider),
    recordedCycles: ref.watch(budgetCycleRepositoryProvider).getAllCycles,
  );
});

/// Unpaid bills due within the next week, overdue ones first.
final billsDueSoonProvider = FutureProvider<List<BillDue>>((ref) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(billServiceProvider).dueItems(daysAhead: 7);
});

/// A bill with its next unpaid due date, for the bills list.
class BillListItem {
  final RecurringBill bill;
  final DateTime? nextDue;
  const BillListItem({required this.bill, this.nextDue});
}

class BillsOverview {
  final List<BillListItem> items;

  /// Unpaid bills due within a week, including overdue ones.
  final List<BillDue> needsAttention;

  /// Average monthly cost of active expense bills.
  final Money monthlyExpenseTotal;

  /// Unpaid expense bills due before the current cycle ends.
  final Money committedThisCycle;

  const BillsOverview({
    required this.items,
    required this.needsAttention,
    required this.monthlyExpenseTotal,
    required this.committedThisCycle,
  });
}

final billsOverviewProvider = FutureProvider<BillsOverview>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(recurringBillRepositoryProvider);
  final cycleRepo = ref.watch(budgetCycleRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final bills = await repo.getAllBills();
  final handled = await repo.getHandledDueDates();
  final cycle = await cycleRepo.getOrCreateCycleForDate(today);
  final schedule = ref
      .watch(billScheduleProvider)
      .withRecordedCycles(await cycleRepo.getAllCycles());

  final unpaid = schedule.unpaidDues(
    bills: bills,
    handled: handled,
    today: today,
    until: today.add(const Duration(days: 400)),
  );
  final nextDueByBill = <String, DateTime>{};
  for (final due in unpaid) {
    nextDueByBill.putIfAbsent(due.bill.id, () => due.dueDate);
  }

  final items = [
    for (final b in bills)
      BillListItem(bill: b, nextDue: b.isActive ? nextDueByBill[b.id] : null),
  ]..sort((a, b) {
      if (a.bill.isActive != b.bill.isActive) return a.bill.isActive ? -1 : 1;
      final ad = a.nextDue, bd = b.nextDue;
      if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
      if ((ad == null) != (bd == null)) return ad == null ? 1 : -1;
      return a.bill.title.compareTo(b.bill.title);
    });

  var monthly = 0;
  for (final b in bills) {
    if (b.isActive && b.isExpense) {
      monthly += BillSchedule.monthlyEquivalent(b).inMinorUnits;
    }
  }

  final weekAhead = today.add(const Duration(days: 7));
  return BillsOverview(
    items: items,
    needsAttention: unpaid.where((d) => !d.dueDate.isAfter(weekAhead)).toList(),
    monthlyExpenseTotal: Money.fromMinorUnits(monthly),
    committedThisCycle: schedule.committedUntil(
      bills: bills,
      handled: handled,
      today: today,
      cycleEnd: cycle.endDate,
    ),
  );
});

/// Paid and skipped due dates of one bill, newest first.
final billHistoryProvider =
    FutureProvider.family<List<BillOccurrence>, String>((ref, billId) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(recurringBillRepositoryProvider).getOccurrences(billId);
});
