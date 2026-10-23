import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    transactionRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CategoryRepository Tests', () {
    test('Create and retrieve categories with default allocations', () async {
      final food = await categoryRepo.createCategory(
        name: 'Food',
        defaultBudget: Money.fromMajorUnits(2000),
      );

      expect(food.name, 'Food');
      expect(food.defaultBudget, Money.fromMajorUnits(2000));
      expect(food.isActive, isTrue);

      final list = await categoryRepo.getAllCategories();
      expect(list.length, 1);
      expect(list.first.id, food.id);
    });

    test(
      'Rejects duplicate names case-insensitively and whitespace-trimmed',
      () async {
        await categoryRepo.createCategory(name: 'Transportation');

        expect(
          () => categoryRepo.createCategory(name: '  transportation  '),
          throwsA(isA<DuplicateCategoryNameException>()),
        );

        expect(
          () => categoryRepo.createCategory(name: 'TRANSPORTATION'),
          throwsA(isA<DuplicateCategoryNameException>()),
        );
      },
    );

    test('Updating category attributes and renaming', () async {
      final cat = await categoryRepo.createCategory(name: 'Gym');
      final updated = await categoryRepo.updateCategory(
        id: cat.id,
        name: 'Fitness & Gym',
        defaultBudget: Money.fromMajorUnits(1500),
      );

      expect(updated.name, 'Fitness & Gym');
      expect(updated.defaultBudget, Money.fromMajorUnits(1500));
    });

    test('Archiving and unarchiving categories', () async {
      final cat = await categoryRepo.createCategory(name: 'Subscriptions');

      await categoryRepo.archiveCategory(cat.id);
      final activeOnly = await categoryRepo.getAllCategories(
        includeInactive: false,
      );
      expect(activeOnly.any((c) => c.id == cat.id), isFalse);

      final all = await categoryRepo.getAllCategories(includeInactive: true);
      expect(all.any((c) => c.id == cat.id), isTrue);

      await categoryRepo.unarchiveCategory(cat.id);
      final activeAgain = await categoryRepo.getAllCategories(
        includeInactive: false,
      );
      expect(activeAgain.any((c) => c.id == cat.id), isTrue);
    });

    test(
      'Deleting category with transactions preserves transactions and keeps category name',
      () async {
        final cat = await categoryRepo.createCategory(name: 'Dining');

        final tx = await transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(50),
          categoryId: cat.id,
          date: DateTime(2026, 10, 26),
        );

        expect(await categoryRepo.canDeleteCategory(cat.id), isTrue);

        // Deleting the category must succeed without error
        await categoryRepo.deleteCategory(cat.id);

        // Category itself is removed
        expect(await categoryRepo.getCategoryById(cat.id), isNull);

        // Transaction is preserved and retains categoryName 'Dining'
        final preservedTxs = await transactionRepo.getAllTransactions();
        expect(preservedTxs.length, 1);
        expect(preservedTxs.first.id, tx.id);
        expect(preservedTxs.first.categoryId, isNull);
        expect(preservedTxs.first.categoryName, 'Dining');
      },
    );

    test('Renaming category cascades updated name to transactions', () async {
      final cat = await categoryRepo.createCategory(name: 'Groceries');

      final tx = await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(120),
        categoryId: cat.id,
        date: DateTime(2026, 10, 26),
      );
      expect(tx.categoryName, 'Groceries');

      // Rename category
      await categoryRepo.updateCategory(id: cat.id, name: 'Supermarket');

      final updatedTxs = await transactionRepo.getAllTransactions();
      expect(updatedTxs.first.id, tx.id);
      expect(updatedTxs.first.categoryName, 'Supermarket');
    });

    test('Can delete category when not in use', () async {
      final cat = await categoryRepo.createCategory(name: 'Unused');
      expect(await categoryRepo.canDeleteCategory(cat.id), isTrue);

      await categoryRepo.deleteCategory(cat.id);
      expect(await categoryRepo.getCategoryById(cat.id), isNull);
    });

    test('seedDefaultCategories populates default categories when empty', () async {
      final initialCats = await categoryRepo.getAllCategories();
      expect(initialCats, isEmpty);

      await categoryRepo.seedDefaultCategories();

      final seeded = await categoryRepo.getAllCategories();
      expect(seeded.length, 6);

      final names = seeded.map((c) => c.name).toSet();
      expect(
        names,
        containsAll([
          'Food',
          'Transportation',
          'Social Life',
          'AI Subscription',
          'Savings',
          'Salary',
        ]),
      );

      final expenses = seeded.where((c) => c.type == CategoryType.expense);
      expect(expenses.length, 5);

      final incomes = seeded.where((c) => c.type == CategoryType.income);
      expect(incomes.length, 1);
      expect(incomes.first.name, 'Salary');
    });

    test('seedDefaultCategories is idempotent and does not duplicate', () async {
      await categoryRepo.seedDefaultCategories();
      var cats = await categoryRepo.getAllCategories();
      expect(cats.length, 6);

      // Call again - should do nothing
      await categoryRepo.seedDefaultCategories();
      cats = await categoryRepo.getAllCategories();
      expect(cats.length, 6);
    });
  });
}
