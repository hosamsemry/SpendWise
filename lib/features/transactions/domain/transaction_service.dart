import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/domain/budget_alert_service.dart';
import 'package:money_tracker/features/budgets/domain/budget_calculation_service.dart';
import 'package:money_tracker/features/budgets/domain/threshold_monitor.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/savings/domain/savings_sync_service.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

/// Single entry point for every ledger write (manual entry, presets, undo,
/// confirmed bank alerts). Each operation persists the change and then runs
/// all dependent side effects, so callers never have to remember them:
///
/// 1. Ensures a budget cycle exists for the transaction date, using the
///    user's configured cycle start day (via the injected [cycleRepo]).
/// 2. Re-syncs the auto "Savings" budget for every cycle touched by income
///    (both the previous and the new version of an edited transaction).
/// 3. Re-evaluates 80% / over-budget thresholds for every expense category
///    touched, which fires new alerts and re-arms cleared ones.
///
/// UI refresh (`refreshTriggerProvider`) stays the caller's responsibility.
class TransactionService {
  final TransactionRepository txRepo;
  final BudgetCycleRepository cycleRepo;
  final CategoryRepository categoryRepo;
  final SavingsSyncService savingsSync;
  final ThresholdMonitor thresholdMonitor;
  final BudgetCalculationService calcService;

  const TransactionService({
    required this.txRepo,
    required this.cycleRepo,
    required this.categoryRepo,
    required this.savingsSync,
    required this.thresholdMonitor,
    this.calcService = const BudgetCalculationService(),
  });

  BudgetAlertService get _alerts => BudgetAlertService(
        txRepo: txRepo,
        cycleRepo: cycleRepo,
        categoryRepo: categoryRepo,
        thresholdMonitor: thresholdMonitor,
        calcService: calcService,
      );

  Future<TransactionModel> add({
    required TransactionType type,
    required Money amount,
    String? categoryId,
    required DateTime date,
    String? note,
  }) async {
    await cycleRepo.getOrCreateCycleForDate(date);
    final added = await txRepo.addTransaction(
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    await _applySideEffects(after: [added]);
    return added;
  }

  /// Replaces all editable fields of transaction [id].
  /// A `null` [categoryId] or [note] clears that field.
  Future<TransactionModel> update({
    required String id,
    required TransactionType type,
    required Money amount,
    required String? categoryId,
    required DateTime date,
    required String? note,
  }) async {
    final before = await txRepo.getTransactionById(id);
    await cycleRepo.getOrCreateCycleForDate(date);
    final updated = await txRepo.updateTransaction(
      id: id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
    );
    await _applySideEffects(before: [?before], after: [updated]);
    return updated;
  }

  Future<void> delete(TransactionModel tx) async {
    await txRepo.deleteTransaction(tx.id);
    await _applySideEffects(before: [tx]);
  }

  /// Re-inserts a previously deleted [tx] (SnackBar undo).
  Future<TransactionModel> restore(TransactionModel tx) async {
    await cycleRepo.getOrCreateCycleForDate(tx.date);
    final restored = await txRepo.restoreTransaction(tx);
    await _applySideEffects(after: [restored]);
    return restored;
  }

  /// [before]: versions that no longer exist (deleted / pre-edit). Their cycles
  /// are looked up but never created. [after]: versions now in the ledger.
  Future<void> _applySideEffects({
    List<TransactionModel> before = const [],
    List<TransactionModel> after = const [],
  }) async {
    final cyclesById = <String, BudgetCycle>{};
    final savingsCycleIds = <String>{};
    final thresholdKeys = <String, Set<String>>{}; // cycleId -> categoryIds

    Future<void> collect(TransactionModel tx, {required bool create}) async {
      final cycle = create
          ? await cycleRepo.getOrCreateCycleForDate(tx.date)
          : await cycleRepo.getCycleForDateOrNull(tx.date);
      if (cycle == null) return;
      cyclesById[cycle.id] = cycle;

      if (tx.isIncome) savingsCycleIds.add(cycle.id);

      final categoryId = tx.categoryId;
      if (tx.isExpense && categoryId != null && categoryId.isNotEmpty) {
        thresholdKeys.putIfAbsent(cycle.id, () => <String>{}).add(categoryId);
      }
    }

    for (final tx in before) {
      await collect(tx, create: false);
    }
    for (final tx in after) {
      await collect(tx, create: true);
    }

    // Savings first: it changes the Savings budget that thresholds read.
    for (final cycleId in savingsCycleIds) {
      await savingsSync.syncSavingsBudgetForCycle(cycleId: cycleId);
    }

    for (final entry in thresholdKeys.entries) {
      await _alerts.reevaluate(cyclesById[entry.key]!, categoryIds: entry.value);
    }
  }
}
