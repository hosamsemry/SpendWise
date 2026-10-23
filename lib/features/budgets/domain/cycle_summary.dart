import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'category_budget.dart';

/// Aggregated financial metrics for a specific budget cycle.
class CycleSummary {
  final BudgetCycle cycle;
  final Money totalIncome;
  final Money totalBudgeted;
  final Money totalSpent;
  final Money positiveUnusedTotal;
  final Money netRemainingTotal;
  final int overspentCategoriesCount;
  final List<CategoryBudget> categoryBudgets;

  const CycleSummary({
    required this.cycle,
    required this.totalIncome,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.positiveUnusedTotal,
    required this.netRemainingTotal,
    required this.overspentCategoriesCount,
    required this.categoryBudgets,
  });
}
