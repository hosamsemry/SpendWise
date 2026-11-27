import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/dashboard/presentation/widgets/balance_hero_card.dart';

void main() {
  final cycle = BudgetCycle(
    id: 'test-cycle',
    startDate: DateTime(2026, 11, 1),
    endDate: DateTime(2026, 11, 30),
  );

  final summary = CycleSummary(
    cycle: cycle,
    totalIncome: const Money.fromMinorUnits(2500000), // 25,000 EGP
    totalBudgeted: const Money.fromMinorUnits(1000000), // 10,000 EGP
    totalSpent: const Money.fromMinorUnits(400000), // 4,000 EGP
    positiveUnusedTotal: const Money.fromMinorUnits(600000),
    netRemainingTotal: const Money.fromMinorUnits(600000), // 6,000 EGP remaining
    overspentCategoriesCount: 0,
    categoryBudgets: [
      const CategoryBudget(
        categoryId: 'cat-1',
        categoryName: 'Groceries',
        budgetedAmount: Money.fromMinorUnits(1000000),
        spentAmount: Money.fromMinorUnits(400000),
      ),
    ],
  );

  const daily = DailySpendingSummary(
    totalSpentToday: Money.fromMinorUnits(15000), // 150 EGP
    transactionCountToday: 2,
    dailyPace: Money.fromMinorUnits(30000), // 300 EGP
    remainingToday: Money.fromMinorUnits(15000), // 150 EGP
    daysRemainingInCycle: 15,
    isOverDailyPace: false,
    overDailyPaceAmount: Money.zero(),
  );

  Widget buildThemedCard(ThemeData theme) {
    return MaterialApp(
      theme: theme,
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(
          child: BalanceHeroCard(
            cycle: cycle,
            summary: summary,
            daily: daily,
          ),
        ),
      ),
    );
  }

  for (final (mode, theme, primary, secondary, accent) in [
    (
      'Light',
      AppTheme.lightTheme,
      AppColors.textPrimary,
      AppColors.textSecondary,
      AppColors.primary,
    ),
    (
      'Dark',
      AppTheme.darkTheme,
      AppColorsDark.textPrimary,
      AppColorsDark.textSecondary,
      AppColorsDark.primary,
    ),
  ]) {
    testWidgets('$mode mode uses theme ink for amounts and the accent for the cycle', (tester) async {
      await tester.pumpWidget(buildThemedCard(theme));
      await tester.pumpAndSettle();

      expect(find.byType(BalanceHeroCard), findsOneWidget);

      final remaining = tester.widget<Text>(find.text('+6,000.00 EGP'));
      expect(remaining.style?.color, primary);

      final header = tester.widget<Text>(find.text('REMAINING BUDGET'));
      expect(header.style?.color, secondary);

      // Days remaining in the ring uses the accent so it stands apart from
      // the currency figures.
      final days = tester.widget<Text>(find.text('15'));
      expect(days.style?.color, accent);
      expect(days.style?.color, isNot(remaining.style?.color));
    });
  }
}
