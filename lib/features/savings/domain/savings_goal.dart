import 'package:money_tracker/core/money/money.dart';

/// A named pocket inside the Savings Vault (Eid, Car, Emergency fund).
class SavingsGoal {
  final String id;
  final String name;

  /// Key into the goal icon set (see `goalIconFor`); null = default.
  final String? icon;
  final Money target;
  final DateTime? targetDate;

  /// What the cycle closeout puts in each cycle; null = nothing automatic.
  final Money? monthlyPlan;

  /// Lower fills first at closeout.
  final int priority;

  /// When the balance first reached the target; null until then.
  final DateTime? achievedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavingsGoal({
    required this.id,
    required this.name,
    this.icon,
    required this.target,
    this.targetDate,
    this.monthlyPlan,
    this.priority = 0,
    this.achievedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAchieved => achievedAt != null;

  /// A copy with the given fields replaced. Pass `clearTargetDate` /
  /// `clearMonthlyPlan` to remove those optional values.
  SavingsGoal copyWith({
    String? name,
    String? icon,
    Money? target,
    DateTime? targetDate,
    bool clearTargetDate = false,
    Money? monthlyPlan,
    bool clearMonthlyPlan = false,
  }) {
    return SavingsGoal(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      target: target ?? this.target,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      monthlyPlan: clearMonthlyPlan ? null : (monthlyPlan ?? this.monthlyPlan),
      priority: priority,
      achievedAt: achievedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

enum SavingsMovementKind {
  opening('opening'),
  sweep('sweep'),
  deposit('deposit'),
  withdraw('withdraw'),
  transfer('transfer');

  final String dbValue;
  const SavingsMovementKind(this.dbValue);

  static SavingsMovementKind fromDb(String v) => SavingsMovementKind.values.firstWhere(
        (k) => k.dbValue == v,
        orElse: () => SavingsMovementKind.deposit,
      );
}

/// One row of savings history. [goalId] null = Unassigned.
class SavingsMovement {
  final String id;
  final String? goalId;

  /// Signed: positive into the bucket, negative out of it.
  final Money amount;
  final SavingsMovementKind kind;
  final String groupId;
  final String? cycleId;
  final DateTime createdAt;

  const SavingsMovement({
    required this.id,
    this.goalId,
    required this.amount,
    required this.kind,
    required this.groupId,
    this.cycleId,
    required this.createdAt,
  });
}

/// A goal together with the money it holds.
class GoalWithBalance {
  final SavingsGoal goal;
  final Money balance;

  const GoalWithBalance({required this.goal, required this.balance});

  /// Share of the target saved, 0–1.
  double get fraction {
    final t = goal.target.inMinorUnits;
    if (t <= 0) return 0;
    final f = balance.inMinorUnits / t;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }

  bool get isReached => balance.inMinorUnits >= goal.target.inMinorUnits;

  Money get remaining {
    final r = goal.target.inMinorUnits - balance.inMinorUnits;
    return Money.fromMinorUnits(r < 0 ? 0 : r);
  }
}
