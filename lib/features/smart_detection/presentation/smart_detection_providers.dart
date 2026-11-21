import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/providers/cycle_providers.dart';
import 'package:money_tracker/core/providers/database_providers.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/core/providers/transaction_providers.dart';
import 'package:money_tracker/features/smart_detection/data/pending_transaction_repository.dart';
import 'package:money_tracker/features/smart_detection/data/smart_detection_channel.dart';
import 'package:money_tracker/features/smart_detection/domain/pending_detected_transaction.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

final pendingTransactionRepositoryProvider =
    Provider<PendingTransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PendingTransactionRepository(db);
});

final smartDetectionChannelProvider = Provider<SmartDetectionChannel>((ref) {
  return SmartDetectionChannel();
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

    if (enabled) {
      final alerts = await channel.consumePendingNativeAlerts();
      for (final alert in alerts) {
        final item = await repo.ingestMessage(
          alert.text,
          title: alert.title,
          sourcePackage: alert.packageName,
          receivedAt: alert.receivedAt,
        );
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

    final item = await repo.ingestMessage(
      alert.text,
      title: alert.title,
      sourcePackage: alert.packageName,
      receivedAt: alert.receivedAt,
    );
    if (item != null) {
      ref.read(refreshTriggerProvider.notifier).trigger();
    }
    return item;
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
