import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/presentation/cycle_summary_screen.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  testWidgets(
    'CycleSummaryScreen uses high-contrast theme-adaptive colors in Dark Mode and Light Mode',
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
        defaultBudget: const Money.fromMinorUnits(200000),
      );
      final cycleRepo = BudgetCycleRepository(db);
      final cycle = await cycleRepo.getOrCreateCycleForDate(DateTime.now());

      final txRepo = TransactionRepository(db);
      await txRepo.addTransaction(
        type: TransactionType.expense,
        amount: const Money.fromMinorUnits(50000),
        categoryId: food.id,
        date: DateTime.now(),
        note: 'Groceries',
      );

      // 1. Dark Mode verification: text must use bright Porcelain white, NOT light-theme dark ink
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: CycleSummaryScreen(cycle: cycle),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final analysisHeading = tester.widget<Text>(
        find.text('Budget Balance Analysis'),
      );
      expect(analysisHeading.style?.color, AppColorsDark.textPrimary);

      final breakdownHeading = tester.widget<Text>(
        find.text('Per-Category Breakdown', skipOffstage: false),
      );
      expect(breakdownHeading.style?.color, AppColorsDark.textPrimary);

      final rangeText = tester.widget<Text>(find.text(cycle.formattedRange));
      expect(rangeText.style?.color, AppColorsDark.textPrimary);

      // 2. Light Mode verification: text uses crisp Obsidian ink
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: CycleSummaryScreen(cycle: cycle),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lightAnalysisHeading = tester.widget<Text>(
        find.text('Budget Balance Analysis'),
      );
      expect(lightAnalysisHeading.style?.color, AppColors.textPrimary);
    },
  );
}
