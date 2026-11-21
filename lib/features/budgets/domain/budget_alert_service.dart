import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/domain/budget_calculation_service.dart';
import 'package:money_tracker/features/budgets/domain/threshold_monitor.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';

/// Re-checks 80% / over-budget alerts for a cycle from its current budgets
/// and spending. Call after anything that changes either side: transaction
/// writes (via `TransactionService`) and budget edits.
///
/// [ThresholdMonitor] records each alert once per cycle/category and clears
/// the record when usage drops back below the threshold, so this both fires
/// new alerts and re-arms ones that no longer apply.
class BudgetAlertService {
  final TransactionRepository txRepo;
  final BudgetCycleRepository cycleRepo;
  final CategoryRepository categoryRepo;
  final ThresholdMonitor thresholdMonitor;
  final BudgetCalculationService calcService;

  const BudgetAlertService({
    required this.txRepo,
    required this.cycleRepo,
    required this.categoryRepo,
    required this.thresholdMonitor,
    this.calcService = const BudgetCalculationService(),
  });

  /// Re-evaluates [categoryIds] in [cycle], or every expense category in it
  /// when [categoryIds] is null.
  Future<void> reevaluate(BudgetCycle cycle, {Set<String>? categoryIds}) async {
    if (categoryIds != null && categoryIds.isEmpty) return;
    final summary = calcService.calculateCycleSummary(
      cycle: cycle,
      categories: await categoryRepo.getAllCategories(includeInactive: true),
      budgetMap: await cycleRepo.getCycleBudgets(cycle.id),
      transactions: await txRepo.getTransactionsForCycle(cycle),
    );
    for (final budget in summary.categoryBudgets) {
      // Orphan rows (deleted categories) have synthetic ids; skip them.
      if (budget.categoryId.startsWith('orphan_')) continue;
      if (categoryIds == null || categoryIds.contains(budget.categoryId)) {
        await thresholdMonitor.evaluateAndNotify(
          cycleId: cycle.id,
          budget: budget,
        );
      }
    }
  }
}
