import 'package:drift/drift.dart';
import 'recurring_bills_table.dart';
import 'transactions_table.dart';

/// One handled due date of a [RecurringBillsTable] bill: paid (with the
/// transaction it created) or skipped. Due dates without a row are unpaid.
@DataClassName('BillOccurrenceEntry')
class BillOccurrencesTable extends Table {
  @override
  String get tableName => 'bill_occurrences';

  TextColumn get id => text()();
  TextColumn get billId => text().references(
    RecurringBillsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get dueDate => text()(); // 'YYYY-MM-DD'
  TextColumn get status => text()(); // 'paid' | 'skipped'
  // Deleting the payment makes the due date unpaid again.
  TextColumn get transactionId => text().nullable().references(
    TransactionsTable,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {billId, dueDate},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status IN ('paid', 'skipped'))",
  ];
}
