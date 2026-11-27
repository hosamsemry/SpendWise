import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/money/math_expression_evaluator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:money_tracker/features/savings/presentation/savings_actions.dart';

class CycleCloseoutCard extends ConsumerStatefulWidget {
  final CycleCloseoutInfo closeout;

  const CycleCloseoutCard({
    super.key,
    required this.closeout,
  });

  @override
  ConsumerState<CycleCloseoutCard> createState() => _CycleCloseoutCardState();
}

class _CycleCloseoutCardState extends ConsumerState<CycleCloseoutCard> {
  /// The user's own split; null = the default (monthly plans in fill order).
  Map<String?, Money>? _customSplit;

  CycleCloseoutInfo get closeout => widget.closeout;

  Map<String?, Money> _split(SavingsOverview? overview) {
    final custom = _customSplit;
    // A split made before the surplus changed no longer adds up: drop it.
    if (custom != null &&
        custom.values.fold<int>(0, (s, m) => s + m.inMinorUnits) == closeout.surplus.inMinorUnits) {
      return custom;
    }
    final goals = overview?.goals.map((g) => g.goal).toList() ?? const <GoalWithBalance>[];
    return ref.read(savingsPlannerProvider).splitSurplus(closeout.surplus, goals);
  }

  Future<void> _sweepSurplus(BuildContext context, Map<String?, Money> split) async {
    HapticFeedback.mediumImpact();
    final container = ProviderScope.containerOf(context, listen: false);
    final service = container.read(savingsGoalServiceProvider);
    final cycle = closeout.cycle;
    final surplus = closeout.surplus;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    final result = await service.sweep(cycleId: cycle.id, amount: surplus, allocation: split);
    container.read(refreshTriggerProvider.notifier).trigger();

    // A repeated tap is a no-op; only offer Undo for the sweep that happened.
    if (result == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.sweptSuccess(surplus.toFormattedString(currencySymbol: l10n.currencySymbol))),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            HapticFeedback.lightImpact();
            final undone = await service.undoSweep(cycle.id, achievedByIt: result.newlyAchieved);
            container.read(refreshTriggerProvider.notifier).trigger();
            if (!undone) messenger.showSnackBar(SnackBar(content: Text(l10n.undoNotPossible)));
          },
        ),
      ),
    );
    if (context.mounted) await celebrateGoals(context, result.newlyAchieved);
  }

  Future<void> _dismiss() async {
    HapticFeedback.lightImpact();
    final repo = ref.read(savingsVaultRepositoryProvider);
    await repo.dismissCycle(closeout.cycle.id);
    ref.read(refreshTriggerProvider.notifier).trigger();
  }

  Future<void> _editSplit(SavingsOverview overview, Map<String?, Money> current) async {
    final edited = await showModalBottomSheet<Map<String?, Money>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _SplitSheet(
        surplus: closeout.surplus,
        goals: overview.activeGoals.map((g) => g.goal.goal).toList(),
        initial: current,
      ),
    );
    if (edited != null) setState(() => _customSplit = edited);
  }

  @override
  Widget build(BuildContext context) {
    final cycle = closeout.cycle;
    final surplus = closeout.surplus;
    final overview = ref.watch(savingsOverviewProvider).value;
    final split = _split(overview);
    final goalNames = {for (final g in overview?.goals ?? const <GoalOverviewItem>[]) g.goal.goal.id: g.goal.goal.name};
    final hasGoals = overview?.activeGoals.isNotEmpty ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.savingsLightColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.savings_rounded,
                    color: context.savingsColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.isArabic
                            ? 'اختتام الدورة — الفائض غير المنفق'
                            : 'CYCLE CLOSED — UNSPENT SURPLUS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: context.savingsColor,
                        ),
                      ),
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
            const SizedBox(height: 12),
            Text(
              context.l10n.isArabic
                  ? 'وفرت ${surplus.toFormattedString(currencySymbol: context.l10n.currencySymbol)} من دورتك السابقة!'
                  : 'You saved ${surplus.toFormattedString(currencySymbol: context.l10n.currencySymbol)} from your last budget cycle!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.isArabic
                  ? 'حوّل هذا الفائض إلى خزينة المدخرات الدائمة لحفظ تقدمك المالي.'
                  : 'Sweep this surplus into your Lifetime Savings Vault to preserve your hard-earned progress.',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                height: 1.3,
              ),
            ),
            if (hasGoals) ...[
              const SizedBox(height: 12),
              for (final entry in split.entries)
                Padding(
                  key: ValueKey('closeout_split_${entry.key ?? 'unassigned'}'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        entry.key == null ? Icons.inbox_rounded : Icons.flag_rounded,
                        size: 16,
                        color: context.savingsColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key == null ? context.l10n.unassignedSavings : (goalNames[entry.key] ?? ''),
                          style: TextStyle(fontSize: 13, color: context.textPrimary),
                        ),
                      ),
                      Text(
                        entry.value.toFormattedString(),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('closeout_edit_split'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.accentColor,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(context.l10n.editSplit),
                  onPressed: () => _editSplit(overview!, split),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('closeout_sweep_button'),
                    onPressed: () => _sweepSurplus(context, split),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      context.l10n.sweepToVault,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.savingsColor,
                      foregroundColor: context.onSavingsColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: context.textSecondary,
                  ),
                  child: Text(context.l10n.dismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user set how much of the surplus each goal gets; whatever is
/// left goes to Unassigned.
class _SplitSheet extends StatefulWidget {
  final Money surplus;
  final List<SavingsGoal> goals;
  final Map<String?, Money> initial;

  const _SplitSheet({required this.surplus, required this.goals, required this.initial});

  @override
  State<_SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<_SplitSheet> {
  late final Map<String, TextEditingController> _fields = {
    for (final g in widget.goals)
      g.id: TextEditingController(
        text: widget.initial[g.id]?.toFormattedString(includeCurrency: false) ?? '',
      )..addListener(() => setState(() {})),
  };
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Parsed shares, or null if one is not a valid amount.
  Map<String, Money>? get _shares {
    final result = <String, Money>{};
    for (final e in _fields.entries) {
      final t = e.value.text.trim();
      if (t.isEmpty) continue;
      final v = MathExpressionEvaluator.tryEvaluate(t);
      if (v == null || v.inMinorUnits < 0) return null;
      if (v.inMinorUnits > 0) result[e.key] = v;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shares = _shares;
    final assigned = shares?.values.fold<int>(0, (s, m) => s + m.inMinorUnits) ?? 0;
    final rest = widget.surplus.inMinorUnits - assigned;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sweepSplitTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
            Text(widget.surplus.toFormattedString(), style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 12),
            for (final g in widget.goals)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  key: ValueKey('split_field_${g.id}'),
                  controller: _fields[g.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: g.name),
                ),
              ),
            Row(
              children: [
                Expanded(child: Text(l10n.unassignedSavings, style: TextStyle(color: context.textPrimary))),
                Text(
                  Money.fromMinorUnits(rest < 0 ? 0 : rest).toFormattedString(),
                  key: const ValueKey('split_unassigned_rest'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
              ],
            ),
            if (rest < 0 || shares == null) ...[
              const SizedBox(height: 8),
              Text(
                shares == null
                    ? l10n.enterValidAmount
                    : l10n.splitExceedsSurplus(widget.surplus.toFormattedString()),
                style: TextStyle(fontSize: 12, color: context.overspentColor),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('split_apply'),
              style: FilledButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: context.onPrimaryColor,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: shares == null || rest < 0
                  ? null
                  : () => Navigator.pop(context, <String?, Money>{
                        ...shares,
                        if (rest > 0) null: Money.fromMinorUnits(rest),
                      }),
              child: Text(l10n.applySplit),
            ),
          ],
        ),
      ),
    );
  }
}
