import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/money/math_expression_evaluator.dart';
import 'package:money_tracker/core/money/money.dart';

void main() {
  group('MathExpressionEvaluator Tests', () {
    test('Direct numbers evaluation', () {
      expect(MathExpressionEvaluator.tryEvaluate('50'), equals(Money.parse('50')));
      expect(MathExpressionEvaluator.tryEvaluate('125.75'), equals(Money.parse('125.75')));
      expect(MathExpressionEvaluator.tryEvaluate('  1,000.50  '), equals(Money.parse('1000.50')));
    });

    test('BODMAS / PEMDAS operator precedence', () {
      // 10 + 5 * 2 = 20 (NOT 30)
      expect(MathExpressionEvaluator.tryEvaluate('10 + 5 * 2'), equals(Money.parse('20')));
      // 50 - 10 / 2 = 45 (NOT 20)
      expect(MathExpressionEvaluator.tryEvaluate('50 - 10 / 2'), equals(Money.parse('45')));
      // 4 * 3 + 12 / 4 = 12 + 3 = 15
      expect(MathExpressionEvaluator.tryEvaluate('4 * 3 + 12 / 4'), equals(Money.parse('15')));
    });

    test('Parentheses override precedence', () {
      // (10 + 5) * 2 = 30
      expect(MathExpressionEvaluator.tryEvaluate('(10 + 5) * 2'), equals(Money.parse('30')));
      // 100 - (20 + 15) = 65
      expect(MathExpressionEvaluator.tryEvaluate('100 - (20 + 15)'), equals(Money.parse('65')));
      // (45 + 30) / (3 + 2) = 75 / 5 = 15
      expect(MathExpressionEvaluator.tryEvaluate('(45 + 30) / (3 + 2)'), equals(Money.parse('15')));
    });

    test('Multiplication and division aliases (× and ÷)', () {
      expect(MathExpressionEvaluator.tryEvaluate('12 × 4'), equals(Money.parse('48')));
      expect(MathExpressionEvaluator.tryEvaluate('100 ÷ 4'), equals(Money.parse('25')));
    });

    test('Division by zero returns null safely', () {
      expect(MathExpressionEvaluator.tryEvaluate('100 / 0'), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('50 / (5 - 5)'), isNull);
    });

    test('Negative or zero result returns null', () {
      expect(MathExpressionEvaluator.tryEvaluate('10 - 20'), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('15 - 15'), isNull);
    });

    test('Exceeding maximum amount limit returns null', () {
      expect(MathExpressionEvaluator.tryEvaluate('1000000000'), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('999999999 * 2'), isNull);
    });

    test('Malformed expressions return null', () {
      expect(MathExpressionEvaluator.tryEvaluate(''), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('   '), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('45 + '), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('+ * 5'), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('((10 + 5)'), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('10 + 5)'), isNull);
      expect(MathExpressionEvaluator.tryEvaluate('abc + 12'), isNull);
    });

    test('Evaluates expressions with Eastern Arabic and Persian numerals', () {
      // ١٠ + ٥ * ٢ = 20
      expect(MathExpressionEvaluator.tryEvaluate('١٠ + ٥ * ٢'), equals(Money.parse('20')));
      // (٤٥ + ٣٠) / ٥ = 15
      expect(MathExpressionEvaluator.tryEvaluate('(٤٥ + ٣٠) / ٥'), equals(Money.parse('15')));
      // ١٢ × ٤ = 48
      expect(MathExpressionEvaluator.tryEvaluate('١٢ × ٤'), equals(Money.parse('48')));
    });
  });
}
