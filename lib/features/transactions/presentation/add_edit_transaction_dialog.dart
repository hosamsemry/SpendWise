import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/math_expression_evaluator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/presets/domain/transaction_preset.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

class AddEditTransactionDialog extends ConsumerStatefulWidget {
  final TransactionModel? initialTransaction;
  final TransactionPreset? initialPreset;
  final TransactionType defaultType;

  const AddEditTransactionDialog({
    super.key,
    this.initialTransaction,
    this.initialPreset,
    this.defaultType = TransactionType.expense,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionModel? transaction,
    TransactionPreset? preset,
    TransactionType defaultType = TransactionType.expense,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditTransactionDialog(
        initialTransaction: transaction,
        initialPreset: preset,
        defaultType: defaultType,
      ),
    );
  }

  @override
  ConsumerState<AddEditTransactionDialog> createState() =>
      _AddEditTransactionDialogState();
}

class _AddEditTransactionDialogState
    extends ConsumerState<AddEditTransactionDialog> {
  late TransactionType _type;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  String? _selectedCategoryId;
  late DateTime _selectedDate;
  String? _amountError;
  String? _categoryError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    final preset = widget.initialPreset;
    _type = tx?.type ?? preset?.type ?? widget.defaultType;
    _amountController = TextEditingController(
      text: tx != null
          ? tx.amount.toFormattedString(includeCurrency: false)
          : preset != null
          ? preset.amount.toFormattedString(includeCurrency: false)
          : '',
    );
    _noteController = TextEditingController(
      text: tx?.note ?? preset?.note ?? '',
    );
    _selectedCategoryId = tx?.categoryId ?? preset?.categoryId;
    _selectedDate = tx?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showQuickAddCategoryDialog(
    BuildContext context,
    CategoryType categoryType,
  ) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            categoryType == CategoryType.expense
                ? context.l10n.newExpenseCategory
                : context.l10n.newIncomeCategory,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.categoryNameLabel,
                  hintText: context.l10n.groceriesHint,
                  errorText: errorMessage,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: categoryType == CategoryType.expense
                      ? context.l10n.defaultAllocationLabel
                      : context.l10n.expectedIncomeLabel,
                  hintText: '0.00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorMessage = context.l10n.nameRequired);
                  return;
                }

                Money budget = const Money.zero();
                final budgetText = budgetController.text.trim();
                if (budgetText.isNotEmpty) {
                  final p = Money.tryParse(budgetText);
                  if (p == null) {
                    setDialogState(() => errorMessage = context.l10n.enterValidAmount);
                    return;
                  }
                  if (p.isNegative) {
                    setDialogState(
                      () => errorMessage = context.l10n.amountCannotBeNegative,
                    );
                    return;
                  }
                  budget = p;
                }

                final categoryRepo = ref.read(categoryRepositoryProvider);
                try {
                  final created = await categoryRepo.createCategory(
                    name: name,
                    type: categoryType,
                    defaultBudget: budget,
                  );
                  if (categoryType == CategoryType.expense &&
                      name.toLowerCase() != 'savings' &&
                      name != 'مدخرات') {
                    final cycle = await ref
                        .read(budgetCycleRepositoryProvider)
                        .getCycleForDateOrNull(DateTime.now());
                    if (cycle != null) {
                      await ref
                          .read(savingsSyncServiceProvider)
                          .syncSavingsBudgetForCycle(cycleId: cycle.id);
                    }
                  }
                  ref.read(refreshTriggerProvider.notifier).trigger();
                  if (mounted) {
                    setState(() {
                      _selectedCategoryId = created.id;
                      _categoryError = null;
                      if (_amountController.text.trim().isEmpty &&
                          created.defaultBudget.inMinorUnits > 0) {
                        _amountController.text = created.defaultBudget
                            .toFormattedString(includeCurrency: false);
                      }
                    });
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                } on DuplicateCategoryNameException catch (e) {
                  setDialogState(() => errorMessage = e.message);
                } catch (e) {
                  setDialogState(
                    () => errorMessage = context.l10n.failedToCreate(e.toString()),
                  );
                }
              },
              child: Text(context.l10n.create),
            ),
          ],
        ),
      ),
    );
  }

  Money? _tryParseAmountOrExpression(String input) {
    return MathExpressionEvaluator.tryEvaluate(input);
  }

  Future<void> _saveTransaction(List<Category> categories) async {
    setState(() {
      _amountError = null;
      _categoryError = null;
    });

    final amountText = _amountController.text.trim();
    final parsedAmount = _tryParseAmountOrExpression(amountText);

    if (parsedAmount == null || parsedAmount.inMinorUnits <= 0) {
      final normalizedRaw = Money.normalizeDigits(amountText)
          .replaceAll(',', '')
          .replaceAll('،', '')
          .replaceAll('٫', '.');
      final numVal = double.tryParse(normalizedRaw);
      if (numVal != null && numVal > Money.maxMajorUnits) {
        setState(() => _amountError = context.l10n.amountExceedsLimit);
      } else {
        setState(() => _amountError = context.l10n.enterValidAmountOrExpr);
      }
      return;
    }

    // Auto-update amount field to the evaluated clean value
    _amountController.text = parsedAmount.toFormattedString(
      includeCurrency: false,
    );

    if (_type == TransactionType.expense &&
        (_selectedCategoryId == null || _selectedCategoryId!.isEmpty)) {
      setState(
        () => _categoryError = context.l10n.selectCategoryForExpense,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final txRepo = ref.read(transactionRepositoryProvider);
      final cycleRepo = ref.read(budgetCycleRepositoryProvider);
      final thresholdMonitor = ref.read(thresholdMonitorProvider);
      final calcService = ref.read(budgetCalculationServiceProvider);

      if (widget.initialTransaction == null) {
        // Create
        await txRepo.addTransaction(
          type: _type,
          amount: parsedAmount,
          categoryId: _selectedCategoryId,
          date: _selectedDate,
          note: _noteController.text,
        );
      } else {
        // Update
        await txRepo.updateTransaction(
          id: widget.initialTransaction!.id,
          type: _type,
          amount: parsedAmount,
          categoryId: _selectedCategoryId,
          date: _selectedDate,
          note: _noteController.text,
        );
      }

      // Check budget thresholds if expense and cycle already exists
      if (_type == TransactionType.expense && _selectedCategoryId != null) {
        final cycle = await cycleRepo.getCycleForDateOrNull(_selectedDate);
        if (cycle != null) {
          final budgetMap = await cycleRepo.getCycleBudgets(cycle.id);
          final cycleTxs = await txRepo.getTransactionsForCycle(cycle);
          final allCategories = await ref
              .read(categoryRepositoryProvider)
              .getAllCategories(includeInactive: true);

          final summary = calcService.calculateCycleSummary(
            cycle: cycle,
            categories: allCategories,
            budgetMap: budgetMap,
            transactions: cycleTxs,
          );

          final categoryBudget = summary.categoryBudgets.firstWhere(
            (b) => b.categoryId == _selectedCategoryId,
            orElse: () => CategoryBudget(
              categoryId: _selectedCategoryId!,
              categoryName: categories
                  .firstWhere(
                    (c) => c.id == _selectedCategoryId,
                    orElse: () => Category(
                      id: _selectedCategoryId!,
                      name: '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  )
                  .name,
              budgetedAmount: const Money.zero(),
              spentAmount: parsedAmount,
            ),
          );

          await thresholdMonitor.evaluateAndNotify(
            cycleId: cycle.id,
            budget: categoryBudget,
          );
        }
      }

      // If income was logged or edited, rebalance Savings allocation
      final bool wasIncome = widget.initialTransaction?.isIncome == true;
      final bool isIncome = _type == TransactionType.income;

      if (wasIncome || isIncome) {
        // Sync for current selected date cycle
        final cycle = await cycleRepo.getOrCreateCycleForDate(_selectedDate);
        await ref
            .read(savingsSyncServiceProvider)
            .syncSavingsBudgetForCycle(cycleId: cycle.id);

        // If previously income and date or type changed, sync old cycle too
        if (wasIncome && widget.initialTransaction != null) {
          final oldDate = widget.initialTransaction!.date;
          final oldCycle = await cycleRepo.getCycleForDateOrNull(oldDate);
          if (oldCycle != null && oldCycle.id != cycle.id) {
            await ref
                .read(savingsSyncServiceProvider)
                .syncSavingsBudgetForCycle(cycleId: oldCycle.id);
          }
        }
      }

      ref.read(refreshTriggerProvider.notifier).trigger();
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorSavingTransaction(e.toString()))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialTransaction != null
                      ? context.l10n.editTransaction
                      : context.l10n.addTransaction,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Segmented toggle: Expense / Income
            SegmentedButton<TransactionType>(
              segments: [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text(context.l10n.expense),
                  icon: Icon(Icons.arrow_upward, size: 18),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text(context.l10n.income),
                  icon: Icon(Icons.arrow_downward, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                final newType = set.first;
                setState(() {
                  _type = newType;
                  _selectedCategoryId =
                      null; // Clear category when toggling type
                  _categoryError = null;
                });
              },
            ),
            const SizedBox(height: 20),

            // Amount field
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: widget.initialTransaction == null,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: context.l10n.amountLabelWithCurrency,
                prefixText: '${context.l10n.currencySymbol} ',
                prefixStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 16),

            // Category selector (Required for expense; optional for income)
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('${context.l10n.error}: $e'),
              data: (categories) {
                // Filter categories matching current transaction type
                final typeFiltered = categories.where((c) {
                  return _type == TransactionType.expense
                      ? c.type.isExpense
                      : c.type.isIncome;
                }).toList();

                final categoryType = _type == TransactionType.expense
                    ? CategoryType.expense
                    : CategoryType.income;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _type == TransactionType.expense
                              ? context.l10n.categoryLabelRequired
                              : context.l10n.categoryLabelOptional,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _categoryError != null
                                ? context.overspentColor
                                : context.textSecondary,
                          ),
                        ),
                        if (_categoryError != null)
                          Text(
                            _categoryError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.overspentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_type == TransactionType.income)
                          ChoiceChip(
                            label: Text(context.l10n.uncategorized),
                            selected: _selectedCategoryId == null,
                            onSelected: (_) {
                              setState(() {
                                _selectedCategoryId = null;
                                _categoryError = null;
                              });
                            },
                          ),
                        ...typeFiltered.map((cat) {
                          final isSelected = _selectedCategoryId == cat.id;
                          return ChoiceChip(
                            label: Text(context.l10n.localizedCategoryName(cat.name)),
                            selected: isSelected,
                            selectedColor:
                                context.primaryColor.withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? context.primaryColor
                                  : context.textPrimary,
                            ),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = selected ? cat.id : null;
                                _categoryError = null;
                                if (selected &&
                                    _amountController.text.trim().isEmpty &&
                                    cat.defaultBudget.inMinorUnits > 0) {
                                  _amountController.text = cat.defaultBudget
                                      .toFormattedString(
                                        includeCurrency: false,
                                      );
                                }
                              });
                            },
                          );
                        }),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: Text(context.l10n.newLabel),
                          onPressed: () => _showQuickAddCategoryDialog(
                            context,
                            categoryType,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Date picker field
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.l10n.transactionDate,
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                ),
                child: Text(
                  DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Note field
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: context.l10n.noteOptional,
                hintText: context.l10n.noteHint,
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      final categories = categoriesAsync.value ?? [];
                      _saveTransaction(categories);
                    },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: _type == TransactionType.expense
                    ? context.primaryColor
                    : context.incomeColor,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.initialTransaction != null
                          ? context.l10n.updateTransactionButton
                          : context.l10n.saveTransactionButton,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
