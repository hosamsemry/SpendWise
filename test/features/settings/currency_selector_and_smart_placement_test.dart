import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/currency_provider.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/presets/data/preset_repository.dart';
import 'package:money_tracker/features/settings/presentation/settings_screen.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:money_tracker/main.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  tearDown(() {
    Money.applyCurrency(AppCurrency.egp, isArabic: false);
  });

  testWidgets(
    'Dynamic Currency Selector updates Hero Card and Savings Vault while lists and chips use minimalist smart placement',
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
        defaultBudget: const Money.fromMinorUnits(300000), // 3,000.00
      );

      final cycleRepo = BudgetCycleRepository(db);
      await cycleRepo.getOrCreateCycleForDate(DateTime.now());

      final txRepo = TransactionRepository(db);
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(50000), // 500.00
        categoryId: food.id,
        date: DateTime.now(),
        note: 'Lunch',
      );

      final presetRepo = PresetRepository(db);
      await presetRepo.createPreset(
        title: 'Coffee',
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(4500), // 45.00
        categoryId: food.id,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MoneyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Default currency is EGP on Hero Card and Savings Vault
      expect(find.text('+2,500.00 EGP'), findsOneWidget);
      expect(find.text('of 3,000.00 EGP'), findsOneWidget);
      expect(find.text('0.00 EGP'), findsWidgets); // Savings Vault / Income

      // 2. Smart Placement Rule: Quick chip, category budget row, and recent transaction have NO currency symbol
      expect(find.text('Coffee • 45.00'), findsOneWidget);
      expect(find.text('500.00 / 3,000.00'), findsOneWidget);
      expect(find.text('-500.00', skipOffstage: false), findsWidgets);

      // 3. Open Settings via Dashboard AppBar gear icon
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      final settingsScrollable = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      );

      await tester.scrollUntilVisible(
        find.text('Primary Currency'),
        100,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();

      expect(find.text('Primary Currency'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('currency_chip_NONE')),
        50,
        scrollable: settingsScrollable,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('currency_chip_EGP')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency_chip_SAR')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency_chip_AED')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency_chip_USD')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency_chip_EUR')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency_chip_GBP')), findsOneWidget);
      expect(find.byKey(const ValueKey('currency_chip_NONE')), findsOneWidget);

      // 4. Select SAR
      await tester.ensureVisible(find.byKey(const ValueKey('currency_chip_SAR')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('currency_chip_SAR')));
      await tester.pumpAndSettle();

      // Verify persisted in app_settings
      final savedSar = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals(primaryCurrencyKey)))
          .getSingle();
      expect(savedSar.value, 'SAR');

      // Pop back to Dashboard
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Hero Card and Savings Vault now show SAR
      expect(find.text('+2,500.00 SAR'), findsOneWidget);
      expect(find.text('of 3,000.00 SAR'), findsOneWidget);
      expect(find.text('0.00 SAR'), findsWidgets);

      // Lists and chips remain clean plain numbers
      expect(find.text('Coffee • 45.00'), findsOneWidget);
      expect(find.text('500.00 / 3,000.00'), findsOneWidget);
      expect(find.text('-500.00', skipOffstage: false), findsWidgets);

      // 5. Open Settings and select "None / Plain Numbers"
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('currency_chip_NONE')),
        50,
        scrollable: find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('currency_chip_NONE')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('currency_chip_NONE')));
      await tester.pumpAndSettle();

      // Pop back to Dashboard
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Even Hero Card and Savings Vault now show plain numbers with no currency suffix
      expect(find.text('+2,500.00'), findsOneWidget);
      expect(find.text('of 3,000.00'), findsOneWidget);
    },
  );
}
