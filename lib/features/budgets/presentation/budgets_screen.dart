import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/bills/presentation/bills_screen.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';

/// Unified Category & Budget Envelope Management Screen.
/// Combines category definition with budget cycle allocation and default monthly targets.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  CategoryType _selectedType = CategoryType.expense;

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    CategoryType type = _selectedType;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            type == CategoryType.expense
                ? context.l10n.addExpenseCategory
                : context.l10n.addIncomeCategory,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<CategoryType>(
                  segments: [
                    ButtonSegment(
                      value: CategoryType.expense,
                      label: Text(context.l10n.expense),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: CategoryType.income,
                      label: Text(context.l10n.income),
                      icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (set) {
                    setDialogState(() => type = set.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.categoryNameLabel,
                    hintText: type == CategoryType.expense
                        ? context.l10n.groceriesGymHint
                        : context.l10n.salaryFreelanceHint,
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
                    labelText: type == CategoryType.expense
                        ? context.l10n.defaultAllocationLabel
                        : context.l10n.expectedIncomeLabel,
                    hintText: '0.00',
                  ),
                ),
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
                    setDialogState(() => errorMessage = context.l10n.enterValidAmount);
                    return;
                  }
                  if (p.isNegative) {
                    setDialogState(() => errorMessage = context.l10n.amountCannotBeNegative);
                    return;
                  }
                  budget = p;
                }

                try {
                  final catRepo = ref.read(categoryRepositoryProvider);
                  await catRepo.createCategory(
                    name: name,
                    type: type,
                    defaultBudget: budget,
                  );
                  if (type == CategoryType.expense &&
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
                  setDialogState(() => errorMessage = context.l10n.failedToCreate(e.toString()));
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryEnvelopeDialog({
    required BudgetCycle cycle,
    required CategoryBudget budget,
    required Category category,
  }) {
    final nameController = TextEditingController(text: category.name);
    final cycleBudgetController = TextEditingController(
      text: budget.budgetedAmount.inMinorUnits == 0
          ? ''
          : budget.budgetedAmount.toFormattedString(includeCurrency: false),
    );
    bool updateDefaultAllocation = false;
    String? errorMessage;
    final isSavings = category.name.trim().toLowerCase() == 'savings' ||
        category.name.trim() == 'مدخرات';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.editBudgetForCategory(context.l10n.localizedCategoryName(category.name))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.l10n.cycleLabel} ${cycle.formattedRange}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                if (isSavings) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.incomeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: context.incomeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      context.l10n.isArabic
                          ? 'تستوعب المدخرات تلقائياً الدخل غير المخصص للدورة (إجمالي الدخل ناقص ميزانيات الفئات الأخرى).'
                          : 'Savings automatically absorbs unallocated cycle income (Total Income minus other category budgets).',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: context.incomeColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],

                // Budget for cycle
                TextField(
                  controller: cycleBudgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.budgetAmountForCycle,
                    hintText: '0.00',
                    suffixText: context.l10n.currencySymbol,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),

                // Category Name field
                TextField(
                  controller: nameController,
                  enabled: !isSavings,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.categoryNameLabel,
                    errorText: errorMessage,
                  ),
                ),
                const SizedBox(height: 14),

                // Default allocation indicator
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: context.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.defaultAllocationText(
                        category.defaultBudget.toFormattedString(includeCurrency: false),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Checkbox to update default allocation
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: updateDefaultAllocation,
                  title: Text(
                    context.l10n.updateDefaultAllocationForFuture,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: context.primaryColor,
                  onChanged: (val) {
                    setDialogState(
                      () => updateDefaultAllocation = val ?? false,
                    );
                  },
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? context.warningLightColor.withValues(alpha: 0.65)
                        : context.warningLightColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.warningColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    updateDefaultAllocation
                        ? context.l10n.cycleAppliesUpcomingNote
                        : context.l10n.cycleAppliesCurrentOnlyNote(cycle.shortLabel),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: context.isDark
                          ? context.warningColor
                          : context.warningColor,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!isSavings)
              TextButton(
                onPressed: () => _confirmDeleteCategory(category),
                style: TextButton.styleFrom(foregroundColor: context.overspentColor),
                child: Text(context.l10n.delete),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = cycleBudgetController.text.trim();
                final Money parsed;
                if (text.isEmpty) {
                  parsed = const Money.zero();
                } else {
                  final p = Money.tryParse(text);
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
                  parsed = p;
                }

                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  setDialogState(() => errorMessage = context.l10n.nameRequired);
                  return;
                }

                try {
                  final cycleRepo = ref.read(budgetCycleRepositoryProvider);
                  final catRepo = ref.read(categoryRepositoryProvider);

                  // Update name if changed
                  if (newName != category.name && !isSavings) {
                    await catRepo.updateCategory(id: category.id, name: newName);
                  }

                  // Update cycle budget
                  await cycleRepo.updateCategoryBudget(
                    cycleId: cycle.id,
                    categoryId: budget.categoryId,
                    budgetAmount: parsed,
                    updateDefaultAllocation: updateDefaultAllocation,
                  );

                  // If category updated was not Savings, rebalance Savings allocation
                  if (!isSavings) {
                    await ref
                        .read(savingsSyncServiceProvider)
                        .syncSavingsBudgetForCycle(cycleId: cycle.id);
                  }

                  // Budgets changed (this one and possibly Savings): fire or
                  // re-arm 80% / over-budget alerts accordingly.
                  await ref.read(budgetAlertServiceProvider).reevaluate(cycle);

                  ref.read(refreshTriggerProvider.notifier).trigger();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialogState(() => errorMessage = context.l10n.failedToSave(e.toString()));
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditIncomeCategoryDialog(Category category) {
    final nameController = TextEditingController(text: category.name);
    final expectedIncomeController = TextEditingController(
      text: category.defaultBudget.inMinorUnits == 0
          ? ''
          : category.defaultBudget.toFormattedString(includeCurrency: false),
    );
    String? errorMessage;

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
                  controller: expectedIncomeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.expectedIncomeLabel,
                    hintText: '0.00',
                    suffixText: context.l10n.currencySymbol,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _confirmDeleteCategory(category),
              style: TextButton.styleFrom(foregroundColor: context.overspentColor),
              child: Text(context.l10n.delete),
            ),
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
                final text = expectedIncomeController.text.trim();
                if (text.isNotEmpty) {
                  final p = Money.tryParse(text);
                  if (p == null) {
                    setDialogState(() => errorMessage = context.l10n.enterValidAmount);
                    return;
                  }
                  budget = p;
                }

                try {
                  await ref.read(categoryRepositoryProvider).updateCategory(
                    id: category.id,
                    name: name,
                    defaultBudget: budget,
                  );
                  ref.read(refreshTriggerProvider.notifier).trigger();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDialogState(() => errorMessage = context.l10n.failedToSave(e.toString()));
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(Category category) {
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
              foregroundColor: context.onOverspentColor,
            ),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);
              final ctxNav = Navigator.of(ctx);
              final failedToDeleteFn = context.l10n.failedToDelete;
              final overspentColor = context.overspentColor;

              try {
                await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
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
                ctxNav.pop(); // Close confirmation
                nav.pop(); // Close edit dialog
              } catch (e) {
                ctxNav.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(failedToDeleteFn(e.toString())),
                    backgroundColor: overspentColor,
                  ),
                );
              }
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCycleAsync = ref.watch(currentCycleProvider);
    final selectedCycle = ref.watch(selectedCycleProvider);
    final allCyclesAsync = ref.watch(allCyclesProvider);
    final allCategoriesAsync = ref.watch(allCategoriesProvider);

    final activeCycle = selectedCycle ?? currentCycleAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navBudgets),
        actions: [
          IconButton(
            key: const ValueKey('budgets_open_bills'),
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: context.l10n.billsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BillsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: context.l10n.addCategory,
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Cycle Switcher Dropdown
          allCyclesAsync.when(
            skipLoadingOnReload: true,
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
            data: (cycles) {
              if (cycles.isEmpty) return const SizedBox.shrink();
              final current = (activeCycle != null &&
                      cycles.any((c) => c.id == activeCycle.id))
                  ? activeCycle
                  : cycles.first;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                // Light: blend with the paper app bar; dark keeps the lifted surface.
                color: context.isDark ? context.surfaceColor : context.backgroundColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.budgetCycleLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    DropdownButton<String>(
                      value: current.id,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.keyboard_arrow_down),
                      items: cycles.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.formattedRange,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        final found = cycles.firstWhere((c) => c.id == id);
                        ref.read(selectedCycleProvider.notifier).select(found);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),

          // 2. Envelopes Type Segmented Switcher (Expenses vs Income)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<CategoryType>(
                segments: [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text(context.l10n.expenseEnvelopes),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text(context.l10n.incomeSources),
                    icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedType = set.first);
                },
              ),
            ),
          ),

          // 3. Envelope List
          Expanded(
            child: activeCycle == null
                ? const Center(child: CircularProgressIndicator())
                : _selectedType == CategoryType.expense
                    ? _buildExpenseEnvelopesList(activeCycle, allCategoriesAsync)
                    : _buildIncomeSourcesList(activeCycle, allCategoriesAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseEnvelopesList(
    BudgetCycle activeCycle,
    AsyncValue<List<Category>> allCategoriesAsync,
  ) {
    final summaryAsync = ref.watch(cycleSummaryProvider(activeCycle));

    return summaryAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${context.l10n.error}: $err')),
      data: (summary) {
        if (summary.categoryBudgets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 48,
                    color: context.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.noExpenseCategoriesFound,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.createCategoriesToTrackDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.addCategory),
                    onPressed: _showAddCategoryDialog,
                  ),
                ],
              ),
            ),
          );
        }

        final categoriesMap = <String, Category>{};
        if (allCategoriesAsync.hasValue && allCategoriesAsync.value != null) {
          for (final c in allCategoriesAsync.value!) {
            categoriesMap[c.id] = c;
          }
        }

        return ListView.builder(
          key: PageStorageKey('cycle_budgets_list_${activeCycle.id}'),
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          itemCount: summary.categoryBudgets.length + 1,
          itemBuilder: (context, index) {
            if (index == summary.categoryBudgets.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.l10n.addAnotherCategory),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _showAddCategoryDialog,
                ),
              );
            }

            final b = summary.categoryBudgets[index];
            final category = categoriesMap[b.categoryId] ??
                Category(
                  id: b.categoryId,
                  name: b.categoryName,
                  type: CategoryType.expense,
                  defaultBudget: b.budgetedAmount,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

            final isOverspent = b.isOverspent;
            final pct = b.usagePercentage;
            final hasBudget = b.budgetedAmount.inMinorUnits > 0;

            Color statusColor;
            if (b.isAtOrOverLimit) {
              statusColor = context.overspentColor;
            } else if (b.isNearLimit) {
              statusColor = context.warningColor;
            } else {
              statusColor = context.primaryColor;
            }

            final isCustomForCycle = hasBudget &&
                category.defaultBudget.inMinorUnits > 0 &&
                b.budgetedAmount != category.defaultBudget;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showEditCategoryEnvelopeDialog(
                  cycle: activeCycle,
                  budget: b,
                  category: category,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Title, status chip, and edit button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  context.l10n.localizedCategoryName(b.categoryName),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                                if (isCustomForCycle) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.primaryLightColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Cycle',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: context.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: context.l10n.editBudget,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showEditCategoryEnvelopeDialog(
                              cycle: activeCycle,
                              budget: b,
                              category: category,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Spent vs Budgeted Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.spentPrefix(
                              b.spentAmount.toFormattedString(includeCurrency: false),
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            hasBudget
                                ? b.budgetedAmount.toFormattedString(includeCurrency: false)
                                : context.l10n.noBudgetSetShort,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: hasBudget
                                  ? context.textSecondary
                                  : context.overspentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Linear Progress Indicator
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: hasBudget
                              ? (pct! / 100.0).clamp(0.0, 1.0)
                              : (b.spentAmount.inMinorUnits > 0 ? 1.0 : 0.0),
                          backgroundColor: context.surfaceVariantColor,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Info: Remaining & Default allocation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.defaultAllocationText(
                              category.defaultBudget.toFormattedString(includeCurrency: false),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                            ),
                          ),
                          Text(
                            isOverspent
                                ? context.l10n.overAmount(
                                    (-b.remainingAmount).toFormattedString(includeCurrency: false),
                                  )
                                : (hasBudget
                                    ? b.remainingAmount.toFormattedString(
                                        includeCurrency: false,
                                        showSign: true,
                                      )
                                    : (b.spentAmount.inMinorUnits > 0
                                        ? context.l10n.noBudgetSet
                                        : '')),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIncomeSourcesList(
    BudgetCycle activeCycle,
    AsyncValue<List<Category>> allCategoriesAsync,
  ) {
    final incomeCategoriesAsync = ref.watch(incomeCategoriesProvider);

    return incomeCategoriesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('${context.l10n.error}: $e')),
      data: (incomeCategories) {
        if (incomeCategories.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: context.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.incomeSources,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.addIncomeCategory),
                    onPressed: _showAddCategoryDialog,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          key: const PageStorageKey('income_sources_list'),
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          itemCount: incomeCategories.length + 1,
          itemBuilder: (context, index) {
            if (index == incomeCategories.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.l10n.addIncomeCategory),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _showAddCategoryDialog,
                ),
              );
            }

            final cat = incomeCategories[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showEditIncomeCategoryDialog(cat),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.incomeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          color: context.incomeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.localizedCategoryName(cat.name),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.expectedIncomeText(
                                cat.defaultBudget.toFormattedString(includeCurrency: false),
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: context.l10n.edit,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showEditIncomeCategoryDialog(cat),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
