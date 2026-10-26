import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:uuid/uuid.dart';

class BudgetCycleRepository {
  final AppDatabase db;
  final BudgetCycleCalculator calculator;
  final Uuid _uuid;

  BudgetCycleRepository(
    this.db, {
    this.calculator = const BudgetCycleCalculator(),
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  Future<void> _sanitizeStoredCyclesIfNeeded(List<BudgetCycleEntry> entries) async {
    for (final entry in entries) {
      try {
        final start = BudgetCycleCalculator.parseDate(entry.startDate);
        final end = BudgetCycleCalculator.parseDate(entry.endDate);
        final normStart = BudgetCycleCalculator.formatDate(start);
        final normEnd = BudgetCycleCalculator.formatDate(end);
        if (normStart != entry.startDate || normEnd != entry.endDate) {
          await (db.update(db.budgetCyclesTable)..where((tbl) => tbl.id.equals(entry.id)))
              .write(BudgetCyclesTableCompanion(
            startDate: Value(normStart),
            endDate: Value(normEnd),
          ));
        }
      } catch (_) {}
    }
  }

  /// Looks up the [BudgetCycle] containing [date] if it already exists in the database.
  /// Returns `null` if the cycle has not been created yet.
  Future<BudgetCycle?> getCycleForDateOrNull(DateTime date) async {
    final target = DateTime(date.year, date.month, date.day);

    // 1. Fetch all existing recorded cycles and sanitize any Eastern Arabic numerals if needed
    final allExisting = await (db.select(db.budgetCyclesTable)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startDate)]))
        .get();
    await _sanitizeStoredCyclesIfNeeded(allExisting);

    // 2. Check for cycle containing target date using true calendar date comparison
    for (final existing in allExisting) {
      final start = BudgetCycleCalculator.parseDate(existing.startDate);
      final end = BudgetCycleCalculator.parseDate(existing.endDate);
      if ((target.isAtSameMomentAs(start) || target.isAfter(start)) &&
          (target.isAtSameMomentAs(end) || target.isBefore(end))) {
        return BudgetCycle(
          id: existing.id,
          startDate: start,
          endDate: end,
        );
      }
    }

    // 3. Fallback: check if calculator-computed cycle startDate matches
    final computedCycle = calculator.getCycleForDate(date);
    final startDateStr = computedCycle.startDateString;

    for (final existing in allExisting) {
      final start = BudgetCycleCalculator.parseDate(existing.startDate);
      if (BudgetCycleCalculator.formatDate(start) == startDateStr) {
        return BudgetCycle(
          id: existing.id,
          startDate: start,
          endDate: BudgetCycleCalculator.parseDate(existing.endDate),
        );
      }
    }

