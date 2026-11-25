import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

enum BillFrequency {
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly'),

  /// On the user's budget cycle start day (payday).
  everyCycle('every_cycle');

  final String dbValue;
  const BillFrequency(this.dbValue);

  static BillFrequency fromDb(String value) => BillFrequency.values.firstWhere(
        (f) => f.dbValue == value,
        orElse: () => BillFrequency.monthly,
      );
}

enum BillOccurrenceStatus {
  paid('paid'),
  skipped('skipped');

  final String dbValue;
  const BillOccurrenceStatus(this.dbValue);

  static BillOccurrenceStatus fromDb(String value) =>
      value == 'skipped' ? BillOccurrenceStatus.skipped : BillOccurrenceStatus.paid;
}

/// A recurring bill, subscription or regular income.
class RecurringBill {
  final String id;
  final String title;
  final TransactionType type;
  final String? categoryId;
  final String? categoryName;

  /// The fixed amount, or for a variable bill the estimate (last amount paid).
  final Money amount;
  final bool isVariable;
  final BillFrequency frequency;

  /// First due date. Later due dates repeat its weekday, day of month or
  /// date of year (clamped in short months).
  final DateTime anchorDate;

  /// Days before the due date to send a reminder; `null` = no reminder.
  final int? remindDaysBefore;
  final bool isActive;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringBill({
    required this.id,
    required this.title,
    required this.type,
    this.categoryId,
    this.categoryName,
    required this.amount,
    this.isVariable = false,
    required this.frequency,
    required this.anchorDate,
    this.remindDaysBefore,
    this.isActive = true,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;
}

/// A handled due date: paid (with its transaction) or skipped.
class BillOccurrence {
  final String id;
  final String billId;
  final DateTime dueDate;
  final BillOccurrenceStatus status;
  final String? transactionId;

  /// Amount of the payment transaction (null when skipped).
  final Money? amount;
  final DateTime createdAt;

  const BillOccurrence({
    required this.id,
    required this.billId,
    required this.dueDate,
    required this.status,
    this.transactionId,
    this.amount,
    required this.createdAt,
  });
}

/// An unpaid due date of [bill] that needs attention.
class BillDue {
  final RecurringBill bill;
  final DateTime dueDate;

  const BillDue({required this.bill, required this.dueDate});

  /// Whole days from [today] until [dueDate]: negative when overdue.
  int daysUntil(DateTime today) {
    final d = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
    final t = DateTime.utc(today.year, today.month, today.day);
    return d.difference(t).inDays;
  }

  bool isOverdue(DateTime today) => daysUntil(today) < 0;
}
