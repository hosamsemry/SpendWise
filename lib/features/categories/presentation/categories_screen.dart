import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const CategoriesScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType _selectedType = CategoryType.expense;

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    String? errorMessage;
    final isExpense = _selectedType == CategoryType.expense;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isExpense ? context.l10n.addExpenseCategory : context.l10n.addIncomeCategory,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: isExpense
                      ? context.l10n.expenseCategoryNameLabel
                      : context.l10n.incomeCategoryNameLabel,
                  hintText: isExpense
                      ? context.l10n.healthPharmacyHint
                      : context.l10n.freelanceDesignHint,
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
                  labelText: isExpense
                      ? context.l10n.defaultAllocationLabel
                      : context.l10n.expectedIncomeLabel,
                  hintText: '0.00',
                  helperText: isExpense
                      ? context.l10n.defaultBudgetDesc
                      : context.l10n.defaultIncomeDesc,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
                    setDialogState(
                      () => errorMessage = context.l10n.enterValidAmount,
                    );
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
                  await categoryRepo.createCategory(
                    name: name,
                    type: _selectedType,
                    defaultBudget: budget,
                  );
                  if (_selectedType == CategoryType.expense &&
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
                  if (ctx.mounted) Navigator.pop(ctx);
                } on DuplicateCategoryNameException catch (e) {
                  setDialogState(() => errorMessage = e.message);
                } catch (e) {
                  setDialogState(
                    () => errorMessage = context.l10n.failedToCreate(e.toString()),
                  );
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    final nameController = TextEditingController(text: category.name);
    final budgetController = TextEditingController(
      text: category.defaultBudget.inMinorUnits == 0
          ? ''
          : category.defaultBudget.toFormattedString(includeCurrency: false),
    );
    String? errorMessage;
    final isExpense = category.type == CategoryType.expense;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.editCategoryName(category.name)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.categoryNameLabel,
                    errorText: errorMessage,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: isExpense
                        ? context.l10n.defaultAllocationLabel
                        : context.l10n.expectedIncomeLabel,
                    hintText: '0.00',
                    helperText: isExpense
                        ? context.l10n.defaultBudgetDesc
                        : context.l10n.defaultIncomeDesc,
                  ),
                ),
                if (isExpense) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.isDark
                          ? context.primaryLightColor.withValues(alpha: 0.5)
                          : context.primaryLightColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.isDark
                            ? context.primaryColor.withValues(alpha: 0.35)
                            : context.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: context.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.editingDefaultBudgetNote,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.isDark
                                  ? context.textPrimary
                                  : context.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
                    setDialogState(
                      () => errorMessage = context.l10n.enterValidAmount,
                    );
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
                  await categoryRepo.updateCategory(
                    id: category.id,
                    name: name,
                    defaultBudget: budget,
                  );
                  if (isExpense && budget != category.defaultBudget) {
                    final cycle = await ref
                        .read(budgetCycleRepositoryProvider)
                        .getCycleForDateOrNull(DateTime.now());
                    if (cycle != null) {
                      await ref
                          .read(budgetCycleRepositoryProvider)
                          .updateCategoryBudget(
                            cycleId: cycle.id,
                            categoryId: category.id,
                            budgetAmount: budget,
                          );
                      if (name.toLowerCase() != 'savings' && name != 'مدخرات') {
                        await ref
                            .read(savingsSyncServiceProvider)
                            .syncSavingsBudgetForCycle(cycleId: cycle.id);
                      }
                    }
                  }
                  ref.read(refreshTriggerProvider.notifier).trigger();
                  if (ctx.mounted) Navigator.pop(ctx);
                } on DuplicateCategoryNameException catch (e) {
                  setDialogState(() => errorMessage = e.message);
                } catch (e) {
                  setDialogState(
                    () => errorMessage = context.l10n.failedToUpdate(e.toString()),
                  );
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteCategoryName(category.name)),
        content: Text(context.l10n.deleteCategoryConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.overspentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final repo = ref.read(categoryRepositoryProvider);
              await repo.deleteCategory(category.id);
              if (category.type == CategoryType.expense &&
                  category.name.trim().toLowerCase() != 'savings' &&
                  category.name.trim() != 'مدخرات') {
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
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(context.l10n.tabCategories),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        heroTag: 'categories_add_fab',
        tooltip: _selectedType == CategoryType.expense
            ? context.l10n.addExpenseCategory
            : context.l10n.addIncomeCategory,
        onPressed: _showAddCategoryDialog,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented switch between Expense and Income
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<CategoryType>(
                  segments: [
                    ButtonSegment(
                      value: CategoryType.expense,
                      label: Text(context.l10n.tabExpenseCategories),
                      icon: Icon(Icons.shopping_bag_outlined),
                    ),
                    ButtonSegment(
                      value: CategoryType.income,
                      label: Text(context.l10n.tabIncomeCategories),
                      icon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedType = set.first;
                    });
                  },
                ),
              ),
            ),

            // Category List
            Expanded(
              child: categoriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(color: context.overspentColor),
                  ),
                ),
                data: (categories) {
                  final filtered = categories
                      .where((c) =>
                          _selectedType == CategoryType.expense
                              ? c.type.isExpense
                              : c.type.isIncome)
                      .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedType == CategoryType.expense
                                  ? Icons.shopping_bag_outlined
                                  : Icons.account_balance_wallet_outlined,
                              size: 56,
                              color: context.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedType == CategoryType.expense
                                  ? context.l10n.noExpenseCategories
                                  : context.l10n.noIncomeCategories,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedType == CategoryType.expense
                                  ? context.l10n.noExpenseCategoriesDesc
                                  : context.l10n.noIncomeCategoriesDesc,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showAddCategoryDialog,
                              icon: const Icon(Icons.add),
                              label: Text(
                                _selectedType == CategoryType.expense
                                    ? context.l10n.addFirstExpenseCategory
                                    : context.l10n.addFirstIncomeCategory,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      96 + MediaQuery.of(context).padding.bottom,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final cat = filtered[index];

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          title: Text(
                            context.l10n.localizedCategoryName(cat.name),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: context.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            cat.type.isExpense
                                ? context.l10n.defaultBudgetPrefix(cat.defaultBudget.toFormattedString())
                                : (cat.defaultBudget.inMinorUnits > 0
                                    ? context.l10n.expectedIncomePrefix(cat.defaultBudget.toFormattedString())
                                    : context.l10n.incomeCategorySubtitle),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                ),
                                tooltip: context.l10n.edit,
                                onPressed: () =>
                                    _showEditCategoryDialog(cat),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: context.overspentColor,
                                ),
                                tooltip: context.l10n.delete,
                                onPressed: () =>
                                    _showDeleteCategoryDialog(cat),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
