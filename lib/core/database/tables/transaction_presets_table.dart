import 'package:drift/drift.dart';
import 'categories_table.dart';

@DataClassName('TransactionPresetEntry')
class TransactionPresetsTable extends Table {
  @override
  String get tableName => 'transaction_presets';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get type => text()();
  TextColumn get categoryId => text().nullable().references(
    CategoriesTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get categoryName => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount_minor > 0)',
    "CHECK (type IN ('expense', 'income'))",
  ];
}
