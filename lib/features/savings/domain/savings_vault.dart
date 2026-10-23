import 'package:money_tracker/core/money/money.dart';

/// Represents the state of the user's Lifetime Savings Vault.
class SavingsVault {
  final Money balance;
  final String? lastSweptCycleId;
  final Money? lastSweepAmount;
  final DateTime? lastSweptAt;

  const SavingsVault({
    required this.balance,
    this.lastSweptCycleId,
    this.lastSweepAmount,
    this.lastSweptAt,
  });

  SavingsVault copyWith({
    Money? balance,
    String? lastSweptCycleId,
    Money? lastSweepAmount,
    DateTime? lastSweptAt,
  }) {
    return SavingsVault(
      balance: balance ?? this.balance,
      lastSweptCycleId: lastSweptCycleId ?? this.lastSweptCycleId,
      lastSweepAmount: lastSweepAmount ?? this.lastSweepAmount,
      lastSweptAt: lastSweptAt ?? this.lastSweptAt,
    );
  }
}