    return null;
  }

  /// Gets the [BudgetCycle] containing [date], creating it and snapshotting
  /// active category default allocations if it does not yet exist.
  ///
  /// This operation is idempotent and safe to run on every app launch or resume.
  Future<BudgetCycle> getOrCreateCycleForDate(DateTime date) async {
    final existingCycle = await getCycleForDateOrNull(date);
    if (existingCycle != null) {
      return existingCycle;
    }

    final computedCycle = calculator.getCycleForDate(date);
    final startDateStr = computedCycle.startDateString;

    // Cycle does not exist: create it in a transaction
    return db.transaction(() async {
      // Double check inside transaction for race-condition idempotency
      final check = await (db.select(db.budgetCyclesTable)
            ..where((tbl) =>
                tbl.startDate.isSmallerOrEqualValue(startDateStr) &
                tbl.endDate.isBiggerOrEqualValue(startDateStr))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.startDate)])
            ..limit(1))
          .get();
      if (check.isNotEmpty) {
        return BudgetCycle(
          id: check.first.id,
          startDate: BudgetCycleCalculator.parseDate(check.first.startDate),
          endDate: BudgetCycleCalculator.parseDate(check.first.endDate),
        );
      }

      final now = DateTime.now().toIso8601String();
      final cycleId = _uuid.v4();

      await db
          .into(db.budgetCyclesTable)
          .insert(
            BudgetCyclesTableCompanion.insert(
              id: cycleId,
              startDate: startDateStr,
              endDate: computedCycle.endDateString,
              createdAt: now,
            ),
          );

      // Snapshot active expense categories' default allocations
      final activeCategories =
          await (db.select(db.categoriesTable)..where(
                (tbl) => tbl.isActive.equals(true) & tbl.type.equals('expense'),
              ))
              .get();

      for (final cat in activeCategories) {
        await db
            .into(db.categoryBudgetsTable)
            .insert(
              CategoryBudgetsTableCompanion.insert(
                id: _uuid.v4(),
                cycleId: cycleId,
                categoryId: cat.id,
                budgetAmountMinor: cat.defaultBudgetMinor,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      return BudgetCycle(
        id: cycleId,
        startDate: computedCycle.startDate,
        endDate: computedCycle.endDate,
      );
    });
  }

  /// Realigns cycles when the user updates their cycle start day in settings.
  ///
  /// Prevents date overlaps between the historical cycle and the newly initiated cycle:
  /// 1. Computes the new current cycle for today with [newStartDay].
  /// 2. If an existing recorded cycle overlaps with the new cycle's start date
  ///    (i.e. `startDate < newStartDate && endDate >= newStartDate`), its `endDate`
  ///    is cleanly truncated to the day immediately preceding `newStartDate`.
  /// 3. Ensures the new current cycle exists and snapshots active category allocations.
  Future<BudgetCycle> realignCyclesOnStartDayChange(int newStartDay) async {
    final newCalculator = BudgetCycleCalculator(startDay: newStartDay);
    final now = DateTime.now();
    final newCycle = newCalculator.getCycleForDate(now);
    final newStartStr = newCycle.startDateString;
    final newEndStr = newCycle.endDateString;

    return db.transaction(() async {
      // 1. Find any existing cycle that overlaps with newStartStr
      final allExisting = await (db.select(db.budgetCyclesTable)
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.startDate)]))
          .get();

      for (final cycle in allExisting) {
        final cycleStart = BudgetCycleCalculator.parseDate(cycle.startDate);
        final cycleEnd = BudgetCycleCalculator.parseDate(cycle.endDate);
        final newStart = BudgetCycleCalculator.parseDate(newStartStr);

        if (cycleStart.isBefore(newStart) && !cycleEnd.isBefore(newStart)) {
          final truncatedEnd = DateTime(newStart.year, newStart.month, newStart.day - 1);
          final truncatedEndStr = BudgetCycleCalculator.formatDate(truncatedEnd);

          await (db.update(db.budgetCyclesTable)..where((tbl) => tbl.id.equals(cycle.id)))
              .write(BudgetCyclesTableCompanion(
            endDate: Value(truncatedEndStr),
          ));
        }
      }

      // 2. Check if a cycle with newStartStr already exists
      final existingNew = await (db.select(db.budgetCyclesTable)
            ..where((tbl) => tbl.startDate.equals(newStartStr)))
          .getSingleOrNull();

      if (existingNew != null) {
        if (existingNew.endDate != newEndStr) {
          await (db.update(db.budgetCyclesTable)..where((tbl) => tbl.id.equals(existingNew.id)))
              .write(BudgetCyclesTableCompanion(
            endDate: Value(newEndStr),
          ));
        }
        return BudgetCycle(
          id: existingNew.id,
          startDate: BudgetCycleCalculator.parseDate(existingNew.startDate),
          endDate: BudgetCycleCalculator.parseDate(newEndStr),
        );
      }

      // 3. Otherwise create the new cycle
      final cycleId = _uuid.v4();
      final nowIso = DateTime.now().toIso8601String();

      await db.into(db.budgetCyclesTable).insert(
            BudgetCyclesTableCompanion.insert(
              id: cycleId,
              startDate: newStartStr,
              endDate: newEndStr,
              createdAt: nowIso,
            ),
          );

      final activeCategories = await (db.select(db.categoriesTable)
            ..where((tbl) => tbl.isActive.equals(true) & tbl.type.equals('expense')))
          .get();

      for (final cat in activeCategories) {
        await db.into(db.categoryBudgetsTable).insert(
              CategoryBudgetsTableCompanion.insert(
                id: _uuid.v4(),
                cycleId: cycleId,
                categoryId: cat.id,
                budgetAmountMinor: cat.defaultBudgetMinor,
                createdAt: nowIso,
                updatedAt: nowIso,
              ),
            );
      }

      return BudgetCycle(
        id: cycleId,
        startDate: newCycle.startDate,
        endDate: newCycle.endDate,
      );
    });
  }

  /// Retrieves all recorded budget cycles, sorted newest first.
  Future<List<BudgetCycle>> getAllCycles() async {
    final query = db.select(db.budgetCyclesTable)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.startDate)]);
    final entries = await query.get();
    await _sanitizeStoredCyclesIfNeeded(entries);

    return entries.map((entry) {
      return BudgetCycle(
        id: entry.id,
        startDate: BudgetCycleCalculator.parseDate(entry.startDate),
        endDate: BudgetCycleCalculator.parseDate(entry.endDate),
      );
    }).toList();
  }

  /// Retrieves the budgeted amounts for all categories in a cycle.
  /// Returns a map of `categoryId -> Money`.
  Future<Map<String, Money>> getCycleBudgets(String cycleId) async {
    final query = db.select(db.categoryBudgetsTable)
      ..where((tbl) => tbl.cycleId.equals(cycleId));
    final entries = await query.get();

    final Map<String, Money> result = {};
    for (final entry in entries) {
      result[entry.categoryId] = Money.fromMinorUnits(entry.budgetAmountMinor);
    }
    return result;
  }

  /// Updates or inserts a specific category's budget amount for a given cycle.
  ///
  /// If [updateDefaultAllocation] is true, also updates the category's
  /// `default_budget_minor` for future cycles.
  Future<void> updateCategoryBudget({
    required String cycleId,
    required String categoryId,
    required Money budgetAmount,
    bool updateDefaultAllocation = false,
  }) async {
    if (budgetAmount.isNegative) {
      throw ArgumentError('Budget amount cannot be negative');
    }

    final now = DateTime.now().toIso8601String();

    await db.transaction(() async {
      // 1. Check if category_budget record exists
      final existing =
          await (db.select(db.categoryBudgetsTable)..where(
                (tbl) =>
                    tbl.cycleId.equals(cycleId) &
                    tbl.categoryId.equals(categoryId),
              ))
              .getSingleOrNull();

      if (existing != null) {
        await (db.update(
          db.categoryBudgetsTable,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          CategoryBudgetsTableCompanion(
            budgetAmountMinor: Value(budgetAmount.inMinorUnits),
            updatedAt: Value(now),
          ),
        );
      } else {
        await db
            .into(db.categoryBudgetsTable)
            .insert(
              CategoryBudgetsTableCompanion.insert(
                id: _uuid.v4(),
                cycleId: cycleId,
                categoryId: categoryId,
                budgetAmountMinor: budgetAmount.inMinorUnits,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      // 2. If requested, update category default allocation for future cycles
      if (updateDefaultAllocation) {
        await (db.update(
          db.categoriesTable,
        )..where((tbl) => tbl.id.equals(categoryId))).write(
          CategoriesTableCompanion(
            defaultBudgetMinor: Value(budgetAmount.inMinorUnits),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Ensures any active category created after the cycle was started
  /// has a corresponding CategoryBudget record (defaulting to its default allocation).
  Future<void> syncCategoriesForCycle(String cycleId) async {
    final existingBudgets = await getCycleBudgets(cycleId);
    final activeCategories =
        await (db.select(db.categoriesTable)..where(
              (tbl) => tbl.isActive.equals(true) & tbl.type.equals('expense'),
            ))
            .get();

    final hasAnyNonSavingsBudget = activeCategories.any((cat) {
      final lower = cat.name.trim().toLowerCase();
      if (lower == 'savings' || lower == 'مدخرات') return false;
      return (existingBudgets[cat.id]?.inMinorUnits ?? 0) > 0;
    });

    final now = DateTime.now().toIso8601String();
    for (final cat in activeCategories) {
      if (!existingBudgets.containsKey(cat.id)) {
        await db
            .into(db.categoryBudgetsTable)
            .insert(
              CategoryBudgetsTableCompanion.insert(
                id: _uuid.v4(),
                cycleId: cycleId,
                categoryId: cat.id,
                budgetAmountMinor: cat.defaultBudgetMinor,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else if (!hasAnyNonSavingsBudget &&
          cat.defaultBudgetMinor > 0 &&
          existingBudgets[cat.id]!.inMinorUnits == 0) {
        final lower = cat.name.trim().toLowerCase();
        if (lower != 'savings' && lower != 'مدخرات') {
          await (db.update(db.categoryBudgetsTable)..where(
                (tbl) =>
                    tbl.cycleId.equals(cycleId) &
                    tbl.categoryId.equals(cat.id),
              ))
              .write(
                CategoryBudgetsTableCompanion(
                  budgetAmountMinor: Value(cat.defaultBudgetMinor),
                  updatedAt: Value(now),
                ),
              );
        }
      }
    }
  }
}
