import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/smart_detection/data/pending_transaction_repository.dart';
import 'package:money_tracker/features/smart_detection/data/smart_detection_channel.dart';
import 'package:money_tracker/features/smart_detection/data/source_app_repository.dart';
import 'package:money_tracker/features/smart_detection/domain/pending_detected_transaction.dart';
import 'package:money_tracker/features/smart_detection/domain/source_app.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

final pendingTransactionRepositoryProvider =
    Provider<PendingTransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PendingTransactionRepository(db);
});

final smartDetectionChannelProvider = Provider<SmartDetectionChannel>((ref) {
  return SmartDetectionChannel();
});

final sourceAppRepositoryProvider = Provider<SourceAppRepository>((ref) {
  return SourceAppRepository(ref.watch(appDatabaseProvider));
});

/// Apps the user approved as bank/wallet notification sources.
final watchedSourceAppsProvider =
    FutureProvider<List<WatchedSourceApp>>((ref) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(sourceAppRepositoryProvider).getWatchedApps();
});

/// Unwatched apps that posted financial-looking notifications and that the
/// user has neither watched nor dismissed yet.
final suggestedSourceAppsProvider =
    FutureProvider<List<SuggestedSourceApp>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(sourceAppRepositoryProvider);
  final watched = (await repo.getWatchedApps()).map((a) => a.packageName).toSet();
  final dismissed = (await repo.getDismissedPackages()).toSet();
  final suggestions =
      await ref.watch(smartDetectionChannelProvider).getSuggestedApps();
  return suggestions
      .where((s) => !watched.contains(s.packageName))
      .where((s) => !dismissed.contains(s.packageName))
      .toList();
});

class SmartDetectionEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repo = ref.watch(pendingTransactionRepositoryProvider);
    final enabled = await repo.isSmartDetectionEnabled();
    await ref.read(smartDetectionChannelProvider).setNativeDetectionEnabled(
          enabled,
        );
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    final repo = ref.read(pendingTransactionRepositoryProvider);
    await repo.setSmartDetectionEnabled(enabled);
    await ref.read(smartDetectionChannelProvider).setNativeDetectionEnabled(
          enabled,
        );
    state = AsyncData(enabled);
  }
}

final smartDetectionEnabledProvider =
    AsyncNotifierProvider<SmartDetectionEnabledNotifier, bool>(
  SmartDetectionEnabledNotifier.new,
);

final notificationAccessStatusProvider = FutureProvider<bool>((ref) async {
  ref.watch(refreshTriggerProvider);
  final channel = ref.watch(smartDetectionChannelProvider);
  return channel.isNotificationAccessEnabled();
});

final pendingTransactionsProvider =
    FutureProvider<List<PendingDetectedTransaction>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final repo = ref.watch(pendingTransactionRepositoryProvider);
  return repo.getPendingTransactions();
});

/// Coordinates native notification/share ingestion with Flutter's pending queue.
class SmartDetectionCoordinator {
  final Ref ref;

  SmartDetectionCoordinator(this.ref);

  Future<int> syncFromNative() async {
    final channel = ref.read(smartDetectionChannelProvider);
    final repo = ref.read(pendingTransactionRepositoryProvider);
    var ingestedCount = 0;

    final enabled = await repo.isSmartDetectionEnabled();
    await channel.setNativeDetectionEnabled(enabled);
    final watched = await _pushSourcePolicy();

    if (enabled) {
      final alerts = await channel.consumePendingNativeAlerts();
      for (final alert in alerts) {
        final item = await _ingestAlert(alert, watched);
        if (item != null) ingestedCount++;
      }
    }

    final sharedText = await channel.consumeSharedText();
    if (sharedText != null && sharedText.trim().isNotEmpty) {
      final item = await repo.ingestMessage(
        sharedText,
        sourcePackage: 'share_intent',
        bypassDuplicateCheck: true,
      );
      if (item != null) ingestedCount++;
    }

    if (ingestedCount > 0) {
      ref.read(refreshTriggerProvider.notifier).trigger();
    }
    return ingestedCount;
  }

