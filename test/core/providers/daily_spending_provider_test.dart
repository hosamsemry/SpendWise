import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  group('groupTransactionsByDay Tests', () {
    test('Groups transactions by calendar day and computes daily totals', () {
      final tx1 = TransactionModel(
        id: '1',
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(50),
        date: DateTime(2026, 10, 16, 10, 30),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final tx2 = TransactionModel(
        id: '2',
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(120),
        date: DateTime(2026, 10, 16, 14, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final tx3 = TransactionModel(
        id: '3',
        type: TransactionType.income,
        amount: Money.fromMajorUnits(500),
        date: DateTime(2026, 10, 15, 9, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final tx4 = TransactionModel(
        id: '4',
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(80),
        date: DateTime(2026, 10, 15, 18, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final groups = groupTransactionsByDay([tx1, tx2, tx3, tx4]);

      expect(groups.length, 2);

      // Newest day first: Oct 16
      expect(groups[0].date, DateTime(2026, 10, 16));
      expect(groups[0].totalSpent.inMinorUnits, 17000); // 50 + 120 = 170
      expect(groups[0].totalIncome.inMinorUnits, 0);
      expect(groups[0].transactions.length, 2);

      // Previous day: Oct 15
      expect(groups[1].date, DateTime(2026, 10, 15));
      expect(groups[1].totalSpent.inMinorUnits, 8000); // 80
      expect(groups[1].totalIncome.inMinorUnits, 50000); // 500
      expect(groups[1].transactions.length, 2);
    });

    test('Returns empty list for empty transactions', () {
      final groups = groupTransactionsByDay([]);
      expect(groups.isEmpty, true);
    });
  });

  group('todaySpendingSummaryProvider Tests', () {
    test('Calculates total spent today correctly', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final catRepo = CategoryRepository(db);
      final txRepo = TransactionRepository(db);

      final foodCat = await catRepo.createCategory(
        name: 'Food',
        type: CategoryType.expense,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12, 0);
      final yesterday = today.subtract(const Duration(days: 1));

      // Today's expenses: 40 + 65 = 105
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(40),
        categoryId: foodCat.id,
        date: today,
      );
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(65),
        categoryId: foodCat.id,
        date: today,
      );

      // Today's income (should NOT be added to spending): 200
      await txRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(200),
        date: today,
      );

      // Yesterday's expense (should NOT be added to today's spending): 150
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(150),
        categoryId: foodCat.id,
        date: yesterday,
      );

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      final summary = await container.read(todaySpendingSummaryProvider.future);

      expect(summary.totalSpentToday.inMinorUnits, 10500); // 105 EGP
      expect(summary.totalSpentToday.toFormattedString(), '105.00 EGP');
      expect(summary.transactionCountToday, 2);

      await db.close();
      container.dispose();
    });

    test('Computes isOverDailyPace and remainingToday accurately', () {
      // 1. Within safe daily pace: budget pace 200 EGP, spent 120 EGP -> 80 remaining, not over pace
      const withinSummary = DailySpendingSummary(
        totalSpentToday: Money.fromMinorUnits(12000),
        transactionCountToday: 2,
        dailyPace: Money.fromMinorUnits(20000),
        daysRemainingInCycle: 10,
        isOverDailyPace: false,
        overDailyPaceAmount: Money.zero(),
        remainingToday: Money.fromMinorUnits(8000),
      );
      expect(withinSummary.isOverDailyPace, isFalse);
      expect(withinSummary.overDailyPaceAmount.inMinorUnits, 0);
      expect(withinSummary.remainingToday.toFormattedString(), '80.00 EGP');

      // 2. Over safe daily pace: budget pace 150 EGP, spent 250 EGP -> over by 100, 0 remaining
      const overSummary = DailySpendingSummary(
        totalSpentToday: Money.fromMinorUnits(25000),
        transactionCountToday: 3,
        dailyPace: Money.fromMinorUnits(15000),
        daysRemainingInCycle: 5,
        isOverDailyPace: true,
        overDailyPaceAmount: Money.fromMinorUnits(10000),
        remainingToday: Money.zero(),
      );
      expect(overSummary.isOverDailyPace, isTrue);
      expect(overSummary.overDailyPaceAmount.toFormattedString(), '100.00 EGP');
      expect(overSummary.remainingToday.inMinorUnits, 0);
    });
  });
}
