import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/features/bills/domain/bill_schedule.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/core/providers/bill_providers.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/daily_spending_provider.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';
import 'package:money_tracker/features/bills/data/bill_reminder_scheduler.dart';
import 'package:money_tracker/features/bills/domain/bill_service.dart';
import 'package:money_tracker/features/bills/domain/recurring_bill.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

class _NoNotifications implements INotificationService {
  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showNotification({required int id, required String title, required String body}) async {}
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

class _FakeReminders implements BillReminderScheduler {
  /// Bill id → scheduled reminder time.
  final Map<String, DateTime> scheduled = {};

  @override
  Future<void> schedule({required RecurringBill bill, required DateTime at, required DateTime dueDate}) async =>
      scheduled[bill.id] = at;

  @override
  Future<void> cancel(String billId) async => scheduled.remove(billId);
}

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late ProviderContainer container;
  late _FakeReminders reminders;
  late Category housing;
  late Category food;
  late Category salary;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    reminders = _FakeReminders();
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '1'),
        );
    final cats = CategoryRepository(db);
    housing = await cats.createCategory(
      name: 'Housing',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(800000),
    );
    food = await cats.createCategory(
      name: 'Food',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(100000),
    );
    salary = await cats.createCategory(name: 'Salary', type: CategoryType.income);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(_NoNotifications()),
      billReminderSchedulerProvider.overrideWithValue(reminders),
    ]);
    await container.read(budgetCycleStartDayProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// A [BillService] whose "today" is [now].
  BillService service(DateTime now) => BillService(
        repo: container.read(recurringBillRepositoryProvider),
        transactions: container.read(transactionServiceProvider),
        schedule: container.read(billScheduleProvider),
        reminders: reminders,
        clock: () => now,
      );

  Future<List<TransactionModel>> allTransactions() =>
      container.read(transactionRepositoryProvider).getAllTransactions();

  test('paying logs a transaction and clears the due date; undo brings it back', () async {
    final s = service(DateTime(2026, 3, 10, 12));
    final rent = await s.create(
      title: 'Rent',
      type: TransactionType.expense,
      categoryId: housing.id,
      amount: const Money.fromMinorUnits(800000),
      frequency: BillFrequency.monthly,
      anchorDate: DateTime(2026, 3, 1),
      remindDaysBefore: 1,
    );
    expect(reminders.scheduled[rent.id], DateTime(2026, 3, 31, 9));

    final due = await s.dueItems();
    expect(due.map((d) => d.dueDate), [DateTime(2026, 3, 1)]);
    expect(due.single.isOverdue(DateTime(2026, 3, 10)), isTrue);

    final tx = await s.pay(due.single);
    expect(tx.amount.inMinorUnits, 800000);
    expect(tx.categoryId, housing.id);
    expect(tx.note, 'Rent');
    expect(tx.date, DateTime(2026, 3, 10));
    expect(await s.dueItems(), isEmpty);

    await s.undoPay(tx);
    expect(await allTransactions(), isEmpty);
    expect((await s.dueItems()).single.dueDate, DateTime(2026, 3, 1));
  });

  test('a variable bill remembers the last amount paid as its estimate', () async {
    final s = service(DateTime(2026, 3, 5));
    await s.create(
      title: 'Electricity',
      type: TransactionType.expense,
      categoryId: housing.id,
      amount: const Money.fromMinorUnits(40000),
      isVariable: true,
      frequency: BillFrequency.monthly,
      anchorDate: DateTime(2026, 3, 5),
    );
    final due = (await s.dueItems()).single;
    await s.pay(due, amount: const Money.fromMinorUnits(52500));
    final bill = (await container.read(recurringBillRepositoryProvider).getAllBills()).single;
    expect(bill.amount.inMinorUnits, 52500);
    final history = await container.read(recurringBillRepositoryProvider).getOccurrences(bill.id);
    expect(history.single.status, BillOccurrenceStatus.paid);
    expect(history.single.amount!.inMinorUnits, 52500);
  });

  test('income bills log income without needing a category', () async {
    final s = service(DateTime(2026, 3, 1));
    await s.create(
      title: 'Salary',
      type: TransactionType.income,
      categoryId: salary.id,
      amount: const Money.fromMinorUnits(2000000),
      frequency: BillFrequency.everyCycle,
      anchorDate: DateTime(2026, 3, 1),
    );
    final tx = await s.pay((await s.dueItems()).single);
    expect(tx.type, TransactionType.income);
  });

  test('skip and undo skip', () async {
    final s = service(DateTime(2026, 3, 2));
    await s.create(
      title: 'Gym',
      type: TransactionType.expense,
      categoryId: food.id,
      amount: const Money.fromMinorUnits(50000),
      frequency: BillFrequency.monthly,
      anchorDate: DateTime(2026, 3, 3),
    );
    final due = (await s.dueItems()).single;
    await s.skip(due);
    expect(await s.dueItems(), isEmpty);
    expect(await allTransactions(), isEmpty);
    await s.undoSkip(due);
    expect(await s.dueItems(), hasLength(1));
  });

  test('deleting the category keeps the name, and paying then asks for a new one', () async {
    final s = service(DateTime(2026, 3, 3));
    await s.create(
      title: 'Groceries box',
      type: TransactionType.expense,
      categoryId: food.id,
      amount: const Money.fromMinorUnits(30000),
      frequency: BillFrequency.weekly,
      anchorDate: DateTime(2026, 3, 3),
    );
    await container.read(categoryRepositoryProvider).deleteCategory(food.id);
    final due = (await s.dueItems()).first;
    expect(due.bill.categoryId, isNull);
    expect(due.bill.categoryName, 'Food');
    expect(() => s.pay(due), throwsA(isA<BillCategoryMissingException>()));
  });

  test('resuming a paused bill skips the dates missed while paused', () async {
    final repo = container.read(recurringBillRepositoryProvider);
    final bill = await service(DateTime(2026, 1, 1)).create(
      title: 'Internet',
      type: TransactionType.expense,
      categoryId: housing.id,
      amount: const Money.fromMinorUnits(45000),
      frequency: BillFrequency.monthly,
      anchorDate: DateTime(2026, 1, 15),
      remindDaysBefore: 0,
    );
    await service(DateTime(2026, 1, 2)).setActive(bill, false);
    expect(reminders.scheduled, isEmpty);
    expect(await service(DateTime(2026, 4, 1)).dueItems(), isEmpty);

    final paused = (await repo.getAllBills()).single;
    final later = service(DateTime(2026, 4, 10));
    await later.setActive(paused, true);
    final due = await later.dueItems();
    expect(due.single.dueDate, DateTime(2026, 4, 15));
    expect(reminders.scheduled[bill.id], DateTime(2026, 4, 15, 9));
  });

  test('deleting a bill keeps its payments and cancels its reminder', () async {
    final s = service(DateTime(2026, 3, 1));
    final bill = await s.create(
      title: 'Netflix',
      type: TransactionType.expense,
      categoryId: food.id,
      amount: const Money.fromMinorUnits(24000),
      frequency: BillFrequency.monthly,
      anchorDate: DateTime(2026, 3, 1),
      remindDaysBefore: 1,
    );
    await s.pay((await s.dueItems()).single);
    await s.delete(bill);
    expect(await allTransactions(), hasLength(1));
    expect(reminders.scheduled, isEmpty);
    expect(await db.select(db.billOccurrencesTable).get(), isEmpty);
  });

  test('daily safe-to-spend sets aside unpaid bills due this cycle', () async {
    final today = DateTime.now();
    final before = await container.read(todaySpendingSummaryProvider.future);

    final s = service(today);
    final bill = await s.create(
      title: 'Phone',
      type: TransactionType.expense,
      categoryId: food.id,
      amount: const Money.fromMinorUnits(30000),
      frequency: BillFrequency.monthly,
      anchorDate: DateTime(today.year, today.month, today.day),
    );
    container.read(refreshTriggerProvider.notifier).trigger();
    final after = await container.read(todaySpendingSummaryProvider.future);

    final days = after.daysRemainingInCycle!;
    expect(after.committedBills.inMinorUnits, 30000);
    expect(after.dailyPace!.inMinorUnits, (900000 - 30000) ~/ days);
    expect(before.dailyPace!.inMinorUnits, 900000 ~/ days);

    // Once paid, the money is spent instead of set aside: the pace is the same.
    await s.pay((await s.dueItems()).firstWhere((d) => d.bill.id == bill.id));
    container.read(refreshTriggerProvider.notifier).trigger();
    final paid = await container.read(todaySpendingSummaryProvider.future);
    expect(paid.committedBills.inMinorUnits, 0);
    expect(paid.dailyPace!.inMinorUnits, (900000 - 30000) ~/ days);
    // The money was set aside already, so paying doesn't count as spending
    // today or push the day over its pace.
    expect(paid.totalSpentToday.inMinorUnits, 0);
    expect(paid.isOverDailyPace, isFalse);
  });

  test('backup restores bills and only the payments whose transactions exist', () async {
    final s = service(DateTime(2026, 3, 10));
    final bill = await s.create(
      title: 'Rent',
      type: TransactionType.expense,
      categoryId: housing.id,
      amount: const Money.fromMinorUnits(800000),
      frequency: BillFrequency.monthly,
      anchorDate: DateTime(2026, 2, 1),
      remindDaysBefore: 3,
    );
    final dues = await s.dueItems();
    await s.pay(dues[0]); // 1 Feb
    await s.skip(dues[1]); // 1 Mar

    final backupService = BackupService(db);
    final backup = await backupService.createBackupData();
    expect(backup.billCount, 1);
    final json = backup.toFormattedJsonString();

    // Drop the payment transaction from the file: its paid record must go too.
    final trimmed = backupService.parseBackupString(json);
    trimmed.transactions.clear();

    await backupService.restoreFromBackup(backupService.parseBackupString(json));
    final repo = container.read(recurringBillRepositoryProvider);
    final restored = (await repo.getAllBills()).single;
    expect(restored.id, bill.id);
    expect(restored.remindDaysBefore, 3);
    expect(restored.anchorDate, DateTime(2026, 2, 1));
    expect((await repo.getHandledDueDates())[bill.id], {'2026-02-01', '2026-03-01'});

    await backupService.restoreFromBackup(trimmed);
    expect((await repo.getHandledDueDates())[bill.id], {'2026-03-01'});
  });

  group('pausing', () {
    test('dates already overdue before the pause stay overdue after resuming', () async {
      final bill = await service(DateTime(2026, 2, 20)).create(
        title: 'Internet',
        type: TransactionType.expense,
        categoryId: housing.id,
        amount: const Money.fromMinorUnits(45000),
        frequency: BillFrequency.monthly,
        anchorDate: DateTime(2026, 1, 15),
      );
      // Jan 15 and Feb 15 are unpaid when the bill is paused on Feb 20.
      await service(DateTime(2026, 2, 20)).setActive(bill, false);
      final paused = (await container.read(recurringBillRepositoryProvider).getAllBills()).single;
      expect(paused.pausedAt, DateTime(2026, 2, 20));

      final later = service(DateTime(2026, 4, 10));
      await later.setActive(paused, true);
      final dates = (await later.dueItems()).map((d) => d.dueDate).toList();
      // Mar 15 passed while paused (skipped); the old overdue ones remain.
      expect(dates, [DateTime(2026, 1, 15), DateTime(2026, 2, 15), DateTime(2026, 4, 15)]);
      final resumed = (await container.read(recurringBillRepositoryProvider).getAllBills()).single;
      expect(resumed.pausedAt, isNull);
    });

    test('a date due on the day of pausing is skipped on resume', () async {
      final bill = await service(DateTime(2026, 2, 20)).create(
        title: 'Gym',
        type: TransactionType.expense,
        categoryId: food.id,
        amount: const Money.fromMinorUnits(30000),
        frequency: BillFrequency.monthly,
        anchorDate: DateTime(2026, 2, 20),
      );
      await service(DateTime(2026, 2, 20)).setActive(bill, false);
      final paused = (await container.read(recurringBillRepositoryProvider).getAllBills()).single;
      final later = service(DateTime(2026, 3, 1));
      await later.setActive(paused, true);
      expect((await later.dueItems(daysAhead: 30)).map((d) => d.dueDate), [DateTime(2026, 3, 20)]);
    });
  });

  group('variable bill estimate', () {
    Future<RecurringBill> electricity() async => (await container
            .read(recurringBillRepositoryProvider)
            .getAllBills())
        .single;

    Future<BillService> setUpBill() async {
      final s = service(DateTime(2026, 3, 5));
      await s.create(
        title: 'Electricity',
        type: TransactionType.expense,
        categoryId: housing.id,
        amount: const Money.fromMinorUnits(40000),
        isVariable: true,
        frequency: BillFrequency.monthly,
        anchorDate: DateTime(2026, 3, 5),
      );
      return s;
    }

    test('undoing a payment brings the previous estimate back', () async {
      final s = await setUpBill();
      final tx = await s.pay((await s.dueItems()).single, amount: const Money.fromMinorUnits(52500));
      expect((await electricity()).amount.inMinorUnits, 52500);
      await s.undoPay(tx);
      expect((await electricity()).amount.inMinorUnits, 40000);
    });

    test('deleting the payment on the Transactions screen does too', () async {
      final s = await setUpBill();
      final tx = await s.pay((await s.dueItems()).single, amount: const Money.fromMinorUnits(52500));
      await container.read(transactionServiceProvider).delete(tx);
      expect((await electricity()).amount.inMinorUnits, 40000);
    });

    test('an estimate typed after a payment wins; saving it unchanged does not', () async {
      final s = await setUpBill();
      final tx = await s.pay((await s.dueItems()).single, amount: const Money.fromMinorUnits(52500));

      // Saving the form with the shown estimate doesn't freeze it.
      final shown = await electricity();
      await s.update(RecurringBill(
        id: shown.id, title: 'Electricity (home)', type: shown.type, categoryId: shown.categoryId,
        amount: shown.amount, isVariable: true, frequency: shown.frequency, anchorDate: shown.anchorDate,
        createdAt: shown.createdAt, updatedAt: shown.updatedAt,
      ));
      await s.undoPay(tx);
      expect((await electricity()).amount.inMinorUnits, 40000);

      // Typing a new estimate after a payment replaces it.
      final again = await s.pay((await s.dueItems()).single, amount: const Money.fromMinorUnits(52500));
      final bill = await electricity();
      await s.update(RecurringBill(
        id: bill.id, title: bill.title, type: bill.type, categoryId: bill.categoryId,
        amount: const Money.fromMinorUnits(60000), isVariable: true, frequency: bill.frequency,
        anchorDate: bill.anchorDate, createdAt: bill.createdAt, updatedAt: bill.updatedAt,
      ));
      expect((await electricity()).amount.inMinorUnits, 60000);
      await s.undoPay(again);
      expect((await electricity()).amount.inMinorUnits, 60000);
    });
  });

  test('"every cycle" bills keep their payments after the start day changes', () async {
    final old = BudgetCycleRepository(db, calculator: const BudgetCycleCalculator(startDay: 25));
    final repo = container.read(recurringBillRepositoryProvider);
    for (final d in [DateTime(2026, 9, 26), DateTime(2026, 10, 26), DateTime(2026, 11, 26)]) {
      await old.getOrCreateCycleForDate(d);
    }
    final rent = await repo.createBill(
      title: 'Rent',
      type: TransactionType.expense,
      categoryId: housing.id,
      amount: const Money.fromMinorUnits(500000),
      frequency: BillFrequency.everyCycle,
      anchorDate: DateTime(2026, 9, 25),
    );
    // Paid every cycle on the old start day.
    for (final d in [DateTime(2026, 9, 25), DateTime(2026, 10, 25), DateTime(2026, 11, 25)]) {
      await repo.recordOccurrence(billId: rent.id, dueDate: d, status: BillOccurrenceStatus.skipped);
    }

    final today = DateTime(2026, 11, 28);
    final current = await BudgetCycleRepository(db, calculator: const BudgetCycleCalculator(startDay: 1))
        .realignCyclesOnStartDayChange(1, today: today);
    expect(current.startDate, DateTime(2026, 11, 1));

    final s = BillService(
      repo: repo,
      transactions: container.read(transactionServiceProvider),
      schedule: const BillSchedule(BudgetCycleCalculator(startDay: 1)),
      recordedCycles: old.getAllCycles,
      clock: () => today,
    );
    // Nothing overdue: the moved cycle's payment moved with it to Nov 1.
    expect((await s.dueItems()).map((d) => d.dueDate), [DateTime(2026, 12, 1)]);
    expect((await s.committedUntil(DateTime(2026, 11, 30))).inMinorUnits, 0);
    expect((await repo.getHandledDueDates())[rent.id], contains('2026-11-01'));
  });
}
