import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/smart_detection/data/pending_transaction_repository.dart';
import 'package:money_tracker/features/smart_detection/presentation/pending_transactions_sheet.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/features/transactions/presentation/add_edit_transaction_dialog.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late CategoryRepository categoryRepo;
  late TransactionRepository txRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'app_language', value: 'en'),
        );
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(
            key: 'budget_cycle_start_day',
            value: '1',
          ),
        );
    await BudgetCycleRepository(db).getOrCreateCycleForDate(DateTime.now());
    categoryRepo = CategoryRepository(db);
    txRepo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildLocalizedTestApp(ProviderContainer container, Widget child) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  test(
    'addTransaction increments category selection counts while updateTransaction does not',
    () async {
      final dining = await categoryRepo.createCategory(
        name: 'Dining',
        type: CategoryType.expense,
      );
      final transport = await categoryRepo.createCategory(
        name: 'Transport',
        type: CategoryType.expense,
      );
      final salary = await categoryRepo.createCategory(
        name: 'Salary',
        type: CategoryType.income,
      );

      expect(await categoryRepo.getCategorySelectionCounts(), isEmpty);

      final firstTx = await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(5000),
        categoryId: dining.id,
        date: DateTime(2026, 11, 20),
      );
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(3000),
        categoryId: dining.id,
        date: DateTime(2026, 11, 20),
      );
      await txRepo.addTransaction(
        type: TransactionType.income,
        amount: const Money.fromMinorUnits(100000),
        categoryId: null,
        date: DateTime(2026, 11, 20),
      );

      // Editing an existing transaction must not increment selection counts.
      await txRepo.updateTransaction(
        id: firstTx.id,
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(5500),
        categoryId: transport.id,
        date: DateTime(2026, 11, 20),
      );

      await txRepo.addTransaction(
        type: TransactionType.income,
        amount: const Money.fromMinorUnits(500000),
        categoryId: salary.id,
        date: DateTime(2026, 11, 20),
      );

      final counts = await categoryRepo.getCategorySelectionCounts();
      expect(counts[dining.id], equals(2));
      expect(counts[salary.id], equals(1));
      expect(counts.containsKey(transport.id), isFalse);
    },
  );

  test(
    'getAllCategories(sortByFrequency: true) puts highest-count categories first and breaks ties alphabetically',
    () async {
      final bills = await categoryRepo.createCategory(
        name: 'Bills',
        type: CategoryType.expense,
      );
      final food = await categoryRepo.createCategory(
        name: 'Food',
        type: CategoryType.expense,
      );
      final transport = await categoryRepo.createCategory(
        name: 'Transport',
        type: CategoryType.expense,
      );
      final utilities = await categoryRepo.createCategory(
        name: 'Utilities',
        type: CategoryType.expense,
      );

      // Initially alphabetical.
      final initialSorted = await categoryRepo.getAllCategories(
        type: CategoryType.expense,
        sortByFrequency: true,
      );
      expect(
        initialSorted.map((c) => c.name).toList(),
        equals(['Bills', 'Food', 'Transport', 'Utilities']),
      );

      // Choose Utilities 3 times, Transport 1 time, Food 1 time, Bills 0 times.
      for (var i = 0; i < 3; i++) {
        await txRepo.addTransaction(
          type: TransactionType.expense,
          amount: const Money.fromMinorUnits(1000),
          categoryId: utilities.id,
          date: DateTime(2026, 11, 20),
        );
      }
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(1000),
        categoryId: transport.id,
        date: DateTime(2026, 11, 20),
      );
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(1000),
        categoryId: food.id,
        date: DateTime(2026, 11, 20),
      );

      final freqSorted = await categoryRepo.getAllCategories(
        type: CategoryType.expense,
        sortByFrequency: true,
      );
      expect(
        freqSorted.map((c) => c.name).toList(),
        equals(['Utilities', 'Food', 'Transport', 'Bills']),
      );

      // Default sort remains alphabetical.
      final alphaSorted = await categoryRepo.getAllCategories(
        type: CategoryType.expense,
      );
      expect(
        alphaSorted.map((c) => c.name).toList(),
        equals(['Bills', 'Food', 'Transport', 'Utilities']),
      );
      expect(bills.id, isNotEmpty);
    },
  );

  testWidgets(
    'AddEditTransactionDialog displays category chips sorted by selection frequency',
    (tester) async {
      await categoryRepo.createCategory(
        name: 'Bills',
        type: CategoryType.expense,
      );
      await categoryRepo.createCategory(
        name: 'Food',
        type: CategoryType.expense,
      );
      final utilities = await categoryRepo.createCategory(
        name: 'Utilities',
        type: CategoryType.expense,
      );

      // Make Utilities the most chosen category, then Food.
      for (var i = 0; i < 2; i++) {
        await txRepo.addTransaction(
          type: TransactionType.expense,
          amount: const Money.fromMinorUnits(1000),
          categoryId: utilities.id,
          date: DateTime(2026, 11, 20),
        );
      }

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container.read(categoriesProvider.future);

      await tester.pumpWidget(
        buildLocalizedTestApp(container, const AddEditTransactionDialog()),
      );
      await tester.pumpAndSettle();

      final chipLabels = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((chip) => (chip.label as Text).data)
          .where((label) => label == 'Utilities' || label == 'Bills' || label == 'Food')
          .toList();

      expect(chipLabels, equals(['Utilities', 'Bills', 'Food']));
    },
  );

  testWidgets(
    'PendingTransactionsSheet displays category chips sorted by selection frequency',
    (tester) async {
      await categoryRepo.createCategory(
        name: 'Bills',
        type: CategoryType.expense,
      );
      final transport = await categoryRepo.createCategory(
        name: 'Transport',
        type: CategoryType.expense,
      );
      final utilities = await categoryRepo.createCategory(
        name: 'Utilities',
        type: CategoryType.expense,
      );

      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(1000),
        categoryId: utilities.id,
        date: DateTime(2026, 11, 20),
      );
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(1000),
        categoryId: utilities.id,
        date: DateTime(2026, 11, 20),
      );
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(1000),
        categoryId: transport.id,
        date: DateTime(2026, 11, 20),
      );

      final pendingRepo = PendingTransactionRepository(db);
      final pending = await pendingRepo.ingestMessage(
        'IPN transfer sent with amount of EGP 100.00 from 5561 on 18/11 at 03:49 PM. Ref# 18369757.',
        sourcePackage: 'test',
      );
      expect(pending, isNotNull);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await container.read(categoriesProvider.future);

      await tester.pumpWidget(
        buildLocalizedTestApp(container, const PendingTransactionsSheet()),
      );
      await tester.pumpAndSettle();

      final chipLabels = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((chip) => (chip.label as Text).data)
          .where(
            (label) =>
                label == 'Utilities' || label == 'Transport' || label == 'Bills',
          )
          .toList();

      expect(chipLabels, equals(['Utilities', 'Transport', 'Bills']));
    },
  );
}
