import 'package:drift/drift.dart';
import 'budget_cycles_table.dart';
import 'categories_table.dart';

@DataClassName('NotificationEventEntry')
class NotificationEventsTable extends Table {
  @override
  String get tableName => 'notification_events';

  TextColumn get id => text()();
  TextColumn get cycleId => text().references(BudgetCyclesTable, #id)();
  TextColumn get categoryId => text().references(CategoriesTable, #id)();
  TextColumn get eventType => text()(); // 'reached_80_percent' or 'over_budget'
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {cycleId, categoryId, eventType},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (event_type IN ('reached_80_percent', 'over_budget'))",
  ];
}
