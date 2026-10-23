import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
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
  const calculator = BudgetCycleCalculator();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    transactionRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionRepository Tests — Spec Section 6 & 16', () {
    test('Add expense requires category and amount > 0', () async {
      final food = await categoryRepo.createCategory(name: 'Food');

      // Zero amount rejected
      expect(
        () => transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: const Money.zero(),
          categoryId: food.id,
          date: DateTime(2026, 10, 26),
        ),
        throwsArgumentError,
      );

      // Missing category for expense rejected
      expect(
        () => transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(100),
          categoryId: null,
          date: DateTime(2026, 10, 26),
        ),
        throwsArgumentError,
      );

      // Valid expense succeeds
      final tx = await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(150.50),
        categoryId: food.id,
        date: DateTime(2026, 10, 26),
        note: 'Supermarket grocery run',
      );

      expect(tx.amount, Money.fromMajorUnits(150.50));
      expect(tx.categoryName, 'Food');
      expect(tx.note, 'Supermarket grocery run');
      expect(tx.isExpense, isTrue);
    });

    test('Add income supports amount, category, date, and note', () async {
      final salaryCat = await categoryRepo.createCategory(name: 'Salary');

      // Income with category
      final inc1 = await transactionRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(15000),
        categoryId: salaryCat.id,
        date: DateTime(2026, 10, 25),
        note: 'October paycheck',
      );

      expect(inc1.isIncome, isTrue);
      expect(inc1.amount, Money.fromMajorUnits(15000));
      expect(inc1.categoryId, salaryCat.id);
      expect(inc1.categoryName, 'Salary');
      expect(inc1.note, 'October paycheck');

      // Income without category
      final inc2 = await transactionRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(500),
        categoryId: null,
        date: DateTime(2026, 10, 26),
      );

      expect(inc2.isIncome, isTrue);
      expect(inc2.categoryId, isNull);
    });

    test('Filters by cycle, type, category, and searches note', () async {
      final food = await categoryRepo.createCategory(name: 'Food');
      final transport = await categoryRepo.createCategory(name: 'Transport');
      final octCycle = calculator.getCycleForDate(DateTime(2026, 10, 26));

      await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(50),
        categoryId: food.id,
        date: DateTime(2026, 10, 26),
        note: 'Lunch at cafe',
      );

      await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(30),
        categoryId: transport.id,
        date: DateTime(2026, 10, 27),
        note: 'Taxi to work',
      );

      await transactionRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(2000),
        categoryId: null,
        date: DateTime(2026, 10, 25),
        note: 'Freelance payment',
      );

      // Previous cycle transaction
      await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(80),
        categoryId: food.id,
        date: DateTime(2026, 10, 20), // Belongs to Sept cycle
        note: 'Old food expense',
      );

      // Query octCycle only
      final octTxs = await transactionRepo.getTransactionsForCycle(octCycle);
      expect(octTxs.length, 3);

      // Filter by type: expense
      final expenses = await transactionRepo.getTransactionsForCycle(
        octCycle,
        type: TransactionType.expense,
      );
      expect(expenses.length, 2);

      // Filter by category: food
      final foodTxs = await transactionRepo.getTransactionsForCycle(
        octCycle,
        categoryId: food.id,
      );
      expect(foodTxs.length, 1);
      expect(foodTxs.first.note, 'Lunch at cafe');

      // Search note case-insensitive
      final searched = await transactionRepo.getTransactionsForCycle(
        octCycle,
        searchNote: 'TAXI',
      );
      expect(searched.length, 1);
      expect(searched.first.note, 'Taxi to work');
    });

    test('Search note containing single quotes succeeds without SQL error', () async {
      final food = await categoryRepo.createCategory(name: 'Fast Food');
      final octCycle = calculator.getCycleForDate(DateTime(2026, 10, 26));

      await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(85),
        categoryId: food.id,
        date: DateTime(2026, 10, 26),
        note: "Dinner at McDonald's & Wendy's",
      );

      final searched = await transactionRepo.getTransactionsForCycle(
        octCycle,
        searchNote: "mcdonald's",
      );
      expect(searched.length, 1);
      expect(searched.first.note, "Dinner at McDonald's & Wendy's");
    });

    test('Editing and deleting transactions updates correctly', () async {
      final food = await categoryRepo.createCategory(name: 'Food');
      final tx = await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(100),
        categoryId: food.id,
        date: DateTime(2026, 10, 26),
        note: 'Initial note',
      );

      // Update
      final updated = await transactionRepo.updateTransaction(
        id: tx.id,
        amount: Money.fromMajorUnits(120),
        note: 'Updated note',
      );

      expect(updated.amount, Money.fromMajorUnits(120));
      expect(updated.note, 'Updated note');

      // Delete
      await transactionRepo.deleteTransaction(tx.id);
      expect(await transactionRepo.getTransactionById(tx.id), isNull);
    });

    test(
      'Transaction assigned by date to a historical cycle affects that historical cycle',
      () async {
        final food = await categoryRepo.createCategory(name: 'Food');
        final septCycle = calculator.getCycleForDate(
          DateTime(2026, 10, 10),
        ); // 25 Sep - 24 Oct
        final octCycle = calculator.getCycleForDate(
          DateTime(2026, 10, 26),
        ); // 25 Oct - 24 Nov

        // Add transaction entered today but dated in Sept cycle
        final historicalTx = await transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(250),
          categoryId: food.id,
          date: DateTime(2026, 10, 15),
          note: 'Belated receipt',
        );

        final septTxs = await transactionRepo.getTransactionsForCycle(
          septCycle,
        );
        expect(septTxs.any((t) => t.id == historicalTx.id), isTrue);

        final octTxs = await transactionRepo.getTransactionsForCycle(octCycle);
        expect(octTxs.any((t) => t.id == historicalTx.id), isFalse);
      },
    );

    test('restoreTransaction restores deleted transaction with original ID and attributes', () async {
      final food = await categoryRepo.createCategory(name: 'Food');
      final tx = await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(85),
        categoryId: food.id,
        date: DateTime(2026, 10, 20),
        note: 'Restorable lunch',
      );

      // Delete
      await transactionRepo.deleteTransaction(tx.id);
      expect(await transactionRepo.getTransactionById(tx.id), isNull);

      // Restore
      final restored = await transactionRepo.restoreTransaction(tx);
      expect(restored.id, tx.id);
      expect(restored.amount, Money.fromMajorUnits(85));
      expect(restored.note, 'Restorable lunch');
      expect(restored.categoryName, 'Food');

      final fetched = await transactionRepo.getTransactionById(tx.id);
      expect(fetched, isNotNull);
      expect(fetched!.amount, Money.fromMajorUnits(85));
    });

    test(
      'restoreTransaction succeeds defensively when category was deleted before undo',
      () async {
        final gym = await categoryRepo.createCategory(name: 'Gym');
        final tx = await transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(120),
          categoryId: gym.id,
          date: DateTime(2026, 10, 21),
        );

        // Delete transaction
        await transactionRepo.deleteTransaction(tx.id);

        // Now delete the category itself
        await categoryRepo.deleteCategory(gym.id);

        // Undo (restore) transaction — must NOT throw a foreign key error
        final restored = await transactionRepo.restoreTransaction(tx);
        expect(restored.id, tx.id);
        expect(restored.amount, Money.fromMajorUnits(120));
        expect(restored.categoryId, isNull);
        expect(restored.categoryName, 'Gym');
      },
    );
  });
}
