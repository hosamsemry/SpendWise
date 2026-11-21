import 'package:money_tracker/core/money/money.dart';
import 'package:money_tracker/features/transactions/domain/transaction_model.dart';

/// A detected bank/wallet alert awaiting user confirmation before insertion.
class PendingDetectedTransaction {
  final String id;
  final TransactionType type;
  final Money amount;
  final String note;
  final String? merchantKey;
  final String? suggestedCategoryId;
  final String? referenceId;
  final String dedupSignature;
  final String rawMessage;
  final String sourcePackage;
  final DateTime transactionDate;
  final DateTime detectedAt;

  const PendingDetectedTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    this.merchantKey,
    this.suggestedCategoryId,
    this.referenceId,
    required this.dedupSignature,
    required this.rawMessage,
    required this.sourcePackage,
    required this.transactionDate,
    required this.detectedAt,
  });

  PendingDetectedTransaction copyWith({
    TransactionType? type,
    Money? amount,
    String? note,
    String? suggestedCategoryId,
    DateTime? transactionDate,
  }) {
    return PendingDetectedTransaction(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      merchantKey: merchantKey,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      referenceId: referenceId,
      dedupSignature: dedupSignature,
      rawMessage: rawMessage,
      sourcePackage: sourcePackage,
      transactionDate: transactionDate ?? this.transactionDate,
      detectedAt: detectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amountMinor': amount.inMinorUnits,
      'note': note,
      'merchantKey': merchantKey,
      'suggestedCategoryId': suggestedCategoryId,
      'referenceId': referenceId,
      'dedupSignature': dedupSignature,
      'rawMessage': rawMessage,
      'sourcePackage': sourcePackage,
      'transactionDate': transactionDate.toIso8601String(),
      'detectedAt': detectedAt.toIso8601String(),
    };
  }

  factory PendingDetectedTransaction.fromJson(Map<String, dynamic> json) {
    return PendingDetectedTransaction(
      id: json['id'] as String,
      type: TransactionType.fromString(json['type'] as String? ?? 'expense'),
      amount: Money.fromMinorUnits((json['amountMinor'] as num).toInt()),
      note: (json['note'] as String?) ?? '',
      merchantKey: json['merchantKey'] as String?,
      suggestedCategoryId: json['suggestedCategoryId'] as String?,
      referenceId: json['referenceId'] as String?,
      dedupSignature: (json['dedupSignature'] as String?) ?? json['id'] as String,
      rawMessage: (json['rawMessage'] as String?) ?? '',
      sourcePackage: (json['sourcePackage'] as String?) ?? '',
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      detectedAt: DateTime.parse(json['detectedAt'] as String),
    );
  }
}
