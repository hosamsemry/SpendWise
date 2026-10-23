import 'package:money_tracker/core/money/money.dart';

enum TransactionType {
  income,
  expense;

  static TransactionType fromString(String value) {
    if (value.toLowerCase() == 'income') return TransactionType.income;
    if (value.toLowerCase() == 'expense') return TransactionType.expense;
    throw ArgumentError('Invalid TransactionType: $value');
  }

  String toDbString() => name;
}

class TransactionModel {
  final String id;
  final TransactionType type;
  final Money amount;
  final String? categoryId;
  final String? categoryName;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.categoryName,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  TransactionModel copyWith({
    String? id,
    TransactionType? type,
    Money? amount,
    String? categoryId,
    String? categoryName,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TransactionModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
