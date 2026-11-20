import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/budgets/domain/cycle_summary.dart';
import 'package:money_tracker/features/reports/presentation/widgets/cash_flow_bar_chart.dart';
import 'package:money_tracker/features/reports/presentation/widgets/category_donut_chart.dart';
import 'package:money_tracker/features/transactions/presentation/add_edit_transaction_dialog.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ReportsScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  // 0 = All Sections (Fluid Page), 1 = Cash Flow, 2 = Categories, 3 = MoM Comparison, 4 = Budget vs Actual
  int _selectedFilterIndex = 0;
  String? _selectedDonutCategoryId;

  @override
  Widget build(BuildContext context) {
    ref.watch(primaryCurrencyProvider);
    final currentCycleAsync = ref.watch(currentCycleProvider);
    final selectedCycle = ref.watch(selectedCycleProvider);
    final allCyclesAsync = ref.watch(allCyclesProvider);

    final activeCycle = selectedCycle ?? currentCycleAsync.value;

    final content = Column(
      children: [
        // 1. Cycle Selector
        allCyclesAsync.when(
          skipLoadingOnReload: true,
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
          data: (cycles) {
            if (cycles.isEmpty) return const SizedBox.shrink();
            final current = (activeCycle != null &&
                    cycles.any((c) => c.id == activeCycle.id))
                ? activeCycle
                : cycles.first;

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              color: context.surfaceColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.reportCycleLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  DropdownButton<String>(
                    value: current.id,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: cycles.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.formattedRange,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final found = cycles.firstWhere((c) => c.id == id);
                      setState(() => _selectedDonutCategoryId = null);
                      ref
                          .read(selectedCycleProvider.notifier)
                          .select(found);
                    },
                  ),
                ],
              ),
            );
          },
        ),
        const Divider(height: 1),

        // 2. Filter Pills for quick focus / section jump
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, context.l10n.allSections, Icons.dashboard_outlined),
                const SizedBox(width: 8),
                _buildFilterChip(1, context.l10n.cashFlowTrendSection, Icons.show_chart),
                const SizedBox(width: 8),
                _buildFilterChip(2, context.l10n.categoryDistributionSection, Icons.pie_chart_outline),
                const SizedBox(width: 8),
                _buildFilterChip(3, context.l10n.cycleOverCycleSection, Icons.compare_arrows_rounded),
                const SizedBox(width: 8),
                _buildFilterChip(4, context.l10n.budgetVsActualSection, Icons.bar_chart_outlined),
              ],
            ),
          ),
        ),

        // 3. Fluid Page or Filtered Section View
        Expanded(
          child: activeCycle == null
              ? const Center(child: CircularProgressIndicator())
              : Consumer(
                  builder: (context, ref, _) {
                    final summaryAsync = ref.watch(
                      cycleSummaryProvider(activeCycle),
                    );

                    return summaryAsync.when(
                      skipLoadingOnReload: true,
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, stack) => Center(
                        child: Text('${context.l10n.error}: $err'),
                      ),
                      data: (summary) {
                        return allCyclesAsync.when(
                          skipLoadingOnReload: true,
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (e, _) => Center(
                            child: Text('${context.l10n.error}: $e'),
                          ),
                          data: (cycles) {
                            return _buildFluidInsightsPage(
                              activeCycle: activeCycle,
                              summary: summary,
                              cycles: cycles,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navInsights),
      ),
      body: content,
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilterIndex == index;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? (context.isDark ? Colors.white : AppColors.primary)
            : context.textSecondary,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (context.isDark ? Colors.white : AppColors.primary)
            : context.textPrimary,
      ),
      backgroundColor: context.surfaceColor,
      selectedColor: context.isDark
          ? AppColorsDark.gold.withValues(alpha: 0.18)
          : AppColors.primaryLight,
      side: BorderSide(
        color: isSelected
            ? (context.isDark ? AppColorsDark.gold : AppColors.primary)
            : context.borderColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) {
        setState(() => _selectedFilterIndex = index);
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluidInsightsPage({
    required BudgetCycle activeCycle,
    required CycleSummary summary,
    required List<BudgetCycle> cycles,
  }) {
    final showAll = _selectedFilterIndex == 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        // Section 1: Multi-Cycle Cash Flow Trend
        if (showAll || _selectedFilterIndex == 1) ...[
          _buildSectionHeader(
            context.l10n.cashFlowTrendSection,
            Icons.show_chart,
          ),
          _CashFlowTrendSection(cycles: cycles),
          const SizedBox(height: 16),
        ],

        // Section 2: Category Expense Distribution
        if (showAll || _selectedFilterIndex == 2) ...[
          _buildSectionHeader(
            context.l10n.categoryDistributionSection,
            Icons.pie_chart_outline_rounded,
          ),
          _buildSpendingByCategorySection(activeCycle, summary),
          const SizedBox(height: 16),
        ],

        // Section 3: Month-over-Month (Cycle-over-Cycle) Comparison
        if (showAll || _selectedFilterIndex == 3) ...[
          _buildSectionHeader(
            context.l10n.cycleOverCycleSection,
            Icons.compare_arrows_rounded,
          ),
          _buildCycleOverCycleSection(activeCycle, summary),
          const SizedBox(height: 16),
        ],

        // Section 4: Budget vs Actual Variance
        if (showAll || _selectedFilterIndex == 4) ...[
          _buildSectionHeader(
            context.l10n.budgetVsActualSection,
            Icons.bar_chart_rounded,
          ),
          _buildBudgetVsActualSection(summary),
        ],
      ],
    );
  }

  Widget _buildSpendingByCategorySection(
    BudgetCycle activeCycle,
    CycleSummary summary,
  ) {
    final totalSpentMinor = summary.totalSpent.inMinorUnits;
    final isDark = context.isDark;

    final categoriesWithSpending = summary.categoryBudgets
        .where((b) => b.spentAmount.inMinorUnits > 0)
        .toList()
      ..sort((a, b) => b.spentAmount.compareTo(a.spentAmount));

    if (categoriesWithSpending.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: context.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.noExpensesRecordedInCycle,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final slices = <DonutSliceData>[];
    final colorByCategoryId = <String, Color>{};
    for (var i = 0; i < categoriesWithSpending.length; i++) {
      final b = categoriesWithSpending[i];
      final sharePct = totalSpentMinor > 0
          ? (b.spentAmount.inMinorUnits / totalSpentMinor) * 100.0
          : 0.0;
      final color = CategoryDonutChart.colorForIndex(i, isDark: isDark);
      colorByCategoryId[b.categoryId] = color;
      slices.add(
        DonutSliceData(
          categoryId: b.categoryId,
          label: context.l10n.localizedCategoryName(b.categoryName),
          amount: b.spentAmount,
          percentage: sharePct,
          color: color,
        ),
      );
    }

    final effectiveSelectedId = _selectedDonutCategoryId != null &&
            categoriesWithSpending
                .any((b) => b.categoryId == _selectedDonutCategoryId)
        ? _selectedDonutCategoryId
        : null;

    DonutSliceData? selectedSlice;
    if (effectiveSelectedId != null) {
      selectedSlice = slices.firstWhere(
        (s) => s.categoryId == effectiveSelectedId,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Interactive Animated Donut Chart
        CategoryDonutChart(
          slices: slices,
          totalSpent: summary.totalSpent,
          selectedCategoryId: effectiveSelectedId,
          onCategorySelected: (categoryId) {
            setState(() => _selectedDonutCategoryId = categoryId);
          },
        ),
        const SizedBox(height: 10),

        // 2. Interactive Category Breakdown Rows (tap any row to sync with Donut Chart)
        ...categoriesWithSpending.map((b) {
          final sharePct = totalSpentMinor > 0
              ? (b.spentAmount.inMinorUnits / totalSpentMinor) * 100.0
              : 0.0;
          final sliceColor =
              colorByCategoryId[b.categoryId] ?? context.primaryColor;
          final isSelected = effectiveSelectedId == b.categoryId;
          final isDimmed = effectiveSelectedId != null && !isSelected;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isDimmed ? 0.58 : 1.0,
            child: Card(
              key: ValueKey('category_breakdown_${b.categoryId}'),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected
                      ? sliceColor
                      : context.borderColor.withValues(alpha: 0.6),
                  width: isSelected ? 1.6 : 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDonutCategoryId = isSelected ? null : b.categoryId;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: sliceColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    context.l10n.localizedCategoryName(
                                      b.categoryName,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            b.spentAmount.toFormattedString(
                              includeCurrency: false,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (sharePct / 100.0).clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? context.surfaceVariantColor
                              : Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(sliceColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.pctOfTotalExpenses(
                          sharePct.toStringAsFixed(1),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? sliceColor
                              : context.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 8),

        // 3. Dynamically Filtered Transaction List below the Category Report
        _buildFilteredCategoryTransactions(
          activeCycle: activeCycle,
          selectedSlice: selectedSlice,
          colorByCategoryId: colorByCategoryId,
        ),
      ],
    );
  }

  Widget _buildFilteredCategoryTransactions({
    required BudgetCycle activeCycle,
    required DonutSliceData? selectedSlice,
    required Map<String, Color> colorByCategoryId,
  }) {
    final expensesAsync = ref.watch(
      cycleExpenseTransactionsProvider(activeCycle),
    );

    return expensesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (allExpenses) {
        final filtered = selectedSlice == null
            ? allExpenses
            : allExpenses
                .where((tx) => tx.categoryId == selectedSlice.categoryId)
                .toList();

        return Column(
          key: const ValueKey('category_filtered_transactions_section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (selectedSlice != null) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: selectedSlice.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          selectedSlice != null
                              ? context.l10n.categoryTransactionsTitle(
                                  selectedSlice.label,
                                )
                              : context.l10n.allCycleExpensesTitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (selectedSlice?.color ?? context.primaryColor)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${filtered.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: selectedSlice?.color ?? context.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedSlice != null)
                  TextButton.icon(
                    key: const ValueKey('clear_donut_filter_button'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDonutCategoryId = null);
                    },
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: Text(context.l10n.clearFilter),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.noTransactionsFound,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final dotColor =
                        colorByCategoryId[tx.categoryId] ?? context.expenseColor;
                    final catLabel =
                        (tx.categoryName != null && tx.categoryName!.isNotEmpty)
                            ? context.l10n.localizedCategoryName(tx.categoryName)
                            : context.l10n.expense;
                    final hasNote = tx.note != null && tx.note!.trim().isNotEmpty;

                    return ListTile(
                      key: ValueKey('donut_tx_${tx.id}'),
                      dense: true,
                      onTap: () => AddEditTransactionDialog.show(
                        context,
                        transaction: tx,
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: dotColor.withValues(alpha: 0.14),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: dotColor,
                        ),
                      ),
                      title: Text(
                        hasNote ? tx.note!.trim() : catLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: context.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        hasNote
                            ? '$catLabel • ${DateFormat('d MMM').format(tx.date)}'
                            : DateFormat('d MMM').format(tx.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                      trailing: Text(
                        '-${tx.amount.toFormattedString(includeCurrency: false)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: context.textPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBudgetVsActualSection(CycleSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Comparison Header Cards
        Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.totalBudgetedLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.totalBudgeted.toFormattedString(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.totalActualSpent,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.totalSpent.toFormattedString(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.expenseColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...summary.categoryBudgets.map((b) {
          final isOver = b.isOverspent;
          final pct = b.usagePercentage;
          final hasBudget = b.budgetedAmount.inMinorUnits > 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.localizedCategoryName(b.categoryName),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOver
                              ? context.overspentLightColor
                              : context.incomeLightColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOver
                              ? context.l10n.overAmount((-b.remainingAmount).toFormattedString())
                              : context.l10n.underAmount(b.remainingAmount.toFormattedString()),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOver
                                ? context.overspentColor
                                : context.incomeColor,
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
                        context.l10n.budgetPrefix(b.budgetedAmount.toFormattedString()),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                      Text(
                        context.l10n.actualPrefix(b.spentAmount.toFormattedString()),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: hasBudget
                          ? (pct! / 100.0).clamp(0.0, 1.0)
                          : (b.spentAmount.inMinorUnits > 0 ? 1.0 : 0.0),
                      backgroundColor: context.isDark
                          ? context.surfaceVariantColor
                          : Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOver ? context.overspentColor : context.primaryColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCycleOverCycleSection(
    BudgetCycle activeCycle,
    CycleSummary currentSummary,
  ) {
    final startDayAsync = ref.watch(budgetCycleStartDayProvider);
    final startDay = startDayAsync.value ?? 1;
    final calculator = BudgetCycleCalculator(startDay: startDay);
    final prevCycle = calculator.getPreviousCycle(activeCycle);
    final prevSummaryAsync = ref.watch(cycleSummaryProvider(prevCycle));

    return prevSummaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('${context.l10n.error}: $err'),
      data: (prevSummary) {
        final currentSpentMinor = currentSummary.totalSpent.inMinorUnits;
        final prevSpentMinor = prevSummary.totalSpent.inMinorUnits;
        final spentDeltaMinor = currentSpentMinor - prevSpentMinor;

        final double? spendPctChange = prevSpentMinor > 0
            ? ((currentSpentMinor - prevSpentMinor) / prevSpentMinor) * 100.0
            : null;

        final currentNetMinor = currentSummary.netRemainingTotal.inMinorUnits;

        // Group categories present in either cycle
        final categoryMap =
            <String, ({String name, Money currentSpent, Money prevSpent})>{};
        for (final b in currentSummary.categoryBudgets) {
          categoryMap[b.categoryId] = (
            name: b.categoryName,
            currentSpent: b.spentAmount,
            prevSpent: const Money.zero(),
          );
        }
        for (final b in prevSummary.categoryBudgets) {
          if (categoryMap.containsKey(b.categoryId)) {
            final existing = categoryMap[b.categoryId]!;
            categoryMap[b.categoryId] = (
              name: existing.name,
              currentSpent: existing.currentSpent,
              prevSpent: b.spentAmount,
            );
          } else {
            categoryMap[b.categoryId] = (
              name: b.categoryName,
              currentSpent: const Money.zero(),
              prevSpent: b.spentAmount,
            );
          }
        }

        final comparedCategories = categoryMap.values.where((item) {
          return item.currentSpent.inMinorUnits > 0 ||
              item.prevSpent.inMinorUnits > 0;
        }).toList()
          ..sort((a, b) {
            final deltaA =
                a.currentSpent.inMinorUnits - a.prevSpent.inMinorUnits;
            final deltaB =
                b.currentSpent.inMinorUnits - b.prevSpent.inMinorUnits;
            return deltaB.compareTo(deltaA); // highest spending increase first
          });

        final bool isFirstCycleBaseline = prevSpentMinor == 0 &&
            prevSummary.totalIncome.inMinorUnits == 0 &&
            prevSummary.totalBudgeted.inMinorUnits == 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isFirstCycleBaseline)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.noTransactionsPreviousCycle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Cycles compared banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.isDark
                    ? context.surfaceVariantColor
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.isDark
                      ? context.borderColor
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 20,
                    color: context.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.comparingCyclesText(activeCycle.shortLabel, prevCycle.shortLabel),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Hero spend variance card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: spentDeltaMinor > 0
                      ? context.overspentColor.withValues(alpha: 0.3)
                      : context.incomeColor.withValues(alpha: 0.3),
                ),
              ),
              color: spentDeltaMinor > 0
                  ? context.overspentColor.withValues(alpha: 0.08)
                  : context.incomeColor.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.totalSpendingVariance,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: context.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: spentDeltaMinor > 0
                                ? context.overspentColor.withValues(alpha: 0.15)
                                : context.incomeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            spentDeltaMinor == 0
                                ? context.l10n.identical
                                : spentDeltaMinor > 0
                                ? spendPctChange != null
                                    ? '+${spendPctChange.toStringAsFixed(1)}% ↗'
                                    : context.l10n.spendIncreased
                                : spendPctChange != null
                                ? '-${spendPctChange.abs().toStringAsFixed(1)}% ↘'
                                : context.l10n.spendDecreased,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: spentDeltaMinor > 0
                                  ? context.overspentColor
                                  : context.incomeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      spentDeltaMinor == 0
                          ? context.l10n.zeroDiffNotice
                          : spentDeltaMinor > 0
                          ? context.l10n.varianceVsLastCycle(Money.fromMinorUnits(spentDeltaMinor).toFormattedString(), true)
                          : context.l10n.varianceVsLastCycle(Money.fromMinorUnits(-spentDeltaMinor).toFormattedString(), false),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: spentDeltaMinor > 0
                            ? context.overspentColor
                            : context.incomeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spentDeltaMinor > 0
                          ? context.l10n.spendingIncreasedDesc
                          : (spentDeltaMinor < 0
                              ? context.l10n.spendingDecreasedDesc
                              : context.l10n.spendingMatchesDesc),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Side-by-side comparison tiles (Expenses, Income, Net Remaining)
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.expensesLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSummary.totalSpent.toFormattedString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.prevPrefix(prevSummary.totalSpent.toFormattedString()),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.incomeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSummary.totalIncome.toFormattedString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.incomeColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.prevPrefix(prevSummary.totalIncome.toFormattedString()),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.netSavingsLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentSummary.netRemainingTotal.toFormattedString(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: currentNetMinor >= 0
                                  ? context.incomeColor
                                  : context.overspentColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.prevPrefix(prevSummary.netRemainingTotal.toFormattedString()),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...comparedCategories.map((cat) {
              final diffMinor =
                  cat.currentSpent.inMinorUnits - cat.prevSpent.inMinorUnits;
              final prevMinor = cat.prevSpent.inMinorUnits;
              final double? catPctChange = prevMinor > 0
                  ? (diffMinor / prevMinor) * 100.0
                  : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.localizedCategoryName(cat.name),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: context.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: prevMinor == 0
                                  ? Colors.blue.withValues(alpha: 0.12)
                                  : (diffMinor > 0
                                      ? context.overspentColor.withValues(
                                          alpha: 0.12,
                                        )
                                      : (diffMinor < 0
                                          ? context.incomeColor.withValues(
                                              alpha: 0.12,
                                            )
                                          : Colors.grey.withValues(
                                              alpha: 0.12,
                                            ))),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              prevMinor == 0
                                  ? context.l10n.newBadge
                                  : (diffMinor > 0
                                      ? '+${(diffMinor / 100).toStringAsFixed(0)} ${context.l10n.currencySymbol} (${catPctChange != null ? "+${catPctChange.toStringAsFixed(0)}%" : ""} ↗)'
                                      : (diffMinor < 0
                                          ? '-${(-diffMinor / 100).toStringAsFixed(0)} ${context.l10n.currencySymbol} (${catPctChange != null ? "-${catPctChange.abs().toStringAsFixed(0)}%" : ""} ↘)'
                                          : context.l10n.sameBadge)),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: prevMinor == 0
                                    ? Colors.blue.shade700
                                    : (diffMinor > 0
                                        ? context.overspentColor
                                        : (diffMinor < 0
                                            ? context.incomeColor
                                            : context.textSecondary)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.currentPrefix(cat.currentSpent.toFormattedString()),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            context.l10n.previousPrefix(cat.prevSpent.toFormattedString()),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _CashFlowTrendSection extends ConsumerWidget {
  final List<BudgetCycle> cycles;

  const _CashFlowTrendSection({required this.cycles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cycles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(context.l10n.noCyclesRecordedYet)),
        ),
      );
    }

    final recentCycles = cycles.take(6).toList();
    final summaries = <CycleSummary>[];
    bool isLoading = false;

    for (final cycle in recentCycles) {
      final asyncSummary = ref.watch(cycleSummaryProvider(cycle));
      if (asyncSummary.isLoading) {
        isLoading = true;
      } else if (asyncSummary.hasValue && asyncSummary.value != null) {
        summaries.add(asyncSummary.value!);
      }
    }

    if (isLoading && summaries.length < recentCycles.length) {
      return const Center(child: CircularProgressIndicator());
    }

    return CashFlowBarChart(cycleSummaries: summaries);
  }
}
