import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/bills/domain/bill_schedule.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:uuid/uuid.dart';

/// Storage for recurring bills and their handled due dates. Paying a bill
/// also writes a transaction, so UI code goes through `BillService`.
class RecurringBillRepository {
  final AppDatabase db;
  final Uuid _uuid;

  RecurringBillRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  RecurringBill _toDomain(RecurringBillEntry e, {String? liveCategoryName}) {
    return RecurringBill(
      id: e.id,
      title: e.title,
      type: TransactionType.fromString(e.type),
      categoryId: e.categoryId,
      categoryName: liveCategoryName ?? e.categoryName,
      amount: Money.fromMinorUnits(e.amountMinor),
      isVariable: e.isVariable,
      frequency: BillFrequency.fromDb(e.frequency),
      anchorDate: BudgetCycleCalculator.parseDate(e.anchorDate),
      remindDaysBefore: e.remindDaysBefore,
      isActive: e.isActive,
      note: e.note,
      createdAt: DateTime.parse(e.createdAt),
      updatedAt: DateTime.parse(e.updatedAt),
    );
  }

  /// All bills with their current category names, alphabetically.
  Future<List<RecurringBill>> getAllBills() async {
    final bills = db.recurringBillsTable;
    final categories = db.categoriesTable;
    final rows = await (db.select(bills).join([
      leftOuterJoin(categories, categories.id.equalsExp(bills.categoryId)),
    ])
          ..orderBy([OrderingTerm.asc(bills.title)]))
        .get();
    return rows
        .map((row) => _toDomain(
              row.readTable(bills),
              liveCategoryName: row.readTableOrNull(categories)?.name,
            ))
        .toList();
  }

  Future<RecurringBill?> getBill(String id) async {
    final all = await getAllBills();
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<String?> _categoryName(String? categoryId) async {
    if (categoryId == null || categoryId.isEmpty) return null;
    final cat = await (db.select(db.categoriesTable)
          ..where((t) => t.id.equals(categoryId)))
        .getSingleOrNull();
    return cat?.name;
  }

  void _validate({
    required String title,
    required TransactionType type,
    required Money amount,
    required String? categoryId,
  }) {
    if (title.trim().isEmpty) throw ArgumentError('Bill title cannot be empty');
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Bill amount must be greater than zero');
    }
    if (type == TransactionType.expense && (categoryId == null || categoryId.isEmpty)) {
      throw ArgumentError('Category is required for expense bills');
    }
  }

