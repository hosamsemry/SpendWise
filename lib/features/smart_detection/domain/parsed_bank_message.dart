import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

/// Structured output extracted locally from a bank SMS or wallet notification.
class ParsedBankMessage {
  final TransactionType type;
  final Money amount;
  final String suggestedNote;
  final String? merchantKey;
  final String? referenceId;
  final DateTime transactionDate;

  /// Whether the message itself stated a time (vs. falling back to when it
  /// was received). Only a stated time is reliable enough for dedup.
  final bool hasExplicitTime;
  final String rawMessage;

  const ParsedBankMessage({
    required this.type,
    required this.amount,
    required this.suggestedNote,
    this.merchantKey,
    this.referenceId,
    required this.transactionDate,
    this.hasExplicitTime = false,
    required this.rawMessage,
  });

  /// Stable deduplication key: the reference number when available,
  /// otherwise type + amount + day (+ the stated time, when the message has
  /// one) + merchant. Including the time keeps two genuine identical
  /// purchases on the same day apart; without a stated time the day is the
  /// finest reliable granularity (re-delivered notifications must collapse).
  String get dedupSignature {
    if (referenceId != null && referenceId!.isNotEmpty) {
      return 'ref:${referenceId!.toLowerCase()}';
    }
    var datePart =
        '${transactionDate.year}-${transactionDate.month}-${transactionDate.day}';
    if (hasExplicitTime) {
      datePart += 'T${transactionDate.hour}:${transactionDate.minute}';
    }
    return 'sig:${type.name}:${amount.inMinorUnits}:$datePart:${(merchantKey ?? suggestedNote).toLowerCase()}';
  }
}
