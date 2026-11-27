import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A copy of the whole database taken automatically before a restore
/// replaced it.
class SafetySnapshot {
  final File file;
  final DateTime createdAt;

  const SafetySnapshot({required this.file, required this.createdAt});
}

/// Keeps the last few automatic safety snapshots in the app's private
/// support folder (not Documents, never shared, and excluded from cloud
/// backup and device transfer like the rest of the app's data).
///
/// Snapshots are plain backup JSON: they sit in the same private sandbox as
/// the database itself, so encrypting them with a key stored on the same
/// device would add nothing.
class SafetySnapshotStore {
  /// How many snapshots to keep; older ones are deleted on each save.
  static const int maxSnapshots = 3;

  static final RegExp _fileName = RegExp(r'^restore_(\d+)\.json$');

  final Future<Directory> Function() _root;

  SafetySnapshotStore({Future<Directory> Function()? root})
      : _root = root ?? getApplicationSupportDirectory;

  Future<Directory> _dir() async {
    final dir = Directory(p.join((await _root()).path, 'safety_snapshots'));
    await dir.create(recursive: true);
    return dir;
  }

  /// Writes [backupJson] as the newest snapshot and prunes older ones.
  Future<SafetySnapshot> save(String backupJson, {DateTime? at}) async {
    final createdAt = at ?? DateTime.now();
    final dir = await _dir();
    final file = File(
      p.join(dir.path, 'restore_${createdAt.microsecondsSinceEpoch}.json'),
    );
    // Write to a temp file first so a crash never leaves a half snapshot.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(backupJson, flush: true);
    await tmp.rename(file.path);

    final all = await list();
    for (final old in all.skip(maxSnapshots)) {
      await old.file.delete();
    }
    return SafetySnapshot(file: file, createdAt: createdAt);
  }

  /// All snapshots, newest first.
  Future<List<SafetySnapshot>> list() async {
    final dir = await _dir();
    final snapshots = <SafetySnapshot>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final match = _fileName.firstMatch(p.basename(entity.path));
      if (match == null) continue;
      snapshots.add(SafetySnapshot(
        file: entity,
        createdAt: DateTime.fromMicrosecondsSinceEpoch(int.parse(match[1]!)),
      ));
    }
    snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return snapshots;
  }

  Future<SafetySnapshot?> latest() async {
    final all = await list();
    return all.isEmpty ? null : all.first;
  }

  Future<void> delete(SafetySnapshot snapshot) async {
    if (await snapshot.file.exists()) await snapshot.file.delete();
  }
}
