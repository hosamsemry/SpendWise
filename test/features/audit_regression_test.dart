import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/date/budget_cycle_calculator.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/notifications/notification_service.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/domain/budget_calculation_service.dart';
import 'package:money_tracker/features/budgets/domain/category_budget.dart';
import 'package:money_tracker/features/budgets/domain/threshold_monitor.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/presets/data/preset_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../test_helper.dart';

class MockNotificationService implements INotificationService {
  final List<int> shownNotificationIds = [];
  bool permissionRequested = false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return true;
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    shownNotificationIds.add(id);
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
  late CategoryRepository categoryRepo;
  late BudgetCycleRepository cycleRepo;
  late TransactionRepository transactionRepo;
  late BudgetCalculationService calcService;
  late MockNotificationService mockNotifications;
  late ThresholdMonitor thresholdMonitor;
  const calculator = BudgetCycleCalculator();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    cycleRepo = BudgetCycleRepository(db, calculator: calculator);
    transactionRepo = TransactionRepository(db);
    calcService = const BudgetCalculationService();
    mockNotifications = MockNotificationService();
    thresholdMonitor = ThresholdMonitor(
      db: db,
      notificationService: mockNotifications,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('C1 & C2: Money parsing and non-negative budget validations', () {
    test('C1: Money.parse and tryParse handle numbers with commas', () {
      final parsed1 = Money.parse('1,250.00');
      expect(parsed1.inMinorUnits, 125000);

      final parsed2 = Money.tryParse('10,500.50');
      expect(parsed2?.inMinorUnits, 1050050);

      final parsed3 = Money.parse('EGP 2,000.00');
      expect(parsed3.inMinorUnits, 200000);

      final parsed4 = Money.parse('1,250.00 EGP');
      expect(parsed4.inMinorUnits, 125000);
    });

    test(
      'C2: CategoryRepository rejects negative default allocations',
      () async {
        expect(
          () => categoryRepo.createCategory(
            name: 'Invalid Budget',
            defaultBudget: const Money.fromMinorUnits(-500),
          ),
          throwsA(isA<ArgumentError>()),
        );

        final validCat = await categoryRepo.createCategory(name: 'Valid');
        expect(
          () => categoryRepo.updateCategory(
            id: validCat.id,
            defaultBudget: const Money.fromMinorUnits(-1000),
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('C2: BudgetCycleRepository rejects negative budget amounts', () async {
      final cat = await categoryRepo.createCategory(name: 'Groceries');
      final cycle = await cycleRepo.getOrCreateCycleForDate(
        DateTime(2026, 10, 26),
      );

      expect(
        () => cycleRepo.updateCategoryBudget(
          cycleId: cycle.id,
          categoryId: cat.id,
          budgetAmount: const Money.fromMinorUnits(-100),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'M2: DB CHECK constraints enforce type, amounts, and category requirements',
      () async {
        final now = DateTime.now().toIso8601String();

        // Negative default budget in categories table fails CHECK
        expect(
          () => db
              .into(db.categoriesTable)
              .insert(
                CategoriesTableCompanion.insert(
                  id: 'c-neg',
                  name: 'Negative',
                  defaultBudgetMinor: const drift.Value(-500),
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsException,
        );

        // Invalid transaction type fails CHECK
        final cat = await categoryRepo.createCategory(name: 'General');
        expect(
          () => db
              .into(db.transactionsTable)
              .insert(
                TransactionsTableCompanion.insert(
                  id: 'tx-bad-type',
                  type: 'transfer',
                  amountMinor: 500,
                  categoryId: drift.Value(cat.id),
                  transactionDate: '2026-10-26',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsException,
        );

        // Expense with NULL category fails CHECK
        expect(
          () => db
              .into(db.transactionsTable)
              .insert(
                TransactionsTableCompanion.insert(
                  id: 'tx-null-cat',
                  type: 'expense',
                  amountMinor: 500,
                  categoryId: const drift.Value(null),
                  transactionDate: '2026-10-26',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
          throwsException,
        );
      },
    );
  });

  group('H1-H6: Budget cycle and transaction editing integrity', () {
    test(
      'H1: getCycleForDateOrNull returns null when cycle does not exist (no early creation)',
      () async {
        final futureDate = DateTime(2027, 5, 10);
        final nullCycle = await cycleRepo.getCycleForDateOrNull(futureDate);
        expect(nullCycle, isNull);

        // Confirm it was NOT inserted into DB
        final allCycles = await cycleRepo.getAllCycles();
        expect(allCycles.isEmpty, isTrue);
      },
    );

    test(
      'H2 & Q3: Adding category mid-cycle syncs to current cycle but never past cycles',
      () async {
        // 1. Create past cycle (August 2026: 2026-07-25 to 2026-08-24)
        final pastDate = DateTime(2026, 8, 10);
        final pastCycle = await cycleRepo.getOrCreateCycleForDate(pastDate);

        // 2. Create current cycle (today)
        final currentCycle = await cycleRepo.getOrCreateCycleForDate(
          DateTime.now(),
        );

        // 3. Create a new category now
        final newCat = await categoryRepo.createCategory(
          name: 'Gym',
          defaultBudget: Money.fromMajorUnits(800),
        );

        // Current cycle should have Gym budget
        final currentBudgets = await cycleRepo.getCycleBudgets(currentCycle.id);
        expect(currentBudgets[newCat.id]?.inMinorUnits, 80000);

        // Past cycle must NOT have Gym budget!
        final pastBudgets = await cycleRepo.getCycleBudgets(pastCycle.id);
        expect(pastBudgets.containsKey(newCat.id), isFalse);
      },
    );

    test(
      'H3: Archived categories with 0 budget and 0 spending are excluded from CycleSummary',
      () async {
        final food = await categoryRepo.createCategory(
          name: 'Food',
          defaultBudget: Money.fromMajorUnits(1000),
        );
        final oldGym = await categoryRepo.createCategory(
          name: 'Old Gym',
          defaultBudget: Money.fromMajorUnits(500),
        );

        // Archive Old Gym
        await categoryRepo.archiveCategory(oldGym.id);

        final cycle = calculator.getCycleForDate(DateTime(2026, 11, 1));
        // In this new cycle, Old Gym has no budget entry and no spending
        final summary = calcService.calculateCycleSummary(
          cycle: cycle,
          categories: [food, (await categoryRepo.getCategoryById(oldGym.id))!],
          budgetMap: {food.id: Money.fromMajorUnits(1000)},
          transactions: [],
        );

        expect(
          summary.categoryBudgets.any((b) => b.categoryId == oldGym.id),
          isFalse,
        );
        expect(
          summary.categoryBudgets.any((b) => b.categoryId == food.id),
          isTrue,
        );
      },
    );

    test(
      'H4: updateTransaction allows clearing category to null for income',
      () async {
        final salary = await categoryRepo.createCategory(name: 'Salary');

        // Create income with category
        final inc = await transactionRepo.addTransaction(
          type: TransactionType.income,
          amount: Money.fromMajorUnits(5000),
          categoryId: salary.id,
          date: DateTime(2026, 10, 26),
        );
        expect(inc.categoryId, salary.id);

        // Update and clear category to null (uncategorized)
        final updated = await transactionRepo.updateTransaction(
          id: inc.id,
          categoryId: null,
        );

        expect(updated.categoryId, isNull);
        expect(updated.categoryName, isNull);
      },
    );

    test(
      'H5 & updateTransaction: can update note or amount while preserving existing attributes',
      () async {
        final food = await categoryRepo.createCategory(name: 'Food');
        final tx = await transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(100),
          categoryId: food.id,
          date: DateTime(2026, 10, 26),
          note: 'Original note',
        );

        // Update only note to null
        final clearedNote = await transactionRepo.updateTransaction(
          id: tx.id,
          note: null,
        );
        expect(clearedNote.note, isNull);
        expect(clearedNote.amount, Money.fromMajorUnits(100));
        expect(clearedNote.categoryId, food.id);
      },
    );
  });

  group('M1, M5, M7: Features and Edge Cases', () {
    test(
      'M1: getTransactionsForCycle supports custom date-range filtering',
      () async {
        final cat = await categoryRepo.createCategory(name: 'Misc');
        final cycle = calculator.getCycleForDate(
          DateTime(2026, 10, 28),
        ); // 25 Oct - 24 Nov

        await transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(10),
          categoryId: cat.id,
          date: DateTime(2026, 10, 26),
        );
        await transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(20),
          categoryId: cat.id,
          date: DateTime(2026, 11, 5),
        );
        await transactionRepo.addTransaction(
          type: TransactionType.expense,
          amount: Money.fromMajorUnits(30),
          categoryId: cat.id,
          date: DateTime(2026, 11, 15),
        );

        // Query only between 2026-11-01 and 2026-11-10
        final filtered = await transactionRepo.getTransactionsForCycle(
          cycle,
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 10),
        );

        expect(filtered.length, 1);
        expect(filtered.first.amount, Money.fromMajorUnits(20));
      },
    );

    test(
      'M5: Threshold notification IDs are disjoint from cycleReminderNotificationId (25000)',
      () async {
        final cat = await categoryRepo.createCategory(
          name: 'Coffee',
          defaultBudget: Money.fromMajorUnits(100),
        );
        final cycle = await cycleRepo.getOrCreateCycleForDate(DateTime.now());

        // Over budget: 150 spent on 100 budget
        await thresholdMonitor.evaluateAndNotify(
          cycleId: cycle.id,
          budget: CategoryBudget(
            categoryId: cat.id,
            categoryName: cat.name,
            budgetedAmount: Money.fromMajorUnits(100),
            spentAmount: Money.fromMajorUnits(150),
          ),
        );

        expect(mockNotifications.shownNotificationIds.length, 1);
        final notifId = mockNotifications.shownNotificationIds.first;
        expect(notifId >= 30000 && notifId < 80000, isTrue);
        expect(notifId, isNot(NotificationService.cycleReminderNotificationId));
      },
    );

    test('M7: Note search treats % and _ as literal characters', () async {
      final cat = await categoryRepo.createCategory(name: 'Work');
      final cycle = calculator.getCycleForDate(DateTime(2026, 10, 26));

      await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(50),
        categoryId: cat.id,
        date: DateTime(2026, 10, 26),
        note: '100% bonus discount',
      );

      await transactionRepo.addTransaction(
        type: TransactionType.expense,
        amount: Money.fromMajorUnits(50),
        categoryId: cat.id,
        date: DateTime(2026, 10, 27),
        note: 'Special 100 bonus discount',
      );

      // Searching literally for '%' should match only the first transaction
      final results = await transactionRepo.getTransactionsForCycle(
        cycle,
        searchNote: '%',
      );

      expect(results.length, 1);
      expect(results.first.note, '100% bonus discount');
    });

    test('Preset categoryId and categoryName sync on category rename and delete', () async {
      final presetRepo = PresetRepository(db);
      final cat = await categoryRepo.createCategory(name: 'Transportation', color: '#123456');

      final preset = await presetRepo.createPreset(
        title: 'Metro',
        type: TransactionType.expense,
        categoryId: cat.id,
        amount: Money.fromMajorUnits(10),
      );

      expect(preset.categoryId, cat.id);
      expect(preset.categoryName, 'Transportation');

      // 1. Rename category
      await categoryRepo.updateCategory(id: cat.id, name: 'Commute');
      final presetsAfterRename = await presetRepo.getAllPresets();
      expect(presetsAfterRename.first.categoryName, 'Commute');

      // 2. Delete category
      await categoryRepo.deleteCategory(cat.id);
      final presetsAfterDelete = await presetRepo.getAllPresets();
      expect(presetsAfterDelete.first.categoryId, isNull);
      expect(presetsAfterDelete.first.categoryName, 'Commute');
    });

    test('Threshold monitor clears obsolete threshold events when spending drops below threshold', () async {
      final cat = await categoryRepo.createCategory(name: 'Groceries');
      final cycle = await cycleRepo.getOrCreateCycleForDate(DateTime(2026, 10, 26));

      // Over budget
      await thresholdMonitor.evaluateAndNotify(
        cycleId: cycle.id,
        budget: CategoryBudget(
          categoryId: cat.id,
          categoryName: cat.name,
          budgetedAmount: Money.fromMajorUnits(100),
          spentAmount: Money.fromMajorUnits(120),
        ),
      );
      expect(mockNotifications.shownNotificationIds.length, 1);

      // Spending reduced below 80% (e.g. refund/deletion)
      await thresholdMonitor.evaluateAndNotify(
        cycleId: cycle.id,
        budget: CategoryBudget(
          categoryId: cat.id,
          categoryName: cat.name,
          budgetedAmount: Money.fromMajorUnits(100),
          spentAmount: Money.fromMajorUnits(50),
        ),
      );

      // Subsequent over budget triggers notification again
      await thresholdMonitor.evaluateAndNotify(
        cycleId: cycle.id,
        budget: CategoryBudget(
          categoryId: cat.id,
          categoryName: cat.name,
          budgetedAmount: Money.fromMajorUnits(100),
          spentAmount: Money.fromMajorUnits(130),
        ),
      );
      expect(mockNotifications.shownNotificationIds.length, 2);
    });
  });
}
