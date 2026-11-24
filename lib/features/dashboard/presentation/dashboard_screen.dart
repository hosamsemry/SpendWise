import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/alert_dismissal_provider.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/core/providers/preset_providers.dart';
import 'package:money_tracker/core/providers/privacy_provider.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/budgets/presentation/cycle_summary_screen.dart';
import 'package:money_tracker/features/presets/domain/transaction_preset.dart';
import 'package:money_tracker/features/presets/presentation/presets_management_screen.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/savings/presentation/cycle_closeout_card.dart';
import 'package:money_tracker/features/savings/presentation/savings_vault_card.dart';
import 'package:money_tracker/features/settings/presentation/settings_screen.dart';
import 'package:money_tracker/features/smart_detection/presentation/pending_transactions_banner.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/features/transactions/presentation/add_edit_transaction_dialog.dart';
import 'widgets/near_limit_alert_card.dart';
import 'widgets/overspent_alert_card.dart';
import 'widgets/velvet_titanium_hero_card.dart';

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
    ref.watch(primaryCurrencyProvider);
    final isAmountsHidden = ref.watch(dashboardAmountsHiddenProvider);
    final currentCycleAsync = ref.watch(currentCycleProvider);
    final allCycles = ref.watch(allCyclesProvider).asData?.value ?? const [];
    final overrideCycle = ref.watch(dashboardCycleProvider);
    final recentTxsAsync = ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appName),
        actions: [
          currentCycleAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
            data: (currentCycle) {
              final activeCycle = (overrideCycle != null &&
                      allCycles.any((c) => c.id == overrideCycle.id))
                  ? overrideCycle
                  : currentCycle;
              return IconButton(
                icon: const Icon(Icons.analytics_outlined),
                tooltip: context.l10n.cycleSummaryTitle,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => CycleSummaryScreen(cycle: activeCycle),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.settingsTitle,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: currentCycleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('${context.l10n.error}: $err')),
        data: (currentCycle) {
          final cycle = (overrideCycle != null &&
                  allCycles.any((c) => c.id == overrideCycle.id))
              ? overrideCycle
              : currentCycle;
          final cycleIndex = allCycles.indexWhere((c) => c.id == cycle.id);
          final prevCycle =
              (cycleIndex >= 0 && cycleIndex < allCycles.length - 1)
                  ? allCycles[cycleIndex + 1]
                  : null;
          final nextCycle = cycleIndex > 0 ? allCycles[cycleIndex - 1] : null;
          final isHistoricalCycle = cycle.id != currentCycle.id;

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
                  skipLoadingOnReload: true,
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (err, _) => Text('${context.l10n.error}: $err'),
                  data: (summary) {
                    final overspentBudgets = summary.categoryBudgets
                        .where((b) => b.isAtOrOverLimit)
                        .toList()
                      ..sort(
                        (a, b) => a.remainingAmount.compareTo(b.remainingAmount),
                      );
                    final nearLimitBudgets = summary.categoryBudgets
                        .where((b) => b.isNearLimit)
                        .toList()
                      ..sort(
                        (a, b) => (b.usagePercentage ?? 0)
                            .compareTo(a.usagePercentage ?? 0),
                      );

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
                        const PendingTransactionsBanner(),
                        _DashboardCycleSwitcherBar(
                          formattedRange: cycle.formattedRange,
                          isHistoricalCycle: isHistoricalCycle,
                          onPreviousCycle: prevCycle != null
                              ? () => ref
                                  .read(dashboardCycleProvider.notifier)
                                  .select(prevCycle)
                              : null,
                          onNextCycle: nextCycle != null
                              ? () => ref
                                  .read(dashboardCycleProvider.notifier)
                                  .select(
                                    nextCycle.id == currentCycle.id
                                        ? null
                                        : nextCycle,
                                  )
                              : null,
                          onJumpToCurrent: isHistoricalCycle
                              ? () => ref
                                  .read(dashboardCycleProvider.notifier)
                                  .select(null)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Consumer(
                          builder: (context, ref, _) {
                            final dailyAsync = ref.watch(todaySpendingSummaryProvider);
                            return dailyAsync.when(
                              skipLoadingOnReload: true,
                              loading: () => const SizedBox.shrink(),
                              error: (err, stack) => const SizedBox.shrink(),
                              data: (daily) {
                                return VelvetTitaniumHeroCard(
                                  cycle: cycle,
                                  summary: summary,
                                  daily: daily,
                                  isAmountsHidden: isAmountsHidden,
                                  isHistoricalCycle: isHistoricalCycle,
                                  onToggleAmountsVisibility: () {
                                    ref
                                        .read(
                                          dashboardAmountsHiddenProvider
                                              .notifier,
                                        )
                                        .toggle();
                                  },
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
                                              '${p.title} • ${p.amount.toFormattedString(includeCurrency: false)}',
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

                        // Overspent Categories Alert (Interactive)
                        if (overspentBudgets.isNotEmpty)
                          OverspentAlertCard(
                            cycle: cycle,
                            overspentBudgets: overspentBudgets,
                            onViewTransactions: (budget) {
                              ref
                                  .read(selectedCycleProvider.notifier)
                                  .select(cycle);
                              ref
                                  .read(categoryFilterProvider.notifier)
                                  .set(budget.categoryId);
                              onNavigateToTransactions();
                            },
                            onEditBudgets: onNavigateToBudgets,
                          ),

                        if (nearLimitBudgets.isNotEmpty)
                          Consumer(
                            builder: (context, ref, _) {
                              final dismissedAsync = ref.watch(
                                dismissedNearLimitCategoriesProvider(cycle.id),
                              );
                              final optimisticMap = ref.watch(
                                optimisticDismissedNearLimitProvider,
                              );
                              final dismissedIds = <String>{
                                ...(dismissedAsync.value ?? const <String>{}),
                                ...(optimisticMap[cycle.id] ?? const <String>{}),
                              };
                              final visibleNearLimit = nearLimitBudgets
                                  .where(
                                    (b) => !dismissedIds.contains(b.categoryId),
                                  )
                                  .toList();

                              if (visibleNearLimit.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return NearLimitAlertCard(
                                cycle: cycle,
                                nearLimitBudgets: visibleNearLimit,
                                onDismiss: (categoryIds) {
                                  // Remove synchronously for Dismissible, then persist to SQLite
                                  ref
                                      .read(
                                        optimisticDismissedNearLimitProvider
                                            .notifier,
                                      )
                                      .dismiss(cycle.id, categoryIds);
                                  ref
                                      .read(alertDismissalRepositoryProvider)
                                      .dismissNearLimitCategories(
                                        cycle.id,
                                        categoryIds,
                                      )
                                      .then((_) {
                                        ref
                                            .read(
                                              alertDismissalTriggerProvider
                                                  .notifier,
                                            )
                                            .trigger();
                                      });
                                },
                                onViewTransactions: (budget) {
                                  ref
                                      .read(selectedCycleProvider.notifier)
                                      .select(cycle);
                                  ref
                                      .read(categoryFilterProvider.notifier)
                                      .set(budget.categoryId);
                                  onNavigateToTransactions();
                                },
                                onEditBudgets: onNavigateToBudgets,
                              );
                            },
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
                                              if (a.isAtOrOverLimit !=
                                                  b.isAtOrOverLimit) {
                                                return a.isAtOrOverLimit ? -1 : 1;
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
                                        final isOver = b.isAtOrOverLimit;
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
                                                    isAmountsHidden
                                                        ? '•••• / ••••'
                                                        : '${b.spentAmount.toFormattedString(includeCurrency: false)} / ${b.budgetedAmount.toFormattedString(includeCurrency: false)}',
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
                                                  backgroundColor:
                                                      context.surfaceVariantColor,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        isOver
                                                            ? context.overspentColor
                                                            : (b.isNearLimit
                                                                ? context.warningColor
                                                                : context.accentColor),
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
                            onTap: () => AddEditTransactionDialog.show(
                              context,
                              transaction: tx,
                            ),
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
                              isAmountsHidden
                                  ? '••••'
                                  : '${isIncome ? '+' : '-'}${tx.amount.toFormattedString(includeCurrency: false)}',
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
      final txService = ref.read(transactionServiceProvider);
      final addedTx = await txService.add(
        type: preset.type,
        amount: preset.amount,
        categoryId: preset.categoryId,
        date: DateTime.now(),
        note: preset.note ?? '',
      );

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
                await txService.delete(addedTx);
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

class _DashboardCycleSwitcherBar extends StatelessWidget {
  final String formattedRange;
  final bool isHistoricalCycle;
  final VoidCallback? onPreviousCycle;
  final VoidCallback? onNextCycle;
  final VoidCallback? onJumpToCurrent;

  const _DashboardCycleSwitcherBar({
    required this.formattedRange,
    required this.isHistoricalCycle,
    required this.onPreviousCycle,
    required this.onNextCycle,
    required this.onJumpToCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final accentColor = context.accentColor;

    return Container(
      key: const ValueKey('dashboard_cycle_switcher_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? context.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHistoricalCycle
              ? accentColor.withValues(alpha: 0.45)
              : context.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.0),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildArrowButton(
            context,
            key: const ValueKey('hero_prev_cycle_btn'),
            icon: Icons.chevron_left_rounded,
            tooltip: context.l10n.previousCycleTooltip,
            onTap: onPreviousCycle,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onJumpToCurrent == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onJumpToCurrent!();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (isHistoricalCycle
                              ? context.l10n.pastBudgetCycle
                              : context.l10n.currentBudgetCycle)
                          .toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: isDark
                            ? const Color(0xFFE5C158)
                            : context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: isHistoricalCycle
                              ? accentColor
                              : context.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            formattedRange,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isHistoricalCycle
                                  ? accentColor
                                  : context.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildArrowButton(
            context,
            key: const ValueKey('hero_next_cycle_btn'),
            icon: Icons.chevron_right_rounded,
            tooltip: context.l10n.nextCycleTooltip,
            onTap: onNextCycle,
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return IconButton(
      key: key,
      onPressed: isEnabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: 20,
        color: isEnabled
            ? context.primaryColor
            : context.textTertiary.withValues(alpha: 0.35),
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
    );
  }
}
