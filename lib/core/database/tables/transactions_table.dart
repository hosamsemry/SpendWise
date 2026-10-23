import 'package:drift/drift.dart';
import 'categories_table.dart';

@DataClassName('TransactionEntry')
class TransactionsTable extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get type => text()(); // 'income' or 'expense'
  IntColumn get amountMinor => integer()();
  TextColumn get categoryId => text().nullable().references(
    CategoriesTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get categoryName => text().nullable()();
  TextColumn get transactionDate => text()(); // 'YYYY-MM-DD'
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('income', 'expense'))",
    'CHECK (amount_minor > 0)',
    "CHECK (type != 'expense' OR category_id IS NOT NULL OR category_name IS NOT NULL)",
  ];
}
