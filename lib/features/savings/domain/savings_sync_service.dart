import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:uuid/uuid.dart';

/// Pure domain/data synchronization service managing dynamic unallocated
/// income auto-budgeting into the "Savings" category.
class SavingsSyncService {
  final AppDatabase db;
  final CategoryRepository categoryRepo;
  final BudgetCycleRepository cycleRepo;
  final TransactionRepository txRepo;
  final Uuid _uuid;

  static const String savingsCategoryName = 'Savings';
  static const String arabicSavingsCategoryName = 'مدخرات';
  static const String savingsColor = '#10B981'; // Emerald Green

  SavingsSyncService({
    required this.db,
    required this.categoryRepo,
    required this.cycleRepo,
    required this.txRepo,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Finds or creates the default "Savings" expense category.
  Future<Category> ensureSavingsCategory({String? preferredName}) async {
    final allCategories = await categoryRepo.getAllCategories(includeInactive: true);
    final existing = allCategories.where((c) {
      if (c.type != CategoryType.expense) return false;
      final name = c.name.trim().toLowerCase();
      return name == savingsCategoryName.toLowerCase() ||
          name == arabicSavingsCategoryName.toLowerCase();
    }).firstOrNull;

    if (existing != null) {
      if (!existing.isActive) {
        await categoryRepo.unarchiveCategory(existing.id);
        return (await categoryRepo.getCategoryById(existing.id))!;
      }
      return existing;
    }

    final bool isArabicLocale = Intl.defaultLocale?.startsWith('ar') == true ||
        allCategories.any((c) => c.name.contains(RegExp(r'[\u0600-\u06FF]')));
    final defaultName =
        isArabicLocale ? arabicSavingsCategoryName : savingsCategoryName;

    return categoryRepo.createCategory(
      name: preferredName ?? defaultName,
      type: CategoryType.expense,
      color: savingsColor,
      defaultBudget: const Money.zero(),
    );
  }

  /// Synchronizes the "Savings" category budget for [cycleId] so it absorbs
  /// unallocated cycle income:
  ///
  /// $$\text{Savings Budget} = \max(0, \text{Total Income} - \sum \text{Other Category Budgets})$$
  Future<Money> syncSavingsBudgetForCycle({required String cycleId}) async {
    // 1. Get cycle details
    final cycleEntry = await (db.select(db.budgetCyclesTable)
          ..where((tbl) => tbl.id.equals(cycleId)))
        .getSingleOrNull();
    if (cycleEntry == null) return const Money.zero();

    final cycle = BudgetCycle(
      id: cycleEntry.id,
      startDate: BudgetCycleCalculator.parseDate(cycleEntry.startDate),
      endDate: BudgetCycleCalculator.parseDate(cycleEntry.endDate),
    );

    // 2. Ensure Savings category exists
    final savingsCat = await ensureSavingsCategory();

    // 3. Compute total income for cycle
    final cycleTxs = await txRepo.getTransactionsForCycle(cycle);
    var totalIncomeMinor = 0;
    for (final tx in cycleTxs) {
      if (tx.isIncome) {
        totalIncomeMinor += tx.amount.inMinorUnits;
      }
    }

    // 4. Compute sum of all other expense category budgets for this cycle
    final budgetMap = await cycleRepo.getCycleBudgets(cycleId);
    var otherBudgetsMinor = 0;
    for (final entry in budgetMap.entries) {
      if (entry.key != savingsCat.id) {
        otherBudgetsMinor += entry.value.inMinorUnits;
      }
    }

    // 5. Unallocated income becomes Savings budget (clamped at 0)
    final unallocatedMinor = totalIncomeMinor - otherBudgetsMinor;
    final targetSavingsMinor = unallocatedMinor > 0 ? unallocatedMinor : 0;
    final targetSavingsBudget = Money.fromMinorUnits(targetSavingsMinor);

    // 6. Update or insert the Savings CategoryBudget in this cycle
    final existingBudget = await (db.select(db.categoryBudgetsTable)
          ..where((tbl) =>
              tbl.cycleId.equals(cycleId) &
              tbl.categoryId.equals(savingsCat.id)))
        .getSingleOrNull();

    final now = DateTime.now().toIso8601String();

    if (existingBudget != null) {
      if (existingBudget.budgetAmountMinor != targetSavingsMinor) {
        await (db.update(db.categoryBudgetsTable)
              ..where((tbl) => tbl.id.equals(existingBudget.id)))
            .write(
          CategoryBudgetsTableCompanion(
            budgetAmountMinor: Value(targetSavingsMinor),
            updatedAt: Value(now),
          ),
        );
      }
    } else {
      await db.into(db.categoryBudgetsTable).insert(
            CategoryBudgetsTableCompanion.insert(
              id: _uuid.v4(),
              cycleId: cycleId,
              categoryId: savingsCat.id,
              budgetAmountMinor: targetSavingsMinor,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    return targetSavingsBudget;
  }
}
