import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/bills/data/bill_reminder_scheduler.dart';
import 'package:money_tracker/features/bills/data/recurring_bill_repository.dart';
import 'package:money_tracker/features/bills/domain/bill_schedule.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/features/transactions/domain/transaction_service.dart';

/// Thrown when an expense bill's category was deleted, so paying it would
/// create an expense without a category.
class BillCategoryMissingException implements Exception {
  const BillCategoryMissingException();
}

/// Every bill write goes through here. Payments are logged with
/// [TransactionService] (so budgets, Savings and alerts update like any other
/// entry), then the due date is recorded and reminders are rescheduled.
/// Nothing is paid automatically: the user confirms each one.
///
/// UI refresh (`refreshTriggerProvider`) stays the caller's responsibility.
class BillService {
  final RecurringBillRepository repo;
  final TransactionService transactions;
  final BillSchedule schedule;
  final BillReminderScheduler? reminders;

  /// Loads the cycles recorded in the database, so "every cycle" bills keep
  /// matching their past payments after a start-day change. Without it the
  /// whole schedule is computed (fine for tests that never change it).
  final Future<List<BudgetCycle>> Function()? recordedCycles;

  /// Clock override for tests.
  final DateTime Function() clock;

  BillService({
    required this.repo,
    required this.transactions,
    required this.schedule,
    this.reminders,
    this.recordedCycles,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// [schedule] with the recorded cycles loaded.
  Future<BillSchedule> scheduleFor() async {
    final load = recordedCycles;
    return load == null ? schedule : schedule.withRecordedCycles(await load());
  }

  DateTime get _today {
    final n = clock();
    return DateTime(n.year, n.month, n.day);
  }

  /// Unpaid due dates of active bills up to [daysAhead] days from today,
  /// overdue ones first.
  Future<List<BillDue>> dueItems({int daysAhead = 7}) async {
    final today = _today;
    return (await scheduleFor()).unpaidDues(
      bills: await repo.getAllBills(),
      handled: await repo.getHandledDueDates(),
      today: today,
      until: today.add(Duration(days: daysAhead)),
    );
  }

  /// Unpaid expense bills due by [cycleEnd] (overdue included).
  Future<Money> committedUntil(DateTime cycleEnd) async {
    return (await scheduleFor()).committedUntil(
      bills: await repo.getAllBills(),
      handled: await repo.getHandledDueDates(),
      today: _today,
      cycleEnd: cycleEnd,
    );
  }

  /// Logs the payment of [due] as a transaction dated [paidOn] (default
  /// today) and marks the due date paid. For a variable bill, [amount]
  /// becomes the estimate for next time: the estimate is read from the latest
  /// payment, so undoing or deleting it brings the previous estimate back.
  Future<TransactionModel> pay(BillDue due, {Money? amount, DateTime? paidOn}) async {
    final bill = due.bill;
    final value = amount ?? bill.amount;
    if (bill.isExpense && (bill.categoryId == null || bill.categoryId!.isEmpty)) {
      throw const BillCategoryMissingException();
    }
    final tx = await transactions.add(
      type: bill.type,
      amount: value,
      categoryId: bill.categoryId,
      date: paidOn ?? _today,
      note: bill.title,
    );
    await repo.recordOccurrence(
      billId: bill.id,
      dueDate: due.dueDate,
      status: BillOccurrenceStatus.paid,
      transactionId: tx.id,
    );
    await rescheduleReminders();
    return tx;
  }

  /// Undoes [pay]: deleting the transaction also clears the paid record.
  Future<void> undoPay(TransactionModel tx) async {
    await transactions.delete(tx);
    await rescheduleReminders();
  }

  Future<void> skip(BillDue due) async {
    await repo.recordOccurrence(
      billId: due.bill.id,
      dueDate: due.dueDate,
      status: BillOccurrenceStatus.skipped,
    );
    await rescheduleReminders();
  }

  Future<void> undoSkip(BillDue due) async {
    await repo.clearOccurrence(due.bill.id, due.dueDate);
    await rescheduleReminders();
  }

  Future<RecurringBill> create({
    required String title,
    required TransactionType type,
    String? categoryId,
    required Money amount,
    bool isVariable = false,
    required BillFrequency frequency,
    required DateTime anchorDate,
    int? remindDaysBefore,
    String? note,
  }) async {
    final bill = await repo.createBill(
      title: title,
      type: type,
      categoryId: categoryId,
      amount: amount,
      isVariable: isVariable,
      frequency: frequency,
      anchorDate: anchorDate,
      remindDaysBefore: remindDaysBefore,
      note: note,
    );
    await rescheduleReminders();
    return bill;
  }

  Future<void> update(RecurringBill bill) async {
    await repo.updateBill(bill);
    await rescheduleReminders();
  }

  /// Pausing hides a bill from due lists, reminders and safe-to-spend.
  /// Resuming skips the due dates from the pause day until yesterday, so they
  /// don't come back as overdue. Dates that were already overdue before the
  /// pause stay overdue.
  Future<void> setActive(RecurringBill bill, bool isActive) async {
    final today = _today;
    if (isActive && !bill.isActive) {
      final handled = (await repo.getHandledDueDates())[bill.id] ?? const <String>{};
      final lookback =
          today.subtract(const Duration(days: BillSchedule.overdueLookbackDays));
      final pausedOn = bill.pausedAt;
      final schedule = await scheduleFor();
      final missed = schedule.dueDatesBetween(
        bill,
        pausedOn != null && pausedOn.isAfter(lookback) ? pausedOn : lookback,
        today.subtract(const Duration(days: 1)),
      );
      for (final d in missed) {
        if (handled.contains(BillSchedule.dateKey(d))) continue;
        await repo.recordOccurrence(
          billId: bill.id,
          dueDate: d,
          status: BillOccurrenceStatus.skipped,
        );
      }
    }
    await repo.setActive(bill.id, isActive, today: today);
    await rescheduleReminders();
  }

  /// Deletes the bill and its history. Payments already logged stay.
  Future<void> delete(RecurringBill bill) async {
    await reminders?.cancel(bill.id);
    await repo.deleteBill(bill.id);
  }

  /// Schedules the next reminder of every bill (and clears stale ones).
  Future<void> rescheduleReminders() async {
    final scheduler = reminders;
    if (scheduler == null) return;
    final now = clock();
    final handled = await repo.getHandledDueDates();
    final schedule = await scheduleFor();
    for (final bill in await repo.getAllBills()) {
      final next = schedule.nextReminder(
        bill: bill,
        handled: handled[bill.id] ?? const <String>{},
        now: now,
      );
      if (next == null) {
        await scheduler.cancel(bill.id);
      } else {
        await scheduler.schedule(
          bill: bill,
          at: next.at,
          dueDate: next.dueDate,
        );
      }
    }
  }
}
