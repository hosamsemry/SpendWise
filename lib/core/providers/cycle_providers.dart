import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'database_providers.dart';
export 'budget_cycle_start_day_provider.dart';

class RefreshTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

/// Counter provider incremented to invalidate and recompute reactive providers
/// whenever a transaction, budget, or category is saved/edited/deleted.
final refreshTriggerProvider = NotifierProvider<RefreshTriggerNotifier, int>(
  RefreshTriggerNotifier.new,
);

class CurrentNavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

/// Persistent navigation shell index provider (persists across data refreshes)
final currentNavigationIndexProvider =
    NotifierProvider<CurrentNavigationIndexNotifier, int>(
      CurrentNavigationIndexNotifier.new,
    );

/// Active categories provider (all)
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories(includeInactive: false);
});

/// Active expense categories provider
final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories(
    includeInactive: false,
    type: CategoryType.expense,
  );
});

/// Active income categories provider
final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories(
    includeInactive: false,
    type: CategoryType.income,
  );
});

/// All categories provider (including archived)
final allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories(includeInactive: true);
});

/// All expense categories provider (including archived)
final allExpenseCategoriesProvider = FutureProvider<List<Category>>((
  ref,
) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories(
    includeInactive: true,
    type: CategoryType.expense,
  );
});

/// All income categories provider (including archived)
final allIncomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllCategories(
    includeInactive: true,
    type: CategoryType.income,
  );
});

/// Current budget cycle for today's local date
final currentCycleProvider = FutureProvider<BudgetCycle>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(budgetCycleRepositoryProvider);
  return repo.getOrCreateCycleForDate(DateTime.now());
});

/// All historical and current cycles
final allCyclesProvider = FutureProvider<List<BudgetCycle>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(budgetCycleRepositoryProvider);
  return repo.getAllCycles();
});

class SelectedCycleNotifier extends Notifier<BudgetCycle?> {
  @override
  BudgetCycle? build() => null;

  void select(BudgetCycle? cycle) => state = cycle;
}

/// The budget cycle currently selected in the UI for Budgets/Reports/Summary
final selectedCycleProvider =
    NotifierProvider<SelectedCycleNotifier, BudgetCycle?>(
      SelectedCycleNotifier.new,
    );

/// Computes the complete [CycleSummary] for a specific [cycle]
final cycleSummaryProvider = FutureProvider.family<CycleSummary, BudgetCycle>((
  ref,
  cycle,
) async {
  ref.watch(refreshTriggerProvider);
  final cycleRepo = ref.watch(budgetCycleRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  final calcService = ref.watch(budgetCalculationServiceProvider);

  var effectiveCycle = cycle;
  var budgetMap = await cycleRepo.getCycleBudgets(cycle.id);
  if (budgetMap.isEmpty) {
    final dbCycle = await cycleRepo.getCycleForDateOrNull(cycle.startDate);
    if (dbCycle != null && dbCycle.id != cycle.id) {
      effectiveCycle = dbCycle;
      budgetMap = await cycleRepo.getCycleBudgets(dbCycle.id);
    }
  }

  final categories = await categoryRepo.getAllCategories(includeInactive: true);
  final transactions = await txRepo.getTransactionsForCycle(effectiveCycle);

  return calcService.calculateCycleSummary(
    cycle: effectiveCycle,
    categories: categories,
    budgetMap: budgetMap,
    transactions: transactions,
  );
});
