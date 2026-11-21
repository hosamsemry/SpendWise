import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/files/export_file_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory cache;
  late Directory docs;
  late ExportFileStore store;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('cache');
    docs = await Directory.systemTemp.createTemp('docs');
    store = ExportFileStore(
      cacheRoot: () async => cache,
      documentsRoot: () async => docs,
    );
  });

  tearDown(() async {
    await cache.delete(recursive: true);
    await docs.delete(recursive: true);
  });

  test('exports go to the cache exports folder, not documents', () async {
    final file = await store.fileFor('SpendWise_Backup_1.json');
    expect(p.dirname(file.path), p.join(cache.path, 'exports'));
  });

  test('file names cannot escape the exports folder', () async {
    final file = await store.fileFor('../../evil.json');
    expect(p.dirname(file.path), p.join(cache.path, 'exports'));
  });

  test('prunes exports older than an hour and keeps recent ones', () async {
    final old = await store.fileFor('old.json');
    await old.writeAsString('x');
    await old.setLastModified(DateTime.now().subtract(const Duration(hours: 2)));
    final recent = await store.fileFor('recent.json');
    await recent.writeAsString('y');

    await store.fileFor('next.json');
    expect(await old.exists(), isFalse);
    expect(await recent.exists(), isTrue, reason: 'may still be uploading');
  });

  test('removes legacy exports from documents but nothing else', () async {
    final keep = <String>['money_tracker.sqlite', 'notes.json'];
    final legacy = <String>[
      'SpendWise_Backup_20261101_101010.json',
      'spendwise_transactions_20261101.csv',
      'spendwise_cycle_2026-10-25.csv',
    ];
    for (final name in [...keep, ...legacy]) {
      await File(p.join(docs.path, name)).writeAsString('data');
    }

    await store.prune();

    for (final name in keep) {
      expect(await File(p.join(docs.path, name)).exists(), isTrue, reason: name);
    }
    for (final name in legacy) {
      expect(await File(p.join(docs.path, name)).exists(), isFalse, reason: name);
    }
  });
}
