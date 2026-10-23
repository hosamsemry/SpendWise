import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
  });

  test('formatDate and parseDate work correctly across Arabic and English locales without throwing', () async {
    for (final loc in ['en', 'ar', 'ar_EG', 'ar_SA', 'ar_AE']) {
      await initializeDateFormatting(loc, null);
      Intl.defaultLocale = loc;
      final date = DateTime(2026, 10, 25);

      // 1. formatDate must strictly produce ASCII ISO string
      final formatted = BudgetCycleCalculator.formatDate(date);
      expect(formatted, '2026-10-25');
      expect(DateTime.parse(formatted), date);

      // 2. parseDate must parse ASCII string
      expect(BudgetCycleCalculator.parseDate('2026-10-25'), date);

      // 3. parseDate must gracefully handle Eastern Arabic numerals
      expect(BudgetCycleCalculator.parseDate('٢٠٢٦-١٠-٢٥'), date);

      // 4. BudgetCycle getters must strictly produce ASCII ISO strings
      final cycle = BudgetCycle(id: 'c1', startDate: date, endDate: date);
      expect(cycle.startDateString, '2026-10-25');
      expect(cycle.endDateString, '2026-10-25');
    }
  });

  const calculator = BudgetCycleCalculator();

  group('BudgetCycleCalculator — Specification Section 16 Required Tests', () {
    test('24 October -> cycle starting 25 September and ending 24 October', () {
      final date = DateTime(2026, 10, 24);
      final cycle = calculator.getCycleForDate(date);

      expect(cycle.startDate, DateTime(2026, 9, 25));
      expect(cycle.endDate, DateTime(2026, 10, 24));
      expect(cycle.startDateString, '2026-09-25');
      expect(cycle.endDateString, '2026-10-24');
      expect(cycle.contains(date), isTrue);
    });

    test('25 October -> cycle starting 25 October and ending 24 November', () {
      final date = DateTime(2026, 10, 25);
      final cycle = calculator.getCycleForDate(date);

      expect(cycle.startDate, DateTime(2026, 10, 25));
      expect(cycle.endDate, DateTime(2026, 11, 24));
      expect(cycle.startDateString, '2026-10-25');
      expect(cycle.endDateString, '2026-11-24');
      expect(cycle.contains(date), isTrue);
    });

    test('1 January -> cycle starting 25 December of previous year', () {
      final date = DateTime(2027, 1, 1);
      final cycle = calculator.getCycleForDate(date);

      expect(cycle.startDate, DateTime(2026, 12, 25));
      expect(cycle.endDate, DateTime(2027, 1, 24));
      expect(cycle.startDateString, '2026-12-25');
      expect(cycle.endDateString, '2027-01-24');
      expect(cycle.contains(date), isTrue);
    });

    test('24 January -> cycle starting 25 December of previous year', () {
      final date = DateTime(2027, 1, 24);
      final cycle = calculator.getCycleForDate(date);

      expect(cycle.startDate, DateTime(2026, 12, 25));
      expect(cycle.endDate, DateTime(2027, 1, 24));
      expect(cycle.startDateString, '2026-12-25');
      expect(cycle.endDateString, '2027-01-24');
      expect(cycle.contains(date), isTrue);
    });

    test('25 January -> cycle starting 25 January', () {
      final date = DateTime(2027, 1, 25);
      final cycle = calculator.getCycleForDate(date);

      expect(cycle.startDate, DateTime(2027, 1, 25));
      expect(cycle.endDate, DateTime(2027, 2, 24));
      expect(cycle.startDateString, '2027-01-25');
      expect(cycle.endDateString, '2027-02-24');
      expect(cycle.contains(date), isTrue);
    });

    test(
      'Leap-year February boundaries (2024 leap year vs 2023 non-leap year)',
      () {
        // 24 Feb in leap year 2024 -> belongs to 25 Jan 2024 - 24 Feb 2024
        final feb24Leap = calculator.getCycleForDate(DateTime(2024, 2, 24));
        expect(feb24Leap.startDate, DateTime(2024, 1, 25));
        expect(feb24Leap.endDate, DateTime(2024, 2, 24));

        // 25 Feb in leap year 2024 -> belongs to 25 Feb 2024 - 24 Mar 2024
        final feb25Leap = calculator.getCycleForDate(DateTime(2024, 2, 25));
        expect(feb25Leap.startDate, DateTime(2024, 2, 25));
        expect(feb25Leap.endDate, DateTime(2024, 3, 24));

        // 29 Feb 2024 (leap day) -> falls inside 25 Feb 2024 - 24 Mar 2024
        expect(feb25Leap.contains(DateTime(2024, 2, 29)), isTrue);

        // Non-leap year: 28 Feb 2023 -> falls inside 25 Feb 2023 - 24 Mar 2023
        final feb28NonLeap = calculator.getCycleForDate(DateTime(2023, 2, 28));
        expect(feb28NonLeap.startDate, DateTime(2023, 2, 25));
        expect(feb28NonLeap.endDate, DateTime(2023, 3, 24));
        expect(feb28NonLeap.contains(DateTime(2023, 2, 28)), isTrue);
      },
    );

    test('Cycle end is always the day before next cycle start (the 24th)', () {
      for (var month = 1; month <= 12; month++) {
        final cycle = calculator.getCycleForDate(DateTime(2026, month, 25));
        expect(cycle.startDate.day, 25);
        expect(cycle.endDate.day, 24);

        final nextCycle = calculator.getNextCycle(cycle);
        expect(nextCycle.startDate.day, 25);
        final dayAfterEnd = DateTime(
          cycle.endDate.year,
          cycle.endDate.month,
          cycle.endDate.day + 1,
        );
        expect(dayAfterEnd, nextCycle.startDate);
      }
    });

    test(
      'getNextCycle and getPreviousCycle transitions across year boundaries',
      () {
        final decCycle = calculator.getCycleForDate(DateTime(2026, 12, 25));
        expect(decCycle.startDate, DateTime(2026, 12, 25));
        expect(decCycle.endDate, DateTime(2027, 1, 24));

        final janCycle = calculator.getNextCycle(decCycle);
        expect(janCycle.startDate, DateTime(2027, 1, 25));
        expect(janCycle.endDate, DateTime(2027, 2, 24));

        final backToDec = calculator.getPreviousCycle(janCycle);
        expect(backToDec.startDate, DateTime(2026, 12, 25));
        expect(backToDec.endDate, DateTime(2027, 1, 24));
        expect(backToDec, decCycle);

        final novCycle = calculator.getPreviousCycle(decCycle);
        expect(novCycle.startDate, DateTime(2026, 11, 25));
        expect(novCycle.endDate, DateTime(2026, 12, 24));
      },
    );

    test('contains correctly checks boundary and internal dates', () {
      final cycle = BudgetCycle(
        id: '2026-10-25_2026-11-24',
        startDate: DateTime(2026, 10, 25),
        endDate: DateTime(2026, 11, 24),
      );

      // Boundaries
      expect(cycle.contains(DateTime(2026, 10, 25)), isTrue);
      expect(cycle.contains(DateTime(2026, 11, 24)), isTrue);

      // Inside
      expect(cycle.contains(DateTime(2026, 10, 31)), isTrue);
      expect(cycle.contains(DateTime(2026, 11, 1)), isTrue);

      // Outside
      expect(cycle.contains(DateTime(2026, 10, 24)), isFalse);
      expect(cycle.contains(DateTime(2026, 11, 25)), isFalse);
      expect(cycle.contains(DateTime(2025, 11, 10)), isFalse);
    });

    test('formatDate and parseDate work with ISO YYYY-MM-DD format', () {
      final dt = DateTime(2026, 10, 25);
      final formatted = BudgetCycleCalculator.formatDate(dt);
      expect(formatted, '2026-10-25');

      final parsed = BudgetCycleCalculator.parseDate(formatted);
      expect(parsed.year, 2026);
      expect(parsed.month, 10);
      expect(parsed.day, 25);
    });
  });

  group('BudgetCycleCalculator — Calendar Month (startDay = 1)', () {
    const calc = BudgetCycleCalculator(startDay: 1);

    test('October month -> 1 Oct to 31 Oct', () {
      final date = DateTime(2026, 10, 15);
      final cycle = calc.getCycleForDate(date);

      expect(cycle.startDate, DateTime(2026, 10, 1));
      expect(cycle.endDate, DateTime(2026, 10, 31));
      expect(cycle.startDateString, '2026-10-01');
      expect(cycle.endDateString, '2026-10-31');
      expect(cycle.contains(DateTime(2026, 10, 1)), isTrue);
      expect(cycle.contains(DateTime(2026, 10, 31)), isTrue);
      expect(cycle.contains(DateTime(2026, 9, 30)), isFalse);
      expect(cycle.contains(DateTime(2026, 11, 1)), isFalse);
    });

    test('February leap year (2024) ends on 29th', () {
      final cycle = calc.getCycleForDate(DateTime(2024, 2, 10));
      expect(cycle.startDate, DateTime(2024, 2, 1));
      expect(cycle.endDate, DateTime(2024, 2, 29));
    });

    test('February non-leap year (2023) ends on 28th', () {
      final cycle = calc.getCycleForDate(DateTime(2023, 2, 10));
      expect(cycle.startDate, DateTime(2023, 2, 1));
      expect(cycle.endDate, DateTime(2023, 2, 28));
    });

    test('Transitions across consecutive calendar months', () {
      final dec = calc.getCycleForDate(DateTime(2026, 12, 1));
      expect(dec.startDate, DateTime(2026, 12, 1));
      expect(dec.endDate, DateTime(2026, 12, 31));

      final jan = calc.getNextCycle(dec);
      expect(jan.startDate, DateTime(2027, 1, 1));
      expect(jan.endDate, DateTime(2027, 1, 31));

      final prev = calc.getPreviousCycle(jan);
      expect(prev, dec);
    });
  });

  group('BudgetCycleCalculator — Custom Day (startDay = 15)', () {
    const calc = BudgetCycleCalculator(startDay: 15);

    test('14 October belongs to 15 Sep - 14 Oct cycle', () {
      final cycle = calc.getCycleForDate(DateTime(2026, 10, 14));
      expect(cycle.startDate, DateTime(2026, 9, 15));
      expect(cycle.endDate, DateTime(2026, 10, 14));
    });

    test('15 October belongs to 15 Oct - 14 Nov cycle', () {
      final cycle = calc.getCycleForDate(DateTime(2026, 10, 15));
      expect(cycle.startDate, DateTime(2026, 10, 15));
      expect(cycle.endDate, DateTime(2026, 11, 14));
    });

    test('Next and previous cycle navigation for day 15', () {
      final oct = calc.getCycleForDate(DateTime(2026, 10, 15));
      final nov = calc.getNextCycle(oct);
      expect(nov.startDate, DateTime(2026, 11, 15));
      expect(nov.endDate, DateTime(2026, 12, 14));

      final backToOct = calc.getPreviousCycle(nov);
      expect(backToOct, oct);
    });
  });

  group('BudgetCycleCalculator — Month-End Clamping (startDay = 31)', () {
    const calc31 = BudgetCycleCalculator(startDay: 31);

    test('31 October belongs to 31 Oct - 29 Nov cycle (Nov has 30 days)', () {
      final cycle = calc31.getCycleForDate(DateTime(2026, 10, 31));
      expect(cycle.startDate, DateTime(2026, 10, 31));
      // Nov has 30 days, so next cycle starts Nov 30; current ends Nov 29
      expect(cycle.endDate, DateTime(2026, 11, 29));
    });

    test('15 February in non-leap year 2023 belongs to 31 Jan - 27 Feb cycle', () {
      // Feb 2023 has 28 days. Feb cycle starts Feb 28; Jan cycle ends Feb 27
      final cycle = calc31.getCycleForDate(DateTime(2023, 2, 15));
      expect(cycle.startDate, DateTime(2023, 1, 31));
      expect(cycle.endDate, DateTime(2023, 2, 27));
    });

    test('February leap year 2024 clamps to 29th', () {
      final cycle = calc31.getCycleForDate(DateTime(2024, 2, 29));
      expect(cycle.startDate, DateTime(2024, 2, 29));
      // Next cycle starts March 31; current ends March 30
      expect(cycle.endDate, DateTime(2024, 3, 30));
    });

    test('Consecutive progression between 31st and 30-day/28-day months', () {
      final janCycle = calc31.getCycleForDate(DateTime(2023, 1, 31));
      final febCycle = calc31.getNextCycle(janCycle);
      expect(febCycle.startDate, DateTime(2023, 2, 28));
      expect(febCycle.endDate, DateTime(2023, 3, 30));

      final backToJan = calc31.getPreviousCycle(febCycle);
      expect(backToJan.startDate, janCycle.startDate);
      expect(backToJan.endDate, janCycle.endDate);
    });
  });

  group('BudgetCycleCalculator — Bounds Validation', () {
    test('Throws assertion error for days outside 1..31', () {
      expect(() => BudgetCycleCalculator(startDay: 0), throwsAssertionError);
      expect(() => BudgetCycleCalculator(startDay: 32), throwsAssertionError);
    });

    test('Allows boundary days 1, 28, and 31', () {
      expect(const BudgetCycleCalculator(startDay: 1).startDay, 1);
      expect(const BudgetCycleCalculator(startDay: 28).startDay, 28);
      expect(const BudgetCycleCalculator(startDay: 31).startDay, 31);
    });

    test('BudgetCycle allows single-day cycles and rejects inverted ranges', () {
      final singleDay = BudgetCycle(
        id: '1-day',
        startDate: DateTime(2026, 10, 25),
        endDate: DateTime(2026, 10, 25),
      );
      expect(singleDay.startDate, singleDay.endDate);

      expect(
        () => BudgetCycle(
          id: 'invalid',
          startDate: DateTime(2026, 10, 26),
          endDate: DateTime(2026, 10, 25),
        ),
        throwsAssertionError,
      );
    });
  });
}
