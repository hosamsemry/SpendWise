import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/savings/data/savings_vault_repository.dart';
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
  final prevCycle = cycleRepo.calculator.getPreviousCycle(currentCycle);

  // 1. Check if previous cycle was actually recorded in database
  final dbPrevCycle = await cycleRepo.getCycleForDateOrNull(prevCycle.startDate);
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
