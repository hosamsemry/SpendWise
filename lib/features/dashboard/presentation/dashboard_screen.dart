import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/preset_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/budgets/presentation/cycle_summary_screen.dart';
import 'package:money_tracker/features/presets/domain/transaction_preset.dart';
import 'package:money_tracker/features/presets/presentation/presets_management_screen.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/savings/presentation/cycle_closeout_card.dart';
import 'package:money_tracker/features/savings/presentation/savings_vault_card.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/features/transactions/presentation/add_edit_transaction_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  final VoidCallback onNavigateToTransactions;
  final VoidCallback onNavigateToBudgets;

  const DashboardScreen({
    super.key,
    required this.onNavigateToTransactions,
    required this.onNavigateToBudgets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCycleAsync = ref.watch(currentCycleProvider);
    final recentTxsAsync = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appName),
        actions: [
          currentCycleAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
            data: (cycle) => TextButton.icon(
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: Text(context.l10n.summary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => CycleSummaryScreen(cycle: cycle),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: currentCycleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('${context.l10n.error}: $err')),
        data: (cycle) {
          final summaryAsync = ref.watch(cycleSummaryProvider(cycle));

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(refreshTriggerProvider.notifier).trigger();
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // 1. Financial Pulse Hero Card & Summary Metrics
                summaryAsync.when(
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (err, _) => Text('${context.l10n.error}: $err'),
                  data: (summary) {
                    final isNetPositive =
                        summary.netRemainingTotal.inMinorUnits >= 0;
                    final overspentCount = summary.overspentCategoriesCount;
                    final nearLimitCount = summary.categoryBudgets
                        .where((b) => b.isNearLimit)
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Consumer(
                          builder: (context, ref, _) {
                            final closeoutAsync =
                                ref.watch(pendingCycleCloseoutProvider);
                            return closeoutAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (e, s) => const SizedBox.shrink(),
                              data: (closeout) => closeout != null
                                  ? CycleCloseoutCard(closeout: closeout)
                                  : const SizedBox.shrink(),
                            );
                          },
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final dailyAsync = ref.watch(todaySpendingSummaryProvider);
                            return dailyAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (err, stack) => const SizedBox.shrink(),
                              data: (daily) {
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: context.isDark
                                          ? const Color(0xFF334155)
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Current Budget Cycle Range & Status Badge
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  context.l10n.currentBudgetCycle,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                    color: context.primaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  cycle.formattedRange,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: context.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (daily.dailyPace != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: !isNetPositive
                                                      ? context.overspentColor.withValues(alpha: 0.12)
                                                      : daily.isOverDailyPace
                                                          ? Colors.amber.withValues(alpha: 0.15)
                                                          : context.incomeColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  !isNetPositive
                                                      ? context.l10n.overBudget
                                                      : daily.isOverDailyPace
                                                          ? context.l10n.overDailyPaceBadge(daily.overDailyPaceAmount.toFormattedString())
                                                          : context.l10n.safeDailyPaceBadge(daily.dailyPace!.toFormattedString()),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: !isNetPositive
                                                        ? context.overspentColor
                                                        : daily.isOverDailyPace
                                                            ? Colors.amber.shade800
                                                            : context.incomeColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),

                                        // Remaining Budget Hero Metric
                                        Text(
                                          context.l10n.remainingBudget,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.6,
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              summary.netRemainingTotal.toFormattedString(showSign: true),
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: isNetPositive
                                                    ? context.textPrimary
                                                    : context.overspentColor,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              context.l10n.ofTotal(summary.totalBudgeted.toFormattedString()),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: context.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Progress Bar
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: LinearProgressIndicator(
                                            value: summary.totalBudgeted.inMinorUnits > 0
                                                ? (summary.totalSpent.inMinorUnits / summary.totalBudgeted.inMinorUnits).clamp(0.0, 1.0)
                                                : (summary.totalSpent.inMinorUnits > 0 ? 1.0 : 0.0),
                                            minHeight: 8,
                                            backgroundColor: context.isDark
                                                ? const Color(0xFF334155)
                                                : Colors.grey.shade100,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isNetPositive ? context.primaryColor : context.overspentColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(height: 1),
                                        const SizedBox(height: 12),

                                        // 3 Key Metrics: Today's Spent, Cycle Spent, Income
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    context.l10n.todaysSpending,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                      color: context.textSecondary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    daily.totalSpentToday.toFormattedString(),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: daily.isOverDailyPace
                                                          ? Colors.amber.shade800
                                                          : context.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 1),
                                                  Text(
                                                    daily.isOverDailyPace
                                                        ? context.l10n.overDailyPace
                                                        : (daily.dailyPace != null && daily.dailyPace!.inMinorUnits > 0
                                                            ? context.l10n.safeLeft(daily.remainingToday.toFormattedString())
                                                            : (daily.transactionCountToday == 0
                                                                ? context.l10n.expensesCount(0)
                                                                : context.l10n.expensesCount(daily.transactionCountToday))),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: daily.isOverDailyPace ? FontWeight.w600 : FontWeight.normal,
                                                      color: daily.isOverDailyPace
                                                          ? Colors.amber.shade800
                                                          : context.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 36,
                                              color: context.isDark
                                                  ? const Color(0xFF334155)
                                                  : Colors.grey.shade200,
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      context.l10n.cycleSpent,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                        color: context.textSecondary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      summary.totalSpent.toFormattedString(),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: context.expenseColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      context.l10n.categoriesCount(summary.categoryBudgets.length),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: context.textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 36,
                                              color: context.isDark
                                                  ? const Color(0xFF334155)
                                                  : Colors.grey.shade200,
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      context.l10n.incomeUpper,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                        color: context.textSecondary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      summary.totalIncome.toFormattedString(),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: context.incomeColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 1),
                                                    Text(
                                                      context.l10n.recorded,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: context.textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const SavingsVaultCard(),
                        const SizedBox(height: 16),

                        // Quick Presets Carousel
                        Consumer(
                          builder: (context, ref, _) {
                            final presetsAsync = ref.watch(allPresetsProvider);
                            return presetsAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (err, stack) => const SizedBox.shrink(),
                              data: (presets) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          context.l10n.quickPresets,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color: context.textSecondary,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const PresetsManagementScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            context.l10n.manage,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: context.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 38,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: presets.length + 1,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(width: 8),
                                        itemBuilder: (context, index) {
                                          if (index == presets.length) {
                                            return ActionChip(
                                              avatar: const Icon(Icons.add, size: 16),
                                              label: Text(context.l10n.newLabel),
                                              onPressed: () {
                                                HapticFeedback.lightImpact();
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const PresetsManagementScreen(),
                                                  ),
                                                );
                                              },
                                            );
                                          }
                                          final p = presets[index];
                                          final isIncome = p.isIncome;
                                          return ActionChip(
                                            avatar: Icon(
                                              isIncome
                                                  ? Icons.arrow_downward
                                                  : Icons.arrow_upward,
                                              size: 14,
                                              color: isIncome
                                                  ? context.incomeColor
                                                  : context.primaryColor,
                                            ),
                                            tooltip: context.l10n.tapToRecordInstantly,
                                            label: Text(
                                              '${p.title} • ${p.amount.toFormattedString()}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            onPressed: () =>
                                                _executeQuickPreset(context, ref, p),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              },
                            );
                          },
                        ),

                        // Overspent Categories Alert
                        if (overspentCount > 0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: context.overspentLightColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: context.isDark
                                    ? const Color(0xFF7F1D1D)
                                    : Colors.red.shade200,
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
                                  child: Text(
                                      context.l10n.overspentAlert(overspentCount),
                                    style: TextStyle(
                                      color: context.overspentColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (nearLimitCount > 0)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.amber.shade800,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      context.l10n.nearLimitAlert(nearLimitCount),
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // 3. Category Budget Progress Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.l10n.categoryBudgets,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: onNavigateToBudgets,
                              child: Text(context.l10n.viewAll),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: summary.categoryBudgets.isEmpty
                                ? Center(
                                    child: Text(context.l10n.noCategoriesYet),
                                  )
                                : Column(
                                    children: () {
                                      final sortedBudgets =
                                          [...summary.categoryBudgets]
                                            ..sort((a, b) {
                                              if (a.isOverspent !=
                                                  b.isOverspent) {
                                                return a.isOverspent ? -1 : 1;
                                              }
                                              if (a.isNearLimit !=
                                                  b.isNearLimit) {
                                                return a.isNearLimit ? -1 : 1;
                                              }
                                              final pctA =
                                                  a.usagePercentage ?? 0.0;
                                              final pctB =
                                                  b.usagePercentage ?? 0.0;
                                              if (pctA != pctB) {
                                                return pctB.compareTo(pctA);
                                              }
                                              return a.categoryName.compareTo(
                                                b.categoryName,
                                              );
                                            });
                                      return sortedBudgets.take(4).map((b) {
                                        final isOver = b.isOverspent;
                                        final pct = b.usagePercentage;
                                        final hasBudget =
                                            b.budgetedAmount.inMinorUnits > 0;

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    context.l10n.localizedCategoryName(b.categoryName),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                      color: context.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${b.spentAmount.toFormattedString()} / ${b.budgetedAmount.toFormattedString()}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isOver
                                                          ? context.overspentColor
                                                          : context.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: LinearProgressIndicator(
                                                  value: hasBudget
                                                      ? (pct! / 100.0).clamp(
                                                          0.0,
                                                          1.0,
                                                        )
                                                      : (b
                                                                    .spentAmount
                                                                    .inMinorUnits >
                                                                0
                                                            ? 1.0
                                                            : 0.0),
                                                  backgroundColor: context.isDark
                                                      ? const Color(0xFF334155)
                                                      : Colors.grey.shade100,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        isOver
                                                            ? context.overspentColor
                                                            : context.primaryColor,
                                                      ),
                                                  minHeight: 6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList();
                                    }(),
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 4. Recent Transactions Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.recentTransactions,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: onNavigateToTransactions,
                      child: Text(context.l10n.viewAll),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                recentTxsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('${context.l10n.error}: $e'),
                  data: (txs) {
                    if (txs.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 40,
                                  color: context.textTertiary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  context.l10n.noTransactionsYet,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txs.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          final isIncome = tx.isIncome;

                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: isIncome
                                  ? context.incomeLightColor
                                  : context.expenseLightColor,
                              child: Icon(
                                isIncome
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 16,
                                color: isIncome
                                    ? context.incomeColor
                                    : context.expenseColor,
                              ),
                            ),
                            title: Text(
                              (tx.categoryName != null && tx.categoryName!.isNotEmpty)
                                  ? context.l10n.localizedCategoryName(tx.categoryName)
                                  : (isIncome ? context.l10n.income : context.l10n.expense),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('d MMM').format(tx.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                            trailing: Text(
                              '${isIncome ? '+' : '-'}${tx.amount.toFormattedString()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isIncome
                                    ? context.incomeColor
                                    : context.textPrimary,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_add_fab',
        onPressed: () => AddEditTransactionDialog.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _executeQuickPreset(
    BuildContext context,
    WidgetRef ref,
    TransactionPreset preset,
  ) async {
    HapticFeedback.lightImpact();
    // If expense preset has no category, open dialog so user can assign one
    if (preset.type == TransactionType.expense &&
        (preset.categoryId == null || preset.categoryId!.isEmpty)) {
      AddEditTransactionDialog.show(context, preset: preset);
      return;
    }

    try {
      final txRepo = ref.read(transactionRepositoryProvider);
      final cycleRepo = ref.read(budgetCycleRepositoryProvider);
      final thresholdMonitor = ref.read(thresholdMonitorProvider);
      final calcService = ref.read(budgetCalculationServiceProvider);
      final catRepo = ref.read(categoryRepositoryProvider);

      final now = DateTime.now();
      final addedTx = await txRepo.addTransaction(
        type: preset.type,
        amount: preset.amount,
        categoryId: preset.categoryId,
        date: now,
        note: preset.note ?? '',
      );

      // Evaluate budget thresholds if expense
      if (preset.type == TransactionType.expense && preset.categoryId != null) {
        final cycle = await cycleRepo.getCycleForDateOrNull(now);
        if (cycle != null) {
          final budgetMap = await cycleRepo.getCycleBudgets(cycle.id);
          final cycleTxs = await txRepo.getTransactionsForCycle(cycle);
          final allCategories = await catRepo.getAllCategories(
            includeInactive: true,
          );

          final summary = calcService.calculateCycleSummary(
            cycle: cycle,
            categories: allCategories,
            budgetMap: budgetMap,
            transactions: cycleTxs,
          );

          final categoryBudget = summary.categoryBudgets.firstWhere(
            (b) => b.categoryId == preset.categoryId,
            orElse: () => CategoryBudget(
              categoryId: preset.categoryId!,
              categoryName: preset.categoryName ?? '',
              budgetedAmount: const Money.zero(),
              spentAmount: preset.amount,
            ),
          );

          await thresholdMonitor.evaluateAndNotify(
            cycleId: cycle.id,
            budget: categoryBudget,
          );
        }
      }

      // Rebalance Savings if preset is income
      if (preset.type == TransactionType.income) {
        final cycle = await cycleRepo.getOrCreateCycleForDate(now);
        await ref
            .read(savingsSyncServiceProvider)
            .syncSavingsBudgetForCycle(cycleId: cycle.id);
      }

      ref.read(refreshTriggerProvider.notifier).trigger();

      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            persist: false,
            duration: const Duration(seconds: 3),
            content: Text(
              context.l10n.addedPresetNotice(preset.title, preset.amount.toFormattedString()),
            ),
            action: SnackBarAction(
              label: context.l10n.undo,
              textColor: Colors.amberAccent,
              onPressed: () async {
                HapticFeedback.lightImpact();
                await txRepo.deleteTransaction(addedTx.id);
                if (preset.type == TransactionType.income) {
                  final cycle = await cycleRepo.getCycleForDateOrNull(now);
                  if (cycle != null) {
                    await ref
                        .read(savingsSyncServiceProvider)
                        .syncSavingsBudgetForCycle(cycleId: cycle.id);
                  }
                }
                ref.read(refreshTriggerProvider.notifier).trigger();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failedToAddPreset(e.toString()))),
        );
      }
    }
  }
}
