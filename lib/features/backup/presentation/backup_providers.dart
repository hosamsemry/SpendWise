import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/features/backup/data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db);
});
