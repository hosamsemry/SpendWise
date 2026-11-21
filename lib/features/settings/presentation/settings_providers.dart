import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/security/biometric_service.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/backup/presentation/backup_providers.dart';

/// PIN / biometric state shown on the Settings hub. Invalidate after
/// returning from the security page (it changes these without a refresh).
final settingsSecuritySummaryProvider =
    FutureProvider<({bool pinEnabled, bool biometricsEnabled})>((ref) async {
      ref.watch(refreshTriggerProvider);
      final pin = await ref.watch(securityServiceProvider).isPinEnabled();
      final bio = await ref
          .watch(biometricServiceProvider)
          .isBiometricsEnabled();
      return (pinEnabled: pin, biometricsEnabled: pin && bio);
    });

/// When this device last exported a backup (`null` = never). Invalidate after
/// returning from the backup page.
final lastBackupAtProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(backupServiceProvider).lastBackupAt();
});

/// Backups older than this trigger the Settings nudge.
const Duration backupNudgeAfter = Duration(days: 30);

/// Whether there is any data worth backing up yet. Kept independent of
/// [lastBackupAtProvider] (no provider chain) because hub providers pause
/// while a sub-page covers the hub and resume mid-frame on return.
final hasTransactionsProvider = FutureProvider<bool>((ref) async {
  ref.watch(refreshTriggerProvider);
  final recent = await ref
      .watch(transactionRepositoryProvider)
      .getRecentTransactions(limit: 1);
  return recent.isNotEmpty;
});

/// Nudge only once there is data and the last backup is missing or stale.
bool shouldShowBackupNudge({
  required bool hasData,
  required DateTime? lastBackup,
  required DateTime now,
}) =>
    hasData &&
    (lastBackup == null || now.difference(lastBackup) >= backupNudgeAfter);

/// Installed app version, e.g. `1.0.2 (3)`, read from the platform so it can
/// never go stale like a hard-coded string.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version} (${info.buildNumber})';
});
