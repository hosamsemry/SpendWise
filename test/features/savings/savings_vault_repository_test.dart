import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/savings/data/savings_vault_repository.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late SavingsVaultRepository vaultRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vaultRepo = SavingsVaultRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SavingsVaultRepository Tests', () {
    test('Initial vault balance is zero', () async {
      final balance = await vaultRepo.getVaultBalance();
      expect(balance.inMinorUnits, 0);

      final vault = await vaultRepo.getVault();
      expect(vault.balance.inMinorUnits, 0);
      expect(vault.lastSweptCycleId, isNull);
      expect(vault.lastSweepAmount, isNull);
      expect(vault.lastSweptAt, isNull);
    });

    test('sweepSurplus records surplus and updates vault metadata', () async {
      const cycleId = 'cycle-2026-01';
      final sweepAmount = Money.fromMajorUnits(1850);

      await vaultRepo.sweepSurplus(cycleId: cycleId, amount: sweepAmount);

      final balance = await vaultRepo.getVaultBalance();
      expect(balance.inMajorUnits, 1850.0);

      final isSwept = await vaultRepo.isCycleSwept(cycleId);
      expect(isSwept, isTrue);

      final vault = await vaultRepo.getVault();
      expect(vault.balance.inMajorUnits, 1850.0);
      expect(vault.lastSweptCycleId, cycleId);
      expect(vault.lastSweepAmount?.inMajorUnits, 1850.0);
      expect(vault.lastSweptAt, isNotNull);
    });

    test('undoSweep reverts the swept balance and clears sweep metadata', () async {
      const cycleId = 'cycle-2026-01';
      final sweepAmount = Money.fromMajorUnits(1850);

      await vaultRepo.sweepSurplus(cycleId: cycleId, amount: sweepAmount);
      expect((await vaultRepo.getVaultBalance()).inMajorUnits, 1850.0);

      await vaultRepo.undoSweep(cycleId: cycleId, amount: sweepAmount);

      final balance = await vaultRepo.getVaultBalance();
      expect(balance.inMinorUnits, 0);

      final isSwept = await vaultRepo.isCycleSwept(cycleId);
      expect(isSwept, isFalse);

      final vault = await vaultRepo.getVault();
      expect(vault.lastSweptCycleId, isNull);
      expect(vault.lastSweepAmount, isNull);
    });

    test('Manual deposit increases vault balance', () async {
      await vaultRepo.deposit(amount: Money.fromMajorUnits(500));
      expect((await vaultRepo.getVaultBalance()).inMajorUnits, 500.0);

      await vaultRepo.deposit(amount: Money.fromMajorUnits(250));
      expect((await vaultRepo.getVaultBalance()).inMajorUnits, 750.0);

      expect(
        () => vaultRepo.deposit(amount: const Money.zero()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Manual withdrawal reduces vault balance and prevents overdraft', () async {
      await vaultRepo.deposit(amount: Money.fromMajorUnits(1000));

      final updated = await vaultRepo.withdraw(amount: Money.fromMajorUnits(400));
      expect(updated.inMajorUnits, 600.0);
      expect((await vaultRepo.getVaultBalance()).inMajorUnits, 600.0);

      // Overdraft throws StateError
      expect(
        () => vaultRepo.withdraw(amount: Money.fromMajorUnits(700)),
        throwsA(isA<StateError>()),
      );

      // Non-positive withdrawal throws ArgumentError
      expect(
        () => vaultRepo.withdraw(amount: const Money.zero()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Dismissed cycles tracking', () async {
      expect(await vaultRepo.isCycleDismissed('c1'), isFalse);
      expect(await vaultRepo.isCycleDismissed('c2'), isFalse);

      await vaultRepo.dismissCycle('c1');
      expect(await vaultRepo.isCycleDismissed('c1'), isTrue);
      expect(await vaultRepo.isCycleDismissed('c2'), isFalse);

      await vaultRepo.dismissCycle('c2');
      expect(await vaultRepo.isCycleDismissed('c1'), isTrue);
      expect(await vaultRepo.isCycleDismissed('c2'), isTrue);
    });

    test('Multiple cycles can be swept and all remain marked as swept', () async {
      await vaultRepo.sweepSurplus(cycleId: 'cycle-1', amount: Money.fromMajorUnits(500));
      expect(await vaultRepo.isCycleSwept('cycle-1'), isTrue);

      await vaultRepo.sweepSurplus(cycleId: 'cycle-2', amount: Money.fromMajorUnits(300));
      expect(await vaultRepo.isCycleSwept('cycle-1'), isTrue);
      expect(await vaultRepo.isCycleSwept('cycle-2'), isTrue);

      await vaultRepo.undoSweep(cycleId: 'cycle-2', amount: Money.fromMajorUnits(300));
      expect(await vaultRepo.isCycleSwept('cycle-1'), isTrue);
      expect(await vaultRepo.isCycleSwept('cycle-2'), isFalse);
    });
  });
}
