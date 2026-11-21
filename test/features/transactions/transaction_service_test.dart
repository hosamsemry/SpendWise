import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/smart_detection/presentation/smart_detection_providers.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/features/transactions/domain/transaction_service.dart';
import '../../test_helper.dart';

class _FakeNotifications implements INotificationService {
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

const _overBudgetTitle = 'Budget Exceeded!';
const _nearLimitTitle = 'Budget Warning (80%)';

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late _FakeNotifications notifications;
  late ProviderContainer container;
  late Category food;
  late Category transport;
  late Category salaryCat;

  /// Boots a container whose cycle repository uses [startDay] like the real app.
  Future<void> boot({required int startDay}) async {
    db = AppDatabase(NativeDatabase.memory());
    notifications = _FakeNotifications();
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(
            key: 'budget_cycle_start_day',
            value: '$startDay',
          ),
        );
    final catRepo = CategoryRepository(db);
    food = await catRepo.createCategory(
      name: 'Food',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(100000), // 1,000
    );
    transport = await catRepo.createCategory(
      name: 'Transport',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(50000), // 500
    );
    salaryCat = await catRepo.createCategory(
      name: 'Salary',
      type: CategoryType.income,
    );

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    await container.read(budgetCycleStartDayProvider.future);
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  TransactionService service() => container.read(transactionServiceProvider);

  /// Recorded cycles as `start_end` ranges.
  Future<List<String>> cycleRanges() async =>
      (await db.select(db.budgetCyclesTable).get())
          .map((c) => '${c.startDate}_${c.endDate}')
          .toList();

  Future<String> cycleIdFor(DateTime date) async => (await container
          .read(budgetCycleRepositoryProvider)
          .getCycleForDateOrNull(date))!
      .id;

  Future<int> savingsBudgetMinor(String cycleId) async {
    final savings = await container
        .read(savingsSyncServiceProvider)
        .ensureSavingsCategory();
    final budgets = await container
        .read(budgetCycleRepositoryProvider)
        .getCycleBudgets(cycleId);
    return budgets[savings.id]?.inMinorUnits ?? 0;
  }

  group('confirming a detected bank alert', () {
    test('fires the over-budget alert like a manual expense would', () async {
      await boot(startDay: 1);
      final date = DateTime(2026, 11, 10);
      await service().add(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(90000),
        categoryId: food.id,
        date: date,
      );
      expect(notifications.titles, [_nearLimitTitle]);

      final repo = container.read(pendingTransactionRepositoryProvider);
      final pending = await repo.ingestMessage(
        'Your card was debited with EGP 200.00 at Carrefour on 10/11 Ref# 5551234',
      );
      expect(pending, isNotNull);

      await container.read(smartDetectionCoordinatorProvider).confirmPending(
            pending: pending!,
            type: TransactionType.expense,
            amount: pending.amount,
            categoryId: food.id,
            date: date,
            note: pending.note,
          );

      expect(notifications.titles, [_nearLimitTitle, _overBudgetTitle]);
      expect(await repo.getPendingTransactions(), isEmpty);
    });

    test('creates cycles with the user start day, not the default 25th',
        () async {
      await boot(startDay: 1);
      final repo = container.read(pendingTransactionRepositoryProvider);
      final pending = await repo.ingestMessage(
        'Your card was debited with EGP 50.00 at Uber on 12/03 Ref# 777001',
      );

      await container.read(smartDetectionCoordinatorProvider).confirmPending(
            pending: pending!,
            type: TransactionType.expense,
            amount: pending.amount,
            categoryId: transport.id,
            date: DateTime(2026, 3, 12),
            note: pending.note,
          );

      expect(await cycleRanges(), ['2026-03-01_2026-03-31']);
    });

    test('honours a custom payday start day', () async {
      await boot(startDay: 10);
      await service().add(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(1000),
        categoryId: transport.id,
        date: DateTime(2026, 3, 5),
      );
      expect(await cycleRanges(), ['2026-02-10_2026-03-09']);
    });
  });

