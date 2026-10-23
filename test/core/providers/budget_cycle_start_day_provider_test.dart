import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  group('budgetCycleStartDayProvider Tests', () {
    test('Defaults to null (no default value) when no setting is saved', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      final initialDay = await container.read(budgetCycleStartDayProvider.future);
      expect(initialDay, isNull);

      await db.close();
      container.dispose();
    });

    test('Updates start day and persists to database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      await container.read(budgetCycleStartDayProvider.notifier).setStartDay(1);
      final day = container.read(budgetCycleStartDayProvider).value;
      expect(day, 1);

      // Verify in database
      final savedRow = await (db.select(db.appSettingsTable)
            ..where((tbl) => tbl.key.equals('budget_cycle_start_day')))
          .getSingleOrNull();
      expect(savedRow, isNotNull);
      expect(savedRow!.value, '1');

      // Verify a new container loading from same DB picks up the saved value
      final container2 = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      final loadedDay = await container2.read(budgetCycleStartDayProvider.future);
      expect(loadedDay, 1);

      await db.close();
      container.dispose();
      container2.dispose();
    });

    test('Throws ArgumentError for days outside 1..31', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      expect(
        () => container.read(budgetCycleStartDayProvider.notifier).setStartDay(0),
        throwsArgumentError,
      );
      expect(
        () => container.read(budgetCycleStartDayProvider.notifier).setStartDay(32),
        throwsArgumentError,
      );

      await db.close();
      container.dispose();
    });

    test('budgetCycleRepositoryProvider updates calculator when startDay changes', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      // Wait for initial load
      await container.read(budgetCycleStartDayProvider.future);

      // Initially fallback to 1 before user configures
      var repo = container.read(budgetCycleRepositoryProvider);
      expect(repo.calculator.startDay, 1);

      await container.read(budgetCycleStartDayProvider.notifier).setStartDay(15);
      repo = container.read(budgetCycleRepositoryProvider);
      expect(repo.calculator.startDay, 15);

      await db.close();
      container.dispose();
    });
  });
}
