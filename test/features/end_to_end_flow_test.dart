import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/domain/budget_calculation_service.dart';
import 'package:money_tracker/features/budgets/domain/threshold_monitor.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../test_helper.dart';

class TestNotificationService implements INotificationService {
  final List<String> eventLogs = [];

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    eventLogs.add('$id: $title - $body');
  }

  @override
  Future<void> scheduleNext25thReminder(DateTime fromDate) async {
    eventLogs.add('Scheduled 25th reminder from $fromDate');
  }

  @override
  Future<void> scheduleDailyEveningReminder({
    required int hour,
    required int minute,
  }) async {
    eventLogs.add('Scheduled daily reminder at $hour:$minute');
  }

  @override
  Future<void> cancelDailyEveningReminder() async {
    eventLogs.add('Cancelled daily reminder');
  }

  @override
  Future<void> sendTestReminder() async {
    eventLogs.add('Sent test reminder');
  }

  @override
  Future<void> cancel(int id) async {
    eventLogs.add('Cancelled notification $id');
  }
}

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late BudgetCycleRepository cycleRepo;
  late TransactionRepository txRepo;
  late TestNotificationService notifService;
  late ThresholdMonitor thresholdMonitor;
  const calcService = BudgetCalculationService();
  const calculator = BudgetCycleCalculator();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    cycleRepo = BudgetCycleRepository(db, calculator: calculator);
    txRepo = TransactionRepository(db);
    notifService = TestNotificationService();
    thresholdMonitor = ThresholdMonitor(
      db: db,
      notificationService: notifService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Full Acceptance Flow & Invariant Verification — Spec Section 15', () {
    test('End-to-end financial workflows and acceptance criteria', () async {
      // 1. Initial setup / Onboarding
      final food = await categoryRepo.createCategory(
        name: 'Food',
        defaultBudget: Money.fromMajorUnits(2000), // 2,000 EGP
      );
      final transport = await categoryRepo.createCategory(
        name: 'Transportation',
        defaultBudget: Money.fromMajorUnits(1000), // 1,000 EGP
      );
      final social = await categoryRepo.createCategory(
        name: 'Social life',
        defaultBudget: Money.fromMajorUnits(500), // 500 EGP
      );
      final gym = await categoryRepo.createCategory(
        name: 'Gym',
        defaultBudget: Money.fromMajorUnits(1000), // 1,000 EGP
      );
      final salary = await categoryRepo.createCategory(
        name: 'Salary',
        defaultBudget: const Money.zero(), // 0 EGP budget (used for income)
      );

      // 2. Create budget cycle for 25 Oct 2026
      final cycle = await cycleRepo.getOrCreateCycleForDate(
        DateTime(2026, 10, 25),
      );
      expect(cycle.startDateString, '2026-10-25');
      expect(cycle.endDateString, '2026-11-24');

      // 3. Snapshot verification: categories got cycle-specific budgets
      final initialBudgets = await cycleRepo.getCycleBudgets(cycle.id);
      expect(initialBudgets[food.id], Money.fromMajorUnits(2000));
      expect(initialBudgets[transport.id], Money.fromMajorUnits(1000));
      expect(initialBudgets[social.id], Money.fromMajorUnits(500));
      expect(initialBudgets[gym.id], Money.fromMajorUnits(1000));

      // 4. Record income with category (as requested by user)
      final incomeTx = await txRepo.addTransaction(
        type: TransactionType.income,
        amount: Money.fromMajorUnits(15000), // 15,000 EGP
        categoryId: salary.id,
        date: DateTime(2026, 10, 25),
        note: 'October Salary',
      );
      expect(incomeTx.isIncome, isTrue);
      expect(incomeTx.categoryName, 'Salary');

      // 5. Record expenses matching Spec Section 5.1 example:
      // Food: 1,500 spent (under budget, +500 remaining)
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(1500),
        categoryId: food.id,
        date: DateTime(2026, 10, 26),
        note: 'Supermarket',
      );

      // Transportation: 700 spent (under budget, +300 remaining)
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(700),
        categoryId: transport.id,
        date: DateTime(2026, 10, 27),
        note: 'Fuel',
      );

      // Social life: 700 spent (over budget by 200, -200 remaining)
      final socialTx = await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(700),
        categoryId: social.id,
        date: DateTime(2026, 10, 28),
        note: 'Dinner with friends',
      );

      // Gym: 100 spent (under budget, +900 remaining)
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(100),
        categoryId: gym.id,
        date: DateTime(2026, 10, 29),
        note: 'Supplement',
      );

      // 6. Calculate cycle summary
      final allCategories = await categoryRepo.getAllCategories(
        includeInactive: true,
      );
      final cycleBudgets = await cycleRepo.getCycleBudgets(cycle.id);
      final cycleTxs = await txRepo.getTransactionsForCycle(cycle);

      final summary = calcService.calculateCycleSummary(
        cycle: cycle,
        categories: allCategories,
        budgetMap: cycleBudgets,
        transactions: cycleTxs,
      );

      // Total income in cycle = 15,000 EGP
      expect(summary.totalIncome, Money.fromMajorUnits(15000));

      // Total budgeted across all categories = 2000 + 1000 + 500 + 1000 = 4,500 EGP
      expect(summary.totalBudgeted, Money.fromMajorUnits(4500));

      // Total spent = 1500 + 700 + 700 + 100 = 3,000 EGP
      expect(summary.totalSpent, Money.fromMajorUnits(3000));

      // Positive unused total = 500 (food) + 300 (transport) + 900 (gym) = 1,700 EGP
      expect(summary.positiveUnusedTotal, Money.fromMajorUnits(1700));

      // Net remaining total = 500 + 300 - 200 + 900 = 1,500 EGP
      expect(summary.netRemainingTotal, Money.fromMajorUnits(1500));

      // Overspent categories count = 1 (Social life)
      expect(summary.overspentCategoriesCount, 1);

      // 7. Threshold notifications evaluation:
      // Social life is overspent (-200 EGP) -> evaluateAndNotify triggers over_budget
      final socialBudget = summary.categoryBudgets.firstWhere(
        (b) => b.categoryId == social.id,
      );
      await thresholdMonitor.evaluateAndNotify(
        cycleId: cycle.id,
        budget: socialBudget,
      );
      expect(
        notifService.eventLogs.any((l) => l.contains('Budget Exceeded')),
        isTrue,
      );

      // Calling again does not duplicate
      final logCount = notifService.eventLogs.length;
      await thresholdMonitor.evaluateAndNotify(
        cycleId: cycle.id,
        budget: socialBudget,
      );
      expect(notifService.eventLogs.length, logCount);

      // 8. Edit transaction: adjust Social expense from 700 to 450 (now under budget!)
      await txRepo.updateTransaction(
        id: socialTx.id,
        amount: Money.fromMajorUnits(450),
      );

      final updatedTxs = await txRepo.getTransactionsForCycle(cycle);
      final updatedSummary = calcService.calculateCycleSummary(
        cycle: cycle,
        categories: allCategories,
        budgetMap: cycleBudgets,
        transactions: updatedTxs,
      );

      // Social life spent is now 450 of 500 budget -> remaining +50 EGP!
      final updatedSocialBudget = updatedSummary.categoryBudgets.firstWhere(
        (b) => b.categoryId == social.id,
      );
      expect(updatedSocialBudget.spentAmount, Money.fromMajorUnits(450));
      expect(updatedSocialBudget.remainingAmount, Money.fromMajorUnits(50));
      expect(updatedSocialBudget.isOverspent, isFalse);

      // Overspent categories count dropped to 0!
      expect(updatedSummary.overspentCategoriesCount, 0);
      // Net remaining increased to 1,750 EGP
      expect(updatedSummary.netRemainingTotal, Money.fromMajorUnits(1750));

      // 9. Historical cycle isolation:
      // Change Food default allocation to 3,000 EGP
      await categoryRepo.updateCategory(
        id: food.id,
        defaultBudget: Money.fromMajorUnits(3000),
      );

      // Current cycle 1 budget remains 2,000 EGP!
      final cycle1BudgetsAfterChange = await cycleRepo.getCycleBudgets(
        cycle.id,
      );
      expect(cycle1BudgetsAfterChange[food.id], Money.fromMajorUnits(2000));

      // Next cycle created on 25 Nov snapshots 3,000 EGP!
      final cycle2 = await cycleRepo.getOrCreateCycleForDate(
        DateTime(2026, 11, 25),
      );
      final cycle2Budgets = await cycleRepo.getCycleBudgets(cycle2.id);
      expect(cycle2Budgets[food.id], Money.fromMajorUnits(3000));

      // 10. Archive category preserves history
      await categoryRepo.archiveCategory(social.id);

      final activeCats = await categoryRepo.getAllCategories(
        includeInactive: false,
      );
      expect(activeCats.any((c) => c.id == social.id), isFalse);

      // Historical cycle summary still reproduces perfectly!
      final finalSummary = calcService.calculateCycleSummary(
        cycle: cycle,
        categories: await categoryRepo.getAllCategories(includeInactive: true),
        budgetMap: cycleBudgets,
        transactions: await txRepo.getTransactionsForCycle(cycle),
      );
      expect(finalSummary.totalSpent, Money.fromMajorUnits(2750));
    });
  });
}
