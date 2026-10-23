import 'package:drift/drift.dart';

@DataClassName('BudgetCycleEntry')
class BudgetCyclesTable extends Table {
  @override
  String get tableName => 'budget_cycles';

  TextColumn get id => text()();
  TextColumn get startDate => text().unique()();
  TextColumn get endDate => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}