  group('savings sync', () {
    test('adding and deleting income rebalances the Savings budget', () async {
      await boot(startDay: 1);
      final date = DateTime(2026, 11, 3);
      final income = await service().add(
        type: TransactionType.income,
        amount: const Money.fromMinorUnits(500000), // 5,000
        categoryId: salaryCat.id,
        date: date,
      );
      final cycleId = (await db.select(db.budgetCyclesTable).getSingle()).id;
      // 5,000 income - 1,500 other budgets
      expect(await savingsBudgetMinor(cycleId), 350000);

      await service().delete(income);
      expect(await savingsBudgetMinor(cycleId), 0);

      await service().restore(income);
      expect(await savingsBudgetMinor(cycleId), 350000);
    });

    test('moving income to another cycle re-syncs both cycles', () async {
      await boot(startDay: 1);
      final income = await service().add(
        type: TransactionType.income,
        amount: const Money.fromMinorUnits(500000),
        categoryId: salaryCat.id,
        date: DateTime(2026, 10, 15),
      );
      await service().update(
        id: income.id,
        type: TransactionType.income,
        amount: income.amount,
        categoryId: salaryCat.id,
        date: DateTime(2026, 11, 15),
        note: null,
      );

      expect(await savingsBudgetMinor(await cycleIdFor(DateTime(2026, 10, 15))), 0);
      expect(
        await savingsBudgetMinor(await cycleIdFor(DateTime(2026, 11, 15))),
        350000,
      );
    });

    test('changing income into an expense removes it from Savings', () async {
      await boot(startDay: 1);
      final tx = await service().add(
        type: TransactionType.income,
        amount: const Money.fromMinorUnits(200000),
        categoryId: salaryCat.id,
        date: DateTime(2026, 11, 2),
      );
      final cycleId = (await db.select(db.budgetCyclesTable).getSingle()).id;
      expect(await savingsBudgetMinor(cycleId), 50000);

      await service().update(
        id: tx.id,
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(1000),
        categoryId: transport.id,
        date: tx.date,
        note: null,
      );
      expect(await savingsBudgetMinor(cycleId), 0);
    });
  });

  group('budget threshold alerts', () {
    test('deleting an expense re-arms the alert for that category', () async {
      await boot(startDay: 1);
      final date = DateTime(2026, 11, 5);
      final big = await service().add(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(110000),
        categoryId: food.id,
        date: date,
      );
      expect(notifications.titles, [_overBudgetTitle]);

      await service().delete(big);
      await service().add(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(120000),
        categoryId: food.id,
        date: date,
      );
      expect(notifications.titles, [_overBudgetTitle, _overBudgetTitle]);
    });

    test('recategorising re-evaluates the category it left', () async {
      await boot(startDay: 1);
      final date = DateTime(2026, 11, 5);
      final tx = await service().add(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(85000),
        categoryId: food.id,
        date: date,
      );
      expect(notifications.titles, [_nearLimitTitle]);

      // Move it to Transport (850 of 500 -> over budget) and away from Food.
      await service().update(
        id: tx.id,
        type: TransactionType.expense,
        amount: tx.amount,
        categoryId: transport.id,
        date: date,
        note: null,
      );
      expect(notifications.titles, [_nearLimitTitle, _overBudgetTitle]);

      final foodEvents = await (db.select(db.notificationEventsTable)
            ..where((t) => t.categoryId.equals(food.id)))
          .get();
      expect(foodEvents, isEmpty);
    });

    test('the same threshold only fires once per cycle', () async {
      await boot(startDay: 1);
      final date = DateTime(2026, 11, 5);
      for (var i = 0; i < 3; i++) {
        await service().add(
          type: TransactionType.expense,
          amount: const Money.fromMinorUnits(40000),
          categoryId: food.id,
          date: date,
        );
      }
      // 400 (40%), 800 (80% -> warning), 1,200 (over -> exceeded)
      expect(notifications.titles, [_nearLimitTitle, _overBudgetTitle]);
    });
  });

}
