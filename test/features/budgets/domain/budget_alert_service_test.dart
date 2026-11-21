import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/domain/budget_alert_service.dart';
import 'package:money_tracker/features/budgets/domain/threshold_monitor.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../../test_helper.dart';

class _Notifications implements INotificationService {
  final List<String> titles = [];
  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async => titles.add(title);
  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> scheduleCycleStartReminder(DateTime at) async {}
  @override
  Future<void> scheduleDailyEveningReminder({required int hour, required int minute}) async {}
  @override
  Future<void> cancelDailyEveningReminder() async {}
  @override
  Future<void> sendTestReminder() async {}
  @override
  Future<void> cancel(int id) async {}
}

const _over = 'Budget Exceeded!';
const _near = 'Budget Warning (80%)';

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late _Notifications notifications;
  late BudgetCycleRepository cycles;
  late BudgetAlertService alerts;
  late Category food;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    notifications = _Notifications();
    cycles = BudgetCycleRepository(db, calculator: const BudgetCycleCalculator(startDay: 1));
    final cats = CategoryRepository(db);
    alerts = BudgetAlertService(
      txRepo: TransactionRepository(db),
      cycleRepo: cycles,
      categoryRepo: cats,
      thresholdMonitor: ThresholdMonitor(db: db, notificationService: notifications),
    );
    food = await cats.createCategory(
      name: 'Food',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(100000), // 1,000
    );
  });

  tearDown(() => db.close());

  Future<void> spend(int minor) => TransactionRepository(db).addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMinorUnits(minor),
        categoryId: food.id,
        date: DateTime(2026, 11, 10),
      );

  Future<void> setBudget(String cycleId, int minor) => cycles.updateCategoryBudget(
        cycleId: cycleId,
        categoryId: food.id,
        budgetAmount: Money.fromMinorUnits(minor),
      );

  test('lowering a budget below current spending raises the alert', () async {
    final cycle = await cycles.getOrCreateCycleForDate(DateTime(2026, 11, 10));
    await spend(60000); // 600 of 1,000: no alert yet
    await alerts.reevaluate(cycle);
    expect(notifications.titles, isEmpty);

    await setBudget(cycle.id, 50000); // now 600 of 500
    await alerts.reevaluate(cycle);
    expect(notifications.titles, [_over]);
  });

  test('raising a budget re-arms an alert that already fired', () async {
    final cycle = await cycles.getOrCreateCycleForDate(DateTime(2026, 11, 10));
    await spend(110000);
    await alerts.reevaluate(cycle);
    expect(notifications.titles, [_over]);

    await setBudget(cycle.id, 200000); // 1,100 of 2,000: back under
    await alerts.reevaluate(cycle);
    expect(await db.select(db.notificationEventsTable).get(), isEmpty);

    await setBudget(cycle.id, 100000); // over again -> alerts again
    await alerts.reevaluate(cycle);
    expect(notifications.titles, [_over, _over]);
  });

  test('restricting to categoryIds leaves other categories alone', () async {
    final cycle = await cycles.getOrCreateCycleForDate(DateTime(2026, 11, 10));
    await spend(85000);
    await alerts.reevaluate(cycle, categoryIds: {'someone-else'});
    expect(notifications.titles, isEmpty);
    await alerts.reevaluate(cycle, categoryIds: {food.id});
    expect(notifications.titles, [_near]);
  });

  test('spending under a deleted category does not break evaluation', () async {
    final cycle = await cycles.getOrCreateCycleForDate(DateTime(2026, 11, 10));
    await spend(5000);
    await CategoryRepository(db).deleteCategory(food.id);
    await alerts.reevaluate(cycle); // orphan row must be skipped, not thrown on
    expect(notifications.titles, isEmpty);
  });
}
