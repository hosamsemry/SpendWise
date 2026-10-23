import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

class DailySpendingSummary {
  final Money totalSpentToday;
  final int transactionCountToday;
  final Money? dailyPace;
  final int? daysRemainingInCycle;
  final bool isOverDailyPace;
  final Money overDailyPaceAmount;
  final Money remainingToday;

  const DailySpendingSummary({
    required this.totalSpentToday,
    required this.transactionCountToday,
    this.dailyPace,
    this.daysRemainingInCycle,
    this.isOverDailyPace = false,
    this.overDailyPaceAmount = const Money.zero(),
    this.remainingToday = const Money.zero(),
  });
}

class DayGroupedTransactions {
  final DateTime date;
  final Money totalSpent;
  final Money totalIncome;
  final List<TransactionModel> transactions;

  const DayGroupedTransactions({
    required this.date,
    required this.totalSpent,
    required this.totalIncome,
    required this.transactions,
  });
}

/// Computes the total spending recorded today, transaction count, and daily safe pace
final todaySpendingSummaryProvider =
    FutureProvider<DailySpendingSummary>((ref) async {
  ref.watch(refreshTriggerProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  final cycleRepo = ref.watch(budgetCycleRepositoryProvider);
  final calcService = ref.watch(budgetCalculationServiceProvider);
  final catRepo = ref.watch(categoryRepositoryProvider);

  final now = DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);

  // Fetch all transactions
  final allTxs = await txRepo.getAllTransactions();

  // Filter today's expenses
  final todayExpenseTxs = allTxs.where((tx) {
    if (tx.type != TransactionType.expense) return false;
    final d = tx.date;
    return d.year == todayDate.year &&
        d.month == todayDate.month &&
        d.day == todayDate.day;
  }).toList();

  int totalSpentMinor = 0;
  for (final tx in todayExpenseTxs) {
    totalSpentMinor += tx.amount.inMinorUnits;
  }

  // Calculate daily safe-to-spend pace if current cycle exists
  Money? dailyPace;
  int? daysRemaining;

  final cycle = await cycleRepo.getOrCreateCycleForDate(now);
  final budgetMap = await cycleRepo.getCycleBudgets(cycle.id);
  final cycleTxs = await txRepo.getTransactionsForCycle(cycle);
  final allCategories = await catRepo.getAllCategories(
    includeInactive: true,
  );

  final summary = calcService.calculateCycleSummary(
    cycle: cycle,
    categories: allCategories,
    budgetMap: budgetMap,
    transactions: cycleTxs,
  );

  final dEndUtc = DateTime.utc(cycle.endDate.year, cycle.endDate.month, cycle.endDate.day);
  final dTodayUtc = DateTime.utc(todayDate.year, todayDate.month, todayDate.day);
  daysRemaining = dEndUtc.difference(dTodayUtc).inDays + 1;
  if (daysRemaining < 1) daysRemaining = 1;

  if (summary.netRemainingTotal.inMinorUnits > 0) {
    dailyPace = Money.fromMinorUnits(
      summary.netRemainingTotal.inMinorUnits ~/ daysRemaining,
    );
  } else {
    dailyPace = const Money.zero();
  }

  bool isOverDailyPace = false;
  Money overDailyPaceAmount = const Money.zero();
  Money remainingToday = const Money.zero();

  if (dailyPace.inMinorUnits > 0) {
    if (totalSpentMinor > dailyPace.inMinorUnits) {
      isOverDailyPace = true;
      overDailyPaceAmount =
          Money.fromMinorUnits(totalSpentMinor - dailyPace.inMinorUnits);
      remainingToday = const Money.zero();
    } else {
      isOverDailyPace = false;
      remainingToday =
          Money.fromMinorUnits(dailyPace.inMinorUnits - totalSpentMinor);
    }
  } else if (totalSpentMinor > 0) {
    isOverDailyPace = true;
    overDailyPaceAmount = Money.fromMinorUnits(totalSpentMinor);
    remainingToday = const Money.zero();
  }

  return DailySpendingSummary(
    totalSpentToday: Money.fromMinorUnits(totalSpentMinor),
    transactionCountToday: todayExpenseTxs.length,
    dailyPace: dailyPace,
    daysRemainingInCycle: daysRemaining,
    isOverDailyPace: isOverDailyPace,
    overDailyPaceAmount: overDailyPaceAmount,
    remainingToday: remainingToday,
  );
});

/// Groups transactions chronologically by day and calculates daily totals
List<DayGroupedTransactions> groupTransactionsByDay(
  List<TransactionModel> transactions,
) {
  if (transactions.isEmpty) return const [];

  final Map<DateTime, List<TransactionModel>> map = {};

  for (final tx in transactions) {
    final dayKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
    map.putIfAbsent(dayKey, () => []).add(tx);
  }

  // Sort groups descending by date (newest days first)
  final sortedDates = map.keys.toList()
    ..sort((a, b) => b.compareTo(a));

  return sortedDates.map((date) {
    final txs = map[date]!;
    int spentMinor = 0;
    int incomeMinor = 0;

    for (final t in txs) {
      if (t.type == TransactionType.expense) {
        spentMinor += t.amount.inMinorUnits;
      } else {
        incomeMinor += t.amount.inMinorUnits;
      }
    }

    return DayGroupedTransactions(
      date: date,
      totalSpent: Money.fromMinorUnits(spentMinor),
      totalIncome: Money.fromMinorUnits(incomeMinor),
      transactions: txs,
    );
  }).toList();
}
