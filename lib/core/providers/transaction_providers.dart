import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'cycle_providers.dart';
import 'database_providers.dart';

class TransactionTypeFilterNotifier extends Notifier<TransactionType?> {
  @override
  TransactionType? build() => null;
  void set(TransactionType? type) => state = type;
}

final transactionTypeFilterProvider =
    NotifierProvider<TransactionTypeFilterNotifier, TransactionType?>(
      TransactionTypeFilterNotifier.new,
    );

class CategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? catId) => state = catId;
}

final categoryFilterProvider =
    NotifierProvider<CategoryFilterNotifier, String?>(
      CategoryFilterNotifier.new,
    );

class NoteSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String query) => state = query;
}

final noteSearchQueryProvider =
    NotifierProvider<NoteSearchQueryNotifier, String>(
      NoteSearchQueryNotifier.new,
    );

class DateRangeFilterNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;
  void set(DateTimeRange? range) => state = range;
}

final dateRangeFilterProvider =
    NotifierProvider<DateRangeFilterNotifier, DateTimeRange?>(
      DateRangeFilterNotifier.new,
    );

/// Transactions in a given cycle, optionally filtered by type, category, note search, or date range
final transactionsForCycleProvider =
    FutureProvider.family<List<TransactionModel>, BudgetCycle>((
      ref,
      cycle,
    ) async {
      ref.watch(refreshTriggerProvider);
      final txRepo = ref.watch(transactionRepositoryProvider);
      final typeFilter = ref.watch(transactionTypeFilterProvider);
      final catFilter = ref.watch(categoryFilterProvider);
      final searchNote = ref.watch(noteSearchQueryProvider);
      final dateRange = ref.watch(dateRangeFilterProvider);

      return txRepo.getTransactionsForCycle(
        cycle,
        type: typeFilter,
        categoryId: catFilter,
        searchNote: searchNote.isEmpty ? null : searchNote,
        startDate: dateRange?.start,
        endDate: dateRange?.end,
      );
    });

/// Recent transactions across all cycles (for Dashboard)
final recentTransactionsProvider = FutureProvider<List<TransactionModel>>((
  ref,
) async {
  ref.watch(refreshTriggerProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  return txRepo.getRecentTransactions(limit: 6);
});
