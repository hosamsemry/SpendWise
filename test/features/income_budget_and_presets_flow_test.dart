import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/presets/data/preset_repository.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late PresetRepository presetRepo;
  late TransactionRepository transactionRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
    presetRepo = PresetRepository(db);
    transactionRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Income Category Initial Budget & Presets Integration Tests', () {
    test(
      'Can create income category with initial default/expected budget',
      () async {
        final category = await categoryRepo.createCategory(
          name: 'Primary Salary',
          type: CategoryType.income,
          defaultBudget: Money.fromMajorUnits(25000), // 25,000 EGP
        );

        expect(category.type, CategoryType.income);
        expect(category.defaultBudget.inMinorUnits, 2500000);
        expect(category.defaultBudget.toFormattedString(), '25,000.00 EGP');

        final incomeCats = await categoryRepo.getAllCategories(
          type: CategoryType.income,
        );
        expect(incomeCats.length, 1);
        expect(incomeCats.first.defaultBudget.inMinorUnits, 2500000);
      },
    );

    test('Updating income category name preserves default budget', () async {
      final category = await categoryRepo.createCategory(
        name: 'Side Hustle',
        type: CategoryType.income,
        defaultBudget: Money.fromMajorUnits(5000),
      );

      await categoryRepo.updateCategory(
        id: category.id,
        name: 'Freelance & Side Hustle',
      );

      final updated = await categoryRepo.getCategoryById(category.id);
      expect(updated?.name, 'Freelance & Side Hustle');
      expect(updated?.defaultBudget.inMinorUnits, 500000);
    });

    test(
      'User can create quick preset based on income category with default amount',
      () async {
        final salaryCat = await categoryRepo.createCategory(
          name: 'Salary',
          type: CategoryType.income,
          defaultBudget: Money.fromMajorUnits(30000),
        );

        final preset = await presetRepo.createPreset(
          title: 'Monthly Paycheck',
          type: TransactionType.income,
          categoryId: salaryCat.id,
          amount: salaryCat.defaultBudget,
          note: 'Direct deposit',
        );

        expect(preset.title, 'Monthly Paycheck');
        expect(preset.type, TransactionType.income);
        expect(preset.categoryId, salaryCat.id);
        expect(preset.categoryName, 'Salary');
        expect(preset.amount.inMinorUnits, 3000000);

        // Verify creating a transaction from this preset
        final tx = await transactionRepo.addTransaction(
          type: preset.type,
          amount: preset.amount,
          date: DateTime(2026, 10, 25),
          categoryId: preset.categoryId,
          note: preset.note,
        );

        expect(tx.isIncome, isTrue);
        expect(tx.amount.inMinorUnits, 3000000);
        expect(tx.categoryName, 'Salary');
        expect(tx.note, 'Direct deposit');
      },
    );
  });
}
