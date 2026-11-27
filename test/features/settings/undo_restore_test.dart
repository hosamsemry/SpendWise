import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/localization/app_localizations.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';
import 'package:money_tracker/features/backup/data/safety_snapshot_store.dart';
import 'package:money_tracker/features/backup/presentation/backup_providers.dart';
import 'package:money_tracker/features/settings/presentation/pages/backup_export_settings_page.dart';
import '../../test_helper.dart';

void main() {
  setUpAll(setupTestSqlite);

  Future<List<String>> categoryNames(AppDatabase db) async =>
      (await db.select(db.categoriesTable).get()).map((c) => c.name).toList();

  Future<void> addCategory(AppDatabase db, String id, String name) {
    final now = DateTime.now().toIso8601String();
    return db.into(db.categoriesTable).insert(CategoriesTableCompanion.insert(
          id: id,
          name: name,
          type: const Value('expense'),
          createdAt: now,
          updatedAt: now,
        ));
  }

  /// Lets real file I/O (snapshot reads/writes) finish, then rebuilds.
  Future<void> settle(WidgetTester tester) async {
    // Each chained file operation completes on the real event loop and then
    // continues in the test zone on the next pump, so alternate a few times.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('Backup page offers to undo the last restore and puts the old data back', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    late Directory root;
    await tester.runAsync(() async {
      root = await Directory.systemTemp.createTemp('undo_restore_ui');
    });
    addTearDown(() => root.deleteSync(recursive: true));
    final service = BackupService(
      db,
      safetySnapshots: SafetySnapshotStore(root: () async => root),
    );

    await db.into(db.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(key: 'budget_cycle_start_day', value: '1'),
        );
    await addCategory(db, 'mine', 'My data');

    // Restore an empty backup over it: the old data goes to a safety snapshot.
    await tester.runAsync(() async {
      final backup = await service.createBackupData();
      final empty = backup.toJson()..['data'] = <String, dynamic>{};
      await service.restoreFromBackup(service.parseBackupString(_encode(empty)));
    });
    expect(await categoryNames(db), isEmpty);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: [Locale('en'), Locale('ar')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BackupExportSettingsPage(),
      ),
    ));
    await settle(tester);

    final tile = find.byKey(const ValueKey('undo_last_restore_tile'));
    expect(tile, findsOneWidget);
    expect(find.text('Undo last restore'), findsOneWidget);

    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Undo last restore?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Undo restore'));
    await settle(tester);

    expect(await categoryNames(db), ['My data']);
    expect(find.text('Restore undone. Your previous data is back.'), findsOneWidget);
    // The snapshot was used up, so the option goes away.
    expect(tile, findsNothing);
  });
}

String _encode(Map<String, dynamic> json) {
  // Matches BackupData.toFormattedJsonString without needing a BackupData.
  return const JsonEncoder().convert(json);
}
