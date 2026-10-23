import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/money/money.dart';

void main() {
  group('Money Value Object', () {
    test('Constructors and basic properties', () {
      const zero = Money.zero();
      expect(zero.inMinorUnits, 0);
      expect(zero.inMajorUnits, 0.0);
      expect(zero.isZero, isTrue);
      expect(zero.isPositive, isFalse);
      expect(zero.isNegative, isFalse);

      const positive = Money.fromMinorUnits(2500);
      expect(positive.inMinorUnits, 2500);
      expect(positive.inMajorUnits, 25.0);
      expect(positive.isPositive, isTrue);
      expect(positive.isNegative, isFalse);
      expect(positive.isZero, isFalse);

      const negative = Money.fromMinorUnits(-150);
      expect(negative.inMinorUnits, -150);
      expect(negative.inMajorUnits, -1.50);
      expect(negative.isNegative, isTrue);
      expect(negative.isPositive, isFalse);
    });

    test('fromMajorUnits converts decimals safely to minor units', () {
      expect(Money.fromMajorUnits(10).inMinorUnits, 1000);
      expect(Money.fromMajorUnits(12.5).inMinorUnits, 1250);
      expect(Money.fromMajorUnits(0.05).inMinorUnits, 5);
      expect(Money.fromMajorUnits(199.99).inMinorUnits, 19999);
      expect(Money.fromMajorUnits(-50.25).inMinorUnits, -5025);
    });

    test('parse handles integers, decimals, prefixes, and signs', () {
      expect(Money.parse('100').inMinorUnits, 10000);
      expect(Money.parse('100.50').inMinorUnits, 10050);
      expect(Money.parse('100.5').inMinorUnits, 10050);
      expect(Money.parse('0.05').inMinorUnits, 5);
      expect(Money.parse('+50.25').inMinorUnits, 5025);
      expect(Money.parse('-200.75').inMinorUnits, -20075);
      expect(Money.parse('1,250.00').inMinorUnits, 125000);
      expect(Money.parse('EGP 2,000').inMinorUnits, 200000);
      expect(Money.parse('1,250.00 EGP').inMinorUnits, 125000);
      expect(Money.parse('  egp  15.50  ').inMinorUnits, 1550);
    });

    test('parse throws FormatException on invalid input', () {
      expect(() => Money.parse(''), throwsFormatException);
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse('12.345'), throwsFormatException);
      expect(() => Money.parse('12.3.4'), throwsFormatException);
      expect(() => Money.parse('1000000000'), throwsFormatException);
    });

    test('enforces maxMajorUnits ceiling', () {
      expect(Money.parse('999999999').inMajorUnits, 999999999.0);
      expect(() => Money.parse('1000000000'), throwsFormatException);
    });

    test('tryParse safely returns null on invalid input', () {
      expect(Money.tryParse(null), isNull);
      expect(Money.tryParse('invalid'), isNull);
      expect(Money.tryParse('50.00')?.inMinorUnits, 5000);
    });

    test('Exact arithmetic operations', () {
      const a = Money.fromMinorUnits(1500); // 15.00
      const b = Money.fromMinorUnits(2550); // 25.50

      expect((a + b).inMinorUnits, 4050);
      expect((b - a).inMinorUnits, 1050);
      expect((a - b).inMinorUnits, -1050);
      expect((-a).inMinorUnits, -1500);
      expect(a * 2, const Money.fromMinorUnits(3000));
      expect(a * 0.5, const Money.fromMinorUnits(750));
      expect(a.abs().inMinorUnits, 1500);
      expect((-a).abs().inMinorUnits, 1500);
    });

    test('Comparisons and equality', () {
      const low = Money.fromMinorUnits(500);
      const mid = Money.fromMinorUnits(1000);
      const high = Money.fromMinorUnits(2000);
      const equalMid = Money.fromMinorUnits(1000);

      expect(low < mid, isTrue);
      expect(mid <= equalMid, isTrue);
      expect(high > mid, isTrue);
      expect(mid >= low, isTrue);
      expect(mid == equalMid, isTrue);
      expect(mid == low, isFalse);
      expect([high, low, mid]..sort(), [low, mid, high]);
    });

    test('toFormattedString formats EGP and signs clearly', () {
      expect(
        const Money.fromMinorUnits(200000).toFormattedString(),
        '2,000.00 EGP',
      );
      expect(const Money.fromMinorUnits(500).toFormattedString(), '5.00 EGP');
      expect(const Money.fromMinorUnits(0).toFormattedString(), '0.00 EGP');
      expect(
        const Money.fromMinorUnits(-20000).toFormattedString(),
        '-200.00 EGP',
      );
      expect(
        const Money.fromMinorUnits(50000).toFormattedString(showSign: true),
        '+500.00 EGP',
      );
      expect(
        const Money.fromMinorUnits(
          150000,
        ).toFormattedString(includeCurrency: false),
        '1,500.00',
      );
    });

    test('parse and tryParse handle Eastern Arabic and Persian numerals and separators', () {
      expect(Money.parse('١٠٠').inMinorUnits, 10000);
      expect(Money.parse('١٢٥٠.٥٠').inMinorUnits, 125050);
      expect(Money.parse('١،٢٥٠٫٥٠').inMinorUnits, 125050);
      expect(Money.parse('ج.م ١٠٠').inMinorUnits, 10000);
      expect(Money.parse('٥٠٠ ج.م').inMinorUnits, 50000);
      expect(Money.tryParse('١٥٠٫٧٥')?.inMinorUnits, 15075);
    });

    test('toFormattedString respects defaultCurrencySymbol dynamically', () {
      Money.defaultCurrencySymbol = 'ج.م';
      expect(
        const Money.fromMinorUnits(25000).toFormattedString(),
        '250.00 ج.م',
      );
      Money.defaultCurrencySymbol = 'EGP';
      expect(
        const Money.fromMinorUnits(25000).toFormattedString(),
        '250.00 EGP',
      );
    });
  });
}
