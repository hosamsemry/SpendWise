import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/categories/presentation/categories_screen.dart';
import 'package:money_tracker/features/reports/presentation/reports_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    CategoryType selectedType = CategoryType.expense;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            selectedType == CategoryType.expense
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
                      icon: Icon(Icons.shopping_bag_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: CategoryType.income,
                      label: Text(context.l10n.income),
                      icon: Icon(Icons.account_balance_wallet_outlined, size: 16),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (set) {
                    setDialogState(() => selectedType = set.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.categoryNameLabel,
                    hintText: selectedType == CategoryType.expense ? context.l10n.groceriesGymHint : context.l10n.salaryFreelanceHint,
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
                    labelText: selectedType == CategoryType.expense
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
                    type: selectedType,
                    defaultBudget: budget,
                  );
                  ref.read(refreshTriggerProvider.notifier).trigger();
                  if (ctx.mounted) Navigator.pop(ctx);
                } on DuplicateCategoryNameException catch (e) {
                  setDialogState(() => errorMessage = e.message);
                } catch (e) {
                  setDialogState(() => errorMessage = context.l10n.failedToCreate(e.toString()));
                }
              },
              child: Text(context.l10n.create),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    BudgetCycle cycle,
    CategoryBudget budget,
  ) {
    final controller = TextEditingController(
      text: budget.budgetedAmount.inMinorUnits == 0
          ? ''
          : budget.budgetedAmount.toFormattedString(includeCurrency: false),
    );
    bool updateDefaultAllocation = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.editBudgetForCategory(context.l10n.localizedCategoryName(budget.categoryName))),
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
                if (budget.categoryName.trim().toLowerCase() == 'savings' ||
                    budget.categoryName.trim() == 'مدخرات') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      context.l10n.isArabic
                          ? 'تستوعب المدخرات تلقائياً الدخل غير المخصص للدورة (إجمالي الدخل ناقص ميزانيات الفئات الأخرى).'
                          : 'Savings automatically absorbs unallocated cycle income (Total Income minus other category budgets).',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF047857),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.l10n.budgetAmountForCycle,
                    hintText: '0.00',
                    errorText: errorMessage,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: updateDefaultAllocation,
                  title: Text(
                    context.l10n.updateDefaultAllocationForFuture,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    updateDefaultAllocation
                        ? context.l10n.cycleAppliesUpcomingNote
                        : context.l10n.cycleAppliesCurrentOnlyNote(cycle.shortLabel),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                      height: 1.3,
                    ),
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
                final text = controller.text.trim();
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

                try {
                  final cycleRepo = ref.read(budgetCycleRepositoryProvider);

                  await cycleRepo.updateCategoryBudget(
                    cycleId: cycle.id,
                    categoryId: budget.categoryId,
                    budgetAmount: parsed,
                    updateDefaultAllocation: updateDefaultAllocation,
                  );

                  // If category updated was not Savings, rebalance Savings allocation
                  final nameLower = budget.categoryName.trim().toLowerCase();
                  if (nameLower != 'savings' && nameLower != 'مدخرات') {
                    await ref
                        .read(savingsSyncServiceProvider)
                        .syncSavingsBudgetForCycle(cycleId: cycle.id);
                  }

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

  Widget _buildBudgetsTab(
    BuildContext context,
    WidgetRef ref,
    BudgetCycle? activeCycle,
    AsyncValue<List<BudgetCycle>> allCyclesAsync,
  ) {
    return Column(
      children: [
        // Cycle Switcher Dropdown
        allCyclesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
          data: (cycles) {
            if (cycles.isEmpty) return const SizedBox.shrink();
            final current = activeCycle ?? cycles.first;

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              color: context.surfaceColor,
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

        Expanded(
          child: activeCycle == null
              ? const Center(child: CircularProgressIndicator())
              : Consumer(
                  builder: (context, ref, child) {
                    final summaryAsync = ref.watch(
                      cycleSummaryProvider(activeCycle),
                    );

                    return summaryAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          Center(child: Text('${context.l10n.error}: $err')),
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
                                    onPressed: () =>
                                        _showAddCategoryDialog(context, ref),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
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
                                  onPressed: () =>
                                      _showAddCategoryDialog(context, ref),
                                ),
                              );
                            }

                            final b = summary.categoryBudgets[index];
                            final isOverspent = b.isOverspent;
                            final pct = b.usagePercentage;
                            final hasBudget =
                                b.budgetedAmount.inMinorUnits > 0;

                            Color statusColor;
                            if (isOverspent) {
                              statusColor = context.overspentColor;
                            } else if (b.isNearLimit) {
                              statusColor = Colors.amber;
                            } else {
                              statusColor = context.primaryColor;
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Category Title and Edit Icon
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              context.l10n.localizedCategoryName(b.categoryName),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                            if (b.categoryName.trim().toLowerCase() ==
                                                    'savings' ||
                                                b.categoryName.trim() ==
                                                    'مدخرات') ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  context.l10n.autoBalancedBadge,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                          ),
                                          tooltip: context.l10n.editBudget,
                                          onPressed: () =>
                                              _showEditBudgetDialog(
                                                context,
                                                ref,
                                                activeCycle,
                                                b,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Progress Bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: hasBudget
                                            ? (pct! / 100.0).clamp(0.0, 1.0)
                                            : (b.spentAmount.inMinorUnits > 0
                                                  ? 1.0
                                                  : 0.0),
                                        backgroundColor: context.isDark
                                            ? const Color(0xFF334155)
                                            : Colors.grey.shade200,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              statusColor,
                                            ),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Budget Metrics Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.l10n.budgetedAmount,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    context.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              b.budgetedAmount
                                                  .toFormattedString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              context.l10n.spent,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    context.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              b.spentAmount
                                                  .toFormattedString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              isOverspent
                                                  ? context.l10n.overspent
                                                  : context.l10n.remaining,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              b.remainingAmount
                                                  .toFormattedString(
                                                    showSign: true,
                                                  ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: statusColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Percentage indicator tag
                                    if (hasBudget) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        context.l10n.percentUsed(pct!.toStringAsFixed(1)),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: statusColor,
                                        ),
                                      ),
                                    ] else if (b.spentAmount.inMinorUnits >
                                        0) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        context.l10n.noBudgetSet,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: context.overspentColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCycleAsync = ref.watch(currentCycleProvider);
    final selectedCycle = ref.watch(selectedCycleProvider);
    final allCyclesAsync = ref.watch(allCyclesProvider);

    final activeCycle = selectedCycle ?? currentCycleAsync.value;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.budgetsAndInsights),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: context.l10n.addCategory,
              onPressed: () => _showAddCategoryDialog(context, ref),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.pie_chart_rounded, size: 18),
                text: context.l10n.tabCycleBudgets,
              ),
              Tab(
                icon: const Icon(Icons.category_rounded, size: 18),
                text: context.l10n.tabCategories,
              ),
              Tab(
                icon: const Icon(Icons.bar_chart_rounded, size: 18),
                text: context.l10n.tabInsights,
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBudgetsTab(context, ref, activeCycle, allCyclesAsync),
            const CategoriesScreen(showAppBar: false),
            const ReportsScreen(showAppBar: false),
          ],
        ),
      ),
    );
  }
}
