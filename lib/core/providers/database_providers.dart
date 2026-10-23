import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/core/providers/budget_cycle_start_day_provider.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/domain/budget_calculation_service.dart';
import 'package:money_tracker/features/budgets/domain/threshold_monitor.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final appDatabaseProvider = databaseProvider;

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryRepository(db);
});

final budgetCycleRepositoryProvider = Provider<BudgetCycleRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final startDayAsync = ref.watch(budgetCycleStartDayProvider);
  final startDay = startDayAsync.asData?.value ?? 1;
  return BudgetCycleRepository(
    db,
    calculator: BudgetCycleCalculator(startDay: startDay),
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepository(db);
});

final budgetCalculationServiceProvider = Provider<BudgetCalculationService>((
  ref,
) {
  return const BudgetCalculationService();
});

final notificationServiceProvider = Provider<INotificationService>((ref) {
  return NotificationService();
});

final thresholdMonitorProvider = Provider<ThresholdMonitor>((ref) {
  final db = ref.watch(databaseProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return ThresholdMonitor(db: db, notificationService: notificationService);
});
