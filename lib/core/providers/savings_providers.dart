import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/savings/data/savings_goal_repository.dart';
import 'package:money_tracker/features/savings/data/savings_vault_repository.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:money_tracker/features/savings/domain/savings_goal_service.dart';
import 'package:money_tracker/features/savings/domain/savings_planner.dart';
import 'package:money_tracker/features/savings/domain/savings_sync_service.dart';
import 'package:money_tracker/features/savings/domain/savings_vault.dart';

/// Information about a closed cycle that has an unspent surplus eligible for sweeping.
class CycleCloseoutInfo {
  final BudgetCycle cycle;
  final Money surplus;
  final CycleSummary summary;

  const CycleCloseoutInfo({
    required this.cycle,
    required this.surplus,
    required this.summary,
  });
}

/// Singleton provider for [SavingsVaultRepository].
final savingsVaultRepositoryProvider = Provider<SavingsVaultRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SavingsVaultRepository(db);
});

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  return SavingsGoalRepository(ref.watch(databaseProvider));
});

/// Goal maths on the user's budget cycles.
final savingsPlannerProvider = Provider<SavingsPlanner>((ref) {
  return SavingsPlanner(ref.watch(budgetCycleRepositoryProvider).calculator);
});

/// Use this for every goal and vault money write. See [SavingsGoalService].
final savingsGoalServiceProvider = Provider<SavingsGoalService>((ref) {
  return SavingsGoalService(
    vault: ref.watch(savingsVaultRepositoryProvider),
    goals: ref.watch(savingsGoalRepositoryProvider),
    planner: ref.watch(savingsPlannerProvider),
  );
});

class GoalOverviewItem {
  final GoalWithBalance goal;
  final GoalForecast forecast;
  const GoalOverviewItem({required this.goal, required this.forecast});
}

class SavingsOverview {
  final Money total;
  final Money unassigned;

  /// Goals in fill order; achieved ones included.
  final List<GoalOverviewItem> goals;
  const SavingsOverview({required this.total, required this.unassigned, required this.goals});

  List<GoalOverviewItem> get activeGoals => goals.where((g) => !g.goal.goal.isAchieved).toList();
  List<GoalOverviewItem> get achievedGoals => goals.where((g) => g.goal.goal.isAchieved).toList();
}

/// The vault split into goals and Unassigned, with each goal's forecast.
final savingsOverviewProvider = FutureProvider<SavingsOverview>((ref) async {
  ref.watch(refreshTriggerProvider);
  final vault = ref.watch(savingsVaultRepositoryProvider);
  final service = ref.watch(savingsGoalServiceProvider);
  final planner = ref.watch(savingsPlannerProvider);
  final today = DateTime.now();

  final goals = await service.goalsWithBalances();
  final movements = await vault.getMovements();
  final balances = await vault.bucketBalances();
  var total = 0;
  for (final b in balances.values) {
    total += b.inMinorUnits;
  }
  return SavingsOverview(
    total: Money.fromMinorUnits(total),
    unassigned: balances[null] ?? const Money.zero(),
    goals: [
      for (final g in goals)
        GoalOverviewItem(goal: g, forecast: planner.forecast(g, movements, today)),
    ],
  );
});

/// History of one goal (or Unassigned when [goalId] is null), newest first.
final savingsHistoryProvider =
    FutureProvider.family<List<SavingsMovement>, String?>((ref, goalId) async {
  ref.watch(refreshTriggerProvider);
  final all = await ref.watch(savingsVaultRepositoryProvider).getMovements();
  return all.where((m) => m.goalId == goalId).toList();
});

/// Singleton provider for [SavingsSyncService].
final savingsSyncServiceProvider = Provider<SavingsSyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final catRepo = ref.watch(categoryRepositoryProvider);
  final cycleRepo = ref.watch(budgetCycleRepositoryProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);

  return SavingsSyncService(
    db: db,
    categoryRepo: catRepo,
    cycleRepo: cycleRepo,
    txRepo: txRepo,
  );
});

/// Reactive provider for the full [SavingsVault] state.
final savingsVaultProvider = FutureProvider<SavingsVault>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(savingsVaultRepositoryProvider);
  return repo.getVault();
});

/// Reactive provider for the current Lifetime Savings Vault balance.
final savingsVaultBalanceProvider = FutureProvider<Money>((ref) async {
  final vault = await ref.watch(savingsVaultProvider.future);
  return vault.balance;
});

/// Evaluates whether the preceding cycle ended with unspent surplus that has not
/// yet been swept into the vault or dismissed by the user.
final pendingCycleCloseoutProvider =
    FutureProvider<CycleCloseoutInfo?>((ref) async {
  ref.watch(refreshTriggerProvider);

  final savingsRepo = ref.watch(savingsVaultRepositoryProvider);
  final cycleRepo = ref.watch(budgetCycleRepositoryProvider);

  final currentCycle = await ref.watch(currentCycleProvider.future);

  // 1. The recorded cycle just before the current one (by date, so it is
  // right after a start-day change too). None recorded: nothing to close.
  final dbPrevCycle = await cycleRepo.getPreviousRecordedCycle(currentCycle);
  if (dbPrevCycle == null) return null;

  // 2. Check if user already swept or dismissed this cycle
  final isSwept = await savingsRepo.isCycleSwept(dbPrevCycle.id);
  if (isSwept) return null;

  final isDismissed = await savingsRepo.isCycleDismissed(dbPrevCycle.id);
  if (isDismissed) return null;

  // 3. Check if previous cycle had net surplus
  final prevSummary = await ref.watch(cycleSummaryProvider(dbPrevCycle).future);
  if (prevSummary.netRemainingTotal.inMinorUnits > 0) {
    return CycleCloseoutInfo(
      cycle: dbPrevCycle,
      surplus: prevSummary.netRemainingTotal,
      summary: prevSummary,
    );
  }

  return null;
});
