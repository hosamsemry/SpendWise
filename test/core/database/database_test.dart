import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
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
}