  Future<PendingDetectedTransaction?> ingestLiveAlert(RawNativeAlert alert) async {
    final repo = ref.read(pendingTransactionRepositoryProvider);
    final enabled = await repo.isSmartDetectionEnabled();
    if (!enabled) return null;

    final watched = (await ref.read(sourceAppRepositoryProvider).getWatchedApps())
        .map((a) => a.packageName)
        .toSet();
    final item = await _ingestAlert(alert, watched);
    if (item != null) {
      ref.read(refreshTriggerProvider.notifier).trigger();
    }
    return item;
  }

  /// Alerts from watched apps use the normal parser; SMS alerts, and alerts
  /// whose source is unknown or no longer watched, must pass strict parsing.
  Future<PendingDetectedTransaction?> _ingestAlert(
    RawNativeAlert alert,
    Set<String> watchedPackages,
  ) {
    final trusted = alert.sourceKind == AlertSourceKind.watched &&
        watchedPackages.contains(alert.packageName);
    return ref.read(pendingTransactionRepositoryProvider).ingestMessage(
          alert.text,
          title: alert.title,
          sourcePackage: alert.packageName,
          receivedAt: alert.receivedAt,
          strict: !trusted,
        );
  }

  /// Mirrors watched/dismissed apps to the native listener.
  /// Returns the watched package names.
  Future<Set<String>> _pushSourcePolicy() async {
    final sources = ref.read(sourceAppRepositoryProvider);
    final watched =
        (await sources.getWatchedApps()).map((a) => a.packageName).toList();
    final dismissed = await sources.getDismissedPackages();
    await ref
        .read(smartDetectionChannelProvider)
        .setSourcePolicy(watched: watched, dismissed: dismissed);
    return watched.toSet();
  }

  Future<void> watchSourceApp({
    required String packageName,
    required String label,
  }) async {
    await ref
        .read(sourceAppRepositoryProvider)
        .watchApp(packageName: packageName, label: label);
    await _pushSourcePolicy();
    ref.read(refreshTriggerProvider.notifier).trigger();
  }

  Future<void> unwatchSourceApp(String packageName) async {
    await ref.read(sourceAppRepositoryProvider).unwatchApp(packageName);
    await _pushSourcePolicy();
    ref.read(refreshTriggerProvider.notifier).trigger();
  }

  Future<void> dismissSuggestedApp(String packageName) async {
    await ref.read(sourceAppRepositoryProvider).dismissApp(packageName);
    await _pushSourcePolicy();
    ref.read(refreshTriggerProvider.notifier).trigger();
  }

  Future<PendingDetectedTransaction?> ingestSharedText(String sharedText) async {
    if (sharedText.trim().isEmpty) return null;
    final repo = ref.read(pendingTransactionRepositoryProvider);
    final item = await repo.ingestMessage(
      sharedText,
      sourcePackage: 'share_intent',
      bypassDuplicateCheck: true,
    );
    if (item != null) {
      ref.read(refreshTriggerProvider.notifier).trigger();
    }
    return item;
  }

  /// Inserts the user-reviewed [pending] alert into the ledger through
  /// [TransactionService] (cycle, savings and budget-alert side effects),
  /// then removes it from the pending queue.
  Future<TransactionModel> confirmPending({
    required PendingDetectedTransaction pending,
    required TransactionType type,
    required Money amount,
    required String? categoryId,
    required DateTime date,
    required String? note,
  }) async {
    final added = await ref.read(transactionServiceProvider).add(
          type: type,
          amount: amount,
          categoryId: categoryId,
          date: date,
          note: note,
        );
    await ref
        .read(pendingTransactionRepositoryProvider)
        .markConfirmed(pending: pending, categoryId: categoryId);
    ref.read(refreshTriggerProvider.notifier).trigger();
    return added;
  }
}

final smartDetectionCoordinatorProvider = Provider<SmartDetectionCoordinator>(
  (ref) => SmartDetectionCoordinator(ref),
);
