import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'category_budget.dart';
import 'cycle_summary.dart';

/// Pure domain service calculating cycle metrics, category spending,
/// remaining budgets, and summary totals.
class BudgetCalculationService {
  const BudgetCalculationService();

  /// Calculates the complete [CycleSummary] for a given [cycle], based on
  /// its [budgetMap] (mapping categoryId to budgeted Money), the list of [categories],
  /// and all [transactions] in that cycle.
  CycleSummary calculateCycleSummary({
    required BudgetCycle cycle,
    required List<Category> categories,
    required Map<String, Money> budgetMap,
    required List<TransactionModel> transactions,
  }) {
    // 1. Filter transactions falling within the cycle date range
    final cycleTransactions = transactions
        .where((t) => cycle.contains(t.date))
        .toList();

    // 2. Sum income transactions
    var incomeMinor = 0;
    for (final t in cycleTransactions) {
      if (t.isIncome) {
        incomeMinor += t.amount.inMinorUnits;
      }
    }
    final totalIncome = Money.fromMinorUnits(incomeMinor);

    // 3. Sum all expense transactions across the cycle
    var totalSpentMinor = 0;
    for (final t in cycleTransactions) {
      if (t.isExpense) {
        totalSpentMinor += t.amount.inMinorUnits;
      }
    }

    // 4. Group expense transactions by category
    final Map<String, int> expenseSpendingMap = {};
    for (final t in cycleTransactions) {
      if (t.isExpense && t.categoryId != null) {
        expenseSpendingMap[t.categoryId!] =
            (expenseSpendingMap[t.categoryId!] ?? 0) + t.amount.inMinorUnits;
      }
    }

    // 5. Compute per-category budget details for known categories
    final List<CategoryBudget> categoryBudgets = [];
    final Set<String> knownCategoryIds = {};
    var totalBudgetedMinor = 0;
    var positiveUnusedMinor = 0;
    var overspentCount = 0;

    for (final cat in categories) {
      knownCategoryIds.add(cat.id);

      // Only expense categories are part of category budgets
      if (cat.type != CategoryType.expense) {
        continue;
      }

      final budgeted = budgetMap[cat.id] ?? const Money.zero();
      final spent = Money.fromMinorUnits(expenseSpendingMap[cat.id] ?? 0);

      // Exclude archived categories that have no budget allocation and no spending in this cycle
      if (!cat.isActive && budgeted.isZero && spent.isZero) {
        continue;
      }

      final remaining = budgeted - spent;

      totalBudgetedMinor += budgeted.inMinorUnits;

      if (remaining.inMinorUnits > 0) {
        positiveUnusedMinor += remaining.inMinorUnits;
      } else if (remaining.inMinorUnits < 0) {
        overspentCount++;
      }

      categoryBudgets.add(
        CategoryBudget(
          categoryId: cat.id,
          categoryName: cat.name,
          categoryColor: cat.color,
          categoryIcon: cat.icon,
          budgetedAmount: budgeted,
          spentAmount: spent,
        ),
      );
    }

    // 6. Aggregate orphan/deleted category expenses
    final Map<String, int> orphanSpendingMap = {};
    for (final t in cycleTransactions) {
      if (t.isExpense &&
          (t.categoryId == null || !knownCategoryIds.contains(t.categoryId))) {
        final name =
            (t.categoryName != null && t.categoryName!.trim().isNotEmpty)
                ? t.categoryName!.trim()
                : 'Uncategorized';
        orphanSpendingMap[name] =
            (orphanSpendingMap[name] ?? 0) + t.amount.inMinorUnits;
      }
    }

    for (final entry in orphanSpendingMap.entries) {
      final name = entry.key;
      final spentMinor = entry.value;
      final spent = Money.fromMinorUnits(spentMinor);
      overspentCount++;
      final displayName =
          name == 'Uncategorized' ? 'Uncategorized' : '$name (Deleted)';
      categoryBudgets.add(
        CategoryBudget(
          categoryId: 'orphan_$name',
          categoryName: displayName,
          categoryColor: '#94A3B8',
          categoryIcon: null,
          budgetedAmount: const Money.zero(),
          spentAmount: spent,
        ),
      );
    }

    final netRemainingMinor = totalBudgetedMinor - totalSpentMinor;

    return CycleSummary(
      cycle: cycle,
      totalIncome: totalIncome,
      totalBudgeted: Money.fromMinorUnits(totalBudgetedMinor),
      totalSpent: Money.fromMinorUnits(totalSpentMinor),
      positiveUnusedTotal: Money.fromMinorUnits(positiveUnusedMinor),
      netRemainingTotal: Money.fromMinorUnits(netRemainingMinor),
      overspentCategoriesCount: overspentCount,
      categoryBudgets: categoryBudgets,
    );
  }
}
