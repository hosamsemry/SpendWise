import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/math_expression_evaluator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:money_tracker/features/savings/presentation/goal_icons.dart';
import 'package:money_tracker/features/savings/presentation/savings_actions.dart';

/// Opens the new / edit goal sheet. [existing] is the goal being edited;
/// [unassigned] is offered as starting money for a new goal.
Future<void> showGoalForm(
  BuildContext context, {
  GoalWithBalance? existing,
  Money unassigned = const Money.zero(),
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => GoalFormSheet(existing: existing, unassigned: unassigned, parentContext: context),
  );
}

class GoalFormSheet extends ConsumerStatefulWidget {
  final GoalWithBalance? existing;
  final Money unassigned;

  /// Used for the celebration once the sheet has closed.
  final BuildContext parentContext;

  const GoalFormSheet({super.key, this.existing, required this.unassigned, required this.parentContext});

  @override
  ConsumerState<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<GoalFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _plan;
  final TextEditingController _starting = TextEditingController();
  String? _icon;
  DateTime? _targetDate;
  String? _nameError;
  String? _targetError;
  String? _planError;
  String? _startingError;
  bool _saving = false;

  SavingsGoal? get _goal => widget.existing?.goal;

  @override
  void initState() {
    super.initState();
    final g = _goal;
    _name = TextEditingController(text: g?.name ?? '');
    _target = TextEditingController(text: g == null ? '' : g.target.toFormattedString(includeCurrency: false));
    _plan = TextEditingController(
      text: g?.monthlyPlan == null ? '' : g!.monthlyPlan!.toFormattedString(includeCurrency: false),
    );
    _icon = g?.icon ?? 'savings';
    _targetDate = g?.targetDate;
    _target.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _plan.dispose();
    _starting.dispose();
    super.dispose();
  }

  Money? _parse(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : MathExpressionEvaluator.tryEvaluate(t);
  }

  /// The per-cycle saving that reaches the target by the chosen date.
  Money? get _suggestedPlan {
    final target = _parse(_target);
    final date = _targetDate;
    if (target == null || date == null) return null;
    final saved = (widget.existing?.balance.inMinorUnits ?? 0) + (_parse(_starting)?.inMinorUnits ?? 0);
    final remaining = Money.fromMinorUnits(target.inMinorUnits - saved);
    if (remaining.inMinorUnits <= 0) return null;
    return ref.read(savingsPlannerProvider).requiredPerCycle(remaining, date, DateTime.now());
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 30, 12, 31),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _name.text.trim();
    final target = _parse(_target);
    final planText = _plan.text.trim();
    final plan = _parse(_plan);
    final startingText = _starting.text.trim();
    final starting = _parse(_starting);
    setState(() {
      _nameError = name.isEmpty ? l10n.nameRequired : null;
      _targetError = (target == null || target.inMinorUnits <= 0) ? l10n.targetMustBePositive : null;
      _planError = planText.isNotEmpty && (plan == null || plan.inMinorUnits <= 0) ? l10n.enterAmountGreaterThanZero : null;
      _startingError = startingText.isEmpty
          ? null
          : (starting == null || starting.inMinorUnits <= 0)
              ? l10n.enterAmountGreaterThanZero
              : (starting > widget.unassigned ? l10n.amountExceedsAvailable : null);
    });
    if (_nameError != null || _targetError != null || _planError != null || _startingError != null) return;

    setState(() => _saving = true);
    final service = ref.read(savingsGoalServiceProvider);
    final parent = widget.parentContext;
    try {
      final List<SavingsGoal> reached;
      final g = _goal;
      if (g == null) {
        final result = await service.createGoal(
          name: name,
          icon: _icon,
          target: target!,
          targetDate: _targetDate,
          monthlyPlan: plan,
          startingAmount: starting,
        );
        reached = result.newlyAchieved;
      } else {
        reached = await service.updateGoal(g.copyWith(
          name: name,
          icon: _icon,
          target: target,
          targetDate: _targetDate,
          clearTargetDate: _targetDate == null,
          monthlyPlan: plan,
          clearMonthlyPlan: plan == null,
        ));
      }
      ref.read(refreshTriggerProvider.notifier).trigger();
      if (mounted) Navigator.pop(context);
      if (parent.mounted) await celebrateGoals(parent, reached);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.failedToSave(e.toString()))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suggested = _suggestedPlan;

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
            Text(
              _goal == null ? l10n.newGoal : l10n.editGoal,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('goal_name_field'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.goalNameLabel, hintText: l10n.goalNameHint, errorText: _nameError),
            ),
            const SizedBox(height: 12),
            Text(l10n.goalIconLabel, style: TextStyle(fontSize: 12, color: context.textSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in goalIcons.entries)
                  ChoiceChip(
                    key: ValueKey('goal_icon_${entry.key}'),
                    label: Icon(entry.value, size: 20),
                    selected: _icon == entry.key,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _icon = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('goal_target_field'),
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.goalTargetLabel, errorText: _targetError),
            ),
            ListTile(
              key: const ValueKey('goal_date_tile'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_rounded),
              title: Text(l10n.goalTargetDateLabel, style: const TextStyle(fontSize: 14)),
              subtitle: Text(_targetDate == null ? l10n.noTargetDate : DateFormat('d MMM yyyy').format(_targetDate!)),
              trailing: _targetDate == null
                  ? null
                  : IconButton(
                      tooltip: l10n.clearDate,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _targetDate = null),
                    ),
              onTap: _pickDate,
            ),
            TextField(
              key: const ValueKey('goal_plan_field'),
              controller: _plan,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.goalMonthlyPlanLabel,
                helperText: l10n.goalMonthlyPlanHelper,
                helperMaxLines: 2,
                errorText: _planError,
              ),
            ),
            if (suggested != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('goal_use_suggested_plan'),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: Text(l10n.goalSuggestPlan(suggested.toFormattedString())),
                  onPressed: () => setState(
                    () => _plan.text = suggested.toFormattedString(includeCurrency: false),
                  ),
                ),
              ),
            if (_goal == null && widget.unassigned.inMinorUnits > 0) ...[
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('goal_starting_field'),
                controller: _starting,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.goalStartingAmountLabel,
                  helperText: l10n.availableAmount(widget.unassigned.toFormattedString()),
                  errorText: _startingError,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('goal_save_button'),
              style: FilledButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: context.onPrimaryColor,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_goal == null ? l10n.save : l10n.update),
            ),
          ],
        ),
      ),
    );
  }
}
