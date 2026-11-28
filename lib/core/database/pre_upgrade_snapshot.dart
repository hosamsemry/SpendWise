import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Before the app upgrades its database schema, keeps an exact copy of the
/// old database file, so data can be recovered if an upgrade ever goes wrong.
///
/// Runs before Drift opens the file (nothing else holds it then) and uses
/// SQLite's `VACUUM INTO`, which writes a consistent copy. Copies go to
/// [into] as `pre_upgrade_v<old version>_<time>.sqlite`; the newest [keep]
/// are kept. Returns the copy, or null when no upgrade is pending (new
/// install, or already on [targetVersion]).
File? snapshotBeforeUpgrade({
  required File database,
  required Directory into,
  required int targetVersion,
  DateTime? now,
  int keep = 2,
}) {
  if (!database.existsSync()) return null;
  final db = sqlite3.open(database.path, mode: OpenMode.readOnly);
  try {
    final version = db.select('PRAGMA user_version').first.columnAt(0) as int;
    // 0 = file created but never set up: nothing worth keeping.
    if (version == 0 || version >= targetVersion) return null;

    into.createSync(recursive: true);
    final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
    final copy = File(p.join(into.path, 'pre_upgrade_v${version}_$stamp.sqlite'));
    db.execute('VACUUM INTO ?', [copy.path]);

    final existing = into
        .listSync()
        .whereType<File>()
        .where((f) => _name.hasMatch(p.basename(f.path)))
        .toList()
      ..sort((a, b) => _stamp(b).compareTo(_stamp(a)));
    for (final old in existing.skip(keep)) {
      old.deleteSync();
    }
    return copy;
  } finally {
    db.dispose();
  }
}

final RegExp _name = RegExp(r'^pre_upgrade_v\d+_(\d+)\.sqlite$');

int _stamp(File f) => int.parse(_name.firstMatch(p.basename(f.path))![1]!);
