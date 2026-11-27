import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';
import 'package:money_tracker/features/backup/data/safety_snapshot_store.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  late AppDatabase db;
  late Directory root;
  late SafetySnapshotStore store;
  late BackupService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('safety_snapshot_test');
    store = SafetySnapshotStore(root: () async => root);
    service = BackupService(db, safetySnapshots: store);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> setSetting(String key, String value) => db
      .into(db.appSettingsTable)
      .insertOnConflictUpdate(
        AppSettingsTableCompanion.insert(key: key, value: value),
      );

  Future<String?> setting(String key) async => (await (db.select(
    db.appSettingsTable,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> addCategory(String id, String name) => db
      .into(db.categoriesTable)
      .insert(CategoriesTableCompanion.insert(
        id: id,
        name: name,
        type: const Value('expense'),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

  Future<List<String>> categoryNames() async =>
      (await db.select(db.categoriesTable).get()).map((c) => c.name).toList();

  test('a restore can be undone, bringing back the data and PIN from before', () async {
    await addCategory('mine', 'My data');
    await setSetting('pin_hash', 'my_pin');

    // A backup from somewhere else, with a different PIN.
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await other.into(other.categoriesTable).insert(CategoriesTableCompanion.insert(
      id: 'theirs',
      name: 'Other data',
      type: const Value('expense'),
      createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
    ));
    await other.into(other.appSettingsTable).insert(
      AppSettingsTableCompanion.insert(key: 'pin_hash', value: 'their_pin'),
    );
    final foreign = await BackupService(other, safetySnapshots: store).createBackupData();

    await service.restoreFromBackup(foreign, keepCurrentPin: false);
    expect(await categoryNames(), ['Other data']);
    expect(await setting('pin_hash'), 'their_pin');
    expect(await service.latestSafetySnapshot(), isNotNull);

    await service.undoLastRestore();
    expect(await categoryNames(), ['My data']);
    expect(await setting('pin_hash'), 'my_pin');

    // The snapshot is used up; undo does not take a new one.
    expect(await service.latestSafetySnapshot(), isNull);
    await expectLater(service.undoLastRestore(), throwsA(isA<BackupException>()));
  });

  test('undo keeps this device\'s last-backup date', () async {
    await addCategory('mine', 'My data');
    final backup = await service.createBackupData();
    await service.restoreFromBackup(backup);

    await setSetting('last_backup_at', '2026-11-27T10:00:00.000');
    await service.undoLastRestore();
    expect(await setting('last_backup_at'), '2026-11-27T10:00:00.000');
  });

  test('if the safety snapshot cannot be written, nothing is restored', () async {
    await addCategory('mine', 'My data');
    final broken = BackupService(
      db,
      safetySnapshots: SafetySnapshotStore(
        root: () async => throw const FileSystemException('disk full'),
      ),
    );
    final empty = BackupData.fromJson(
      (await service.createBackupData()).toJson()
        ..['data'] = <String, dynamic>{},
    );

    await expectLater(broken.restoreFromBackup(empty), throwsA(isA<FileSystemException>()));
    expect(await categoryNames(), ['My data']);
  });

  test('the safety copy is optional', () async {
    await addCategory('mine', 'My data');
    final backup = await service.createBackupData();
    await service.restoreFromBackup(backup, takeSafetySnapshot: false);
    expect(await service.latestSafetySnapshot(), isNull);
  });

  test('only the newest snapshots are kept', () async {
    final start = DateTime(2026, 11, 1);
    for (var i = 0; i < SafetySnapshotStore.maxSnapshots + 2; i++) {
      await store.save('{"n": $i}', at: start.add(Duration(days: i)));
    }

    final kept = await store.list();
    expect(kept, hasLength(SafetySnapshotStore.maxSnapshots));
    expect(kept.first.createdAt, start.add(const Duration(days: 4)));
    expect(kept.last.createdAt, start.add(const Duration(days: 2)));
    expect(await kept.first.file.readAsString(), '{"n": 4}');
    // No temp files left behind.
    final names = root
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.tmp'));
    expect(names, isEmpty);
  });
}
