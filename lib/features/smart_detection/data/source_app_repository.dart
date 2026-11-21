import 'dart:convert';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/smart_detection/domain/source_app.dart';

const String watchedSourceAppsKey = 'smart_detection_watched_apps_json';
const String dismissedSourceAppsKey = 'smart_detection_dismissed_apps_json';

/// Persists which apps may be read as transaction sources (watched) and which
/// suggested apps the user declined (dismissed), in `app_settings` so the
/// choice survives backup/restore. The native listener gets a mirrored copy
/// via `SmartDetectionChannel.setSourcePolicy`.
class SourceAppRepository {
  final AppDatabase db;

  const SourceAppRepository(this.db);

  Future<List<WatchedSourceApp>> getWatchedApps() async {
    final raw = await _read(watchedSourceAppsKey);
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(WatchedSourceApp.fromJson)
        .where((app) => app.packageName.isNotEmpty)
        .toList();
  }

  Future<List<String>> getDismissedPackages() async {
    final raw = await _read(dismissedSourceAppsKey);
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  /// Watches [packageName]; also removes it from the dismissed list.
  Future<void> watchApp({required String packageName, required String label}) async {
    final watched = await getWatchedApps();
    if (!watched.any((a) => a.packageName == packageName)) {
      await _write(watchedSourceAppsKey, [
        ...watched.map((a) => a.toJson()),
        WatchedSourceApp(packageName: packageName, label: label).toJson(),
      ]);
    }
    final dismissed = await getDismissedPackages();
    if (dismissed.contains(packageName)) {
      await _write(
        dismissedSourceAppsKey,
        dismissed.where((p) => p != packageName).toList(),
      );
    }
  }

  Future<void> unwatchApp(String packageName) async {
    final watched = await getWatchedApps();
    await _write(
      watchedSourceAppsKey,
      watched
          .where((a) => a.packageName != packageName)
          .map((a) => a.toJson())
          .toList(),
    );
  }

  /// Stops suggesting [packageName] until the user watches it manually.
  Future<void> dismissApp(String packageName) async {
    final dismissed = await getDismissedPackages();
    if (dismissed.contains(packageName)) return;
    await _write(dismissedSourceAppsKey, [...dismissed, packageName]);
  }

  Future<Object?> _read(String key) async {
    final entry = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    if (entry == null) return null;
    try {
      return jsonDecode(entry.value);
    } on FormatException {
      return null;
    }
  }

  Future<void> _write(String key, Object value) async {
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: key, value: jsonEncode(value)),
        );
  }
}
