import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:money_tracker/features/dashboard/presentation/widgets/near_limit_alert_card.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  Future<({AppDatabase db, Category food, Category transport})>
      createNearLimitDb() async {
    final db = AppDatabase(NativeDatabase.memory());
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
      name: 'Dining Out',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(100000), // 1,000 EGP
    );
    final transport = await catRepo.createCategory(
      name: 'Commute',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(100000), // 1,000 EGP
    );

    final cycleRepo = BudgetCycleRepository(db);
    await cycleRepo.getOrCreateCycleForDate(DateTime.now());

    // Spend 850 / 1,000 (85%) on Dining Out -> triggers >= 80% near-limit warning
    final txRepo = TransactionRepository(db);
    await txRepo.addTransaction(
      type: TransactionType.expense,
      amount: const Money.fromMinorUnits(85000),
      categoryId: food.id,
      date: DateTime.now(),
      note: 'Dinner',
    );

    return (db: db, food: food, transport: transport);
  }

  Widget buildDashboardApp(
    AppDatabase db, {
    VoidCallback? onNavigateToTransactions,
    VoidCallback? onNavigateToBudgets,
    ProviderContainer? container,
  }) {
    final app = MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DashboardScreen(
        onNavigateToTransactions: onNavigateToTransactions ?? () {},
        onNavigateToBudgets: onNavigateToBudgets ?? () {},
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(container: container, child: app);
    }
    return ProviderScope(
      key: UniqueKey(),
      overrides: [databaseProvider.overrideWithValue(db)],
      child: app,
    );
  }

  testWidgets(
    'Shows category name on 80% warning banner and opens breakdown sheet on tap',
    (tester) async {
      final setup = await createNearLimitDb();
      addTearDown(setup.db.close);

      var navigatedToTransactions = false;
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(setup.db)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        buildDashboardApp(
          setup.db,
          container: container,
          onNavigateToTransactions: () => navigatedToTransactions = true,
        ),
      );
      await tester.pumpAndSettle();

      // Banner displays category name and percentage directly
      expect(find.byType(NearLimitAlertCard), findsOneWidget);
      expect(find.textContaining('Dining Out (85%)'), findsOneWidget);

      // Scroll banner into view and tap to open breakdown sheet
      await tester.ensureVisible(find.byType(NearLimitAlertCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NearLimitAlertCard));
      await tester.pumpAndSettle();

      // Verify bottom sheet details
      expect(find.text('Near Budget Limit (≥ 80%)'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('View Transactions'), findsOneWidget);
      expect(find.text('Edit Budget'), findsOneWidget);

      // Tap View Transactions -> sets category filter and navigates
      await tester.tap(find.text('View Transactions'));
      await tester.pumpAndSettle();

      expect(navigatedToTransactions, isTrue);
      expect(container.read(categoryFilterProvider), setup.food.id);
    },
  );

  testWidgets(
    'Swiping right dismisses warning, persists dismissal, and reappears for new category',
    (tester) async {
      final setup = await createNearLimitDb();
      addTearDown(setup.db.close);

      await tester.pumpWidget(buildDashboardApp(setup.db));
      await tester.pumpAndSettle();

      final alertFinder = find.byType(NearLimitAlertCard);
      expect(alertFinder, findsOneWidget);

      // Scroll into view and swipe right to dismiss
      await tester.ensureVisible(alertFinder);
      await tester.pumpAndSettle();
      await tester.drag(alertFinder, const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.byType(NearLimitAlertCard), findsNothing);

      // Rebuild with a brand-new ProviderScope (simulating app restart)
      await tester.pumpWidget(buildDashboardApp(setup.db));
      await tester.pumpAndSettle();

      // Still dismissed because it was persisted in app_settings
      expect(find.byType(NearLimitAlertCard), findsNothing);

      // Now a SECOND category (Commute) crosses 80%
      final txRepo = TransactionRepository(setup.db);
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(90000), // 90%
        categoryId: setup.transport.id,
        date: DateTime.now(),
        note: 'Monthly pass',
      );

      // Rebuild dashboard with a fresh ProviderScope -> alert reappears ONLY for Commute
      await tester.pumpWidget(buildDashboardApp(setup.db));
      await tester.pumpAndSettle();

      expect(find.byType(NearLimitAlertCard), findsOneWidget);
      expect(find.textContaining('Commute (90%)'), findsOneWidget);
      expect(find.textContaining('Dining Out (85%)'), findsNothing);
    },
  );

  testWidgets(
    'Swiping left also dismisses the 80% warning banner cleanly',
    (tester) async {
      final setup = await createNearLimitDb();
      addTearDown(setup.db.close);

      await tester.pumpWidget(buildDashboardApp(setup.db));
      await tester.pumpAndSettle();

      final alertFinder = find.byType(NearLimitAlertCard);
      expect(alertFinder, findsOneWidget);

      // Scroll into view and swipe left to dismiss
      await tester.ensureVisible(alertFinder);
      await tester.pumpAndSettle();
      await tester.drag(alertFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.byType(NearLimitAlertCard), findsNothing);
    },
  );
}
