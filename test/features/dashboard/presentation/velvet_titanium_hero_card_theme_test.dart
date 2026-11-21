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
import 'package:money_tracker/features/dashboard/presentation/widgets/velvet_titanium_hero_card.dart';

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
          child: VelvetTitaniumHeroCard(
            cycle: cycle,
            summary: summary,
            daily: daily,
          ),
        ),
      ),
    );
  }

  testWidgets('Light mode uses paper surfaces and ink typography', (tester) async {
    await tester.pumpWidget(buildThemedCard(AppTheme.lightTheme));
    await tester.pumpAndSettle();

    // Verify card exists
    expect(find.byType(VelvetTitaniumHeroCard), findsOneWidget);

    // Remaining budget text should be rendered with deep obsidian in Light Mode (not white)
    final remainingTextFinder = find.text('+6,000.00 EGP');
    expect(remainingTextFinder, findsOneWidget);
    final remainingTextWidget = tester.widget<Text>(remainingTextFinder);
    expect(remainingTextWidget.style?.color, AppColors.textPrimary); // Ink

    // Header accent label should be rendered with AA-compliant burnished bronze
    final headerLabelFinder = find.text('REMAINING BUDGET');
    expect(headerLabelFinder, findsOneWidget);
    final headerLabelWidget = tester.widget<Text>(headerLabelFinder);
    expect(headerLabelWidget.style?.color, AppColors.textSecondary);

    // Days remaining text in the pace ring gauge uses brand gold to stand apart from black currency figures
    final daysRemainingFinder = find.text('15');
    expect(daysRemainingFinder, findsOneWidget);
    final daysRemainingWidget = tester.widget<Text>(daysRemainingFinder);
    expect(daysRemainingWidget.style?.color, AppColors.gold);
    expect(daysRemainingWidget.style?.color, isNot(remainingTextWidget.style?.color));
  });

  testWidgets('Dark mode maintains Velvet Titanium obsidian surface and luminous text', (tester) async {
    await tester.pumpWidget(buildThemedCard(AppTheme.darkTheme));
    await tester.pumpAndSettle();

    expect(find.byType(VelvetTitaniumHeroCard), findsOneWidget);

    // Remaining budget text should be crisp porcelain white in Dark Mode
    final remainingTextFinder = find.text('+6,000.00 EGP');
    expect(remainingTextFinder, findsOneWidget);
    final remainingTextWidget = tester.widget<Text>(remainingTextFinder);
    expect(remainingTextWidget.style?.color, const Color(0xFFF8FAFC));

    // Header accent label should be Champagne Gold
    final headerLabelFinder = find.text('REMAINING BUDGET');
    expect(headerLabelFinder, findsOneWidget);
    final headerLabelWidget = tester.widget<Text>(headerLabelFinder);
    expect(headerLabelWidget.style?.color, const Color(0xFFE5C158));

    // Days remaining text should be luminous porcelain white
    final daysRemainingFinder = find.text('15');
    expect(daysRemainingFinder, findsOneWidget);
    final daysRemainingWidget = tester.widget<Text>(daysRemainingFinder);
    expect(daysRemainingWidget.style?.color, const Color(0xFFF8FAFC));
  });
}
