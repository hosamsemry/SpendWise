import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/math_expression_evaluator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/savings/domain/savings_goal.dart';
import 'package:money_tracker/features/savings/domain/savings_goal_service.dart';

enum SavingsMoneyAction { add, takeOut, move }

/// One place money can sit: a goal, or Unassigned when [goal] is null.
class SavingsBucket {
  final SavingsGoal? goal;
  final Money balance;
  const SavingsBucket({this.goal, required this.balance});

  String? get id => goal?.id;
  String name(BuildContext context) => goal?.name ?? context.l10n.unassignedSavings;
}

/// Celebrates goals that just reached their target.
Future<void> celebrateGoals(BuildContext context, List<SavingsGoal> goals) async {
  for (final g in goals) {
    if (!context.mounted) return;
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.emoji_events_rounded, size: 48, color: ctx.savingsColor),
        title: Text(ctx.l10n.goalReachedTitle(g.name), textAlign: TextAlign.center),
        content: Text(
          ctx.l10n.goalReachedBody(g.target.toFormattedString()),
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.primaryColor,
              foregroundColor: ctx.onPrimaryColor,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.great),
          ),
        ],
      ),
    );
  }
}

/// Shows an amount sheet for [action] on [from] and runs it through
/// [SavingsGoalService], with an Undo snackbar. For [SavingsMoneyAction.move]
/// the user picks the destination among [buckets].
Future<void> showSavingsMoneySheet(
  BuildContext context, {
  required SavingsMoneyAction action,
  required SavingsBucket from,
  List<SavingsBucket> buckets = const [],
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final undoColor = context.primaryColor;

  final result = await showModalBottomSheet<_MoneyInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _MoneySheet(action: action, from: from, buckets: buckets),
  );
  if (result == null) return;

  final service = container.read(savingsGoalServiceProvider);
  final SavingsActionResult done;
  final String notice;
  final amountText = result.amount.toFormattedString();
  try {
    switch (action) {
      case SavingsMoneyAction.add:
        done = await service.deposit(result.amount, goalId: from.id);
        notice = l10n.savedToNotice(amountText, from.goal?.name ?? l10n.unassignedSavings);
      case SavingsMoneyAction.takeOut:
        done = await service.withdraw(result.amount, goalId: from.id);
        notice = l10n.tookOutNotice(amountText, from.goal?.name ?? l10n.unassignedSavings);
      case SavingsMoneyAction.move:
        done = await service.transfer(result.amount, from: from.id, to: result.to!.id);
        notice = l10n.movedNotice(amountText, result.to!.goal?.name ?? l10n.unassignedSavings);
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.failedToSave(e.toString()))));
    return;
  }
  HapticFeedback.mediumImpact();
  container.read(refreshTriggerProvider.notifier).trigger();
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(notice),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: l10n.undo,
        textColor: undoColor,
        onPressed: () async {
          final undone = await service.undo(done);
          container.read(refreshTriggerProvider.notifier).trigger();
          if (!undone) messenger.showSnackBar(SnackBar(content: Text(l10n.undoNotPossible)));
        },
      ),
    ));
  if (context.mounted) await celebrateGoals(context, done.newlyAchieved);
}

class _MoneyInput {
  final Money amount;
  final SavingsBucket? to;
  const _MoneyInput(this.amount, this.to);
}

class _MoneySheet extends StatefulWidget {
  final SavingsMoneyAction action;
  final SavingsBucket from;
  final List<SavingsBucket> buckets;

  const _MoneySheet({required this.action, required this.from, required this.buckets});

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  final _amount = TextEditingController();
  SavingsBucket? _to;
  String? _error;

  List<SavingsBucket> get _destinations =>
      widget.buckets.where((b) => b.id != widget.from.id).toList();

  @override
  void initState() {
    super.initState();
    if (widget.action == SavingsMoneyAction.move && _destinations.isNotEmpty) {
      _to = _destinations.first;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final value = MathExpressionEvaluator.tryEvaluate(_amount.text.trim());
    if (value == null || value.inMinorUnits <= 0) {
      setState(() => _error = l10n.enterAmountGreaterThanZero);
      return;
    }
    if (widget.action != SavingsMoneyAction.add && value > widget.from.balance) {
      setState(() => _error = l10n.amountExceedsAvailable);
      return;
    }
    Navigator.pop(context, _MoneyInput(value, _to));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = widget.from.name(context);
    final title = switch (widget.action) {
      SavingsMoneyAction.add => l10n.addMoneyTo(name),
      SavingsMoneyAction.takeOut => l10n.takeOutFrom(name),
      SavingsMoneyAction.move => l10n.moveFrom(name),
    };
    final limited = widget.action != SavingsMoneyAction.add;

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
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('savings_amount_field'),
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.amountLabelWithCurrency,
                helperText: limited ? l10n.availableAmount(widget.from.balance.toFormattedString()) : null,
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (widget.action == SavingsMoneyAction.move) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const ValueKey('savings_move_to_field'),
                initialValue: _to?.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.moveToLabel),
                items: [
                  for (final b in _destinations)
                    DropdownMenuItem<String?>(value: b.id, child: Text(b.name(context))),
                ],
                onChanged: (id) => setState(() => _to = _destinations.firstWhere((b) => b.id == id)),
              ),
            ],
            if (widget.action == SavingsMoneyAction.takeOut) ...[
              const SizedBox(height: 12),
              Text(l10n.takeOutHint, style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('savings_amount_submit'),
              style: FilledButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: context.onPrimaryColor,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submit,
              child: Text(switch (widget.action) {
                SavingsMoneyAction.add => l10n.addMoney,
                SavingsMoneyAction.takeOut => l10n.takeOutMoney,
                SavingsMoneyAction.move => l10n.moveMoney,
              }),
            ),
          ],
        ),
      ),
    );
  }
}
