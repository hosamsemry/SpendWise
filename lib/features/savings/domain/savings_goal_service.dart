import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/savings/data/savings_goal_repository.dart';
import 'package:money_tracker/features/savings/data/savings_vault_repository.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:money_tracker/features/savings/domain/savings_planner.dart';

/// Result of a vault action: the group id to undo it with, and any goals
/// that reached their target because of it (to celebrate).
class SavingsActionResult {
  final String groupId;
  final List<SavingsGoal> newlyAchieved;

  const SavingsActionResult({required this.groupId, this.newlyAchieved = const []});
}

/// Every savings-goal write goes through here, so a goal is marked achieved
/// the first time its balance reaches the target. Money never enters the
/// cycle budget: taking money out of a goal is not an expense.
///
/// UI refresh (`refreshTriggerProvider`) stays the caller's responsibility.
class SavingsGoalService {
  final SavingsVaultRepository vault;
  final SavingsGoalRepository goals;
  final SavingsPlanner planner;
  final DateTime Function() clock;

  SavingsGoalService({
    required this.vault,
    required this.goals,
    required this.planner,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// Goals in fill order with the money each holds.
  Future<List<GoalWithBalance>> goalsWithBalances() async {
    final balances = await vault.bucketBalances();
    return [
      for (final g in await goals.getGoals())
        GoalWithBalance(goal: g, balance: balances[g.id] ?? const Money.zero()),
    ];
  }

  Future<Money> unassignedBalance() async =>
      (await vault.bucketBalances())[null] ?? const Money.zero();

  /// The default closeout split: monthly plans in fill order, rest Unassigned.
  Future<Map<String?, Money>> defaultSweepSplit(Money surplus) async =>
      planner.splitSurplus(surplus, await goalsWithBalances());

  /// Marks goals that just reached their target. Returns them.
  Future<List<SavingsGoal>> _markReached() async {
    final reached = <SavingsGoal>[];
    for (final g in await goalsWithBalances()) {
      if (g.isReached && !g.goal.isAchieved) {
        await goals.setAchievedAt(g.goal.id, clock());
        reached.add(g.goal);
      }
    }
    return reached;
  }

  /// Sweeps a closed cycle's surplus with [allocation] (see
  /// [SavingsVaultRepository.sweepSurplus]). Returns null if that cycle was
  /// already swept.
  Future<SavingsActionResult?> sweep({
    required String cycleId,
    required Money amount,
    required Map<String?, Money> allocation,
  }) async {
    final swept = await vault.sweepSurplus(cycleId: cycleId, amount: amount, allocation: allocation);
    if (!swept) return null;
    return SavingsActionResult(groupId: 'sweep:$cycleId', newlyAchieved: await _markReached());
  }

  Future<bool> undoSweep(String cycleId, {List<SavingsGoal> achievedByIt = const []}) async {
    final undone = await vault.undoSweep(cycleId: cycleId);
    if (undone) await _clearAchieved(achievedByIt);
    return undone;
  }

  Future<SavingsActionResult> deposit(Money amount, {String? goalId}) async {
    final groupId = vault.newGroupId();
    await vault.deposit(amount: amount, goalId: goalId, groupId: groupId);
    return SavingsActionResult(groupId: groupId, newlyAchieved: await _markReached());
  }

  Future<SavingsActionResult> withdraw(Money amount, {String? goalId}) async {
    final groupId = vault.newGroupId();
    await vault.withdraw(amount: amount, goalId: goalId, groupId: groupId);
    return SavingsActionResult(groupId: groupId);
  }

  Future<SavingsActionResult> transfer(Money amount, {required String? from, required String? to}) async {
    final groupId = vault.newGroupId();
    await vault.transfer(from: from, to: to, amount: amount, groupId: groupId);
    return SavingsActionResult(groupId: groupId, newlyAchieved: await _markReached());
  }

  /// Undoes a deposit, withdrawal or transfer. Goals it made achieved go back
  /// to in progress. Returns false if the money has moved on since.
  Future<bool> undo(SavingsActionResult result) async {
    final undone = await vault.undoGroup(result.groupId);
    if (undone) await _clearAchieved(result.newlyAchieved);
    return undone;
  }

  Future<void> _clearAchieved(List<SavingsGoal> list) async {
    for (final g in list) {
      await goals.setAchievedAt(g.id, null);
    }
  }

  Future<SavingsActionResult> createGoal({
    required String name,
    String? icon,
    required Money target,
    DateTime? targetDate,
    Money? monthlyPlan,
    Money? startingAmount,
  }) async {
    final goal = await goals.createGoal(
      name: name,
      icon: icon,
      target: target,
      targetDate: targetDate,
      monthlyPlan: monthlyPlan,
    );
    // Move money the user already has in Unassigned into the new goal.
    if (startingAmount != null && startingAmount.inMinorUnits > 0) {
      return transfer(startingAmount, from: null, to: goal.id);
    }
    return SavingsActionResult(groupId: '', newlyAchieved: await _markReached());
  }

  /// Saves [goal]. Raising the target above the balance makes an achieved
  /// goal in progress again; lowering it to the balance achieves it.
  Future<List<SavingsGoal>> updateGoal(SavingsGoal goal) async {
    final balance = (await vault.bucketBalances())[goal.id] ?? const Money.zero();
    final reached = balance.inMinorUnits >= goal.target.inMinorUnits;
    await goals.updateGoal(SavingsGoal(
      id: goal.id,
      name: goal.name,
      icon: goal.icon,
      target: goal.target,
      targetDate: goal.targetDate,
      monthlyPlan: goal.monthlyPlan,
      priority: goal.priority,
      achievedAt: reached ? goal.achievedAt : null,
      createdAt: goal.createdAt,
      updatedAt: goal.updatedAt,
    ));
    return _markReached();
  }

  /// Deletes [goal]; its money returns to Unassigned.
  Future<void> deleteGoal(SavingsGoal goal) => goals.deleteGoal(goal.id);

  Future<void> reorder(List<String> orderedIds) => goals.reorder(orderedIds);
}
