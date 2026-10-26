import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'add_edit_transaction_dialog.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _isSearchVisible = false;
  bool _isFilterVisible = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteTransactionWithUndo(
    BuildContext context,
    WidgetRef ref,
    TransactionModel tx,
  ) async {
    HapticFeedback.lightImpact();
    final txRepo = ref.read(transactionRepositoryProvider);
    await txRepo.deleteTransaction(tx.id);
    if (tx.isIncome) {
      final cycleRepo = ref.read(budgetCycleRepositoryProvider);
      final cycle = await cycleRepo.getCycleForDateOrNull(tx.date);
      if (cycle != null) {
        await ref.read(savingsSyncServiceProvider).syncSavingsBudgetForCycle(
              cycleId: cycle.id,
            );
      }
    }
    ref.read(refreshTriggerProvider.notifier).trigger();

    if (!context.mounted) return;
    final name = tx.categoryName ?? (tx.isIncome ? context.l10n.income : context.l10n.expense);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.deletedTransactionNotice(name, tx.amount.toFormattedString())),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: context.l10n.undo,
          textColor: Colors.amber,
          onPressed: () async {
            HapticFeedback.lightImpact();
            await txRepo.restoreTransaction(tx);
            if (tx.isIncome) {
              final cycleRepo = ref.read(budgetCycleRepositoryProvider);
              final cycle = await cycleRepo.getCycleForDateOrNull(tx.date);
              if (cycle != null) {
                await ref.read(savingsSyncServiceProvider).syncSavingsBudgetForCycle(
                      cycleId: cycle.id,
                    );
              }
            }
            ref.read(refreshTriggerProvider.notifier).trigger();
          },
        ),
      ),
    );
  }

  String _formatDayHeader(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) {
      return context.l10n.today;
    } else if (d == yesterday) {
      return context.l10n.yesterday;
    } else {
      return DateFormat('EEE, d MMM').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCycleAsync = ref.watch(currentCycleProvider);
    final selectedCycle = ref.watch(selectedCycleProvider);
    final allCyclesAsync = ref.watch(allCyclesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final activeCycle = selectedCycle ?? currentCycleAsync.value;

    final typeFilter = ref.watch(transactionTypeFilterProvider);
    final categoryFilter = ref.watch(categoryFilterProvider);
    final searchQuery = ref.watch(noteSearchQueryProvider);
    final dateRange = ref.watch(dateRangeFilterProvider);
    final hasActiveFilters =
        typeFilter != null || categoryFilter != null || dateRange != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navTransactions),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.search_off : Icons.search),
            tooltip: _isSearchVisible ? context.l10n.closeSearch : context.l10n.searchNotes,
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  ref.read(noteSearchQueryProvider.notifier).set('');
                }
              });
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: hasActiveFilters,
              child: const Icon(Icons.tune),
            ),
            tooltip: context.l10n.filterOptions,
            onPressed: () {
              setState(() {
                _isFilterVisible = !_isFilterVisible;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.addTransaction,
            onPressed: () => AddEditTransactionDialog.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Cycle Selector Header
          allCyclesAsync.when(
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
                color: context.surfaceColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.cycleLabel,
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

          // Collapsible Search Field
          if (_isSearchVisible || searchQuery.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                autofocus: _isSearchVisible && searchQuery.isEmpty,
                decoration: InputDecoration(
                  hintText: context.l10n.searchNotesHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(noteSearchQueryProvider.notifier).set('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (val) {
                  ref.read(noteSearchQueryProvider.notifier).set(val);
                },
              ),
            ),
          ],

          // Collapsible Filters Row
          if (_isFilterVisible || hasActiveFilters) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(context.l10n.all),
                      selected: typeFilter == null,
                      onSelected: (_) {
                        ref
                            .read(transactionTypeFilterProvider.notifier)
                            .set(null);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(context.l10n.expenses),
                      selected: typeFilter == TransactionType.expense,
                      onSelected: (selected) {
                        ref
                            .read(transactionTypeFilterProvider.notifier)
                            .set(selected ? TransactionType.expense : null);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(context.l10n.income),
                      selected: typeFilter == TransactionType.income,
                      onSelected: (selected) {
                        ref
                            .read(transactionTypeFilterProvider.notifier)
                            .set(selected ? TransactionType.income : null);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: Icon(
                        dateRange != null ? Icons.close : Icons.date_range,
                        size: 16,
                      ),
                      label: Text(
                        dateRange == null
                            ? context.l10n.dateRange
                            : '${DateFormat('d MMM').format(dateRange.start)} - ${DateFormat('d MMM').format(dateRange.end)}',
                      ),
                      selected: dateRange != null,
                      onSelected: (_) async {
                        if (dateRange != null) {
                          ref
                              .read(dateRangeFilterProvider.notifier)
                              .set(null);
                        } else {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDateRange: activeCycle != null
                                ? DateTimeRange(
                                    start: activeCycle.startDate,
                                    end: activeCycle.endDate,
                                  )
                                : null,
                          );
                          if (picked != null) {
                            ref
                                .read(dateRangeFilterProvider.notifier)
                                .set(picked);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    categoriesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, s) => const SizedBox.shrink(),
                      data: (categories) {
                        final filtered = categories.where((c) {
                          if (typeFilter == null) return true;
                          return typeFilter == TransactionType.expense
                              ? c.type.isExpense
                              : c.type.isIncome;
                        }).toList();

                        return DropdownButton<String?>(
                          value: filtered.any((c) => c.id == categoryFilter)
                              ? categoryFilter
                              : null,
                          hint: Text(
                            typeFilter == TransactionType.expense
                                ? '${context.l10n.expenses}: ${context.l10n.all}'
                                : typeFilter == TransactionType.income
                                ? '${context.l10n.income}: ${context.l10n.all}'
                                : '${context.l10n.categoryLabelOptional}: ${context.l10n.all}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(context.l10n.allCategories),
                            ),
                            ...filtered.map((c) {
                              return DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(context.l10n.localizedCategoryName(c.name)),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            ref
                                .read(categoryFilterProvider.notifier)
                                .set(val);
                          },
                        );
                      },
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final prevType = typeFilter;
                          final prevCat = categoryFilter;
                          final prevRange = dateRange;

                          ref
                              .read(transactionTypeFilterProvider.notifier)
                              .set(null);
                          ref
                              .read(categoryFilterProvider.notifier)
                              .set(null);
                          ref
                              .read(dateRangeFilterProvider.notifier)
                              .set(null);

                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.filtersCleared),
                              duration: const Duration(seconds: 4),
                              action: SnackBarAction(
                                label: context.l10n.undo,
                                textColor: Colors.amber,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(transactionTypeFilterProvider.notifier)
                                      .set(prevType);
                                  ref
                                      .read(categoryFilterProvider.notifier)
                                      .set(prevCat);
                                  ref
                                      .read(dateRangeFilterProvider.notifier)
                                      .set(prevRange);
                                },
                              ),
                            ),
                          );
                        },
                        child: Text(context.l10n.reset),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Transactions List
          Expanded(
            child: activeCycle == null
                ? const Center(child: CircularProgressIndicator())
                : Consumer(
                    builder: (context, ref, child) {
                      final txsAsync = ref.watch(
                        transactionsForCycleProvider(activeCycle),
                      );

                      return txsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) =>
                            Center(child: Text('${context.l10n.error}: $err')),
                        data: (transactions) {
                          if (transactions.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.l10n.noTransactionsFound,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () =>
                                        AddEditTransactionDialog.show(context),
                                    icon: const Icon(Icons.add),
                                    label: Text(context.l10n.addTransaction),
                                  ),
                                ],
                              ),
                            );
                          }

                          final dayGroups = groupTransactionsByDay(transactions);

                          return ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              24 + MediaQuery.of(context).padding.bottom,
                            ),
                            itemCount: dayGroups.length,
                            itemBuilder: (context, groupIndex) {
                              final group = dayGroups[groupIndex];
                              final hasExpenses = group.totalSpent.inMinorUnits > 0;
                              final hasIncome = group.totalIncome.inMinorUnits > 0;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      4,
                                      groupIndex == 0 ? 4 : 16,
                                      4,
                                      8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_outlined,
                                              size: 13,
                                              color: context.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatDayHeader(context, group.date),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                                color: context.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              DateFormat(
                                                'd MMM yyyy',
                                              ).format(group.date),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: context.textSecondary
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (hasExpenses)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.isDark
                                                  ? const Color(0xFF334155)
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              context.l10n.spentPrefix(group.totalSpent.toFormattedString()),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                          )
                                        else if (hasIncome)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: context.incomeLightColor,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              context.l10n.incomePrefix(group.totalIncome.toFormattedString()),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: context.incomeColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  ...group.transactions.map((tx) {
                                    final isIncome = tx.isIncome;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Dismissible(
                                        key: ValueKey('tx_${tx.id}'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 20),
                                          decoration: BoxDecoration(
                                            color: context.overspentColor,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.delete_outline,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                context.l10n.delete,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        onDismissed: (_) {
                                          _deleteTransactionWithUndo(
                                            context,
                                            ref,
                                            tx,
                                          );
                                        },
                                        child: Card(
                                          margin: EdgeInsets.zero,
                                          child: ListTile(
                                            onTap: () {
                                              AddEditTransactionDialog.show(
                                                context,
                                                transaction: tx,
                                              );
                                            },
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 6,
                                                ),
                                            leading: CircleAvatar(
                                              backgroundColor: isIncome
                                                  ? context.incomeLightColor
                                                  : context.expenseLightColor,
                                              child: Icon(
                                                isIncome
                                                    ? Icons.arrow_downward_rounded
                                                    : Icons.arrow_upward_rounded,
                                                color: isIncome
                                                    ? context.incomeColor
                                                    : context.expenseColor,
                                              ),
                                            ),
                                            title: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  (tx.categoryName != null && tx.categoryName!.isNotEmpty)
                                                      ? context.l10n.localizedCategoryName(tx.categoryName)
                                                      : (isIncome ? context.l10n.income : context.l10n.expense),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: context.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  '${isIncome ? '+' : '-'}${tx.amount.toFormattedString()}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isIncome
                                                        ? context.incomeColor
                                                        : context.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: (tx.note != null &&
                                                    tx.note!.isNotEmpty)
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      tx.note!,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: context
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                            trailing: IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: context.overspentColor,
                                              ),
                                              onPressed: () =>
                                                  _deleteTransactionWithUndo(
                                                    context,
                                                    ref,
                                                    tx,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'transactions_add_fab',
        onPressed: () => AddEditTransactionDialog.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
