import 'package:money_tracker/core/money/money.dart';

/// Represents the budget allocation, spending, and remaining amount
/// for a single category within a specific budget cycle.
class CategoryBudget {
  final String categoryId;
  final String categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final Money budgetedAmount;
  final Money spentAmount;

  const CategoryBudget({
    required this.categoryId,
    required this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    required this.budgetedAmount,
    required this.spentAmount,
  });

  /// Remaining amount = budgeted - spent. Can be negative if overspent.
  Money get remainingAmount => budgetedAmount - spentAmount;

  /// True if spentAmount > budgetedAmount (or remainingAmount < 0).
  bool get isOverspent => remainingAmount.isNegative;

  /// Usage percentage = spent / budgeted * 100.
  /// Returns `null` if budgeted amount is zero or negative to safely avoid division by zero.
  double? get usagePercentage {
    if (budgetedAmount.inMinorUnits <= 0) return null;
    return (spentAmount.inMinorUnits / budgetedAmount.inMinorUnits) * 100.0;
  }

  /// True if spending has reached or exceeded 80% of budget, but has not yet exceeded 100%.
  bool get isNearLimit {
    final pct = usagePercentage;
    if (pct == null) return false;
    return pct >= 80.0 && pct <= 100.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryBudget &&
          other.categoryId == categoryId &&
          other.categoryName == categoryName &&
          other.categoryColor == categoryColor &&
          other.categoryIcon == categoryIcon &&
          other.budgetedAmount == budgetedAmount &&
          other.spentAmount == spentAmount);

  @override
  int get hashCode => Object.hash(
    categoryId,
    categoryName,
    categoryColor,
    categoryIcon,
    budgetedAmount,
    spentAmount,
  );
}
