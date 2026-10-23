import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/money/money.dart';

void main() {
  group('Cycle-over-Cycle Comparative Insights Calculation Tests', () {
    test('Calculates overall spending delta and percentage correctly when previous spending > 0', () {
      final currentSpent = Money.fromMajorUnits(4500);
      final prevSpent = Money.fromMajorUnits(4000);

      final diffMinor = currentSpent.inMinorUnits - prevSpent.inMinorUnits;
      final pctChange = ((currentSpent.inMinorUnits - prevSpent.inMinorUnits) / prevSpent.inMinorUnits) * 100.0;

      expect(diffMinor, 50000); // +500 EGP
      expect(pctChange, 12.5); // +12.5% increase
    });

    test('Calculates spending decrease and percentage correctly', () {
      final currentSpent = Money.fromMajorUnits(3200);
      final prevSpent = Money.fromMajorUnits(4000);

      final diffMinor = currentSpent.inMinorUnits - prevSpent.inMinorUnits;
      final pctChange = ((currentSpent.inMinorUnits - prevSpent.inMinorUnits) / prevSpent.inMinorUnits) * 100.0;

      expect(diffMinor, -80000); // -800 EGP
      expect(pctChange, -20.0); // -20% decrease (savings)
    });

    test('Handles zero previous spending safely without division by zero', () {
      final currentSpent = Money.fromMajorUnits(1500);
      final prevSpent = Money.zero();

      final diffMinor = currentSpent.inMinorUnits - prevSpent.inMinorUnits;
      final double? pctChange = prevSpent.inMinorUnits > 0
          ? ((currentSpent.inMinorUnits - prevSpent.inMinorUnits) / prevSpent.inMinorUnits) * 100.0
          : null;

      expect(diffMinor, 150000);
      expect(pctChange, isNull);
    });

    test('Merges categories and sorts by highest spending increase', () {
      final currentCategories = [
        (name: 'Food', spent: Money.fromMajorUnits(1200)),
        (name: 'Utilities', spent: Money.fromMajorUnits(400)),
        (name: 'Gym', spent: Money.fromMajorUnits(300)),
      ];

      final prevCategories = [
        (name: 'Food', spent: Money.fromMajorUnits(800)),      // +400
        (name: 'Utilities', spent: Money.fromMajorUnits(500)), // -100
        (name: 'Coffee', spent: Money.fromMajorUnits(200)),    // in prev only
      ];

      final map = <String, ({String name, Money current, Money prev})>{};
      for (final c in currentCategories) {
        map[c.name] = (name: c.name, current: c.spent, prev: const Money.zero());
      }
      for (final p in prevCategories) {
        if (map.containsKey(p.name)) {
          final existing = map[p.name]!;
          map[p.name] = (name: p.name, current: existing.current, prev: p.spent);
        } else {
          map[p.name] = (name: p.name, current: const Money.zero(), prev: p.spent);
        }
      }

      final list = map.values.toList()
        ..sort((a, b) {
          final deltaA = a.current.inMinorUnits - a.prev.inMinorUnits;
          final deltaB = b.current.inMinorUnits - b.prev.inMinorUnits;
          return deltaB.compareTo(deltaA); // highest variance first
        });

      // 1st: Food (+400)
      expect(list[0].name, 'Food');
      expect(list[0].current.inMinorUnits - list[0].prev.inMinorUnits, 40000);

      // 2nd: Gym (+300, new in current)
      expect(list[1].name, 'Gym');
      expect(list[1].current.inMinorUnits - list[1].prev.inMinorUnits, 30000);

      // 3rd: Utilities (-100)
      expect(list[2].name, 'Utilities');
      expect(list[2].current.inMinorUnits - list[2].prev.inMinorUnits, -10000);

      // 4th: Coffee (-200, only in prev)
      expect(list[3].name, 'Coffee');
      expect(list[3].current.inMinorUnits - list[3].prev.inMinorUnits, -20000);
    });
  });
}
