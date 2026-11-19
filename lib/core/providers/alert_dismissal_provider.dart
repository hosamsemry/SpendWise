import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'database_providers.dart';

class AlertDismissalTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

/// Lightweight trigger to refresh dismissed alert state without reloading full cycle summaries.
final alertDismissalTriggerProvider =
    NotifierProvider<AlertDismissalTriggerNotifier, int>(
      AlertDismissalTriggerNotifier.new,
    );

class OptimisticDismissedNearLimitNotifier
    extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => const {};

  void dismiss(String cycleId, Iterable<String> categoryIds) {
    final existing = state[cycleId] ?? const <String>{};
    state = {
      ...state,
      cycleId: {...existing, ...categoryIds},
    };
  }
}

/// Immediate in-memory dismissal state so [Dismissible] is removed synchronously on swipe,
/// while [AlertDismissalRepository] persists it to SQLite across app restarts.
final optimisticDismissedNearLimitProvider =
    NotifierProvider<OptimisticDismissedNearLimitNotifier, Map<String, Set<String>>>(
      OptimisticDismissedNearLimitNotifier.new,
    );

class AlertDismissalRepository {
  final AppDatabase db;

  const AlertDismissalRepository(this.db);

  static String _keyForCycle(String cycleId) => 'dismissed_near_limit_$cycleId';

  Future<Set<String>> getDismissedNearLimitCategoryIds(String cycleId) async {
    final entry = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(_keyForCycle(cycleId))))
        .getSingleOrNull();
    final raw = entry?.value;
    if (raw == null || raw.isEmpty) return <String>{};
    return raw.split(',').where((id) => id.isNotEmpty).toSet();
  }

  Future<void> dismissNearLimitCategories(
    String cycleId,
    Iterable<String> categoryIds,
  ) async {
    final existing = await getDismissedNearLimitCategoryIds(cycleId);
    final updated = {...existing, ...categoryIds};
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: _keyForCycle(cycleId),
            value: updated.join(','),
          ),
        );
  }
}

final alertDismissalRepositoryProvider = Provider<AlertDismissalRepository>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return AlertDismissalRepository(db);
});

/// Returns the set of category IDs whose 80% near-limit warning has been dismissed for [cycleId].
final dismissedNearLimitCategoriesProvider =
    FutureProvider.family<Set<String>, String>((ref, cycleId) async {
      ref.watch(alertDismissalTriggerProvider);
      final repo = ref.watch(alertDismissalRepositoryProvider);
      return repo.getDismissedNearLimitCategoryIds(cycleId);
    });
