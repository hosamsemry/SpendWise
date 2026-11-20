import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:money_tracker/features/dashboard/presentation/widgets/overspent_alert_card.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/features/transactions/presentation/add_edit_transaction_dialog.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  testWidgets(
    'OverspentAlertCard opens interactive breakdown sheet and recent transactions open edit sheet on tap',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(key: 'app_language', value: 'en'),
          );
      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(
              key: 'budget_cycle_start_day',
              value: '1',
            ),
          );

      final catRepo = CategoryRepository(db);
      final food = await catRepo.createCategory(
        name: 'Food',
        type: CategoryType.expense,
        defaultBudget: const Money.fromMinorUnits(100000), // 1,000
      );

      final cycleRepo = BudgetCycleRepository(db);
      await cycleRepo.getOrCreateCycleForDate(DateTime.now());

      // Spend 1,250 against 1,000 budget -> overspent by 250
      final txRepo = TransactionRepository(db);
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(125000),
        categoryId: food.id,
        date: DateTime.now(),
        note: 'Big Grocery Haul',
      );

      var navigatedToTransactions = false;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
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
            home: DashboardScreen(
              onNavigateToTransactions: () => navigatedToTransactions = true,
              onNavigateToBudgets: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. OverspentAlertCard renders with category name and opens breakdown sheet on tap
      final overspentFinder = find.byType(OverspentAlertCard);
      expect(overspentFinder, findsOneWidget);
      await tester.ensureVisible(overspentFinder);
      await tester.pumpAndSettle();
      await tester.tap(overspentFinder);
      await tester.pumpAndSettle();

      expect(find.text('Overspent Categories'), findsOneWidget);
      expect(find.text('250.00 Over'), findsOneWidget);

      await tester.tap(find.text('View Transactions'));
      await tester.pumpAndSettle();
      expect(navigatedToTransactions, isTrue);
      expect(container.read(categoryFilterProvider), food.id);

      // 2. Scroll to Recent Transactions and tap the transaction -> opens AddEditTransactionDialog
      await tester.scrollUntilVisible(
        find.text('-1,250.00'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('-1,250.00'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditTransactionDialog), findsOneWidget);
      expect(find.text('Edit Transaction'), findsOneWidget);
    },
  );
}
