import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:money_tracker/features/savings/domain/savings_planner.dart';
import 'package:money_tracker/features/savings/presentation/goal_form_sheet.dart';
import 'package:money_tracker/features/savings/presentation/goal_icons.dart';
import 'package:money_tracker/features/savings/presentation/savings_actions.dart';

String _monthYear(DateTime d) => DateFormat('MMM yyyy').format(d);

List<SavingsBucket> _buckets(SavingsOverview o) => [
      SavingsBucket(balance: o.unassigned),
      for (final g in o.goals) SavingsBucket(goal: g.goal.goal, balance: g.goal.balance),
    ];

/// The Savings Vault split into goals and Unassigned. Goals are dragged into
/// the order the cycle closeout fills them.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(savingsOverviewProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.savingsGoalsTitle)),
      floatingActionButton: overviewAsync.value == null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('goals_add_fab'),
              heroTag: 'goals_add_fab',
              backgroundColor: context.primaryColor,
              foregroundColor: context.onPrimaryColor,
              onPressed: () => showGoalForm(context, unassigned: overviewAsync.value!.unassigned),
              icon: const Icon(Icons.add),
              label: Text(l10n.newGoal),
            ),
      body: overviewAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.error}: $e')),
        data: (overview) {
          final active = overview.activeGoals;
          final achieved = overview.achievedGoals;
          final bottom = 96 + MediaQuery.of(context).padding.bottom;

          return ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
            buildDefaultDragHandles: false,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VaultHeader(overview: overview),
                const SizedBox(height: 20),
                if (active.isEmpty && achieved.isEmpty)
                  _EmptyGoals(unassigned: overview.unassigned)
                else if (active.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                    child: Text(l10n.goalsSectionHint, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  ),
              ],
            ),
            footer: achieved.isEmpty
                ? null
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                        child: Text(
                          l10n.achievedGoals.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                      for (final item in achieved)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _GoalCard(item: item, overview: overview),
                        ),
                    ],
                  ),
            itemCount: active.length,
            onReorder: (oldIndex, newIndex) async {
              final ids = active.map((g) => g.goal.goal.id).toList();
              if (newIndex > oldIndex) newIndex -= 1;
              ids.insert(newIndex, ids.removeAt(oldIndex));
              HapticFeedback.selectionClick();
              await ref.read(savingsGoalServiceProvider).reorder([
                ...ids,
                ...achieved.map((g) => g.goal.goal.id),
              ]);
              ref.read(refreshTriggerProvider.notifier).trigger();
            },
            itemBuilder: (context, index) {
              final item = active[index];
              return Padding(
                key: ValueKey('goal_card_${item.goal.goal.id}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: _GoalCard(item: item, overview: overview, dragIndex: index),
              );
            },
          );
        },
      ),
    );
  }
}

