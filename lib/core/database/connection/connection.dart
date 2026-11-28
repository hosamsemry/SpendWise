import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/database/pre_upgrade_snapshot.dart';
import 'package:path_provider/path_provider.dart';

/// Opens a connection to the application SQLite file on native platforms.
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'money_tracker.sqlite'));
    try {
      final support = await getApplicationSupportDirectory();
      snapshotBeforeUpgrade(
        database: file,
        into: Directory(p.join(support.path, 'safety_snapshots')),
        targetVersion: AppDatabase.currentSchemaVersion,
      );
    } catch (e) {
      // Never block opening the app; the upgrade itself still runs.
      debugPrint('Pre-upgrade snapshot failed: $e');
    }
    return NativeDatabase.createInBackground(file);
  });
}
