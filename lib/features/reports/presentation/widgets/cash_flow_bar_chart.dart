import 'package:money_tracker/core/localization/app_localizations.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';

class CashFlowBarChart extends StatefulWidget {
  final List<CycleSummary> cycleSummaries;

  const CashFlowBarChart({super.key, required this.cycleSummaries});

  @override
  State<CashFlowBarChart> createState() => _CashFlowBarChartState();
}

class _CashFlowBarChartState extends State<CashFlowBarChart> {
  int? _selectedCycleIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final incomeColor = isDark ? AppColorsDark.income : AppColors.income;
    final expenseColor = isDark ? AppColorsDark.overspent : AppColors.overspent;
    final textSecondary = isDark
        ? AppColorsDark.textSecondary
        : AppColors.textSecondary;

    if (widget.cycleSummaries.isEmpty) {
      return Center(child: Text(context.l10n.noDataAvailable));
    }

    // Chronological order (oldest to newest for the chart)
    final summaries = widget.cycleSummaries.reversed.toList();

    // Calculate maximum value for chart scaling
    int maxMinor = 0;
    for (final s in summaries) {
      maxMinor = max(maxMinor, s.totalIncome.inMinorUnits);
      maxMinor = max(maxMinor, s.totalSpent.inMinorUnits);
    }
    if (maxMinor == 0) maxMinor = 100000; // Default 1,000 EGP scale fallback

    final selected =
        _selectedCycleIndex != null && _selectedCycleIndex! < summaries.length
        ? summaries[_selectedCycleIndex!]
        : summaries.last;

    final netMinor =
        selected.totalIncome.inMinorUnits - selected.totalSpent.inMinorUnits;
    final isPositive = netMinor >= 0;
    final savingsPct = selected.totalIncome.inMinorUnits > 0
        ? ((netMinor / selected.totalIncome.inMinorUnits) * 100).clamp(
            -999,
            100,
          )
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Interactive Selected Cycle Header Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selected.cycle.formattedRange,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? incomeColor.withValues(alpha: 0.15)
                            : expenseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.savingsPercent(savingsPct.toStringAsFixed(1), isPositive),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPositive ? incomeColor : expenseColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.incomeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selected.totalIncome.toFormattedString(currencySymbol: context.l10n.currencySymbol),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: incomeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.expensesLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selected.totalSpent.toFormattedString(currencySymbol: context.l10n.currencySymbol),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.netCashFlow,
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Money.fromMinorUnits(netMinor).toFormattedString(currencySymbol: context.l10n.currencySymbol),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isPositive ? incomeColor : expenseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. Chart Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem(incomeColor, context.l10n.incomeLabel),
            const SizedBox(width: 20),
            _buildLegendItem(expenseColor, context.l10n.expensesLabel),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Side-by-Side Bar Chart View
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(summaries.length, (index) {
              final s = summaries[index];
              final isSelected =
                  (_selectedCycleIndex ?? (summaries.length - 1)) == index;

              final incomeHeight =
                  (s.totalIncome.inMinorUnits / maxMinor).clamp(0.04, 1.0) *
                  130;
              final expenseHeight =
                  (s.totalSpent.inMinorUnits / maxMinor).clamp(0.04, 1.0) * 130;

              final label = DateFormat('MMM yy').format(s.cycle.startDate);

              return GestureDetector(
                onTap: () => setState(() => _selectedCycleIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected
                        ? (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04))
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Income Bar
                          Container(
                            width: 14,
                            height: incomeHeight,
                            decoration: BoxDecoration(
                              color: incomeColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          // Expense Bar
                          Container(
                            width: 14,
                            height: expenseHeight,
                            decoration: BoxDecoration(
                              color: expenseColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? (isDark
                                    ? AppColorsDark.textPrimary
                                    : AppColors.textPrimary)
                              : textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
