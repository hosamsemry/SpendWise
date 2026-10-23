import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/domain/budget_calculation_service.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

void main() {
  const service = BudgetCalculationService();

  final cycle = BudgetCycle(
    id: '2026-10-25_2026-11-24',
    startDate: DateTime(2026, 10, 25),
    endDate: DateTime(2026, 11, 24),
  );

  final now = DateTime(2026, 10, 25);

  Category createCat(String id, String name) {
    return Category(id: id, name: name, createdAt: now, updatedAt: now);
  }

  TransactionModel createTx({
    required String id,
    required TransactionType type,
    required num amountMajor,
    String? categoryId,
    required DateTime date,
  }) {
    return TransactionModel(
      id: id,
      type: type,
      amount: Money.fromMajorUnits(amountMajor),
      categoryId: categoryId,
      date: date,
      createdAt: now,
      updatedAt: now,
    );
  }

  group(
    'BudgetCalculationService — Section 16 & Section 5 Specification Tests',
    () {
      test('Under budget, exactly at budget, and over budget calculations', () {
        final food = createCat('food', 'Food');
        final transport = createCat('transport', 'Transport');
        final social = createCat('social', 'Social life');

        final categories = [food, transport, social];

        final budgetMap = {
          'food': Money.fromMajorUnits(2000), // 2000
          'transport': Money.fromMajorUnits(1000), // 1000
          'social': Money.fromMajorUnits(500), // 500
        };

        final transactions = [
          // Under budget: food spent 1500 -> remaining +500
          createTx(
            id: '1',
            type: TransactionType.expense,
            amountMajor: 1500,
            categoryId: 'food',
            date: DateTime(2026, 10, 26),
          ),
          // Exactly at budget: transport spent 1000 -> remaining 0
          createTx(
            id: '2',
            type: TransactionType.expense,
            amountMajor: 1000,
            categoryId: 'transport',
            date: DateTime(2026, 10, 27),
          ),
          // Over budget: social spent 700 -> remaining -200
          createTx(
            id: '3',
            type: TransactionType.expense,
            amountMajor: 700,
            categoryId: 'social',
            date: DateTime(2026, 10, 28),
          ),
        ];

        final summary = service.calculateCycleSummary(
          cycle: cycle,
          categories: categories,
          budgetMap: budgetMap,
          transactions: transactions,
        );

        final foodBudget = summary.categoryBudgets.firstWhere(
          (b) => b.categoryId == 'food',
        );
        expect(foodBudget.budgetedAmount, Money.fromMajorUnits(2000));
        expect(foodBudget.spentAmount, Money.fromMajorUnits(1500));
        expect(foodBudget.remainingAmount, Money.fromMajorUnits(500));
        expect(foodBudget.isOverspent, isFalse);
        expect(foodBudget.usagePercentage, 75.0);

        final transportBudget = summary.categoryBudgets.firstWhere(
          (b) => b.categoryId == 'transport',
        );
        expect(transportBudget.budgetedAmount, Money.fromMajorUnits(1000));
        expect(transportBudget.spentAmount, Money.fromMajorUnits(1000));
        expect(transportBudget.remainingAmount, const Money.zero());
        expect(transportBudget.isOverspent, isFalse);
        expect(transportBudget.usagePercentage, 100.0);

        final socialBudget = summary.categoryBudgets.firstWhere(
          (b) => b.categoryId == 'social',
        );
        expect(socialBudget.budgetedAmount, Money.fromMajorUnits(500));
        expect(socialBudget.spentAmount, Money.fromMajorUnits(700));
        expect(socialBudget.remainingAmount, Money.fromMajorUnits(-200));
        expect(socialBudget.isOverspent, isTrue);
        expect(socialBudget.usagePercentage, 140.0);
      });

      test('Zero budget handling: no spending and with spending', () {
        final unbudgetedCat1 = createCat('misc1', 'Misc 1');
        final unbudgetedCat2 = createCat('misc2', 'Misc 2');

        final categories = [unbudgetedCat1, unbudgetedCat2];
        final budgetMap = {
          'misc1': const Money.zero(),
          'misc2': const Money.zero(),
        };

        final transactions = [
          // Misc 2 has 250 EGP spending with zero budget
          createTx(
            id: '1',
            type: TransactionType.expense,
            amountMajor: 250,
            categoryId: 'misc2',
            date: DateTime(2026, 10, 26),
          ),
        ];

        final summary = service.calculateCycleSummary(
          cycle: cycle,
          categories: categories,
          budgetMap: budgetMap,
          transactions: transactions,
        );

        final b1 = summary.categoryBudgets.firstWhere(
          (b) => b.categoryId == 'misc1',
        );
        expect(b1.budgetedAmount, const Money.zero());
        expect(b1.spentAmount, const Money.zero());
        expect(b1.remainingAmount, const Money.zero());
        expect(b1.usagePercentage, isNull); // Safely avoided division by zero!
        expect(b1.isOverspent, isFalse);

        final b2 = summary.categoryBudgets.firstWhere(
          (b) => b.categoryId == 'misc2',
        );
        expect(b2.budgetedAmount, const Money.zero());
        expect(b2.spentAmount, Money.fromMajorUnits(250));
        expect(b2.remainingAmount, Money.fromMajorUnits(-250));
        expect(b2.usagePercentage, isNull);
        expect(b2.isOverspent, isTrue);
      });

      test(
        'Section 5.1 Spec Example: Positive unused total vs Net remaining total',
        () {
          // Spec Section 5.1 example table:
          // Food: 2,000 budget, 1,500 spent -> +500 remaining
          // Transport: 1,000 budget, 700 spent -> +300 remaining
          // Social life: 500 budget, 700 spent -> -200 remaining
          // Gym: 1,000 budget, 100 spent -> +900 remaining
          // Total: 4,500 budget, 3,000 spent -> +1,500 net
          // Positive unused total = 500 + 300 + 900 = 1,700 EGP.
          // Net remaining total = 500 + 300 - 200 + 900 = 1,500 EGP.
          // Overspent categories count = 1.
          final food = createCat('food', 'Food');
          final transport = createCat('transport', 'Transport');
          final social = createCat('social', 'Social life');
          final gym = createCat('gym', 'Gym');

          final categories = [food, transport, social, gym];
          final budgetMap = {
            'food': Money.fromMajorUnits(2000),
            'transport': Money.fromMajorUnits(1000),
            'social': Money.fromMajorUnits(500),
            'gym': Money.fromMajorUnits(1000),
          };

          final transactions = [
            createTx(
              id: '1',
              type: TransactionType.expense,
              amountMajor: 1500,
              categoryId: 'food',
              date: DateTime(2026, 10, 26),
            ),
            createTx(
              id: '2',
              type: TransactionType.expense,
              amountMajor: 700,
              categoryId: 'transport',
              date: DateTime(2026, 10, 26),
            ),
            createTx(
              id: '3',
              type: TransactionType.expense,
              amountMajor: 700,
              categoryId: 'social',
              date: DateTime(2026, 10, 26),
            ),
            createTx(
              id: '4',
              type: TransactionType.expense,
              amountMajor: 100,
              categoryId: 'gym',
              date: DateTime(2026, 10, 26),
            ),
            // Income transaction in cycle: 10,000 EGP
            createTx(
              id: '5',
              type: TransactionType.income,
              amountMajor: 10000,
              categoryId: null,
              date: DateTime(2026, 10, 25),
            ),
          ];

          final summary = service.calculateCycleSummary(
            cycle: cycle,
            categories: categories,
            budgetMap: budgetMap,
            transactions: transactions,
          );

          expect(summary.totalBudgeted, Money.fromMajorUnits(4500));
          expect(summary.totalSpent, Money.fromMajorUnits(3000));
          expect(summary.positiveUnusedTotal, Money.fromMajorUnits(1700));
          expect(summary.netRemainingTotal, Money.fromMajorUnits(1500));
          expect(summary.overspentCategoriesCount, 1);
          expect(summary.totalIncome, Money.fromMajorUnits(10000));
        },
      );

      test('Multiple transactions in one category sum correctly', () {
        final food = createCat('food', 'Food');
        final budgetMap = {'food': Money.fromMajorUnits(1000)};

        final transactions = [
          createTx(
            id: '1',
            type: TransactionType.expense,
            amountMajor: 150,
            categoryId: 'food',
            date: DateTime(2026, 10, 26),
          ),
          createTx(
            id: '2',
            type: TransactionType.expense,
            amountMajor: 350.50,
            categoryId: 'food',
            date: DateTime(2026, 10, 27),
          ),
          createTx(
            id: '3',
            type: TransactionType.expense,
            amountMajor: 200,
            categoryId: 'food',
            date: DateTime(2026, 10, 28),
          ),
        ];

        final summary = service.calculateCycleSummary(
          cycle: cycle,
          categories: [food],
          budgetMap: budgetMap,
          transactions: transactions,
        );

        final foodBudget = summary.categoryBudgets.first;
        expect(foodBudget.spentAmount, Money.fromMajorUnits(700.50));
        expect(foodBudget.remainingAmount, Money.fromMajorUnits(299.50));
      });

      test(
        'Transactions outside cycle date boundaries are excluded from cycle totals',
        () {
          final food = createCat('food', 'Food');
          final budgetMap = {'food': Money.fromMajorUnits(1000)};

          final transactions = [
            // Inside cycle
            createTx(
              id: '1',
              type: TransactionType.expense,
              amountMajor: 200,
              categoryId: 'food',
              date: DateTime(2026, 10, 25),
            ),
            // Outside cycle (before start date)
            createTx(
              id: '2',
              type: TransactionType.expense,
              amountMajor: 500,
              categoryId: 'food',
              date: DateTime(2026, 10, 24),
            ),
            // Outside cycle (after end date)
            createTx(
              id: '3',
              type: TransactionType.expense,
              amountMajor: 800,
              categoryId: 'food',
              date: DateTime(2026, 11, 25),
            ),
          ];

          final summary = service.calculateCycleSummary(
            cycle: cycle,
            categories: [food],
            budgetMap: budgetMap,
            transactions: transactions,
          );

          final foodBudget = summary.categoryBudgets.first;
          expect(foodBudget.spentAmount, Money.fromMajorUnits(200));
          expect(summary.totalSpent, Money.fromMajorUnits(200));
        },
      );

      test(
        'Orphan and deleted category expenses are preserved and counted in cycle totals',
        () {
          final food = createCat('food', 'Food');
          final budgetMap = {'food': Money.fromMajorUnits(1000)};

          final transactions = [
            // Normal expense in active category: 300 EGP
            createTx(
              id: '1',
              type: TransactionType.expense,
              amountMajor: 300,
              categoryId: 'food',
              date: DateTime(2026, 10, 26),
            ),
            // Orphan expense with categoryId = null (e.g. category deleted): 150 EGP
            TransactionModel(
              id: '2',
              type: TransactionType.expense,
              amount: Money.fromMajorUnits(150),
              categoryId: null,
              categoryName: 'Transportation',
              date: DateTime(2026, 10, 27),
              createdAt: now,
              updatedAt: now,
            ),
            // Orphan expense with unknown categoryId: 50 EGP
            TransactionModel(
              id: '3',
              type: TransactionType.expense,
              amount: Money.fromMajorUnits(50),
              categoryId: 'deleted_cat_id',
              categoryName: 'Subscriptions',
              date: DateTime(2026, 10, 28),
              createdAt: now,
              updatedAt: now,
            ),
          ];

          final summary = service.calculateCycleSummary(
            cycle: cycle,
            categories: [food],
            budgetMap: budgetMap,
            transactions: transactions,
          );

          // Total spent must include both normal and orphan expenses: 300 + 150 + 50 = 500 EGP
          expect(summary.totalSpent, Money.fromMajorUnits(500));
          expect(summary.totalBudgeted, Money.fromMajorUnits(1000));
          // Net remaining = 1000 - 500 = 500 EGP
          expect(summary.netRemainingTotal, Money.fromMajorUnits(500));

          // Food budget
          final foodBudget = summary.categoryBudgets.firstWhere(
            (b) => b.categoryId == 'food',
          );
          expect(foodBudget.spentAmount, Money.fromMajorUnits(300));

          // Orphan category budgets
          final transBudget = summary.categoryBudgets.firstWhere(
            (b) => b.categoryName == 'Transportation (Deleted)',
          );
          expect(transBudget.spentAmount, Money.fromMajorUnits(150));
          expect(transBudget.budgetedAmount, Money.zero());

          final subBudget = summary.categoryBudgets.firstWhere(
            (b) => b.categoryName == 'Subscriptions (Deleted)',
          );
          expect(subBudget.spentAmount, Money.fromMajorUnits(50));
          expect(subBudget.budgetedAmount, Money.zero());
        },
      );
    },
  );
}
