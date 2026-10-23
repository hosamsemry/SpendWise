import 'package:drift/drift.dart';

@DataClassName('CategoryEntry')
class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get defaultBudgetMinor =>
      integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get type =>
      text().withDefault(const Constant('expense'))(); // 'expense' or 'income'
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (name COLLATE NOCASE, type)',
    'CHECK (default_budget_minor >= 0)',
    "CHECK (type IN ('expense', 'income'))",
  ];
}
