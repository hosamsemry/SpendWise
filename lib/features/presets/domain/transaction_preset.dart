import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

class TransactionPreset {
  final String id;
  final String title;
  final TransactionType type;
  final String? categoryId;
  final String? categoryName;
  final Money amount;
  final String? note;
  final int displayOrder;
  final DateTime createdAt;

  const TransactionPreset({
    required this.id,
    required this.title,
    required this.type,
    this.categoryId,
    this.categoryName,
    required this.amount,
    this.note,
    this.displayOrder = 0,
    required this.createdAt,
  });

  bool get isExpense => type == TransactionType.expense;
  bool get isIncome => type == TransactionType.income;
}
