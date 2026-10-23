import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/presets/domain/transaction_preset.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:uuid/uuid.dart';

class PresetRepository {
  final AppDatabase db;
  final Uuid _uuid;

  PresetRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  TransactionPreset _mapToDomain(
    TransactionPresetEntry entry, {
    String? categoryName,
  }) {
    return TransactionPreset(
      id: entry.id,
      title: entry.title,
      type: TransactionType.fromString(entry.type),
      categoryId: entry.categoryId,
      categoryName: categoryName ?? entry.categoryName,
      amount: Money.fromMinorUnits(entry.amountMinor),
      note: entry.note,
      displayOrder: entry.displayOrder,
      createdAt: DateTime.parse(entry.createdAt),
    );
  }

  /// Retrieves all transaction presets ordered by display order and creation date.
  Future<List<TransactionPreset>> getAllPresets() async {
    final presets = db.transactionPresetsTable;
    final categories = db.categoriesTable;

    final query =
        db.select(presets).join([
          leftOuterJoin(
            categories,
            categories.id.equalsExp(presets.categoryId),
          ),
        ])..orderBy([
          OrderingTerm.asc(presets.displayOrder),
          OrderingTerm.asc(presets.createdAt),
        ]);

    final rows = await query.get();
    return rows.map((row) {
      final p = row.readTable(presets);
      final c = row.readTableOrNull(categories);
      return _mapToDomain(p, categoryName: c?.name);
    }).toList();
  }

  /// Creates a new custom preset.
  Future<TransactionPreset> createPreset({
    required String title,
    required TransactionType type,
    String? categoryId,
    required Money amount,
    String? note,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Preset title cannot be empty');
    }
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Preset amount must be greater than zero');
    }

    String? catName;
    String? effectiveCategoryId = categoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      final cat = await (db.select(
        db.categoriesTable,
      )..where((tbl) => tbl.id.equals(categoryId))).getSingleOrNull();
      catName = cat?.name;
      if (cat == null) {
        effectiveCategoryId = null;
      }
    }

    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db
        .into(db.transactionPresetsTable)
        .insert(
          TransactionPresetsTableCompanion.insert(
            id: id,
            title: trimmedTitle,
            type: type.toDbString(),
            categoryId: Value(effectiveCategoryId),
            categoryName: Value(catName),
            amountMinor: amount.inMinorUnits,
            note: Value(note?.trim().isEmpty == true ? null : note?.trim()),
            createdAt: now,
          ),
        );

    final created = await (db.select(
      db.transactionPresetsTable,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
    return _mapToDomain(created, categoryName: catName);
  }

  /// Updates an existing preset.
  Future<void> updatePreset({
    required String id,
    String? title,
    TransactionType? type,
    String? categoryId,
    Money? amount,
    String? note,
  }) async {
    String? catName;
    String? effectiveCategoryId = categoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      final cat = await (db.select(
        db.categoriesTable,
      )..where((tbl) => tbl.id.equals(categoryId))).getSingleOrNull();
      catName = cat?.name;
      if (cat == null) {
        effectiveCategoryId = null;
      }
    }

    await (db.update(
      db.transactionPresetsTable,
    )..where((tbl) => tbl.id.equals(id))).write(
      TransactionPresetsTableCompanion(
        title: title != null ? Value(title.trim()) : const Value.absent(),
        type: type != null ? Value(type.toDbString()) : const Value.absent(),
        categoryId: categoryId != null
            ? Value(effectiveCategoryId)
            : const Value.absent(),
        categoryName: catName != null ? Value(catName) : const Value.absent(),
        amountMinor: amount != null
            ? Value(amount.inMinorUnits)
            : const Value.absent(),
        note: note != null
            ? Value(note.trim().isEmpty ? null : note.trim())
            : const Value.absent(),
      ),
    );
  }

  /// Deletes a preset.
  Future<void> deletePreset(String id) async {
    await (db.delete(
      db.transactionPresetsTable,
    )..where((tbl) => tbl.id.equals(id))).go();
  }
}
