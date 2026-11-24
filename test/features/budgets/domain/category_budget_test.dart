import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';

CategoryBudget _budget(int budgeted, int spent) => CategoryBudget(
      categoryId: 'c1',
      categoryName: 'Food',
      budgetedAmount: Money.fromMinorUnits(budgeted),
      spentAmount: Money.fromMinorUnits(spent),
    );

void main() {
  group('CategoryBudget thresholds', () {
    test('below 80% is neither near limit nor at limit', () {
      final b = _budget(10000, 7999);
      expect(b.isNearLimit, isFalse);
      expect(b.isAtOrOverLimit, isFalse);
    });

    test('80%..<100% is near limit only', () {
      final b = _budget(10000, 9999);
      expect(b.isNearLimit, isTrue);
      expect(b.isLimitReached, isFalse);
      expect(b.isAtOrOverLimit, isFalse);
    });

    test('exactly 100% is limit reached, not near limit or overspent', () {
      final b = _budget(10000, 10000);
      expect(b.isLimitReached, isTrue);
      expect(b.isAtOrOverLimit, isTrue);
      expect(b.isOverspent, isFalse);
      expect(b.isNearLimit, isFalse);
    });

    test('over 100% is overspent and at-or-over limit', () {
      final b = _budget(10000, 10001);
      expect(b.isOverspent, isTrue);
      expect(b.isLimitReached, isFalse);
      expect(b.isAtOrOverLimit, isTrue);
    });

    test('zero budget with zero spending raises nothing', () {
      final b = _budget(0, 0);
      expect(b.isLimitReached, isFalse);
      expect(b.isAtOrOverLimit, isFalse);
    });
  });
}
