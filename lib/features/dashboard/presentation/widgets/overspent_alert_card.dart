import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';

/// Interactive alert card for categories that have exceeded 100% of their budget.
/// Tapping opens a breakdown sheet with quick actions to view transactions or edit budgets.
class OverspentAlertCard extends StatelessWidget {
  final BudgetCycle cycle;
  final List<CategoryBudget> overspentBudgets;
  final ValueChanged<CategoryBudget> onViewTransactions;
  final VoidCallback onEditBudgets;

  const OverspentAlertCard({
    super.key,
    required this.cycle,
    required this.overspentBudgets,
    required this.onViewTransactions,
    required this.onEditBudgets,
  });

  String _buildCategorySummaryLine(BuildContext context) {
    final names = overspentBudgets
        .map((b) => context.l10n.localizedCategoryName(b.categoryName))
        .toList();

    if (names.length <= 2) {
      return names.join(' • ');
    }
    final remaining = names.length - 2;
    return '${names[0]} • ${names[1]} ${context.l10n.andMoreCount(remaining)}';
  }

  void _showBreakdownSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: context.isDark
                    ? context.overspentColor.withValues(alpha: 0.45)
                    : context.borderColor,
                width: 1.5,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(sheetCtx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.textTertiary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? context.crimsonLightColor.withValues(alpha: 0.7)
                          : context.overspentLightColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: context.overspentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.overspentCategoriesLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cycle.formattedRange,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category Breakdown List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: overspentBudgets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final b = overspentBudgets[index];
                    final name = context.l10n.localizedCategoryName(
                      b.categoryName,
                    );
                    final overBy = (-b.remainingAmount).toFormattedString(
                      includeCurrency: false,
                    );

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.overspentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: context.overspentColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  context.l10n.overAmount(overBy),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.overspentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${context.l10n.spent}: ${b.spentAmount.toFormattedString(includeCurrency: false)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${context.l10n.budget}: ${b.budgetedAmount.toFormattedString(includeCurrency: false)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    onViewTransactions(b);
                                  },
                                  icon: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    context.l10n.viewTransactions,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    foregroundColor: context.textPrimary,
                                    side: BorderSide(color: context.borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    onEditBudgets();
                                  },
                                  icon: const Icon(
                                    Icons.tune_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    context.l10n.editBudget,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    foregroundColor: context.primaryColor,
                                    side: BorderSide(
                                      color: context.primaryColor.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (overspentBudgets.isEmpty) return const SizedBox.shrink();

    final isDark = context.isDark;
    final categoryLine = _buildCategorySummaryLine(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('overspent_alert_card'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showBreakdownSheet(context),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? context.crimsonLightColor.withValues(alpha: 0.6)
                  : context.overspentLightColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? context.crimsonColor : Colors.red.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: context.overspentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.overspentAlert(overspentBudgets.length),
                        style: TextStyle(
                          color: context.overspentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        categoryLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.overspentColor.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.overspentColor.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
