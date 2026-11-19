import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';

class NearLimitAlertCard extends StatelessWidget {
  final BudgetCycle cycle;
  final List<CategoryBudget> nearLimitBudgets;
  final ValueChanged<List<String>> onDismiss;
  final ValueChanged<CategoryBudget> onViewTransactions;
  final VoidCallback onEditBudgets;

  const NearLimitAlertCard({
    super.key,
    required this.cycle,
    required this.nearLimitBudgets,
    required this.onDismiss,
    required this.onViewTransactions,
    required this.onEditBudgets,
  });

  String _buildCategorySummaryLine(BuildContext context) {
    final formatted = nearLimitBudgets.map((b) {
      final name = context.l10n.localizedCategoryName(b.categoryName);
      final pct = b.usagePercentage;
      if (pct != null) {
        return '$name (${pct.toStringAsFixed(0)}%)';
      }
      return name;
    }).toList();

    if (formatted.length <= 2) {
      return formatted.join(' • ');
    }
    final remaining = formatted.length - 2;
    return '${formatted[0]} • ${formatted[1]} ${context.l10n.andMoreCount(remaining)}';
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
                    ? context.warningColor.withValues(alpha: 0.4)
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
                          ? context.warningLightColor.withValues(alpha: 0.7)
                          : Colors.amber.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: context.warningColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.nearLimitSheetTitle,
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
                  itemCount: nearLimitBudgets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final b = nearLimitBudgets[index];
                    final pct = (b.usagePercentage ?? 0.0).clamp(0.0, 100.0);
                    final name = context.l10n.localizedCategoryName(
                      b.categoryName,
                    );

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.warningColor.withValues(alpha: 0.3),
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
                                  color: context.warningColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: context.warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (pct / 100.0).clamp(0.0, 1.0),
                              backgroundColor: context.isDark
                                  ? context.surfaceColor
                                  : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.warningColor,
                              ),
                              minHeight: 7,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${context.l10n.spent}: ${b.spentAmount.toFormattedString()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${context.l10n.budget}: ${b.budgetedAmount.toFormattedString()}',
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
                                      horizontal: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    onViewTransactions(b);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    context.l10n.editBudget,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(sheetCtx);
                                    onEditBudgets();
                                  },
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
              const SizedBox(height: 12),

              // Dismiss Alert Button
              TextButton.icon(
                icon: const Icon(Icons.close_rounded, size: 18),
                label: Text(context.l10n.dismissAlert),
                style: TextButton.styleFrom(
                  foregroundColor: context.textSecondary,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(sheetCtx);
                  onDismiss(
                    nearLimitBudgets.map((b) => b.categoryId).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context, {
    required AlignmentGeometry alignment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: alignment,
      decoration: BoxDecoration(
        color: context.warningColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.close_rounded,
            color: context.warningColor,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.dismiss,
            style: TextStyle(
              color: context.warningColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (nearLimitBudgets.isEmpty) return const SizedBox.shrink();

    final idsKey = nearLimitBudgets.map((b) => b.categoryId).join('_');

    return Dismissible(
      key: ValueKey('near_limit_alert_${cycle.id}_$idsKey'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        context,
        alignment: AlignmentDirectional.centerStart,
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        alignment: AlignmentDirectional.centerEnd,
      ),
      onDismissed: (_) {
        HapticFeedback.lightImpact();
        onDismiss(nearLimitBudgets.map((b) => b.categoryId).toList());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.isDark
              ? context.warningLightColor.withValues(alpha: 0.6)
              : Colors.amber.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.isDark
                ? context.warningColor.withValues(alpha: 0.5)
                : Colors.amber.shade200,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showBreakdownSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.warningColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.nearLimitAlert(nearLimitBudgets.length),
                          style: TextStyle(
                            color: context.warningColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _buildCategorySummaryLine(context),
                          style: TextStyle(
                            color: context.isDark
                                ? context.textPrimary.withValues(alpha: 0.85)
                                : const Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.warningColor.withValues(alpha: 0.85),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