  static String? _cleanNote(String? note) {
    final t = note?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<RecurringBill> createBill({
    required String title,
    required TransactionType type,
    String? categoryId,
    required Money amount,
    bool isVariable = false,
    required BillFrequency frequency,
    required DateTime anchorDate,
    int? remindDaysBefore,
    String? note,
  }) async {
    _validate(title: title, type: type, amount: amount, categoryId: categoryId);
    final catName = await _categoryName(categoryId);
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    await db.into(db.recurringBillsTable).insert(
          RecurringBillsTableCompanion.insert(
            id: id,
            title: title.trim(),
            type: type.toDbString(),
            categoryId: Value(catName == null ? null : categoryId),
            categoryName: Value(catName),
            amountMinor: amount.inMinorUnits,
            isVariable: Value(isVariable),
            frequency: frequency.dbValue,
            anchorDate: BudgetCycleCalculator.formatDate(anchorDate),
            remindDaysBefore: Value(remindDaysBefore),
            note: Value(_cleanNote(note)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getBill(id))!;
  }

  /// Replaces every editable field of [bill] (matched by id).
  Future<void> updateBill(RecurringBill bill) async {
    _validate(
      title: bill.title,
      type: bill.type,
      amount: bill.amount,
      categoryId: bill.categoryId,
    );
    final catName = await _categoryName(bill.categoryId);
    await (db.update(db.recurringBillsTable)..where((t) => t.id.equals(bill.id))).write(
      RecurringBillsTableCompanion(
        title: Value(bill.title.trim()),
        type: Value(bill.type.toDbString()),
        categoryId: Value(catName == null ? null : bill.categoryId),
        categoryName: Value(catName ?? bill.categoryName),
        amountMinor: Value(bill.amount.inMinorUnits),
        isVariable: Value(bill.isVariable),
        frequency: Value(bill.frequency.dbValue),
        anchorDate: Value(BudgetCycleCalculator.formatDate(bill.anchorDate)),
        remindDaysBefore: Value(bill.remindDaysBefore),
        isActive: Value(bill.isActive),
        note: Value(_cleanNote(bill.note)),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  Future<void> setActive(String id, bool isActive) async {
    await (db.update(db.recurringBillsTable)..where((t) => t.id.equals(id))).write(
      RecurringBillsTableCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Stores [amount] as the new estimate of a variable bill.
  Future<void> updateAmount(String id, Money amount) async {
    if (amount.inMinorUnits <= 0) return;
    await (db.update(db.recurringBillsTable)..where((t) => t.id.equals(id))).write(
      RecurringBillsTableCompanion(amountMinor: Value(amount.inMinorUnits)),
    );
  }

  /// Deletes the bill and its due-date history. Transactions it created stay.
  Future<void> deleteBill(String id) async {
    await db.transaction(() async {
      await (db.delete(db.billOccurrencesTable)..where((t) => t.billId.equals(id))).go();
      await (db.delete(db.recurringBillsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Bill id → [BillSchedule.dateKey]s that are paid or skipped.
  Future<Map<String, Set<String>>> getHandledDueDates() async {
    final rows = await db.select(db.billOccurrencesTable).get();
    final map = <String, Set<String>>{};
    for (final r in rows) {
      map.putIfAbsent(r.billId, () => <String>{}).add(r.dueDate);
    }
    return map;
  }

  /// Ids of the transactions that paid a bill. Safe-to-spend already set
  /// that money aside, so these don't count as day-to-day spending.
  Future<Set<String>> getBillPaymentTransactionIds() async {
    final occ = db.billOccurrencesTable;
    final rows = await (db.select(occ)..where((t) => t.transactionId.isNotNull())).get();
    return {for (final r in rows) r.transactionId!};
  }

  /// Handled due dates of [billId], newest first, with payment amounts.
  Future<List<BillOccurrence>> getOccurrences(String billId) async {
    final occ = db.billOccurrencesTable;
    final txs = db.transactionsTable;
    final rows = await (db.select(occ).join([
      leftOuterJoin(txs, txs.id.equalsExp(occ.transactionId)),
    ])
          ..where(occ.billId.equals(billId))
          ..orderBy([OrderingTerm.desc(occ.dueDate)]))
        .get();
    return rows.map((row) {
      final r = row.readTable(occ);
      final tx = row.readTableOrNull(txs);
      return BillOccurrence(
        id: r.id,
        billId: r.billId,
        dueDate: BudgetCycleCalculator.parseDate(r.dueDate),
        status: BillOccurrenceStatus.fromDb(r.status),
        transactionId: r.transactionId,
        amount: tx == null ? null : Money.fromMinorUnits(tx.amountMinor),
        createdAt: DateTime.parse(r.createdAt),
      );
    }).toList();
  }

  /// Marks [dueDate] of [billId] as paid (by [transactionId]) or skipped,
  /// replacing any earlier record for that date.
  Future<void> recordOccurrence({
    required String billId,
    required DateTime dueDate,
    required BillOccurrenceStatus status,
    String? transactionId,
  }) async {
    await db.into(db.billOccurrencesTable).insert(
          BillOccurrencesTableCompanion.insert(
            id: _uuid.v4(),
            billId: billId,
            dueDate: BillSchedule.dateKey(dueDate),
            status: status.dbValue,
            transactionId: Value(transactionId),
            createdAt: DateTime.now().toIso8601String(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Makes [dueDate] of [billId] unpaid again (undo of a skip).
  Future<void> clearOccurrence(String billId, DateTime dueDate) async {
    await (db.delete(db.billOccurrencesTable)
          ..where((t) => t.billId.equals(billId) & t.dueDate.equals(BillSchedule.dateKey(dueDate))))
        .go();
  }
}
