import 'package:drift/drift.dart';

/// A named savings goal: a pocket inside the Savings Vault. Its balance is
/// the sum of its [SavingsMovementsTable] rows.
@DataClassName('SavingsGoalEntry')
class SavingsGoalsTable extends Table {
  @override
  String get tableName => 'savings_goals';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  IntColumn get targetMinor => integer()();
  TextColumn get targetDate => text().nullable()(); // 'YYYY-MM-DD'
  // How much the cycle closeout sweep puts in each cycle; null = none.
  IntColumn get monthlyPlanMinor => integer().nullable()();
  // Lower fills first at closeout.
  IntColumn get priority => integer().withDefault(const Constant(0))();
  // Set the first time the balance reaches the target.
  TextColumn get achievedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (target_minor > 0)',
    'CHECK (monthly_plan_minor IS NULL OR monthly_plan_minor > 0)',
  ];
}
