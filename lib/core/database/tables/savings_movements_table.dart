import 'package:drift/drift.dart';
import 'savings_goals_table.dart';

/// Every movement of money into, out of or within the Savings Vault. The
/// vault balance is the sum of all rows; a goal's balance is the sum of its
/// rows, and rows without a goal are "Unassigned". Deleting a goal sets its
/// rows' goal to null, which returns its money to Unassigned.
@DataClassName('SavingsMovementEntry')
class SavingsMovementsTable extends Table {
  @override
  String get tableName => 'savings_movements';

  TextColumn get id => text()();
  TextColumn get goalId => text().nullable().references(
    SavingsGoalsTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // Signed: positive adds to the bucket, negative takes out.
  IntColumn get amountMinor => integer()();
  // 'opening' | 'sweep' | 'deposit' | 'withdraw' | 'transfer'
  TextColumn get kind => text()();
  // Rows written by one action share a group id (a sweep split, a transfer),
  // so undo removes them together.
  TextColumn get groupId => text()();
  // The budget cycle a sweep came from.
  TextColumn get cycleId => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount_minor != 0)',
    "CHECK (kind IN ('opening', 'sweep', 'deposit', 'withdraw', 'transfer'))",
  ];
}
