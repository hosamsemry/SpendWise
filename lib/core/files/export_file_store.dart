import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where exported backups and CSVs are written before being shared.
///
/// Files go to a cache subfolder (excluded from backups and clearable by the
/// OS) instead of the app documents folder, where every export used to pile
/// up forever. Files are not deleted right after sharing because the
/// receiving app may still be reading them; instead each new export prunes
/// files older than [maxAge].
class ExportFileStore {
  static const Duration maxAge = Duration(hours: 1);

  /// Legacy exports left in the documents folder by earlier versions (when
  /// the app was called SpendWise).
  static final RegExp _legacyExportName = RegExp(
    r'^(SpendWise_Backup_.*\.json|spendwise_(transactions|cycle)_.*\.csv)$',
  );

  final Future<Directory> Function() _cacheRoot;
  final Future<Directory> Function() _documentsRoot;

  ExportFileStore({
    Future<Directory> Function()? cacheRoot,
    Future<Directory> Function()? documentsRoot,
  })  : _cacheRoot = cacheRoot ?? getTemporaryDirectory,
        _documentsRoot = documentsRoot ?? getApplicationDocumentsDirectory;

  /// Returns a fresh file path for [fileName] after pruning stale exports.
  Future<File> fileFor(String fileName, {DateTime? now}) async {
    final dir = Directory(p.join((await _cacheRoot()).path, 'exports'));
    await dir.create(recursive: true);
    await prune(now: now);
    return File(p.join(dir.path, p.basename(fileName)));
  }

  /// Deletes exports older than [maxAge] and legacy exports in documents.
  Future<void> prune({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(maxAge);
    final dir = Directory(p.join((await _cacheRoot()).path, 'exports'));
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && (await entity.lastModified()).isBefore(cutoff)) {
          await _tryDelete(entity);
        }
      }
    }

    final docs = await _documentsRoot();
    if (await docs.exists()) {
      await for (final entity in docs.list()) {
        if (entity is File &&
            _legacyExportName.hasMatch(p.basename(entity.path))) {
          await _tryDelete(entity);
        }
      }
    }
  }

  static Future<void> _tryDelete(File file) async {
    try {
      await file.delete();
    } catch (_) {
      // Best effort: a file in use is retried on the next export.
    }
  }
}
