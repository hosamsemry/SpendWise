import 'package:drift/drift.dart';
import 'categories_table.dart';

/// A recurring bill, subscription or regular income (rent, Netflix, salary).
/// Each due date is tracked in [BillOccurrencesTable] once it is paid or skipped.
@DataClassName('RecurringBillEntry')
class RecurringBillsTable extends Table {
  @override
  String get tableName => 'recurring_bills';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get type => text()(); // 'expense' or 'income'
  TextColumn get categoryId => text().nullable().references(
    CategoriesTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // Denormalized so a bill still shows its category after it is deleted.
  TextColumn get categoryName => text().nullable()();
  // Fixed amount, or for a variable bill the estimate the user typed. The
  // estimate shown is the latest existing payment made after [amountSetAt]
  // (see RecurringBillRepository), so undoing a payment brings it back.
  IntColumn get amountMinor => integer()();
  // When the user last set [amountMinor] (ISO-8601). Null = when created.
  TextColumn get amountSetAt => text().nullable()();
  BoolColumn get isVariable => boolean().withDefault(const Constant(false))();
  // 'weekly' | 'monthly' | 'yearly' | 'every_cycle'
  TextColumn get frequency => text()();
  // First due date 'YYYY-MM-DD'. Sets the weekday / day of month / date of
  // year that later due dates repeat on.
  TextColumn get anchorDate => text()();
  // Days before the due date to remind; null = no reminder.
  IntColumn get remindDaysBefore => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  // The day the bill was paused ('YYYY-MM-DD'); null while active. Resuming
  // skips only the due dates from this day on, not older overdue ones.
  TextColumn get pausedAt => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (amount_minor > 0)',
    "CHECK (type IN ('expense', 'income'))",
    "CHECK (frequency IN ('weekly', 'monthly', 'yearly', 'every_cycle'))",
    'CHECK (remind_days_before IS NULL OR remind_days_before >= 0)',
  ];
}
