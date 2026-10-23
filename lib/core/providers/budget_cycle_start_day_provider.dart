import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'database_providers.dart';

const String budgetCycleStartDayKey = 'budget_cycle_start_day';

class BudgetCycleStartDayNotifier extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async {
    final db = ref.watch(appDatabaseProvider);
    final setting = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(budgetCycleStartDayKey)))
        .getSingleOrNull();

    if (setting != null) {
      final parsed = int.tryParse(setting.value);
      if (parsed != null && parsed >= 1 && parsed <= 31) {
        return parsed;
      }
    }
    return null; // No default value! Must be explicitly configured by the user.
  }

  Future<void> setStartDay(int day) async {
    if (day < 1 || day > 31) {
      throw ArgumentError('Cycle start day must be between 1 and 31');
    }
    await future;
    final db = ref.read(appDatabaseProvider);
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
      AppSettingsTableCompanion.insert(
        key: budgetCycleStartDayKey,
        value: day.toString(),
      ),
    );
    state = AsyncData(day);
  }
}

final budgetCycleStartDayProvider =
    AsyncNotifierProvider<BudgetCycleStartDayNotifier, int?>(
      BudgetCycleStartDayNotifier.new,
    );
