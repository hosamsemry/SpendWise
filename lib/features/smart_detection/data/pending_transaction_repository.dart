import 'dart:convert';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/budgets/data/budget_cycle_repository.dart';
import 'package:money_tracker/features/smart_detection/domain/bank_message_parser.dart';
import 'package:money_tracker/features/smart_detection/domain/pending_detected_transaction.dart';
import 'package:money_tracker/features/transactions/data/transaction_repository.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';
import 'package:uuid/uuid.dart';

const String smartDetectionEnabledKey = 'smart_detection_enabled';
const String pendingDetectedTransactionsKey = 'smart_detection_pending_json';
const String seenDetectedSignaturesKey = 'smart_detection_seen_refs_json';
const String merchantCategoryMapKey = 'smart_detection_merchant_categories_json';

/// Persists pending detected bank/wallet transactions, deduplication history,
/// and learned merchant-to-category mappings in SQLite `app_settings`.
class PendingTransactionRepository {
  final AppDatabase db;
  static const Uuid _uuid = Uuid();
  static const int _maxPendingItems = 50;
  static const int _maxSeenSignatures = 250;

  PendingTransactionRepository(this.db);

  Future<bool> isSmartDetectionEnabled() async {
    final row = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(smartDetectionEnabledKey)))
        .getSingleOrNull();
    return row?.value == 'true';
  }

  Future<void> setSmartDetectionEnabled(bool enabled) async {
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: smartDetectionEnabledKey,
            value: enabled ? 'true' : 'false',
          ),
        );
  }

  Future<List<PendingDetectedTransaction>> getPendingTransactions() async {
    final row = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(pendingDetectedTransactionsKey)))
        .getSingleOrNull();
    if (row == null || row.value.isEmpty) return const [];

    try {
      final decoded = jsonDecode(row.value) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PendingDetectedTransaction.fromJson)
          .toList()
        ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _savePendingTransactions(
    List<PendingDetectedTransaction> items,
  ) async {
    final capped = items.take(_maxPendingItems).map((e) => e.toJson()).toList();
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: pendingDetectedTransactionsKey,
            value: jsonEncode(capped),
          ),
        );
  }

  Future<List<String>> _getSeenSignatures() async {
    final row = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(seenDetectedSignaturesKey)))
        .getSingleOrNull();
    if (row == null || row.value.isEmpty) return const [];
    try {
      final decoded = jsonDecode(row.value) as List<dynamic>;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _addSeenSignature(String signature) async {
    final existing = await _getSeenSignatures();
    if (existing.contains(signature)) return;
    final updated = [signature, ...existing].take(_maxSeenSignatures).toList();
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: seenDetectedSignaturesKey,
            value: jsonEncode(updated),
          ),
        );
  }

  Future<Map<String, String>> getMerchantCategoryMap() async {
    final row = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(merchantCategoryMapKey)))
        .getSingleOrNull();
    if (row == null || row.value.isEmpty) return const {};
    try {
      final decoded = jsonDecode(row.value) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  Future<void> _saveMerchantCategoryMapping(
    String merchantKey,
    String categoryId,
  ) async {
    final cleanedKey = merchantKey.trim().toLowerCase();
    if (cleanedKey.isEmpty) return;

    final map = Map<String, String>.from(await getMerchantCategoryMap());
    map[cleanedKey] = categoryId;
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: merchantCategoryMapKey,
            value: jsonEncode(map),
          ),
        );
  }

  /// Parses [rawMessage] locally and queues it as a [PendingDetectedTransaction]
  /// unless it is non-financial or a duplicate of an already pending/handled alert.
  Future<PendingDetectedTransaction?> ingestMessage(
    String rawMessage, {
    String? title,
    String sourcePackage = '',
    DateTime? receivedAt,
    bool bypassDuplicateCheck = false,
  }) async {
    final parsed = BankMessageParser.parse(
      rawMessage,
      title: title,
      receivedAt: receivedAt,
    );
    if (parsed == null) return null;

    final currentPending = await getPendingTransactions();
    final seen = await _getSeenSignatures();

    if (!bypassDuplicateCheck) {
      final alreadyPending = currentPending.any(
        (p) => p.dedupSignature == parsed.dedupSignature,
      );
      final alreadyHandled = seen.contains(parsed.dedupSignature);
      if (alreadyPending || alreadyHandled) return null;
    }

    final merchantMap = await getMerchantCategoryMap();
    final lookupKey =
        (parsed.merchantKey ?? parsed.suggestedNote).trim().toLowerCase();
    final learnedCategoryId = merchantMap[lookupKey];

    final pendingItem = PendingDetectedTransaction(
      id: _uuid.v4(),
      type: parsed.type,
      amount: parsed.amount,
      note: parsed.suggestedNote,
      merchantKey: parsed.merchantKey,
      suggestedCategoryId: learnedCategoryId,
      referenceId: parsed.referenceId,
      dedupSignature: parsed.dedupSignature,
      rawMessage: parsed.rawMessage,
      sourcePackage: sourcePackage,
      transactionDate: parsed.transactionDate,
      detectedAt: receivedAt ?? DateTime.now(),
    );

    await _savePendingTransactions([pendingItem, ...currentPending]);
    return pendingItem;
  }

  /// Confirms and inserts a pending detected transaction into the real ledger,
  /// syncs Savings Vault / cycle budgets, learns the merchant -> category mapping,
  /// and removes the item from the pending queue.
  Future<TransactionModel> confirmPendingTransaction({
    required PendingDetectedTransaction pending,
    required TransactionType type,
    required Money amount,
    required String? categoryId,
    required DateTime date,
    required String? note,
  }) async {
    final txRepo = TransactionRepository(db);
    final cycleRepo = BudgetCycleRepository(db);

    await cycleRepo.getOrCreateCycleForDate(date);
    final added = await txRepo.addTransaction(
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date,
      note: note,
    );

    // Learn merchant -> category preference for future auto-suggestion
    final learnKey = pending.merchantKey ??
        (pending.note.trim().isNotEmpty ? pending.note.trim().toLowerCase() : null);
    if (learnKey != null && categoryId != null && categoryId.isNotEmpty) {
      await _saveMerchantCategoryMapping(learnKey, categoryId);
    }

    await _addSeenSignature(pending.dedupSignature);
    final remaining = (await getPendingTransactions())
        .where((item) => item.id != pending.id)
        .toList();
    await _savePendingTransactions(remaining);

    return added;
  }

  /// Dismisses a single pending item (e.g., own-account transfer or ignored alert).
  Future<void> dismissPendingTransaction(PendingDetectedTransaction pending) async {
    await _addSeenSignature(pending.dedupSignature);
    final remaining = (await getPendingTransactions())
        .where((item) => item.id != pending.id)
        .toList();
    await _savePendingTransactions(remaining);
  }

  /// Dismisses all pending items at once.
  Future<void> clearAllPendingTransactions() async {
    final current = await getPendingTransactions();
    for (final item in current) {
      await _addSeenSignature(item.dedupSignature);
    }
    await _savePendingTransactions(const []);
  }
}
