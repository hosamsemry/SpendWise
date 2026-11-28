import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/date/budget_cycle_timeline.dart';
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

    final target = DateTime(date.year, date.month, date.day);

    return db.transaction(() async {
      final recorded =
          (await db.select(db.budgetCyclesTable).get()).map(_toDomain).toList();

      // Re-check inside the transaction for race-condition idempotency.
      for (final cycle in recorded) {
        if (cycle.contains(target)) return cycle;
      }

      // Never overlap recorded cycles (e.g. one truncated by a start-day
      // change): the timeline shrinks the computed range to fit the gap.
      final cycle = BudgetCycleTimeline(calculator, recorded).cycleContaining(target);
      return _insertCycle(cycle.startDate, cycle.endDate);
    });
  }

  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  static BudgetCycle _toDomain(BudgetCycleEntry row) {
    final start = BudgetCycleCalculator.parseDate(row.startDate);
    final end = BudgetCycleCalculator.parseDate(row.endDate);
    return BudgetCycle(
      id: row.id,
      startDate: start,
      endDate: end,
    );
  }

  /// Inserts a cycle row and its budget snapshot: [budgetsMinor]
  /// (categoryId -> amount) when given, otherwise each active expense
  /// category's default allocation. Must run inside a transaction.
  Future<BudgetCycle> _insertCycle(
    DateTime start,
    DateTime end, {
    Map<String, int>? budgetsMinor,
  }) async {
    final now = DateTime.now().toIso8601String();
    final cycleId = _uuid.v4();
    await db.into(db.budgetCyclesTable).insert(
          BudgetCyclesTableCompanion.insert(
            id: cycleId,
            startDate: BudgetCycleCalculator.formatDate(start),
            endDate: BudgetCycleCalculator.formatDate(end),
            createdAt: now,
          ),
        );

    final Map<String, int> snapshot;
    if (budgetsMinor != null) {
      snapshot = budgetsMinor;
    } else {
      final activeCategories = await (db.select(db.categoriesTable)
            ..where(
              (tbl) => tbl.isActive.equals(true) & tbl.type.equals('expense'),
            ))
          .get();
      snapshot = {for (final c in activeCategories) c.id: c.defaultBudgetMinor};
    }

    for (final entry in snapshot.entries) {
      await db.into(db.categoryBudgetsTable).insert(
            CategoryBudgetsTableCompanion.insert(
              id: _uuid.v4(),
              cycleId: cycleId,
              categoryId: entry.key,
              budgetAmountMinor: entry.value,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    return BudgetCycle(id: cycleId, startDate: start, endDate: end);
  }

  /// Realigns recorded cycles when the user changes their cycle start day,
  /// so cycles never overlap and today's cycle follows the new schedule.
  ///
  /// With the new current cycle N = [S, E] (for [today], default now):
  /// 1. Cycles entirely before S are kept untouched (frozen history).
  /// 2. A cycle that started before S and runs into it is truncated to S-1,
  ///    and its budgets shrink in proportion to the days it keeps (a full
  ///    month's budget over a few days would make its surplus look huge).
  /// 3. A cycle starting inside N (typically the old current cycle) is moved
  ///    onto N, keeping its id, budgets and alert history; "every cycle"
  ///    bill payments recorded on its old start date move with it. If none
  ///    exists, N is created with the budgets of the cycle that was current
  ///    before the change (falling back to category defaults).
  /// 4. Any other cycle starting on/after S (future cycles laid out with the
  ///    old start day) is deleted with its budgets and alert events; it is
  ///    recreated on the new schedule when needed. Transactions are keyed by
  ///    date, so none are lost.
  Future<BudgetCycle> realignCyclesOnStartDayChange(
    int newStartDay, {
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final newCycle = BudgetCycleCalculator(startDay: newStartDay).getCycleForDate(now);
    final s = newCycle.startDate;
    final e = newCycle.endDate;

    return db.transaction(() async {
      final cycles = (await db.select(db.budgetCyclesTable).get())
          .map(_toDomain)
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      final previousCurrent =
          cycles.where((c) => c.contains(todayDate)).firstOrNull;
      final carriedBudgets = previousCurrent == null
          ? null
          : (await getCycleBudgets(previousCurrent.id))
              .map((k, v) => MapEntry(k, v.inMinorUnits));

      BudgetCycle? reused;
      for (final cycle in cycles) {
        if (cycle.startDate.isBefore(s)) {
          if (!cycle.endDate.isBefore(s)) {
            final newEnd = _addDays(s, -1);
            await _setRange(cycle.id, cycle.startDate, newEnd);
            await _prorateBudgets(
              cycle.id,
              keptDays: BudgetCycleCalculator.calendarDaysBetween(cycle.startDate, newEnd) + 1,
              originalDays:
                  BudgetCycleCalculator.calendarDaysBetween(cycle.startDate, cycle.endDate) + 1,
            );
          }
        } else if (reused == null && !cycle.startDate.isAfter(e)) {
          await _setRange(cycle.id, s, e);
          if (!cycle.startDate.isAtSameMomentAs(s)) {
            await _moveEveryCycleBillDates(from: cycle.startDate, to: s);
          }
          reused = BudgetCycle(id: cycle.id, startDate: s, endDate: e);
        } else {
          await _deleteCycle(cycle.id);
        }
      }

      return reused ?? await _insertCycle(s, e, budgetsMinor: carriedBudgets);
    });
  }

  /// Scales every budget of [cycleId] by [keptDays] / [originalDays], rounded
  /// half up to whole minor units.
  Future<void> _prorateBudgets(
    String cycleId, {
    required int keptDays,
    required int originalDays,
  }) async {
    if (keptDays >= originalDays || originalDays <= 0) return;
    final rows = await (db.select(db.categoryBudgetsTable)
          ..where((tbl) => tbl.cycleId.equals(cycleId)))
        .get();
    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      final scaled =
          (row.budgetAmountMinor * keptDays * 2 + originalDays) ~/ (2 * originalDays);
      await (db.update(db.categoryBudgetsTable)..where((tbl) => tbl.id.equals(row.id)))
          .write(CategoryBudgetsTableCompanion(
        budgetAmountMinor: Value(scaled),
        updatedAt: Value(now),
      ));
    }
  }

  /// "Every cycle" bills fall due on a cycle's start date, so when a cycle
  /// moves, its paid / skipped records move with it. A record already on the
  /// new date wins (OR IGNORE keeps the unique (bill, date) constraint).
  Future<void> _moveEveryCycleBillDates({
    required DateTime from,
    required DateTime to,
  }) async {
    await db.customStatement(
      'UPDATE OR IGNORE bill_occurrences SET due_date = ? '
      'WHERE due_date = ? AND bill_id IN '
      "(SELECT id FROM recurring_bills WHERE frequency = 'every_cycle')",
      [BudgetCycleCalculator.formatDate(to), BudgetCycleCalculator.formatDate(from)],
    );
  }

  /// The recorded cycle just before [cycle] (the one containing the day
  /// before it starts), or null if that day has no recorded cycle. Unlike
  /// the calculator's previous cycle, this is right after a start-day change.
  Future<BudgetCycle?> getPreviousRecordedCycle(BudgetCycle cycle) =>
      getCycleForDateOrNull(_addDays(cycle.startDate, -1));

  Future<void> _setRange(String cycleId, DateTime start, DateTime end) async {
    await (db.update(db.budgetCyclesTable)..where((tbl) => tbl.id.equals(cycleId)))
        .write(BudgetCyclesTableCompanion(
      startDate: Value(BudgetCycleCalculator.formatDate(start)),
      endDate: Value(BudgetCycleCalculator.formatDate(end)),
    ));
  }

  Future<void> _deleteCycle(String cycleId) async {
    await (db.delete(db.notificationEventsTable)
          ..where((tbl) => tbl.cycleId.equals(cycleId)))
        .go();
    await (db.delete(db.categoryBudgetsTable)
          ..where((tbl) => tbl.cycleId.equals(cycleId)))
        .go();
    await (db.delete(db.budgetCyclesTable)..where((tbl) => tbl.id.equals(cycleId)))
        .go();
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
  /// has a corresponding CategoryBudget record (defaulting to its default
  /// allocation). Existing budgets, including deliberate zeros, are never
  /// changed.
  Future<void> syncCategoriesForCycle(String cycleId) async {
    final existingBudgets = await getCycleBudgets(cycleId);
    final activeCategories =
        await (db.select(db.categoriesTable)..where(
              (tbl) => tbl.isActive.equals(true) & tbl.type.equals('expense'),
            ))
            .get();

    final now = DateTime.now().toIso8601String();
    for (final cat in activeCategories) {
      if (existingBudgets.containsKey(cat.id)) continue;
      await db.into(db.categoryBudgetsTable).insert(
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
  }
}
