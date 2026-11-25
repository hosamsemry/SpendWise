import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/math_expression_evaluator.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

/// Opens the add / edit bill sheet. [nextDue] is shown as the due date when
/// editing, so the user sees the upcoming date rather than the first one.
Future<void> showBillForm(
  BuildContext context, {
  RecurringBill? bill,
  DateTime? nextDue,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BillFormSheet(bill: bill, nextDue: nextDue),
  );
}

const List<int?> _reminderChoices = [null, 0, 1, 3, 7];

class BillFormSheet extends ConsumerStatefulWidget {
  final RecurringBill? bill;
  final DateTime? nextDue;

  const BillFormSheet({super.key, this.bill, this.nextDue});

  @override
  ConsumerState<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends ConsumerState<BillFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late TransactionType _type;
  String? _categoryId;
  late bool _isVariable;
  late BillFrequency _frequency;
  late DateTime _dueDate;
  bool _dueDateChanged = false;
  int? _remindDaysBefore;
  String? _titleError;
  String? _amountError;
  String? _categoryError;
  bool _saving = false;

  bool get _isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    final now = DateTime.now();
    _title = TextEditingController(text: b?.title ?? '');
    _amount = TextEditingController(
      text: b == null ? '' : b.amount.toFormattedString(includeCurrency: false),
    );
    _note = TextEditingController(text: b?.note ?? '');
    _type = b?.type ?? TransactionType.expense;
    _categoryId = b?.categoryId;
    _isVariable = b?.isVariable ?? false;
    _frequency = b?.frequency ?? BillFrequency.monthly;
    _dueDate = widget.nextDue ?? b?.anchorDate ?? DateTime(now.year, now.month, now.day);
    _remindDaysBefore = b == null ? 1 : b.remindDaysBefore;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueDateChanged = true;
      });
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    final amount = MathExpressionEvaluator.tryEvaluate(_amount.text.trim());
    setState(() {
      _titleError = title.isEmpty ? l10n.titleRequired : null;
      _amountError = (amount == null || amount.inMinorUnits <= 0)
          ? l10n.enterAmountGreaterThanZero
          : null;
      _categoryError = (_type == TransactionType.expense && _categoryId == null)
          ? l10n.selectCategoryForExpense
          : null;
    });
    if (_titleError != null || _amountError != null || _categoryError != null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final existing = widget.bill;
    // Keep the original anchor unless the date was changed, so past due
    // dates still line up with their paid / skipped records.
    final anchor = _frequency == BillFrequency.everyCycle
        ? (existing?.frequency == BillFrequency.everyCycle ? existing!.anchorDate : today)
        : (_dueDateChanged || existing == null || existing.frequency != _frequency
            ? _dueDate
            : existing.anchorDate);

    setState(() => _saving = true);
    final service = ref.read(billServiceProvider);
    try {
      if (existing == null) {
        await service.create(
          title: title,
          type: _type,
          categoryId: _categoryId,
          amount: amount!,
          isVariable: _isVariable,
          frequency: _frequency,
          anchorDate: anchor,
          remindDaysBefore: _remindDaysBefore,
          note: _note.text,
        );
      } else {
        await service.update(RecurringBill(
          id: existing.id,
          title: title,
          type: _type,
          categoryId: _categoryId,
          categoryName: existing.categoryName,
          amount: amount!,
          isVariable: _isVariable,
          frequency: _frequency,
          anchorDate: anchor,
          remindDaysBefore: _remindDaysBefore,
          isActive: existing.isActive,
          note: _note.text,
          createdAt: existing.createdAt,
          updatedAt: existing.updatedAt,
        ));
      }
      ref.read(refreshTriggerProvider.notifier).trigger();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToSave(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categoriesAsync = ref.watch(categoriesProvider);
    final startDay = ref.watch(budgetCycleStartDayProvider).value ?? 1;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? l10n.editBill : l10n.newBill,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(l10n.expense),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(l10n.income),
                  icon: const Icon(Icons.arrow_downward, size: 16),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() {
                _type = set.first;
                _categoryId = null;
                _categoryError = null;
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('bill_title_field'),
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.billTitleLabel,
                hintText: l10n.billTitleHint,
                errorText: _titleError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('bill_amount_field'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.amountLabelWithCurrency,
                hintText: l10n.amountHint,
                errorText: _amountError,
              ),
            ),
            SwitchListTile(
              key: const ValueKey('bill_variable_switch'),
              contentPadding: EdgeInsets.zero,
              value: _isVariable,
              title: Text(l10n.variableAmountLabel, style: const TextStyle(fontSize: 14)),
              subtitle: _isVariable
                  ? Text(l10n.variableAmountHint, style: const TextStyle(fontSize: 12))
                  : null,
              onChanged: (v) => setState(() => _isVariable = v),
            ),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('${l10n.error}: $e'),
              data: (cats) {
                final filtered = cats
                    .where((c) => _type == TransactionType.expense ? c.type.isExpense : c.type.isIncome)
                    .toList();
                final value = filtered.any((c) => c.id == _categoryId) ? _categoryId : null;
                return DropdownButtonFormField<String?>(
                  key: ValueKey('bill_category_${_type.name}'),
                  initialValue: value,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _type == TransactionType.expense
                        ? l10n.categoryLabelRequired
                        : l10n.categoryLabelOptional,
                    errorText: _categoryError,
                  ),
                  items: [
                    if (_type == TransactionType.income)
                      DropdownMenuItem<String?>(value: null, child: Text(l10n.noCategory)),
                    for (final c in filtered)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(l10n.localizedCategoryName(c.name)),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _categoryId = v;
                    _categoryError = null;
                  }),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BillFrequency>(
              key: const ValueKey('bill_frequency_field'),
              initialValue: _frequency,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.repeatsLabel),
              items: [
                DropdownMenuItem(value: BillFrequency.monthly, child: Text(l10n.frequencyMonthly)),
                DropdownMenuItem(value: BillFrequency.everyCycle, child: Text(l10n.frequencyEveryCycle)),
                DropdownMenuItem(value: BillFrequency.weekly, child: Text(l10n.frequencyWeekly)),
                DropdownMenuItem(value: BillFrequency.yearly, child: Text(l10n.frequencyYearly)),
              ],
              onChanged: (v) => setState(() => _frequency = v ?? _frequency),
            ),
            const SizedBox(height: 8),
            if (_frequency == BillFrequency.everyCycle)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.everyCycleHint(startDay),
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              )
            else
              ListTile(
                key: const ValueKey('bill_due_date_tile'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text(l10n.nextDueDateLabel, style: const TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('EEE, d MMM yyyy').format(_dueDate)),
                onTap: _pickDate,
              ),
            DropdownButtonFormField<int?>(
              key: const ValueKey('bill_reminder_field'),
              initialValue: _remindDaysBefore,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.reminderLabel),
              items: [
                for (final d in _reminderChoices)
                  DropdownMenuItem<int?>(value: d, child: Text(l10n.reminderOption(d))),
              ],
              onChanged: (v) => setState(() => _remindDaysBefore = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.noteOptional),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('bill_save_button'),
              style: FilledButton.styleFrom(
                backgroundColor: context.primaryColor,
                foregroundColor: context.onPrimaryColor,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? l10n.update : l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
