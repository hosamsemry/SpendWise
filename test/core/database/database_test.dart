import 'package:drift/drift.dart' as drift;
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/database/pre_upgrade_snapshot.dart';
import 'package:uuid/uuid.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  const uuid = Uuid();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Schema & Integrity Tests', () {
    test('Can insert and retrieve categories', () async {
      final now = DateTime.now().toIso8601String();
      final catId = uuid.v4();

      await db
          .into(db.categoriesTable)
          .insert(
            CategoriesTableCompanion.insert(
              id: catId,
              name: 'Food & Dining',
              defaultBudgetMinor: const drift.Value(200000), // 2,000 EGP
              createdAt: now,
              updatedAt: now,
            ),
          );

      final categories = await db.select(db.categoriesTable).get();
      expect(categories.length, 1);
      expect(categories.first.id, catId);
      expect(categories.first.name, 'Food & Dining');
      expect(categories.first.defaultBudgetMinor, 200000);
      expect(categories.first.isActive, isTrue);
    });

    test('Category name enforces case-insensitive uniqueness', () async {
      final now = DateTime.now().toIso8601String();

      await db
          .into(db.categoriesTable)
          .insert(
            CategoriesTableCompanion.insert(
              id: uuid.v4(),
              name: 'Groceries',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Attempting to insert duplicate with different casing should fail
      expect(
        () => db
            .into(db.categoriesTable)
            .insert(
              CategoriesTableCompanion.insert(
                id: uuid.v4(),
                name: 'groceries',
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'Foreign key enforcement: Cannot insert CategoryBudget with invalid FKs',
      () async {
        final now = DateTime.now().toIso8601String();

        // Non-existent cycle and category
        expect(
          () => db
              .into(db.categoryBudgetsTable)
              .insert(
                CategoryBudgetsTableCompanion.insert(
                  id: uuid.v4(),
                  cycleId: 'non_existent_cycle',
                  categoryId: 'non_existent_cat',
                  budgetAmountMinor: 100000,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'Foreign key enforcement: Cannot delete Category referenced by Transactions',
      () async {
        final now = DateTime.now().toIso8601String();
        final catId = uuid.v4();

        await db
            .into(db.categoriesTable)
            .insert(
              CategoriesTableCompanion.insert(
                id: catId,
                name: 'Transportation',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.transactionsTable)
            .insert(
              TransactionsTableCompanion.insert(
                id: uuid.v4(),
                type: 'expense',
                amountMinor: 5000,
                categoryId: drift.Value(catId),
                transactionDate: '2026-10-26',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Attempting to delete the referenced category should throw SqliteException (FK violation)
        expect(
          () => (db.delete(
            db.categoriesTable,
          )..where((tbl) => tbl.id.equals(catId))).go(),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'Transactions support both Income and Expense with categories',
      () async {
        final now = DateTime.now().toIso8601String();
        final salaryCatId = uuid.v4();
        final coffeeCatId = uuid.v4();

        await db
            .into(db.categoriesTable)
            .insert(
              CategoriesTableCompanion.insert(
                id: salaryCatId,
                name: 'Salary',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.categoriesTable)
            .insert(
              CategoriesTableCompanion.insert(
                id: coffeeCatId,
                name: 'Coffee',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Income with category
        final incId = uuid.v4();
        await db
            .into(db.transactionsTable)
            .insert(
              TransactionsTableCompanion.insert(
                id: incId,
                type: 'income',
                amountMinor: 1500000, // 15,000 EGP
                categoryId: drift.Value(salaryCatId),
                transactionDate: '2026-10-25',
                note: const drift.Value('Monthly salary'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Income without category
        final uncategorizedIncId = uuid.v4();
        await db
            .into(db.transactionsTable)
            .insert(
              TransactionsTableCompanion.insert(
                id: uncategorizedIncId,
                type: 'income',
                amountMinor: 50000, // 500 EGP
                categoryId: const drift.Value(null),
                transactionDate: '2026-10-26',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Expense with category
        final expId = uuid.v4();
        await db
            .into(db.transactionsTable)
            .insert(
              TransactionsTableCompanion.insert(
                id: expId,
                type: 'expense',
                amountMinor: 6500, // 65 EGP
                categoryId: drift.Value(coffeeCatId),
                transactionDate: '2026-10-26',
                note: const drift.Value('Morning latte'),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final txs = await db.select(db.transactionsTable).get();
        expect(txs.length, 3);
      },
    );

    test(
      'Unique constraints on BudgetCycles, CategoryBudgets, and NotificationEvents',
      () async {
        final now = DateTime.now().toIso8601String();
        final cycleId = uuid.v4();
        final catId = uuid.v4();

        await db
            .into(db.categoriesTable)
            .insert(
              CategoriesTableCompanion.insert(
                id: catId,
                name: 'Gym',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.budgetCyclesTable)
            .insert(
              BudgetCyclesTableCompanion.insert(
                id: cycleId,
                startDate: '2026-10-25',
                endDate: '2026-11-24',
                createdAt: now,
              ),
            );

        // Duplicate cycle start date must fail
        expect(
          () => db
              .into(db.budgetCyclesTable)
              .insert(
                BudgetCyclesTableCompanion.insert(
                  id: uuid.v4(),
                  startDate: '2026-10-25',
                  endDate: '2026-11-24',
                  createdAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // CategoryBudget unique constraint on (cycle_id, category_id)
        await db
            .into(db.categoryBudgetsTable)
            .insert(
              CategoryBudgetsTableCompanion.insert(
                id: uuid.v4(),
                cycleId: cycleId,
                categoryId: catId,
                budgetAmountMinor: 100000,
                createdAt: now,
                updatedAt: now,
              ),
            );

        expect(
          () => db
              .into(db.categoryBudgetsTable)
              .insert(
                CategoryBudgetsTableCompanion.insert(
                  id: uuid.v4(),
                  cycleId: cycleId,
                  categoryId: catId,
                  budgetAmountMinor: 120000,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // NotificationEvents unique constraint on (cycle_id, category_id, event_type)
        await db
            .into(db.notificationEventsTable)
            .insert(
              NotificationEventsTableCompanion.insert(
                id: uuid.v4(),
                cycleId: cycleId,
                categoryId: catId,
                eventType: 'reached_80_percent',
                createdAt: now,
              ),
            );

        expect(
          () => db
              .into(db.notificationEventsTable)
              .insert(
                NotificationEventsTableCompanion.insert(
                  id: uuid.v4(),
                  cycleId: cycleId,
                  categoryId: catId,
                  eventType: 'reached_80_percent',
                  createdAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test(
      'Check constraints: Budget and Transaction amounts must be valid',
      () async {
        final now = DateTime.now().toIso8601String();
        final cycleId = uuid.v4();
        final catId = uuid.v4();

        await db
            .into(db.categoriesTable)
            .insert(
              CategoriesTableCompanion.insert(
                id: catId,
                name: 'Shopping',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.budgetCyclesTable)
            .insert(
              BudgetCyclesTableCompanion.insert(
                id: cycleId,
                startDate: '2026-10-25',
                endDate: '2026-11-24',
                createdAt: now,
              ),
            );

        // Negative budget amount must fail
        expect(
          () => db
              .into(db.categoryBudgetsTable)
              .insert(
                CategoryBudgetsTableCompanion.insert(
                  id: uuid.v4(),
                  cycleId: cycleId,
                  categoryId: catId,
                  budgetAmountMinor: -500,
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Non-positive transaction amount must fail
        expect(
          () => db
              .into(db.transactionsTable)
              .insert(
                TransactionsTableCompanion.insert(
                  id: uuid.v4(),
                  type: 'expense',
                  amountMinor: 0,
                  categoryId: drift.Value(catId),
                  transactionDate: '2026-10-26',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });

  test('upgrading a version 4 database adds the bill tables and keeps data', () async {
    final dir = await Directory.systemTemp.createTemp('paydial_migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/money_tracker.sqlite');

    // Build a v4 database: today's schema minus the v5 tables.
    final v4 = AppDatabase(NativeDatabase(file));
    await v4.into(v4.categoriesTable).insert(
          CategoriesTableCompanion.insert(
            id: 'cat-1',
            name: 'Housing',
            createdAt: '2026-01-01',
            updatedAt: '2026-01-01',
          ),
        );
    await v4.customStatement('DROP TABLE savings_movements');
    await v4.customStatement('DROP TABLE savings_goals');
    await v4.customStatement('DROP TABLE bill_occurrences');
    await v4.customStatement('DROP TABLE recurring_bills');
    await v4.customStatement('PRAGMA user_version = 4');
    await v4.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    expect((await upgraded.select(upgraded.categoriesTable).get()).single.name, 'Housing');
    await upgraded.into(upgraded.recurringBillsTable).insert(
          RecurringBillsTableCompanion.insert(
            id: 'bill-1',
            title: 'Rent',
            type: 'expense',
            categoryId: const drift.Value('cat-1'),
            amountMinor: 800000,
            frequency: 'monthly',
            anchorDate: '2026-01-01',
            createdAt: '2026-01-01',
            updatedAt: '2026-01-01',
          ),
        );
    await upgraded.into(upgraded.billOccurrencesTable).insert(
          BillOccurrencesTableCompanion.insert(
            id: 'occ-1',
            billId: 'bill-1',
            dueDate: '2026-01-01',
            status: 'skipped',
            createdAt: '2026-01-01',
          ),
        );
    expect(await upgraded.select(upgraded.billOccurrencesTable).get(), hasLength(1));
  });

  test('upgrading to version 6 moves the vault balance into the savings history', () async {
    final dir = await Directory.systemTemp.createTemp('paydial_migration_v6');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/money_tracker.sqlite');

    final v5 = AppDatabase(NativeDatabase(file));
    await v5.customStatement('DROP TABLE savings_movements');
    await v5.customStatement('DROP TABLE savings_goals');
    await v5.into(v5.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: legacyVaultBalanceKey, value: '185000'),
        );
    await v5.customStatement('PRAGMA user_version = 5');
    await v5.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final movements = await upgraded.select(upgraded.savingsMovementsTable).get();
    expect(movements.single.amountMinor, 185000);
    expect(movements.single.kind, 'opening');
    expect(movements.single.goalId, isNull);
    final legacy = await (upgraded.select(upgraded.appSettingsTable)
          ..where((t) => t.key.equals(legacyVaultBalanceKey)))
        .get();
    expect(legacy, isEmpty);
  });

  test('upgrading to version 7 records when paused bills were paused', () async {
    final dir = await Directory.systemTemp.createTemp('paydial_migration_v7');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/money_tracker.sqlite');

    // A real v6 file: recurring_bills without the v7 columns.
    final v6 = AppDatabase(NativeDatabase(file));
    await v6.customStatement('ALTER TABLE recurring_bills DROP COLUMN paused_at');
    await v6.customStatement('ALTER TABLE recurring_bills DROP COLUMN amount_set_at');
    await v6.customStatement(
      "INSERT INTO recurring_bills (id, title, type, amount_minor, is_variable, frequency, anchor_date, "
      "is_active, created_at, updated_at) VALUES "
      "('paused', 'Gym', 'income', 1000, 0, 'monthly', '2026-01-01', 0, '2026-01-01T10:00:00.000', '2026-03-05T18:30:00.000'), "
      "('active', 'Rent', 'income', 2000, 1, 'monthly', '2026-01-01', 1, '2026-01-01T10:00:00.000', '2026-02-01T09:00:00.000')",
    );
    await v6.customStatement('PRAGMA user_version = 6');
    await v6.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final rows = {for (final b in await upgraded.select(upgraded.recurringBillsTable).get()) b.id: b};
    expect(rows['paused']!.pausedAt, '2026-03-05', reason: 'last change is the best guess');
    expect(rows['active']!.pausedAt, isNull);
    expect(rows['active']!.amountSetAt, '2026-02-01T09:00:00.000');
  });

  test('a copy of the database is kept before a schema upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('paydial_pre_upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/money_tracker.sqlite');
    final snapshots = Directory('${dir.path}/safety_snapshots');

    final old = AppDatabase(NativeDatabase(file));
    await old.into(old.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'app_language', value: 'ar'),
        );
    await old.customStatement('PRAGMA user_version = 6');
    await old.close();

    final copy = snapshotBeforeUpgrade(database: file, into: snapshots, targetVersion: 7);
    expect(copy, isNotNull);
    expect(copy!.path, contains('pre_upgrade_v6_'));
    final saved = AppDatabase(NativeDatabase(copy));
    addTearDown(saved.close);
    final lang = await (saved.select(saved.appSettingsTable)..where((t) => t.key.equals('app_language'))).getSingle();
    expect(lang.value, 'ar');

    // Nothing to do when already on the latest version.
    expect(snapshotBeforeUpgrade(database: file, into: snapshots, targetVersion: 6), isNull);
    // Only the newest copies are kept.
    for (var i = 1; i <= 3; i++) {
      snapshotBeforeUpgrade(
        database: file,
        into: snapshots,
        targetVersion: 7,
        now: DateTime(2027, 1, i),
      );
    }
    final kept = snapshots.listSync().whereType<File>().map((f) => f.path.split('/').last).toList()..sort();
    expect(kept, hasLength(2));
    expect(kept.last, contains('${DateTime(2027, 1, 3).microsecondsSinceEpoch}'));
  });
}
