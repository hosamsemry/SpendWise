import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';
import 'package:money_tracker/features/savings/data/savings_goal_repository.dart';
import 'package:money_tracker/features/savings/data/savings_vault_repository.dart';
import 'package:money_tracker/features/savings/domain/savings_goal_service.dart';
import 'package:money_tracker/features/savings/domain/savings_planner.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late SavingsVaultRepository vault;
  late SavingsGoalService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vault = SavingsVaultRepository(db);
    service = SavingsGoalService(
      vault: vault,
      goals: SavingsGoalRepository(db),
      planner: const SavingsPlanner(BudgetCycleCalculator(startDay: 1)),
    );
  });

  tearDown(() => db.close());

  Money m(int minor) => Money.fromMinorUnits(minor);
  Future<Map<String?, int>> buckets() async =>
      (await vault.bucketBalances()).map((k, v) => MapEntry(k, v.inMinorUnits));

  test('a sweep split credits goals and Unassigned; undo removes all of it', () async {
    final car = (await service.goals.createGoal(name: 'Car', target: m(4500000), monthlyPlan: m(200000)));
    final eid = (await service.goals.createGoal(name: 'Eid', target: m(300000), monthlyPlan: m(50000)));

    final split = await service.defaultSweepSplit(m(285000));
    expect(split.map((k, v) => MapEntry(k, v.inMinorUnits)), {car.id: 200000, eid.id: 50000, null: 35000});

    final result = await service.sweep(cycleId: 'c1', amount: m(285000), allocation: split);
    expect(result, isNotNull);
    expect(await buckets(), {car.id: 200000, eid.id: 50000, null: 35000});
    expect((await vault.getVaultBalance()).inMinorUnits, 285000);
    expect(await service.sweep(cycleId: 'c1', amount: m(285000), allocation: split), isNull);

    expect(await service.undoSweep('c1'), isTrue);
    expect((await vault.getVaultBalance()).inMinorUnits, 0);
    expect(await vault.isCycleSwept('c1'), isFalse);
  });

  test('sweep shares must add up to the surplus', () async {
    expect(
      () => vault.sweepSurplus(cycleId: 'c1', amount: m(1000), allocation: {null: m(900)}),
      throwsArgumentError,
    );
  });

  test('moving and taking out money never lets a bucket go below zero', () async {
    final car = await service.goals.createGoal(name: 'Car', target: m(1000000));
    await service.deposit(m(50000));
    await service.transfer(m(30000), from: null, to: car.id);
    expect(await buckets(), {null: 20000, car.id: 30000});

    expect(() => service.transfer(m(30001), from: car.id, to: null), throwsStateError);
    expect(() => service.withdraw(m(20001)), throwsStateError);

    // Spending goal money reduces the vault but writes no transaction.
    await service.withdraw(m(10000), goalId: car.id);
    expect(await buckets(), {null: 20000, car.id: 20000});
    expect(await db.select(db.transactionsTable).get(), isEmpty);
  });

  test('undo refuses once the money has moved on', () async {
    final car = await service.goals.createGoal(name: 'Car', target: m(1000000));
    final deposit = await service.deposit(m(50000));
    await service.transfer(m(50000), from: null, to: car.id);
    expect(await service.undo(deposit), isFalse);
    expect((await vault.getVaultBalance()).inMinorUnits, 50000);
  });

  test('reaching the target marks the goal achieved once; undo reverts it', () async {
    final eid = await service.goals.createGoal(name: 'Eid', target: m(100000));
    final first = await service.deposit(m(60000), goalId: eid.id);
    expect(first.newlyAchieved, isEmpty);

    final second = await service.deposit(m(40000), goalId: eid.id);
    expect(second.newlyAchieved.single.id, eid.id);
    expect((await service.goals.getGoal(eid.id))!.isAchieved, isTrue);

    // Adding more does not celebrate again.
    final more = await service.deposit(m(1), goalId: eid.id);
    expect(more.newlyAchieved, isEmpty);

    expect(await service.undo(more), isTrue);
    expect(await service.undo(second), isTrue);
    expect((await service.goals.getGoal(eid.id))!.isAchieved, isFalse);
  });

  test('raising the target reopens an achieved goal', () async {
    final eid = await service.goals.createGoal(name: 'Eid', target: m(100000));
    await service.deposit(m(100000), goalId: eid.id);
    final achieved = (await service.goals.getGoal(eid.id))!;
    expect(achieved.isAchieved, isTrue);

    await service.updateGoal(achieved.copyWith(target: m(150000)));
    expect((await service.goals.getGoal(eid.id))!.isAchieved, isFalse);
  });

  test('a new goal can start with money from Unassigned', () async {
    await service.deposit(m(80000));
    final result = await service.createGoal(name: 'Trip', target: m(500000), startingAmount: m(30000));
    final goals = await service.goalsWithBalances();
    expect(goals.single.balance.inMinorUnits, 30000);
    expect((await service.unassignedBalance()).inMinorUnits, 50000);
    expect(await service.undo(result), isTrue);
    expect((await service.unassignedBalance()).inMinorUnits, 80000);
  });

  test('deleting a goal returns its money to Unassigned', () async {
    final car = await service.goals.createGoal(name: 'Car', target: m(1000000));
    await service.deposit(m(70000), goalId: car.id);
    await service.deleteGoal(car);
    expect(await buckets(), {null: 70000});
    expect((await vault.getVaultBalance()).inMinorUnits, 70000);
  });

  test('reorder sets the fill order', () async {
    final a = await service.goals.createGoal(name: 'A', target: m(1000));
    final b = await service.goals.createGoal(name: 'B', target: m(1000));
    await service.reorder([b.id, a.id]);
    expect((await service.goals.getGoals()).map((g) => g.name), ['B', 'A']);
  });

  test('backup round trip keeps goals and history', () async {
    final car = await service.goals.createGoal(name: 'Car', target: m(1000000), monthlyPlan: m(20000));
    await service.deposit(m(50000), goalId: car.id);
    await service.deposit(m(5000));

    final backups = BackupService(db);
    final data = await backups.createBackupData();
    expect(data.savingsGoalCount, 1);
    await backups.restoreFromBackup(backups.parseBackupString(data.toFormattedJsonString()));

    expect(await buckets(), {car.id: 50000, null: 5000});
    final restored = (await service.goals.getGoals()).single;
    expect(restored.monthlyPlan!.inMinorUnits, 20000);
  });

  test('restoring an old backup turns its vault balance into an opening entry', () async {
    final backups = BackupService(db);
    final data = await backups.createBackupData();
    final json = data.toFormattedJsonString().replaceFirst(
          '"appSettings": []',
          '"appSettings": [{"key": "savings_vault_balance_minor", "value": "123400"}]',
        );
    await backups.restoreFromBackup(backups.parseBackupString(json));
    expect(await buckets(), {null: 123400});
    final settings = await db.select(db.appSettingsTable).get();
    expect(settings.where((s) => s.key == legacyVaultBalanceKey), isEmpty);
  });
}
