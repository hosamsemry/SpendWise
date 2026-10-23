import 'package:drift/drift.dart';
import 'budget_cycles_table.dart';
import 'categories_table.dart';

@DataClassName('CategoryBudgetEntry')
class CategoryBudgetsTable extends Table {
  @override
  String get tableName => 'category_budgets';

  TextColumn get id => text()();
  TextColumn get cycleId => text().references(BudgetCyclesTable, #id)();
  TextColumn get categoryId => text().references(CategoriesTable, #id)();
  IntColumn get budgetAmountMinor => integer()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {cycleId, categoryId},
  ];

  @override
  List<String> get customConstraints => ['CHECK (budget_amount_minor >= 0)'];
}
