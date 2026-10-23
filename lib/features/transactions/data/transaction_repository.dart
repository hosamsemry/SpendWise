import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:uuid/uuid.dart';

const Object _unsetField = Object();

class TransactionRepository {
  final AppDatabase db;
  final Uuid _uuid;

  TransactionRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  TransactionModel _mapToDomain(
    TransactionEntry entry, {
    String? categoryName,
  }) {
    return TransactionModel(
      id: entry.id,
      type: TransactionType.fromString(entry.type),
      amount: Money.fromMinorUnits(entry.amountMinor),
      categoryId: entry.categoryId,
      categoryName: categoryName ?? entry.categoryName,
      date: BudgetCycleCalculator.parseDate(entry.transactionDate),
      note: entry.note,
      createdAt: DateTime.parse(BudgetCycleCalculator.normalizeDigits(entry.createdAt)),
      updatedAt: DateTime.parse(BudgetCycleCalculator.normalizeDigits(entry.updatedAt)),
    );
  }

  /// Adds a new transaction.
  ///
  /// - [amount] must be greater than zero.
  /// - [categoryId] is required if [type] is [TransactionType.expense].
  /// - [categoryId] is optional/supported if [type] is [TransactionType.income].
  Future<TransactionModel> addTransaction({
    required TransactionType type,
    required Money amount,
    String? categoryId,
    required DateTime date,
    String? note,
  }) async {
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }

    if (type == TransactionType.expense &&
        (categoryId == null || categoryId.isEmpty)) {
      throw ArgumentError('Category is required for expense transactions');
    }

    String? categoryName;
    if (categoryId != null && categoryId.isNotEmpty) {
      final cat = await (db.select(
        db.categoriesTable,
      )..where((tbl) => tbl.id.equals(categoryId))).getSingleOrNull();
      categoryName = cat?.name;
    }

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final dateStr = BudgetCycleCalculator.formatDate(date);

