import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/budgets/presentation/budgets_screen.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import '../../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  Future<AppDatabase> createSeededDatabase() async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'app_language', value: 'en'),
        );
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(
            key: 'budget_cycle_start_day',
            value: '25',
          ),
        );

    final catRepo = CategoryRepository(db);
    for (var i = 1; i <= 15; i++) {
      await catRepo.createCategory(
        name: 'Category ${i.toString().padLeft(2, '0')}',
        type: CategoryType.expense,
        defaultBudget: Money.fromMinorUnits(i * 10000), // i * 100 EGP
      );
    }

    final cycleRepo = BudgetCycleRepository(db);
    await cycleRepo.getOrCreateCycleForDate(DateTime.now());
    return db;
  }

  Widget buildTestApp(AppDatabase db) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BudgetsScreen(),
      ),
    );
  }

  testWidgets(
    'Editing a category budget preserves scroll position in Cycle Budgets tab',
    (tester) async {
      final db = await createSeededDatabase();
      addTearDown(db.close);

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      // Scroll down near the bottom of the budgets list
      final listFinder = find.byType(ListView).first;
      await tester.drag(listFinder, const Offset(0, -1200));
      await tester.pumpAndSettle();

      final scrollableBefore = tester.state<ScrollableState>(
        find.descendant(of: listFinder, matching: find.byType(Scrollable)),
      );
      final offsetBefore = scrollableBefore.position.pixels;
      expect(offsetBefore, greaterThan(400));

      // Tap the edit button on a visible category card near the bottom
      final editButtons = find.byTooltip('Edit Budget');
      expect(editButtons, findsWidgets);
      await tester.tap(editButtons.last);
      await tester.pumpAndSettle();

      // Enter a new budget amount and save
      final textField = find.byType(TextField).first;
      await tester.enterText(textField, '2500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Verify updated amount is rendered
      expect(find.textContaining('2,500'), findsWidgets);

      // Verify scroll position was NOT reset to top
      final scrollableAfter = tester.state<ScrollableState>(
        find.descendant(of: listFinder, matching: find.byType(Scrollable)),
      );
      expect(scrollableAfter.position.pixels, closeTo(offsetBefore, 1.0));
    },
  );

  testWidgets(
    'Editing a category default allocation preserves scroll position in unified envelopes list',
    (tester) async {
      final db = await createSeededDatabase();
      addTearDown(db.close);

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      // Scroll down near the bottom of the envelopes list
      final listFinder = find.byType(ListView).first;
      await tester.drag(listFinder, const Offset(0, -800));
      await tester.pumpAndSettle();

      final scrollableBefore = tester.state<ScrollableState>(
        find.descendant(of: listFinder, matching: find.byType(Scrollable)),
      );
      final offsetBefore = scrollableBefore.position.pixels;
      expect(offsetBefore, greaterThan(200));

      // Tap the edit button on a visible category near the bottom
      final editIcons = find.byIcon(Icons.edit_outlined);
      expect(editIcons, findsWidgets);
      await tester.tap(editIcons.last);
      await tester.pumpAndSettle();

      // Update budget and check "update default allocation for future cycles"
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      await tester.enterText(textFields.first, '3450');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      // Verify updated default budget is displayed
      expect(find.textContaining('3,450'), findsWidgets);

      // Verify scroll position was NOT reset to top
      final scrollableAfter = tester.state<ScrollableState>(
        find.descendant(of: listFinder, matching: find.byType(Scrollable)),
      );
      expect(scrollableAfter.position.pixels, closeTo(offsetBefore, 1.0));
    },
  );
}
