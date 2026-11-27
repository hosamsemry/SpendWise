import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:uuid/uuid.dart';

/// Storage for savings goals. Money in and out of goals goes through
/// `SavingsVaultRepository` (via `SavingsGoalService`).
class SavingsGoalRepository {
  final AppDatabase db;
  final Uuid _uuid;

  SavingsGoalRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  SavingsGoal _toDomain(SavingsGoalEntry e) => SavingsGoal(
        id: e.id,
        name: e.name,
        icon: e.icon,
        target: Money.fromMinorUnits(e.targetMinor),
        targetDate: e.targetDate == null ? null : BudgetCycleCalculator.parseDate(e.targetDate!),
        monthlyPlan: e.monthlyPlanMinor == null ? null : Money.fromMinorUnits(e.monthlyPlanMinor!),
        priority: e.priority,
        achievedAt: e.achievedAt == null ? null : DateTime.tryParse(e.achievedAt!),
        createdAt: DateTime.parse(e.createdAt),
        updatedAt: DateTime.parse(e.updatedAt),
      );

  /// All goals in fill order (priority, then oldest first).
  Future<List<SavingsGoal>> getGoals() async {
    final rows = await (db.select(db.savingsGoalsTable)
          ..orderBy([
            (t) => OrderingTerm.asc(t.priority),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return rows.map(_toDomain).toList();
  }

  Future<SavingsGoal?> getGoal(String id) async {
    final row = await (db.select(db.savingsGoalsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  static void _validate(String name, Money target, Money? monthlyPlan) {
    if (name.trim().isEmpty) throw ArgumentError('Goal name cannot be empty');
    if (target.inMinorUnits <= 0) throw ArgumentError('Goal target must be greater than zero');
    if (monthlyPlan != null && monthlyPlan.inMinorUnits <= 0) {
      throw ArgumentError('Monthly plan must be greater than zero');
    }
  }

  /// Creates a goal at the end of the fill order.
  Future<SavingsGoal> createGoal({
    required String name,
    String? icon,
    required Money target,
    DateTime? targetDate,
    Money? monthlyPlan,
  }) async {
    _validate(name, target, monthlyPlan);
    final goals = await getGoals();
    final nextPriority = goals.isEmpty ? 0 : goals.map((g) => g.priority).reduce((a, b) => a > b ? a : b) + 1;
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await db.into(db.savingsGoalsTable).insert(
          SavingsGoalsTableCompanion.insert(
            id: id,
            name: name.trim(),
            icon: Value(icon),
            targetMinor: target.inMinorUnits,
            targetDate: Value(targetDate == null ? null : BudgetCycleCalculator.formatDate(targetDate)),
            monthlyPlanMinor: Value(monthlyPlan?.inMinorUnits),
            priority: Value(nextPriority),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getGoal(id))!;
  }

  /// Replaces the editable fields of [goal]. Raising the target above the
  /// saved balance is handled by the service (it clears [SavingsGoal.achievedAt]).
  Future<void> updateGoal(SavingsGoal goal) async {
    _validate(goal.name, goal.target, goal.monthlyPlan);
    await (db.update(db.savingsGoalsTable)..where((t) => t.id.equals(goal.id))).write(
      SavingsGoalsTableCompanion(
        name: Value(goal.name.trim()),
        icon: Value(goal.icon),
        targetMinor: Value(goal.target.inMinorUnits),
        targetDate: Value(goal.targetDate == null ? null : BudgetCycleCalculator.formatDate(goal.targetDate!)),
        monthlyPlanMinor: Value(goal.monthlyPlan?.inMinorUnits),
        achievedAt: Value(goal.achievedAt?.toIso8601String()),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> setAchievedAt(String id, DateTime? at) async {
    await (db.update(db.savingsGoalsTable)..where((t) => t.id.equals(id))).write(
      SavingsGoalsTableCompanion(achievedAt: Value(at?.toIso8601String())),
    );
  }

  /// Saves a new fill order: [orderedIds] first to last.
  Future<void> reorder(List<String> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.savingsGoalsTable)..where((t) => t.id.equals(orderedIds[i]))).write(
          SavingsGoalsTableCompanion(priority: Value(i)),
        );
      }
    });
  }

  /// Deletes the goal. Its history stays and its money returns to
  /// Unassigned (the movements' goal id is set to null by the foreign key).
  Future<void> deleteGoal(String id) async {
    await (db.delete(db.savingsGoalsTable)..where((t) => t.id.equals(id))).go();
  }
}
