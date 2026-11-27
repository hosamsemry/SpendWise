import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:money_tracker/features/dashboard/presentation/widgets/balance_hero_card.dart';
import 'package:money_tracker/features/savings/presentation/savings_vault_card.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  Future<AppDatabase> createSeededDb() async {
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
      name: 'Food',
      type: CategoryType.expense,
      defaultBudget: const Money.fromMinorUnits(1000000), // 10,000 EGP
    );
    final salary = await catRepo.createCategory(
      name: 'Salary',
      type: CategoryType.income,
      defaultBudget: const Money.fromMinorUnits(2500000), // 25,000 EGP
    );

    final cycleRepo = BudgetCycleRepository(db);
    await cycleRepo.getOrCreateCycleForDate(DateTime.now());

    final txRepo = TransactionRepository(db);
    await txRepo.addTransaction(
      type: TransactionType.income,
      amount: const Money.fromMinorUnits(2500000), // 25,000 EGP income
      categoryId: salary.id,
      date: DateTime.now(),
      note: 'Monthly salary',
    );
    await txRepo.addTransaction(
      type: TransactionType.expense,
      amount: const Money.fromMinorUnits(123400), // 1,234 EGP spent today
      categoryId: food.id,
      date: DateTime.now(),
      note: 'Groceries',
    );

    return db;
  }

  testWidgets(
    'Tapping dashboard hero card masks all monetary numbers and tapping again reveals them',
    (tester) async {
      final db = await createSeededDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: DashboardScreen(
              onNavigateToTransactions: () {},
              onNavigateToBudgets: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heroFinder = find.byType(BalanceHeroCard);
      expect(heroFinder, findsOneWidget);

      // Initially visible inside the hero card:
      // Remaining = +8,766 EGP, Total Budgeted = 10,000 EGP,
      // Today & Cycle Spent = 1,234 EGP (Total Income is intentionally omitted from Hero Card)
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('8,766')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('10,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('1,234')),
        findsNWidgets(2), // Today's spending + Cycle spent
      );
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('25,000')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: heroFinder,
          matching: find.byIcon(Icons.visibility_outlined),
        ),
        findsOneWidget,
      );

      // Tap anywhere on the hero card to hide all money numbers
      await tester.tap(heroFinder);
      await tester.pumpAndSettle();

      // None of the monetary figures should appear inside the hero card
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('8,766')),
        findsNothing,
      );
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('10,000')),
        findsNothing,
      );
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('1,234')),
        findsNothing,
      );
      // No EGP currency amounts remain inside the hero card
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('EGP')),
        findsNothing,
      );

      // Masked dots and visibility_off icon are displayed
      expect(
        find.descendant(of: heroFinder, matching: find.text('••••••')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('••••')),
        findsAtLeastNWidgets(4),
      );
      expect(
        find.descendant(
          of: heroFinder,
          matching: find.byIcon(Icons.visibility_off_rounded),
        ),
        findsOneWidget,
      );

      // Savings Vault balance and Dashboard category/recent transaction amounts are also masked
      final vaultFinder = find.byType(SavingsVaultCard);
      expect(
        find.descendant(of: vaultFinder, matching: find.text('••••••')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: vaultFinder, matching: find.textContaining('EGP')),
        findsNothing,
      );
      expect(find.text('•••• / ••••', skipOffstage: false), findsWidgets);

      // Tap again to reveal all numbers
      await tester.tap(heroFinder);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('8,766')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: heroFinder, matching: find.textContaining('1,234')),
        findsNWidgets(2),
      );
    },
  );
}
