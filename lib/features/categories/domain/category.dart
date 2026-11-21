import 'package:money_tracker/core/money/money.dart';

/// Whether [name] is the auto-managed Savings category (English or Arabic).
bool isSavingsCategoryName(String name) {
  final lower = name.trim().toLowerCase();
  return lower == 'savings' || lower == 'مدخرات';
}

enum CategoryType {
  expense,
  income;

  bool get isExpense => this == CategoryType.expense;
  bool get isIncome => this == CategoryType.income;
}

class Category {
  final String id;
  final String name;
  final CategoryType type;
  final String? color;
  final String? icon;
  final Money defaultBudget;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.type = CategoryType.expense,
    this.color,
    this.icon,
    this.defaultBudget = const Money.zero(),
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Category copyWith({
    String? id,
    String? name,
    CategoryType? type,
    String? color,
    String? icon,
    Money? defaultBudget,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      defaultBudget: defaultBudget ?? this.defaultBudget,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
