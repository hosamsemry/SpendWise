import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/app/theme/app_theme.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/categories/data/category_repository.dart';
import 'package:money_tracker/features/categories/domain/category.dart';
import 'package:money_tracker/features/transactions/presentation/add_edit_transaction_dialog.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  /// Opens the add sheet as a real modal sheet on a 393x852 phone, then
  /// raises a 330px keyboard over the autofocused amount field.
  Future<double> openWithKeyboard(WidgetTester tester, List<String> names) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'app_language', value: 'en'),
        );
    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '1'),
        );
    await BudgetCycleRepository(db).getOrCreateCycleForDate(DateTime.now());
    final repo = CategoryRepository(db);
    for (final n in names) {
      await repo.createCategory(name: n, type: CategoryType.expense);
    }
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(categoriesProvider.future);

    const size = Size(393, 852);
    const keyboard = 330.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
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
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AddEditTransactionDialog.show(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The keyboard rises; Android drops the bottom inset while it is open.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    tester.view.padding = const FakeViewPadding(top: 24);
    await tester.pumpAndSettle();
    return size.height - keyboard;
  }

  testWidgets('category chips stay above the keyboard while typing the amount', (tester) async {
    final keyboardTop = await openWithKeyboard(
      tester,
      ['Food', 'Transportation', 'Social Life', 'Groceries', 'Utilities', 'Health'],
    );

    final amount = tester.getRect(find.byType(TextField).first);
    expect(amount.top, greaterThanOrEqualTo(24));
    expect(amount.bottom, lessThanOrEqualTo(keyboardTop));

    final chips = find.byType(ChoiceChip);
    expect(chips, findsNWidgets(6));
    for (final chip in chips.evaluate()) {
      final r = tester.getRect(find.byWidget(chip.widget));
      expect(r.top, greaterThanOrEqualTo(24), reason: 'chip cut off at the top');
      expect(r.bottom, lessThanOrEqualTo(keyboardTop), reason: 'chip behind the keyboard');
    }
  });

  testWidgets('with many categories the amount and the most-used chips stay visible', (tester) async {
    final keyboardTop = await openWithKeyboard(tester, [
      'Food', 'Transportation', 'Social Life', 'Groceries', 'Utilities',
      'Health', 'Shopping', 'Education', 'Gifts', 'Entertainment',
    ]);

    final amount = tester.getRect(find.byType(TextField).first);
    expect(amount.top, greaterThanOrEqualTo(24));
    expect(amount.bottom, lessThanOrEqualTo(keyboardTop));

    // Chips are sorted by use, so the first ones must be on screen.
    final first = tester.getRect(find.byType(ChoiceChip).first);
    expect(first.top, greaterThan(amount.bottom));
    expect(first.bottom, lessThanOrEqualTo(keyboardTop));
  });
}