class _VaultHeader extends StatelessWidget {
  final SavingsOverview overview;
  const _VaultHeader({required this.overview});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unassigned = SavingsBucket(balance: overview.unassigned);
    final hasGoals = overview.goals.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.vaultTotal, style: TextStyle(fontSize: 12, color: context.textSecondary)),
            const SizedBox(height: 4),
            Text(
              overview.total.toFormattedString(),
              key: const ValueKey('vault_total_text'),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.unassignedSavings,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                      ),
                      Text(l10n.unassignedHint, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                ),
                Text(
                  overview.unassigned.toFormattedString(),
                  key: const ValueKey('vault_unassigned_text'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('unassigned_add'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.addMoney),
                  onPressed: () => showSavingsMoneySheet(context, action: SavingsMoneyAction.add, from: unassigned),
                ),
                if (overview.unassigned.inMinorUnits > 0)
                  OutlinedButton.icon(
                    key: const ValueKey('unassigned_take_out'),
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: Text(l10n.takeOutMoney),
                    onPressed: () => showSavingsMoneySheet(context, action: SavingsMoneyAction.takeOut, from: unassigned),
                  ),
                if (hasGoals && overview.unassigned.inMinorUnits > 0)
                  OutlinedButton.icon(
                    key: const ValueKey('unassigned_move'),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(l10n.moveMoney),
                    onPressed: () => showSavingsMoneySheet(
                      context,
                      action: SavingsMoneyAction.move,
                      from: unassigned,
                      buckets: _buckets(overview),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Status chip text and colour for a goal.
({String text, Color color})? _status(BuildContext context, GoalOverviewItem item) {
  final l10n = context.l10n;
  if (item.goal.goal.isAchieved) return (text: l10n.goalAchieved, color: context.savingsColor);
  return switch (item.forecast.pace) {
    GoalPace.onTrack => (text: l10n.goalOnTrack, color: context.incomeColor),
    GoalPace.behind => (text: l10n.goalBehind, color: context.warningColor),
    GoalPace.noTargetDate => null,
  };
}

/// The forecast line under a goal's progress.
String? _forecastLine(BuildContext context, GoalOverviewItem item) {
  final l10n = context.l10n;
  final g = item.goal;
  if (g.goal.isAchieved || g.isReached) return null;
  final f = item.forecast;
  final date = g.goal.targetDate;
  if (date != null && f.requiredPerCycle != null && f.pace == GoalPace.behind) {
    return l10n.goalNeedsPerCycle(f.requiredPerCycle!.toFormattedString(), _monthYear(date));
  }
  if (f.projectedDate != null) return l10n.goalProjection(_monthYear(f.projectedDate!));
  if (date != null && f.requiredPerCycle != null) {
    return l10n.goalNeedsPerCycle(f.requiredPerCycle!.toFormattedString(), _monthYear(date));
  }
  return l10n.goalNoPaceYet;
}

class _GoalCard extends StatelessWidget {
  final GoalOverviewItem item;
  final SavingsOverview overview;

  /// Position in the reorderable list; null for achieved goals.
  final int? dragIndex;

  const _GoalCard({required this.item, required this.overview, this.dragIndex});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final g = item.goal;
    final status = _status(context, item);
    final forecast = _forecastLine(context, item);
    final percent = (g.fraction * 100).floor();

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _GoalDetailsSheet.show(context, item.goal.goal.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: context.savingsLightColor,
                child: Icon(goalIconFor(g.goal.icon), color: context.savingsColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.goal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                          ),
                        ),
                        if (status != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: status.color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.text,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status.color),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: g.fraction,
                        minHeight: 6,
                        color: context.savingsColor,
                        backgroundColor: context.borderColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.goalProgress(g.balance.toFormattedString(), g.goal.target.toFormattedString())} · $percent%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textPrimary),
                    ),
                    if (forecast != null) ...[
                      const SizedBox(height: 2),
                      Text(forecast, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator_rounded, color: context.textTertiary),
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalDetailsSheet extends ConsumerWidget {
  final String goalId;
  final BuildContext parentContext;

  const _GoalDetailsSheet({required this.goalId, required this.parentContext});

  static Future<void> show(BuildContext context, String goalId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _GoalDetailsSheet(goalId: goalId, parentContext: context),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, GoalWithBalance g) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteGoalTitle(g.goal.name)),
        content: Text(l10n.deleteGoalBody(g.balance.toFormattedString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            key: const ValueKey('goal_delete_confirm'),
            style: TextButton.styleFrom(foregroundColor: ctx.overspentColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(savingsGoalServiceProvider).deleteGoal(g.goal);
    ref.read(refreshTriggerProvider.notifier).trigger();
    if (context.mounted) Navigator.pop(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.goalDeletedNotice(g.goal.name))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(savingsOverviewProvider).value;
    final item = overview?.goals.where((g) => g.goal.goal.id == goalId).firstOrNull;
    if (overview == null || item == null) return const SizedBox(height: 120);
    final g = item.goal;
    final bucket = SavingsBucket(goal: g.goal, balance: g.balance);
    final history = ref.watch(savingsHistoryProvider(goalId));
    final forecast = _forecastLine(context, item);

    void runAction(SavingsMoneyAction action) {
      Navigator.pop(context);
      showSavingsMoneySheet(parentContext, action: action, from: bucket, buckets: _buckets(overview));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(goalIconFor(g.goal.icon), color: context.savingsColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.goal.name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: g.fraction,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: context.savingsColor,
            backgroundColor: context.borderColor,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.goalProgress(g.balance.toFormattedString(), g.goal.target.toFormattedString()),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          if (forecast != null)
            Text(forecast, style: TextStyle(fontSize: 13, color: context.textSecondary)),
          if (g.goal.monthlyPlan != null)
            Text(
              l10n.goalPlanLine(g.goal.monthlyPlan!.toFormattedString()),
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('goal_add_money'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: context.onPrimaryColor,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.addMoney),
                onPressed: () => runAction(SavingsMoneyAction.add),
              ),
              if (g.balance.inMinorUnits > 0) ...[
                OutlinedButton.icon(
                  key: const ValueKey('goal_take_out'),
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  label: Text(l10n.takeOutMoney),
                  onPressed: () => runAction(SavingsMoneyAction.takeOut),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('goal_move'),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(l10n.moveMoney),
                  onPressed: () => runAction(SavingsMoneyAction.move),
                ),
              ],
              OutlinedButton.icon(
                key: const ValueKey('goal_edit'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.edit),
                onPressed: () {
                  Navigator.pop(context);
                  showGoalForm(parentContext, existing: g, unassigned: overview.unassigned);
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('goal_delete'),
                style: OutlinedButton.styleFrom(foregroundColor: context.overspentColor),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.delete),
                onPressed: () => _delete(context, ref, g),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.savingsHistory,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('${l10n.error}: $e'),
            data: (rows) => rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l10n.noSavingsHistory, style: TextStyle(fontSize: 13, color: context.textSecondary)),
                  )
                : Column(
                    children: [
                      for (final m in rows.take(20))
                        _HistoryRow(movement: m),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SavingsMovement movement;
  const _HistoryRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isIn = movement.amount.inMinorUnits > 0;
    final abs = Money.fromMinorUnits(movement.amount.inMinorUnits.abs());
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
        size: 18,
        color: isIn ? context.incomeColor : context.textSecondary,
      ),
      title: Text(context.l10n.savingsMovementLabel(movement.kind.dbValue, isIn)),
      subtitle: Text(DateFormat('d MMM yyyy').format(movement.createdAt)),
      trailing: Text(
        '${isIn ? '+' : '−'}${abs.toFormattedString()}',
        style: TextStyle(fontWeight: FontWeight.w700, color: isIn ? context.incomeColor : context.textPrimary),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  final Money unassigned;
  const _EmptyGoals({required this.unassigned});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.flag_circle_rounded, size: 44, color: context.savingsColor),
            const SizedBox(height: 12),
            Text(
              l10n.noGoalsYet,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.noGoalsDescription,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('goals_create_first'),
              style: FilledButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: context.onPrimaryColor,
              ),
              onPressed: () => showGoalForm(context, unassigned: unassigned),
              icon: const Icon(Icons.add),
              label: Text(l10n.createFirstGoal),
            ),
          ],
        ),
      ),
    );
  }
}