    final companion = TransactionsTableCompanion.insert(
      id: id,
      type: type.toDbString(),
      amountMinor: amount.inMinorUnits,
      categoryId: Value(categoryId),
      categoryName: Value(categoryName),
      transactionDate: dateStr,
      note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.transactionsTable).insert(companion);
    final tx = await getTransactionById(id);
    return tx!;
  }

  /// Updates an existing transaction.
  ///
  /// Passing `null` for [categoryId] clears it (only allowed for income).
  /// Passing `null` for [note] clears it.
  Future<TransactionModel> updateTransaction({
    required String id,
    TransactionType? type,
    Money? amount,
    Object? categoryId = _unsetField,
    DateTime? date,
    Object? note = _unsetField,
  }) async {
    final existing = await getTransactionById(id);
    if (existing == null) {
      throw StateError('Transaction with id "$id" not found');
    }

    final targetType = type ?? existing.type;
    final targetAmount = amount ?? existing.amount;
    final String? targetCategoryId = identical(categoryId, _unsetField)
        ? existing.categoryId
        : (categoryId as String?);
    final targetDate = date ?? existing.date;
    final String? noteStr = identical(note, _unsetField)
        ? null
        : (note as String?);
    final String? targetNote = identical(note, _unsetField)
        ? existing.note
        : (noteStr?.trim().isEmpty == true ? null : noteStr?.trim());

    if (targetAmount.inMinorUnits <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero');
    }

    if (targetType == TransactionType.expense &&
        (targetCategoryId == null || targetCategoryId.isEmpty)) {
      throw ArgumentError('Category is required for expense transactions');
    }

    String? targetCategoryName = existing.categoryName;
    if (targetCategoryId != existing.categoryId) {
      if (targetCategoryId != null && targetCategoryId.isNotEmpty) {
        final cat = await (db.select(
          db.categoriesTable,
        )..where((tbl) => tbl.id.equals(targetCategoryId))).getSingleOrNull();
        targetCategoryName = cat?.name;
      } else {
        targetCategoryName = null;
      }
    }

    final now = DateTime.now().toIso8601String();
    final companion = TransactionsTableCompanion(
      type: Value(targetType.toDbString()),
      amountMinor: Value(targetAmount.inMinorUnits),
      categoryId: Value(targetCategoryId),
      categoryName: Value(targetCategoryName),
      transactionDate: Value(BudgetCycleCalculator.formatDate(targetDate)),
      note: Value(targetNote),
      updatedAt: Value(now),
    );

    await (db.update(
      db.transactionsTable,
    )..where((tbl) => tbl.id.equals(id))).write(companion);

    return (await getTransactionById(id))!;
  }

  /// Deletes a transaction.
  Future<void> deleteTransaction(String id) async {
    await (db.delete(
      db.transactionsTable,
    )..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<TransactionModel> restoreTransaction(TransactionModel tx) async {
    String? categoryId = tx.categoryId;
    String? categoryName = tx.categoryName;

    final catId = categoryId;
    if (catId != null && catId.isNotEmpty) {
      final cat = await (db.select(db.categoriesTable)
            ..where((tbl) => tbl.id.equals(catId)))
          .getSingleOrNull();
      if (cat == null) {
        // Category was deleted while transaction was pending undo
        categoryId = null;
        categoryName ??= 'Uncategorized';
      } else {
        categoryName = cat.name;
      }
    }

    final dateStr = BudgetCycleCalculator.formatDate(tx.date);
    final companion = TransactionsTableCompanion.insert(
      id: tx.id,
      type: tx.type.toDbString(),
      amountMinor: tx.amount.inMinorUnits,
      categoryId: Value(categoryId),
      categoryName: Value(categoryName),
      transactionDate: dateStr,
      note: Value(tx.note?.trim().isEmpty == true ? null : tx.note?.trim()),
      createdAt: tx.createdAt.toIso8601String(),
      updatedAt: tx.updatedAt.toIso8601String(),
    );

    await db.into(db.transactionsTable).insert(companion);
    final restored = await getTransactionById(tx.id);
    return restored ?? tx;
  }

  /// Retrieves a transaction by its [id] joined with category name.
  Future<TransactionModel?> getTransactionById(String id) async {
    final tx = db.transactionsTable;
    final cat = db.categoriesTable;

    final query = db.select(tx).join([
      leftOuterJoin(cat, cat.id.equalsExp(tx.categoryId)),
    ])..where(tx.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final txEntry = row.readTable(tx);
    final catEntry = row.readTableOrNull(cat);

    return _mapToDomain(txEntry, categoryName: catEntry?.name);
  }

  /// Retrieves transactions within a specific [cycle] with optional filters.
  /// Ordered by `transaction_date DESC, created_at DESC`.
  Future<List<TransactionModel>> getTransactionsForCycle(
    BudgetCycle cycle, {
    TransactionType? type,
    String? categoryId,
    String? searchNote,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final tx = db.transactionsTable;
    final cat = db.categoriesTable;

    final query = db.select(tx).join([
      leftOuterJoin(cat, cat.id.equalsExp(tx.categoryId)),
    ]);

    final effectiveStart = startDate != null
        ? BudgetCycleCalculator.formatDate(startDate)
        : cycle.startDateString;
    final effectiveEnd = endDate != null
        ? BudgetCycleCalculator.formatDate(endDate)
        : cycle.endDateString;

    query.where(
      tx.transactionDate.isBiggerOrEqualValue(effectiveStart) &
          tx.transactionDate.isSmallerOrEqualValue(effectiveEnd),
    );

    if (type != null) {
      query.where(tx.type.equals(type.toDbString()));
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(tx.categoryId.equals(categoryId));
    }

    if (searchNote != null && searchNote.trim().isNotEmpty) {
      final escaped = searchNote
          .trim()
          .toLowerCase()
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_')
          .replaceAll("'", "''");
      query.where(
        CustomExpression<bool>(
          "LOWER(transactions.note) LIKE '%$escaped%' ESCAPE '\\'",
        ),
      );
    }

    query.orderBy([
      OrderingTerm.desc(tx.transactionDate),
      OrderingTerm.desc(tx.createdAt),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      final txEntry = row.readTable(tx);
      final catEntry = row.readTableOrNull(cat);
      return _mapToDomain(txEntry, categoryName: catEntry?.name);
    }).toList();
  }

  /// Retrieves recent transactions up to [limit].
  Future<List<TransactionModel>> getRecentTransactions({int limit = 10}) async {
    final tx = db.transactionsTable;
    final cat = db.categoriesTable;

    final query =
        db.select(tx).join([
            leftOuterJoin(cat, cat.id.equalsExp(tx.categoryId)),
          ])
          ..orderBy([
            OrderingTerm.desc(tx.transactionDate),
            OrderingTerm.desc(tx.createdAt),
          ])
          ..limit(limit);

    final rows = await query.get();
    return rows.map((row) {
      final txEntry = row.readTable(tx);
      final catEntry = row.readTableOrNull(cat);
      return _mapToDomain(txEntry, categoryName: catEntry?.name);
    }).toList();
  }

  /// Retrieves all transactions ordered by transaction_date DESC, created_at DESC.
  Future<List<TransactionModel>> getAllTransactions() async {
    final tx = db.transactionsTable;
    final cat = db.categoriesTable;

    final query =
        db.select(tx).join([
          leftOuterJoin(cat, cat.id.equalsExp(tx.categoryId)),
        ])..orderBy([
          OrderingTerm.desc(tx.transactionDate),
          OrderingTerm.desc(tx.createdAt),
        ]);

    final rows = await query.get();
    return rows.map((row) {
      final txEntry = row.readTable(tx);
      final catEntry = row.readTableOrNull(cat);
      return _mapToDomain(txEntry, categoryName: catEntry?.name);
    }).toList();
  }
}
