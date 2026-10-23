import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/budgets/domain/threshold_monitor.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import '../../../test_helper.dart';

class FakeNotificationService implements INotificationService {
  final List<Map<String, dynamic>> shownNotifications = [];

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
    shownNotifications.add({'id': id, 'title': title, 'body': body});
  }

  @override
  Future<void> scheduleNext25thReminder(DateTime fromDate) async {}

  @override
  Future<void> scheduleDailyEveningReminder({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> cancelDailyEveningReminder() async {}

  @override
  Future<void> sendTestReminder() async {}

  @override
  Future<void> cancel(int id) async {}
}

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late FakeNotificationService fakeNotifications;
  late ThresholdMonitor monitor;
  late CategoryRepository categoryRepo;
  late BudgetCycleRepository cycleRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeNotifications = FakeNotificationService();
    monitor = ThresholdMonitor(db: db, notificationService: fakeNotifications);
    categoryRepo = CategoryRepository(db);
    cycleRepo = BudgetCycleRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ThresholdMonitor Tests — Spec Section 8 & 16', () {
    test(
      '80% threshold crossing triggers notification once per category per cycle',
      () async {
        final food = await categoryRepo.createCategory(
          name: 'Food',
          defaultBudget: Money.fromMajorUnits(1000),
        );
        final cycle = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 10, 25),
        );

        // 1. Spending at 75% -> no notification
        final b75 = CategoryBudget(
          categoryId: food.id,
          categoryName: 'Food',
          budgetedAmount: Money.fromMajorUnits(1000),
          spentAmount: Money.fromMajorUnits(750),
        );
        await monitor.evaluateAndNotify(cycleId: cycle.id, budget: b75);
        expect(fakeNotifications.shownNotifications, isEmpty);

        // 2. Spending reaches 80% -> triggers notification
        final b80 = CategoryBudget(
          categoryId: food.id,
          categoryName: 'Food',
          budgetedAmount: Money.fromMajorUnits(1000),
          spentAmount: Money.fromMajorUnits(800),
        );
        await monitor.evaluateAndNotify(cycleId: cycle.id, budget: b80);
        expect(fakeNotifications.shownNotifications.length, 1);
        expect(
          fakeNotifications.shownNotifications.first['title'],
          contains('80%'),
        );

        // 3. Further spending to 90% in same cycle -> suppressed (no duplicate notification)
        final b90 = CategoryBudget(
          categoryId: food.id,
          categoryName: 'Food',
          budgetedAmount: Money.fromMajorUnits(1000),
          spentAmount: Money.fromMajorUnits(900),
        );
        await monitor.evaluateAndNotify(cycleId: cycle.id, budget: b90);
        expect(fakeNotifications.shownNotifications.length, 1);
      },
    );

    test(
      'Over-budget crossing triggers notification once per category per cycle',
      () async {
        final gym = await categoryRepo.createCategory(
          name: 'Gym',
          defaultBudget: Money.fromMajorUnits(500),
        );
        final cycle = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 10, 25),
        );

        // 1. Crosses to over budget (spent 600 of 500)
        final bOver1 = CategoryBudget(
          categoryId: gym.id,
          categoryName: 'Gym',
          budgetedAmount: Money.fromMajorUnits(500),
          spentAmount: Money.fromMajorUnits(600),
        );
        await monitor.evaluateAndNotify(cycleId: cycle.id, budget: bOver1);
        expect(fakeNotifications.shownNotifications.length, 1);
        expect(
          fakeNotifications.shownNotifications.first['title'],
          contains('Exceeded'),
        );

        // 2. Additional spending in same cycle (spent 700) -> suppressed
        final bOver2 = CategoryBudget(
          categoryId: gym.id,
          categoryName: 'Gym',
          budgetedAmount: Money.fromMajorUnits(500),
          spentAmount: Money.fromMajorUnits(700),
        );
        await monitor.evaluateAndNotify(cycleId: cycle.id, budget: bOver2);
        expect(fakeNotifications.shownNotifications.length, 1);
      },
    );

    test(
      'Zero budget category with spending triggers over-budget notification',
      () async {
        final misc = await categoryRepo.createCategory(
          name: 'Misc',
          defaultBudget: const Money.zero(),
        );
        final cycle = await cycleRepo.getOrCreateCycleForDate(
          DateTime(2026, 10, 25),
        );

        final bZeroSpent = CategoryBudget(
          categoryId: misc.id,
          categoryName: 'Misc',
          budgetedAmount: const Money.zero(),
          spentAmount: Money.fromMajorUnits(100),
        );
        await monitor.evaluateAndNotify(cycleId: cycle.id, budget: bZeroSpent);
        expect(fakeNotifications.shownNotifications.length, 1);
        expect(
          fakeNotifications.shownNotifications.first['title'],
          contains('Exceeded'),
        );
      },
    );
  });
}
