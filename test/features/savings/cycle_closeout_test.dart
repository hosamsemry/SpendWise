import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/savings/data/savings_vault_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late ProviderContainer container;
  late BudgetCycleRepository cycleRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository txRepo;
  late SavingsVaultRepository vaultRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    cycleRepo = container.read(budgetCycleRepositoryProvider);
    categoryRepo = container.read(categoryRepositoryProvider);
    txRepo = container.read(transactionRepositoryProvider);
    vaultRepo = container.read(savingsVaultRepositoryProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('pendingCycleCloseoutProvider Tests', () {
    test('Returns null when no previous cycle exists in database', () async {
      final closeout = await container.read(pendingCycleCloseoutProvider.future);
      expect(closeout, isNull);
    });

    test('Detects net surplus in previous cycle and handles sweep, undo, and dismiss', () async {
      // 1. Get current cycle
      final currentCycle = await container.read(currentCycleProvider.future);
      final prevCalculated = cycleRepo.calculator.getPreviousCycle(currentCycle);

      // 2. Ensure previous cycle is created in database
      final prevCycle = await cycleRepo.getOrCreateCycleForDate(prevCalculated.startDate);

      // 3. Set up category and budget in previous cycle
      final foodCat = await categoryRepo.createCategory(
        name: 'Groceries',
        type: CategoryType.expense,
        defaultBudget: Money.fromMajorUnits(4000),
      );
      await cycleRepo.updateCategoryBudget(
        cycleId: prevCycle.id,
        categoryId: foodCat.id,
        budgetAmount: Money.fromMajorUnits(4000),
      );

      // Spend 2,500 EGP in previous cycle (remaining 1,500 EGP surplus)
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(2500),
        date: prevCycle.startDate.add(const Duration(days: 2)),
        categoryId: foodCat.id,
      );

      // 4. Check pending closeout
      container.read(refreshTriggerProvider.notifier).trigger();
      final closeout = await container.read(pendingCycleCloseoutProvider.future);
      expect(closeout, isNotNull);
      expect(closeout!.cycle.id, prevCycle.id);
      expect(closeout.surplus.inMajorUnits, 1500.0);

      // 5. Sweep surplus into the vault
      await vaultRepo.sweepSurplus(
        cycleId: prevCycle.id,
        amount: closeout.surplus,
      );
      container.read(refreshTriggerProvider.notifier).trigger();

      final afterSweep = await container.read(pendingCycleCloseoutProvider.future);
      expect(afterSweep, isNull);

      final vaultBalance = await container.read(savingsVaultBalanceProvider.future);
      expect(vaultBalance.inMajorUnits, 1500.0);

      // 6. Undo sweep restores pending closeout
      await vaultRepo.undoSweep(
        cycleId: prevCycle.id,
        amount: closeout.surplus,
      );
      container.read(refreshTriggerProvider.notifier).trigger();

      final afterUndo = await container.read(pendingCycleCloseoutProvider.future);
      expect(afterUndo, isNotNull);
      expect(afterUndo!.surplus.inMajorUnits, 1500.0);

      final balanceAfterUndo = await container.read(savingsVaultBalanceProvider.future);
      expect(balanceAfterUndo.inMinorUnits, 0);

      // 7. Dismissing cycle hides the closeout prompt
      await vaultRepo.dismissCycle(prevCycle.id);
      container.read(refreshTriggerProvider.notifier).trigger();

      final afterDismiss = await container.read(pendingCycleCloseoutProvider.future);
      expect(afterDismiss, isNull);
    });

    test('Returns null when previous cycle ended in deficit or zero balance', () async {
      final currentCycle = await container.read(currentCycleProvider.future);
      final prevCalculated = cycleRepo.calculator.getPreviousCycle(currentCycle);

      final prevCycle = await cycleRepo.getOrCreateCycleForDate(prevCalculated.startDate);

      final diningCat = await categoryRepo.createCategory(
        name: 'Dining',
        type: CategoryType.expense,
        defaultBudget: Money.fromMajorUnits(1000),
      );
      await cycleRepo.updateCategoryBudget(
        cycleId: prevCycle.id,
        categoryId: diningCat.id,
        budgetAmount: Money.fromMajorUnits(1000),
      );

      // Spend 1,200 EGP (overspent by 200)
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(1200),
        date: prevCycle.startDate.add(const Duration(days: 1)),
        categoryId: diningCat.id,
      );

      container.read(refreshTriggerProvider.notifier).trigger();
      final closeout = await container.read(pendingCycleCloseoutProvider.future);
      expect(closeout, isNull);
    });
  });
}
