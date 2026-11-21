import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import '../domain/savings_vault.dart';

class SavingsVaultRepository {
  final AppDatabase db;

  static const String keyVaultBalance = 'savings_vault_balance_minor';
  static const String keyLastSweptCycleId = 'savings_vault_last_swept_cycle_id';
  static const String keyLastSweepAmount = 'savings_vault_last_sweep_amount_minor';
  static const String keyLastSweptAt = 'savings_vault_last_swept_at';
  static const String keyDismissedCycleIds = 'savings_vault_dismissed_cycles';
  static const String keySweptCycleIds = 'savings_vault_swept_cycles';

  const SavingsVaultRepository(this.db);

  Future<String?> _getSetting(String key) async {
    final entry = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return entry?.value;
  }

  Future<void> _setSetting(String key, String value) async {
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: key,
            value: value,
          ),
        );
  }

  /// Retrieves the current accumulated balance in the Savings Vault.
  Future<Money> getVaultBalance() async {
    final raw = await _getSetting(keyVaultBalance);
    final minor = int.tryParse(raw ?? '0') ?? 0;
    return Money.fromMinorUnits(minor);
  }

  /// Retrieves the complete state of the Savings Vault.
  Future<SavingsVault> getVault() async {
    final balance = await getVaultBalance();
    final lastSweptCycleId = await _getSetting(keyLastSweptCycleId);
    final lastSweepAmountRaw = await _getSetting(keyLastSweepAmount);
    final lastSweptAtRaw = await _getSetting(keyLastSweptAt);

    return SavingsVault(
      balance: balance,
      lastSweptCycleId: lastSweptCycleId,
      lastSweepAmount: lastSweepAmountRaw != null
          ? Money.fromMinorUnits(int.tryParse(lastSweepAmountRaw) ?? 0)
          : null,
      lastSweptAt:
          lastSweptAtRaw != null ? DateTime.tryParse(lastSweptAtRaw) : null,
    );
  }

  Future<Set<String>> _sweptCycleIds() async {
    final raw = await _getSetting(keySweptCycleIds);
    return raw != null && raw.isNotEmpty ? raw.split(',').toSet() : <String>{};
  }

  /// Sweeps cycle surplus into the Lifetime Savings Vault.
  ///
  /// Idempotent per cycle: returns `false` and changes nothing if [cycleId]
  /// was already swept (e.g. a double tap before the card refreshes). The
  /// check and the balance update run in one transaction.
  Future<bool> sweepSurplus({
    required String cycleId,
    required Money amount,
  }) {
    return db.transaction(() async {
      if (await isCycleSwept(cycleId)) return false;

      final balance = await getVaultBalance();
      final sweptIds = await _sweptCycleIds()..add(cycleId);

      await _setSetting(
        keyVaultBalance,
        (balance.inMinorUnits + amount.inMinorUnits).toString(),
      );
      await _setSetting(keySweptCycleIds, sweptIds.join(','));
      await _setSetting(keyLastSweptCycleId, cycleId);
      await _setSetting(keyLastSweepAmount, amount.inMinorUnits.toString());
      await _setSetting(keyLastSweptAt, DateTime.now().toIso8601String());
      return true;
    });
  }

  /// Undoes a previously executed surplus sweep. Returns `false` and changes
  /// nothing if [cycleId] is not currently swept, so a repeated undo cannot
  /// remove money twice.
  Future<bool> undoSweep({
    required String cycleId,
    required Money amount,
  }) {
    return db.transaction(() async {
      if (!await isCycleSwept(cycleId)) return false;

      final balance = await getVaultBalance();
      var newBalanceMinor = balance.inMinorUnits - amount.inMinorUnits;
      if (newBalanceMinor < 0) newBalanceMinor = 0;
      final sweptIds = await _sweptCycleIds()..remove(cycleId);

      await _setSetting(keyVaultBalance, newBalanceMinor.toString());
      await _setSetting(keySweptCycleIds, sweptIds.join(','));
      final lastSwept = await _getSetting(keyLastSweptCycleId);
      if (lastSwept == cycleId) {
        await (db.delete(db.appSettingsTable)
              ..where((tbl) => tbl.key.isIn([
                    keyLastSweptCycleId,
                    keyLastSweepAmount,
                    keyLastSweptAt,
                  ])))
            .go();
      }
      return true;
    });
  }

  /// Manually deposits funds into the Savings Vault.
  Future<Money> deposit({required Money amount}) {
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Deposit amount must be positive');
    }
    return db.transaction(() async {
      final updated = await getVaultBalance() + amount;
      await _setSetting(keyVaultBalance, updated.inMinorUnits.toString());
      return updated;
    });
  }

  /// Manually withdraws funds from the Savings Vault (e.g. for emergencies or planned spending).
  Future<Money> withdraw({required Money amount}) {
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Withdrawal amount must be positive');
    }
    return db.transaction(() async {
      final current = await getVaultBalance();
      if (amount > current) {
        throw StateError('Cannot withdraw more than available vault balance');
      }
      final updated = current - amount;
      await _setSetting(keyVaultBalance, updated.inMinorUnits.toString());
      return updated;
    });
  }

  /// Checks whether surplus from [cycleId] has already been swept.
  Future<bool> isCycleSwept(String cycleId) async {
    final lastSwept = await _getSetting(keyLastSweptCycleId);
    if (lastSwept == cycleId) return true;
    final rawSwept = await _getSetting(keySweptCycleIds);
    if (rawSwept == null || rawSwept.isEmpty) return false;
    return rawSwept.split(',').contains(cycleId);
  }

  /// Checks whether the user previously dismissed the closeout prompt for [cycleId].
  Future<bool> isCycleDismissed(String cycleId) async {
    final raw = await _getSetting(keyDismissedCycleIds);
    if (raw == null || raw.isEmpty) return false;
    final ids = raw.split(',');
    return ids.contains(cycleId);
  }

  /// Records that the user dismissed the closeout prompt for [cycleId].
  Future<void> dismissCycle(String cycleId) async {
    final raw = await _getSetting(keyDismissedCycleIds);
    final Set<String> ids =
        raw != null && raw.isNotEmpty ? raw.split(',').toSet() : {};
    ids.add(cycleId);
    await _setSetting(keyDismissedCycleIds, ids.join(','));
  }
}
