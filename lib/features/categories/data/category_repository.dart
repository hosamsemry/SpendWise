import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:uuid/uuid.dart';

class DuplicateCategoryNameException implements Exception {
  final String message;
  const DuplicateCategoryNameException(this.message);

  @override
  String toString() => message;
}

class CategoryInUseException implements Exception {
  final String message;
  const CategoryInUseException(this.message);

  @override
  String toString() => message;
}

class CategoryRepository {
  final AppDatabase db;
  final Uuid _uuid;

  CategoryRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Category _mapEntryToDomain(CategoryEntry entry) {
    return Category(
      id: entry.id,
      name: entry.name,
      type: entry.type == 'income' ? CategoryType.income : CategoryType.expense,
      color: entry.color,
      icon: entry.icon,
      defaultBudget: Money.fromMinorUnits(entry.defaultBudgetMinor),
      isActive: entry.isActive,
      createdAt: DateTime.parse(entry.createdAt),
      updatedAt: DateTime.parse(entry.updatedAt),
    );
  }

  /// Retrieves all categories. If [includeInactive] is false, returns only active categories.
  /// If [type] is provided, filters categories by that type.
  Future<List<Category>> getAllCategories({
    bool includeInactive = false,
    CategoryType? type,
  }) async {
    final query = db.select(db.categoriesTable);
    if (!includeInactive) {
      query.where((tbl) => tbl.isActive.equals(true));
    }
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type.name));
    }
    query.orderBy([
      (tbl) => OrderingTerm(expression: tbl.name.collate(Collate.noCase)),
    ]);

    final entries = await query.get();
    return entries.map(_mapEntryToDomain).toList();
  }

  /// Retrieves a category by [id].
  Future<Category?> getCategoryById(String id) async {
    final query = db.select(db.categoriesTable)
      ..where((tbl) => tbl.id.equals(id));
    final entry = await query.getSingleOrNull();
    return entry != null ? _mapEntryToDomain(entry) : null;
  }

  /// Checks if a trimmed category name is unique case-insensitively within its [type].
  Future<bool> isNameUnique(
    String name, {
    String? excludeId,
    CategoryType type = CategoryType.expense,
  }) async {
    final trimmed = name.trim().toLowerCase();
    final query = db.select(db.categoriesTable)
      ..where(
        (tbl) => tbl.name.lower().equals(trimmed) & tbl.type.equals(type.name),
      );
    if (excludeId != null) {
      query.where((tbl) => tbl.id.equals(excludeId).not());
    }
    final existing = await query.getSingleOrNull();
    return existing == null;
  }

  /// Creates a new category.
  Future<Category> createCategory({
    required String name,
    CategoryType type = CategoryType.expense,
    Money defaultBudget = const Money.zero(),
    String? color,
    String? icon,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }

    if (defaultBudget.isNegative) {
      throw ArgumentError('Default budget cannot be negative');
    }

    if (!await isNameUnique(trimmedName, type: type)) {
      throw DuplicateCategoryNameException(
        'A category with the name "$trimmedName" already exists for ${type.name}.',
      );
    }

    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    final companion = CategoriesTableCompanion.insert(
      id: id,
      name: trimmedName,
      type: Value(type.name),
      color: Value(color),
      icon: Value(icon),
      defaultBudgetMinor: Value(defaultBudget.inMinorUnits),
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    );

    await db.into(db.categoriesTable).insert(companion);
    final created = await getCategoryById(id);
    if (type == CategoryType.expense) {
      await _syncToCurrentCycleIfPresent(
        id,
        defaultBudget.inMinorUnits,
        rebalanceSavings: !_isSavingsCategoryName(trimmedName),
      );
    }
    return created!;
  }

  bool _isSavingsCategoryName(String name) {
    final lower = name.trim().toLowerCase();
    return lower == 'savings' || lower == 'مدخرات';
  }

  Future<BudgetCycleEntry?> _getCurrentCycleEntry() async {
    final today = BudgetCycleCalculator.formatDate(DateTime.now());
    return (db.select(db.budgetCyclesTable)
          ..where(
            (tbl) =>
                tbl.startDate.isSmallerOrEqualValue(today) &
                tbl.endDate.isBiggerOrEqualValue(today),
          )
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> _rebalanceSavingsForCycleIfPresent(
    BudgetCycleEntry cycle,
  ) async {
    final allExpenseCategories =
        await (db.select(db.categoriesTable)..where(
              (tbl) => tbl.type.equals('expense') & tbl.isActive.equals(true),
            ))
            .get();

    final savingsCat = allExpenseCategories
        .where((c) => _isSavingsCategoryName(c.name))
        .firstOrNull;
    if (savingsCat == null) return;

    final incomeTxs =
        await (db.select(db.transactionsTable)..where(
              (tbl) =>
                  tbl.type.equals('income') &
                  tbl.transactionDate.isBiggerOrEqualValue(cycle.startDate) &
                  tbl.transactionDate.isSmallerOrEqualValue(cycle.endDate),
            ))
            .get();

    var totalIncomeMinor = 0;
    for (final tx in incomeTxs) {
      totalIncomeMinor += tx.amountMinor;
    }

    final cycleBudgets =
        await (db.select(db.categoryBudgetsTable)
              ..where((tbl) => tbl.cycleId.equals(cycle.id)))
            .get();

    var otherBudgetsMinor = 0;
    CategoryBudgetEntry? existingSavingsBudget;
    for (final entry in cycleBudgets) {
      if (entry.categoryId == savingsCat.id) {
        existingSavingsBudget = entry;
      } else {
        otherBudgetsMinor += entry.budgetAmountMinor;
      }
    }

    final unallocatedMinor = totalIncomeMinor - otherBudgetsMinor;
    final targetSavingsMinor = unallocatedMinor > 0 ? unallocatedMinor : 0;
    final now = DateTime.now().toIso8601String();

    if (existingSavingsBudget != null) {
      if (existingSavingsBudget.budgetAmountMinor != targetSavingsMinor) {
        await (db.update(db.categoryBudgetsTable)
              ..where((tbl) => tbl.id.equals(existingSavingsBudget!.id)))
            .write(
              CategoryBudgetsTableCompanion(
                budgetAmountMinor: Value(targetSavingsMinor),
                updatedAt: Value(now),
              ),
            );
      }
    } else {
      await db
          .into(db.categoryBudgetsTable)
          .insert(
            CategoryBudgetsTableCompanion.insert(
              id: _uuid.v4(),
              cycleId: cycle.id,
              categoryId: savingsCat.id,
              budgetAmountMinor: targetSavingsMinor,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  Future<void> _syncToCurrentCycleIfPresent(
    String categoryId,
    int defaultBudgetMinor, {
    bool rebalanceSavings = true,
  }) async {
    final currentCycle = await _getCurrentCycleEntry();

    if (currentCycle != null) {
      final existingBudget =
          await (db.select(db.categoryBudgetsTable)..where(
                (tbl) =>
                    tbl.cycleId.equals(currentCycle.id) &
                    tbl.categoryId.equals(categoryId),
              ))
              .getSingleOrNull();

      if (existingBudget == null) {
        final now = DateTime.now().toIso8601String();
        await db
            .into(db.categoryBudgetsTable)
            .insert(
              CategoryBudgetsTableCompanion.insert(
                id: _uuid.v4(),
                cycleId: currentCycle.id,
                categoryId: categoryId,
                budgetAmountMinor: defaultBudgetMinor,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      if (rebalanceSavings) {
        await _rebalanceSavingsForCycleIfPresent(currentCycle);
      }
    }
  }

  /// Updates an existing category.
  Future<Category> updateCategory({
    required String id,
    String? name,
    Money? defaultBudget,
    String? color,
    String? icon,
    bool? isActive,
  }) async {
    final existing = await getCategoryById(id);
    if (existing == null) {
      throw StateError('Category with id "$id" does not exist');
    }

    String finalName = existing.name;
    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('Category name cannot be empty');
      }
      if (!await isNameUnique(trimmed, excludeId: id, type: existing.type)) {
        throw DuplicateCategoryNameException(
          'A category with the name "$trimmed" already exists for ${existing.type.name}.',
        );
      }
      finalName = trimmed;
    }

    if (defaultBudget != null && defaultBudget.isNegative) {
      throw ArgumentError('Default budget cannot be negative');
    }

    final now = DateTime.now().toIso8601String();
    final companion = CategoriesTableCompanion(
      name: Value(finalName),
      color: color != null ? Value(color) : Value(existing.color),
      icon: icon != null ? Value(icon) : Value(existing.icon),
      defaultBudgetMinor: defaultBudget != null
          ? Value(defaultBudget.inMinorUnits)
          : Value(existing.defaultBudget.inMinorUnits),
      isActive: isActive != null ? Value(isActive) : Value(existing.isActive),
      updatedAt: Value(now),
    );

    await db.transaction(() async {
      await (db.update(
        db.categoriesTable,
      )..where((tbl) => tbl.id.equals(id))).write(companion);

      if (finalName != existing.name) {
        await (db.update(db.transactionsTable)
              ..where((tbl) => tbl.categoryId.equals(id)))
            .write(TransactionsTableCompanion(categoryName: Value(finalName)));
        await (db.update(db.transactionPresetsTable)
              ..where((tbl) => tbl.categoryId.equals(id)))
            .write(TransactionPresetsTableCompanion(categoryName: Value(finalName)));
      }
    });

    return (await getCategoryById(id))!;
  }

  /// Sets isActive to false.
  Future<void> archiveCategory(String id) async {
    await updateCategory(id: id, isActive: false);
  }

  /// Sets isActive to true.
  Future<void> unarchiveCategory(String id) async {
    final cat = await updateCategory(id: id, isActive: true);
    if (cat.type == CategoryType.expense) {
      await _syncToCurrentCycleIfPresent(
        id,
        cat.defaultBudget.inMinorUnits,
        rebalanceSavings: !_isSavingsCategoryName(cat.name),
      );
    }
  }

  /// Restores all inactive/archived categories to active status.
  Future<void> unarchiveAllCategories() async {
    await (db.update(db.categoriesTable)
          ..where((tbl) => tbl.isActive.equals(false)))
        .write(const CategoriesTableCompanion(isActive: Value(true)));
  }

  /// Checks if a category can be deleted. Always returns true as categories can be safely
  /// deleted while preserving historical transaction records.
  Future<bool> canDeleteCategory(String id) async {
    return true;
  }

  /// Deletes a category. Any transactions referencing this category preserve their
  /// category name, and have their categoryId dissociated to maintain integrity.
  /// Any category budgets for this category are also removed.
  Future<void> deleteCategory(String id) async {
    final existing = await getCategoryById(id);
    if (existing == null) return;

    await db.transaction(() async {
      // 1. Snapshot category name to associated transactions and dissociate categoryId
      await (db.update(
        db.transactionsTable,
      )..where((tbl) => tbl.categoryId.equals(id))).write(
        TransactionsTableCompanion(
          categoryId: const Value(null),
          categoryName: Value(existing.name),
        ),
      );

      // 2. Snapshot category name to associated transaction presets and dissociate categoryId
      await (db.update(
        db.transactionPresetsTable,
      )..where((tbl) => tbl.categoryId.equals(id))).write(
        TransactionPresetsTableCompanion(
          categoryId: const Value(null),
          categoryName: Value(existing.name),
        ),
      );

      // 3. Delete associated notification events and category budgets
      await (db.delete(
        db.notificationEventsTable,
      )..where((tbl) => tbl.categoryId.equals(id))).go();

      await (db.delete(
        db.categoryBudgetsTable,
      )..where((tbl) => tbl.categoryId.equals(id))).go();

      // 4. Delete category itself
      await (db.delete(
        db.categoriesTable,
      )..where((tbl) => tbl.id.equals(id))).go();
    });

    if (existing.type == CategoryType.expense &&
        !_isSavingsCategoryName(existing.name)) {
      final currentCycle = await _getCurrentCycleEntry();
      if (currentCycle != null) {
        await _rebalanceSavingsForCycleIfPresent(currentCycle);
      }
    }
  }

  /// Seeds default categories if no categories exist yet.
  Future<void> seedDefaultCategories({String? languageCode}) async {
    final count = await db.categoriesTable.count().getSingle();
    if (count == 0) {
      final isAr = languageCode == 'ar';
      await createCategory(
        name: isAr ? 'طعام' : 'Food',
        type: CategoryType.expense,
        color: '#F59E0B',
      );
      await createCategory(
        name: isAr ? 'مواصلات' : 'Transportation',
        type: CategoryType.expense,
        color: '#3B82F6',
      );
      await createCategory(
        name: isAr ? 'حياة اجتماعية' : 'Social Life',
        type: CategoryType.expense,
        color: '#EC4899',
      );
      await createCategory(
        name: isAr ? 'اشتراكات ذكاء اصطناعي' : 'AI Subscription',
        type: CategoryType.expense,
        color: '#8B5CF6',
      );
      await createCategory(
        name: isAr ? 'مدخرات' : 'Savings',
        type: CategoryType.expense,
        color: '#10B981',
      );
      await createCategory(
        name: isAr ? 'راتب' : 'Salary',
        type: CategoryType.income,
        color: '#10B981',
      );
    }
  }
}
