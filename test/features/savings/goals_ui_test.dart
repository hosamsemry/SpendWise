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
import 'package:money_tracker/core/providers/savings_providers.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/savings/presentation/cycle_closeout_card.dart';
import 'package:money_tracker/features/savings/presentation/goal_form_sheet.dart';
import 'package:money_tracker/features/savings/presentation/goals_screen.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late ProviderContainer container;

  Future<void> boot() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '1'),
        );
    container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    await container.read(budgetCycleStartDayProvider.future);
  }

  Future<void> teardown() async {
    container.dispose();
    await db.close();
  }

  Future<void> pump(WidgetTester tester, Widget home, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<Map<String?, int>> buckets() async => (await container.read(savingsVaultRepositoryProvider).bucketBalances())
      .map((k, v) => MapEntry(k, v.inMinorUnits));

  testWidgets('create a goal, add money until it is reached, and celebrate', (tester) async {
    await boot();
    addTearDown(teardown);
    await container.read(savingsGoalServiceProvider).deposit(const Money.fromMinorUnits(500000));
    await pump(tester, const GoalsScreen());

    expect(find.text('Give your savings a purpose'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goals_create_first')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('goal_name_field')), 'Eid');
    await tester.enterText(find.byKey(const ValueKey('goal_target_field')), '3000');
    await tester.enterText(find.byKey(const ValueKey('goal_plan_field')), '500');
    await tester.ensureVisible(find.byKey(const ValueKey('goal_starting_field')));
    await tester.enterText(find.byKey(const ValueKey('goal_starting_field')), '1000');
    await tester.ensureVisible(find.byKey(const ValueKey('goal_save_button')));
    await tester.tap(find.byKey(const ValueKey('goal_save_button')));
    await tester.pumpAndSettle();

    final goal = (await container.read(savingsGoalRepositoryProvider).getGoals()).single;
    expect(goal.monthlyPlan!.inMinorUnits, 50000);
    expect(await buckets(), {null: 400000, goal.id: 100000});
    expect(find.textContaining('33%'), findsOneWidget);

    // Open the goal and add the rest.
    await tester.tap(find.text('Eid'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal_add_money')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('savings_amount_field')), '2000');
    await tester.tap(find.byKey(const ValueKey('savings_amount_submit')));
    await tester.pumpAndSettle();

    expect(find.text('You reached "Eid"!'), findsOneWidget);
    await tester.tap(find.text('Great'));
    await tester.pumpAndSettle();
    expect(find.text('ACHIEVED'), findsOneWidget);
    expect((await buckets())[goal.id], 300000);
  });

  testWidgets('taking out more than a goal holds is refused', (tester) async {
    await boot();
    addTearDown(teardown);
    final service = container.read(savingsGoalServiceProvider);
    await service.createGoal(name: 'Car', target: const Money.fromMinorUnits(5000000));
    final car = (await service.goalsWithBalances()).single.goal;
    await service.deposit(const Money.fromMinorUnits(20000), goalId: car.id);
    await pump(tester, const GoalsScreen());

    await tester.tap(find.text('Car'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal_take_out')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not count as spending'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('savings_amount_field')), '300');
    await tester.tap(find.byKey(const ValueKey('savings_amount_submit')));
    await tester.pumpAndSettle();
    expect(find.text('That is more than is available'), findsOneWidget);
    expect((await buckets())[car.id], 20000);
  });

  testWidgets('closeout card splits the surplus by monthly plans and sweeps it', (tester) async {
    await boot();
    addTearDown(teardown);

    // A previous cycle that ended 1,500 under budget.
    final cycleRepo = container.read(budgetCycleRepositoryProvider);
    final current = await container.read(currentCycleProvider.future);
    final prev = await cycleRepo.getOrCreateCycleForDate(cycleRepo.calculator.getPreviousCycle(current).startDate);
    final food = await container.read(categoryRepositoryProvider).createCategory(
          name: 'Food',
          type: CategoryType.expense,
          defaultBudget: const Money.fromMinorUnits(400000),
        );
    await cycleRepo.updateCategoryBudget(
      cycleId: prev.id,
      categoryId: food.id,
      budgetAmount: const Money.fromMinorUnits(400000),
    );
    await container.read(transactionRepositoryProvider).addTransaction(
          type: TransactionType.expense,
          amount: const Money.fromMinorUnits(250000),
          date: prev.startDate,
          categoryId: food.id,
        );

    final service = container.read(savingsGoalServiceProvider);
    await service.createGoal(
      name: 'Eid',
      target: const Money.fromMinorUnits(300000),
      monthlyPlan: const Money.fromMinorUnits(100000),
    );
    final eid = (await service.goalsWithBalances()).single.goal;
    container.read(refreshTriggerProvider.notifier).trigger();
    final closeout = (await container.read(pendingCycleCloseoutProvider.future))!;
    expect(closeout.surplus.inMinorUnits, 150000);

    await pump(tester, Scaffold(body: SingleChildScrollView(child: CycleCloseoutCard(closeout: closeout))));
    expect(find.byKey(ValueKey('closeout_split_${eid.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('closeout_split_unassigned')), findsOneWidget);

    // Change the split: everything to Eid.
    await tester.tap(find.byKey(const ValueKey('closeout_edit_split')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(ValueKey('split_field_${eid.id}')), '1600');
    await tester.pump();
    expect(find.textContaining('more than the surplus'), findsOneWidget);
    await tester.enterText(find.byKey(ValueKey('split_field_${eid.id}')), '1500');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('split_apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('closeout_split_unassigned')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('closeout_sweep_button')));
    await tester.pumpAndSettle();
    expect(await buckets(), {eid.id: 150000});

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await buckets(), isEmpty);
  });

  testWidgets('goals screen fits a narrow phone in Arabic', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await boot();
    addTearDown(teardown);
    final service = container.read(savingsGoalServiceProvider);
    await service.deposit(const Money.fromMinorUnits(987654321));
    await service.createGoal(
      name: 'صندوق الطوارئ لستة أشهر من المصروفات',
      target: const Money.fromMinorUnits(99999999900),
      targetDate: DateTime.now().add(const Duration(days: 400)),
      monthlyPlan: const Money.fromMinorUnits(500000),
      startingAmount: const Money.fromMinorUnits(123456789),
    );
    await pump(tester, const GoalsScreen(), locale: const Locale('ar'));
    expect(find.text('أهداف الادخار'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a goal whose target date has passed can still open the date picker', (tester) async {
    await boot();
    addTearDown(teardown);
    final service = container.read(savingsGoalServiceProvider);
    final now = DateTime.now();
    await service.createGoal(
      name: 'Trip',
      target: const Money.fromMinorUnits(100000),
      targetDate: DateTime(now.year, now.month - 2, 1),
    );
    final trip = (await service.goalsWithBalances()).single;

    await pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showGoalForm(ctx, existing: trip),
            child: const Text('edit'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('goal_date_tile')));
    await tester.tap(find.byKey(const ValueKey('goal_date_tile')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
