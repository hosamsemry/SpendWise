import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/math_expression_evaluator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/features/bills/domain/bill_service.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/bills/presentation/bill_form_sheet.dart';

/// Amount text for a bill: "about 350.00 EGP" when it changes each time.
String billAmountText(BuildContext context, RecurringBill bill) {
  final amount = bill.amount.toFormattedString();
  return bill.isVariable ? context.l10n.approxAmount(amount) : amount;
}

String billFrequencyText(BuildContext context, BillFrequency f) {
  final l10n = context.l10n;
  return switch (f) {
    BillFrequency.weekly => l10n.frequencyWeekly,
    BillFrequency.monthly => l10n.frequencyMonthly,
    BillFrequency.yearly => l10n.frequencyYearly,
    BillFrequency.everyCycle => l10n.frequencyEveryCycle,
  };
}

String billDateText(DateTime d) => DateFormat('d MMM').format(d);

/// Logs [due] as paid after the user confirms it. A variable bill first asks
/// for the amount. Shows an Undo snackbar.
Future<void> payBillDue(BuildContext context, BillDue due) async {
  // The row that called this is gone once the bill is paid, so Undo must not
  // use its [ref]: keep the container instead.
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final undoColor = context.primaryColor;
  Money? amount;
  if (due.bill.isVariable) {
    amount = await _askAmount(context, due);
    if (amount == null) return;
  }
  final service = container.read(billServiceProvider);
  try {
    final tx = await service.pay(due, amount: amount);
    HapticFeedback.lightImpact();
    container.read(refreshTriggerProvider.notifier).trigger();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(l10n.billPaidNotice(due.bill.title)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.undo,
          textColor: undoColor,
          onPressed: () async {
            await service.undoPay(tx);
            container.read(refreshTriggerProvider.notifier).trigger();
          },
        ),
      ));
  } on BillCategoryMissingException {
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.billCategoryMissing)));
    if (context.mounted) {
      await showBillForm(context, bill: due.bill, nextDue: due.dueDate);
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.failedToSave(e.toString()))));
  }
}

/// Marks [due] as skipped, with an Undo snackbar.
Future<void> skipBillDue(BuildContext context, BillDue due) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final undoColor = context.primaryColor;
  final service = container.read(billServiceProvider);
  await service.skip(due);
  HapticFeedback.selectionClick();
  container.read(refreshTriggerProvider.notifier).trigger();
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(l10n.billSkippedNotice(due.bill.title)),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: l10n.undo,
        textColor: undoColor,
        onPressed: () async {
          await service.undoSkip(due);
          container.read(refreshTriggerProvider.notifier).trigger();
        },
      ),
    ));
}

Future<Money?> _askAmount(BuildContext context, BillDue due) {
  final controller = TextEditingController(
    text: due.bill.amount.toFormattedString(includeCurrency: false),
  );
  String? error;
  return showDialog<Money>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          final value = MathExpressionEvaluator.tryEvaluate(controller.text.trim());
          if (value == null || value.inMinorUnits <= 0) {
            setState(() => error = ctx.l10n.enterAmountGreaterThanZero);
            return;
          }
          Navigator.pop(ctx, value);
        }

        return AlertDialog(
          title: Text(due.bill.isIncome
              ? ctx.l10n.receiveBillTitle(due.bill.title)
              : ctx.l10n.payBillTitle(due.bill.title)),
          content: TextField(
            key: const ValueKey('bill_pay_amount_field'),
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: ctx.l10n.amountLabelWithCurrency,
              helperText: '${ctx.l10n.billDueDateLabel}: ${billDateText(due.dueDate)}',
              errorText: error,
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
            ElevatedButton(
              onPressed: submit,
              child: Text(due.bill.isIncome ? ctx.l10n.markBillReceived : ctx.l10n.markBillPaid),
            ),
          ],
        );
      },
    ),
  );
}

/// One unpaid due date with Skip and Paid buttons.
class BillDueTile extends StatelessWidget {
  final BillDue due;
  const BillDueTile({super.key, required this.due});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = due.daysUntil(DateTime(now.year, now.month, now.day));
    final dueColor = days < 0
        ? context.overspentColor
        : days == 0
            ? context.warningColor
            : context.textSecondary;
    final bill = due.bill;

    final info = Row(
      children: [
        Icon(
          bill.isIncome ? Icons.south_west_rounded : Icons.receipt_long_rounded,
          size: 20,
          color: bill.isIncome ? context.incomeColor : context.accentColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bill.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: context.l10n.billDueLabel(days),
                    style: TextStyle(color: dueColor, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ' · ${billAmountText(context, bill)}'),
                ]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          key: ValueKey('bill_skip_${bill.id}'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: context.textSecondary,
          ),
          onPressed: () => skipBillDue(context, due),
          child: Text(context.l10n.skipBill),
        ),
        FilledButton(
          key: ValueKey('bill_pay_${bill.id}'),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: context.primaryColor,
            foregroundColor: context.onPrimaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          onPressed: () => payBillDue(context, due),
          child: Text(bill.isIncome ? context.l10n.markBillReceived : context.l10n.markBillPaid),
        ),
      ],
    );

    return Padding(
      key: ValueKey('bill_due_${bill.id}_${due.dueDate.toIso8601String()}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      // On narrow phones the buttons move under the name instead of squeezing it.
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 330
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  Align(alignment: AlignmentDirectional.centerEnd, child: buttons),
                ],
              )
            : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 4),
                  buttons,
                ],
              ),
      ),
    );
  }
}
