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
  final String rawMessage;

  const ParsedBankMessage({
    required this.type,
    required this.amount,
    required this.suggestedNote,
    this.merchantKey,
    this.referenceId,
    required this.transactionDate,
    required this.rawMessage,
  });

  /// Stable deduplication key combining reference number (when available)
  /// or normalized amount + type + day/hour signature.
  String get dedupSignature {
    if (referenceId != null && referenceId!.isNotEmpty) {
      return 'ref:${referenceId!.toLowerCase()}';
    }
    final datePart =
        '${transactionDate.year}-${transactionDate.month}-${transactionDate.day}';
    return 'sig:${type.name}:${amount.inMinorUnits}:$datePart:${(merchantKey ?? suggestedNote).toLowerCase()}';
  }
}
