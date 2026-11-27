import 'package:drift/drift.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/money/money.dart';
import 'package:uuid/uuid.dart';
import '../domain/savings_goal.dart';
import '../domain/savings_vault.dart';

/// The Savings Vault, stored as a history of movements
/// (`savings_movements`). The vault balance is the sum of every movement; a
/// goal's balance is the sum of its movements, and movements without a goal
/// are Unassigned. No bucket is ever allowed to go below zero.
///
/// Savings sit outside the cycle budget: nothing here writes transactions.
class SavingsVaultRepository {
  final AppDatabase db;
  final Uuid _uuid;

  static const String keyLastSweptCycleId = 'savings_vault_last_swept_cycle_id';
  static const String keyLastSweepAmount = 'savings_vault_last_sweep_amount_minor';
  static const String keyLastSweptAt = 'savings_vault_last_swept_at';
  static const String keyDismissedCycleIds = 'savings_vault_dismissed_cycles';
  static const String keySweptCycleIds = 'savings_vault_swept_cycles';

  SavingsVaultRepository(this.db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<String?> _getSetting(String key) async {
    final entry = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return entry?.value;
  }

  Future<void> _setSetting(String key, String value) async {
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: key, value: value),
        );
  }

  /// A fresh id for [deposit] / [withdraw] / [transfer], so the caller can
  /// [undoGroup] exactly that action later.
  String newGroupId() => _uuid.v4();

  /// Total money in the vault (all goals plus Unassigned).
  Future<Money> getVaultBalance() async {
    final total = db.savingsMovementsTable.amountMinor.sum();
    final row = await (db.selectOnly(db.savingsMovementsTable)..addColumns([total])).getSingle();
    return Money.fromMinorUnits(row.read(total) ?? 0);
  }

  /// Balance per bucket: goal id → money, with `null` for Unassigned.
  Future<Map<String?, Money>> bucketBalances() async {
    final t = db.savingsMovementsTable;
    final total = t.amountMinor.sum();
    final rows = await (db.selectOnly(t)
          ..addColumns([t.goalId, total])
          ..groupBy([t.goalId]))
        .get();
    return {
      for (final r in rows) r.read(t.goalId): Money.fromMinorUnits(r.read(total) ?? 0),
    };
  }

  Future<Money> _bucketBalance(String? goalId) async {
    final t = db.savingsMovementsTable;
    final total = t.amountMinor.sum();
    final query = db.selectOnly(t)..addColumns([total]);
    query.where(goalId == null ? t.goalId.isNull() : t.goalId.equals(goalId));
    final row = await query.getSingle();
    return Money.fromMinorUnits(row.read(total) ?? 0);
  }

  Future<void> _insert({
    required String? goalId,
    required int amountMinor,
    required SavingsMovementKind kind,
    required String groupId,
    String? cycleId,
  }) async {
    await db.into(db.savingsMovementsTable).insert(
          SavingsMovementsTableCompanion.insert(
            id: _uuid.v4(),
            goalId: Value(goalId),
            amountMinor: amountMinor,
            kind: kind.dbValue,
            groupId: groupId,
            cycleId: Value(cycleId),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
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
      lastSweptAt: lastSweptAtRaw != null ? DateTime.tryParse(lastSweptAtRaw) : null,
    );
  }

  Future<Set<String>> _sweptCycleIds() async {
    final raw = await _getSetting(keySweptCycleIds);
    return raw != null && raw.isNotEmpty ? raw.split(',').toSet() : <String>{};
  }

  /// Sweeps a cycle's surplus into the vault, split by [allocation]
  /// (goal id → share, `null` = Unassigned; default: all Unassigned). The
  /// shares must add up to [amount].
  ///
  /// Idempotent per cycle: returns `false` and changes nothing if [cycleId]
  /// was already swept (e.g. a double tap before the card refreshes). The
  /// check and the writes run in one transaction.
  Future<bool> sweepSurplus({
    required String cycleId,
    required Money amount,
    Map<String?, Money>? allocation,
  }) {
    final split = allocation ?? {null: amount};
    final splitTotal = split.values.fold<int>(0, (s, m) => s + m.inMinorUnits);
    if (amount.inMinorUnits <= 0 || splitTotal != amount.inMinorUnits) {
      throw ArgumentError('Sweep shares must add up to the surplus');
    }
    if (split.values.any((m) => m.inMinorUnits < 0)) {
      throw ArgumentError('Sweep shares cannot be negative');
    }
    return db.transaction(() async {
      if (await isCycleSwept(cycleId)) return false;

      final groupId = 'sweep:$cycleId';
      for (final entry in split.entries) {
        if (entry.value.inMinorUnits == 0) continue;
        await _insert(
          goalId: entry.key,
          amountMinor: entry.value.inMinorUnits,
          kind: SavingsMovementKind.sweep,
          groupId: groupId,
          cycleId: cycleId,
        );
      }
      final sweptIds = await _sweptCycleIds()..add(cycleId);
      await _setSetting(keySweptCycleIds, sweptIds.join(','));
      await _setSetting(keyLastSweptCycleId, cycleId);
      await _setSetting(keyLastSweepAmount, amount.inMinorUnits.toString());
      await _setSetting(keyLastSweptAt, DateTime.now().toIso8601String());
      return true;
    });
  }

  /// Undoes the sweep of [cycleId]. Returns `false` and changes nothing if it
  /// is not currently swept, so a repeated undo cannot remove money twice, or
  /// if the swept money has since been moved or spent.
  Future<bool> undoSweep({required String cycleId, Money? amount}) {
    return db.transaction(() async {
      if (!await isCycleSwept(cycleId)) return false;
      if (!await _removeGroup('sweep:$cycleId')) return false;

      final sweptIds = await _sweptCycleIds()..remove(cycleId);
      await _setSetting(keySweptCycleIds, sweptIds.join(','));
      final lastSwept = await _getSetting(keyLastSweptCycleId);
      if (lastSwept == cycleId) {
        await (db.delete(db.appSettingsTable)
              ..where((tbl) => tbl.key.isIn([keyLastSweptCycleId, keyLastSweepAmount, keyLastSweptAt])))
            .go();
      }
      return true;
    });
  }

  /// Deletes the movements of [groupId] unless that would leave a bucket
  /// below zero. Must run inside a transaction.
  Future<bool> _removeGroup(String groupId) async {
    final t = db.savingsMovementsTable;
    final rows = await (db.select(t)..where((r) => r.groupId.equals(groupId))).get();
    final change = <String?, int>{};
    for (final r in rows) {
      change[r.goalId] = (change[r.goalId] ?? 0) - r.amountMinor;
    }
    for (final e in change.entries) {
      final balance = await _bucketBalance(e.key);
      if (balance.inMinorUnits + e.value < 0) return false;
    }
    await (db.delete(t)..where((r) => r.groupId.equals(groupId))).go();
    return true;
  }

  /// Undoes one [deposit], [withdraw] or [transfer] by its group id. Returns
  /// `false` if it would leave a bucket below zero (the money moved on).
  Future<bool> undoGroup(String groupId) => db.transaction(() => _removeGroup(groupId));

  /// Adds new money to [goalId] (or Unassigned). Returns the vault total.
  Future<Money> deposit({required Money amount, String? goalId, String? groupId}) {
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Deposit amount must be positive');
    }
    return db.transaction(() async {
      await _insert(
        goalId: goalId,
        amountMinor: amount.inMinorUnits,
        kind: SavingsMovementKind.deposit,
        groupId: groupId ?? newGroupId(),
      );
      return getVaultBalance();
    });
  }

  /// Takes money out of [goalId] (or Unassigned), e.g. to spend it. It never
  /// touches the cycle budget. Returns the vault total.
  /// Throws [StateError] if the bucket holds less than [amount].
  Future<Money> withdraw({required Money amount, String? goalId, String? groupId}) {
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Withdrawal amount must be positive');
    }
    return db.transaction(() async {
      final available = await _bucketBalance(goalId);
      if (amount > available) {
        throw StateError('Cannot withdraw more than available vault balance');
      }
      await _insert(
        goalId: goalId,
        amountMinor: -amount.inMinorUnits,
        kind: SavingsMovementKind.withdraw,
        groupId: groupId ?? newGroupId(),
      );
      return getVaultBalance();
    });
  }

  /// Moves money between buckets (`null` = Unassigned). The vault total is
  /// unchanged. Throws [StateError] if [from] holds less than [amount].
  Future<void> transfer({
    required String? from,
    required String? to,
    required Money amount,
    String? groupId,
  }) {
    if (amount.inMinorUnits <= 0) {
      throw ArgumentError('Transfer amount must be positive');
    }
    if (from == to) throw ArgumentError('Cannot move money to the same place');
    return db.transaction(() async {
      final available = await _bucketBalance(from);
      if (amount > available) {
        throw StateError('Cannot move more than is available');
      }
      final id = groupId ?? newGroupId();
      await _insert(goalId: from, amountMinor: -amount.inMinorUnits, kind: SavingsMovementKind.transfer, groupId: id);
      await _insert(goalId: to, amountMinor: amount.inMinorUnits, kind: SavingsMovementKind.transfer, groupId: id);
    });
  }

  SavingsMovement _toDomain(SavingsMovementEntry e) => SavingsMovement(
        id: e.id,
        goalId: e.goalId,
        amount: Money.fromMinorUnits(e.amountMinor),
        kind: SavingsMovementKind.fromDb(e.kind),
        groupId: e.groupId,
        cycleId: e.cycleId,
        createdAt: DateTime.parse(e.createdAt),
      );

  /// All movements, newest first.
  Future<List<SavingsMovement>> getMovements() async {
    final rows = await (db.select(db.savingsMovementsTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows.map(_toDomain).toList();
  }

  /// Checks whether surplus from [cycleId] has already been swept.
  Future<bool> isCycleSwept(String cycleId) async {
    final lastSwept = await _getSetting(keyLastSweptCycleId);
    if (lastSwept == cycleId) return true;
    return (await _sweptCycleIds()).contains(cycleId);
  }

  /// Checks whether the user previously dismissed the closeout prompt for [cycleId].
  Future<bool> isCycleDismissed(String cycleId) async {
    final raw = await _getSetting(keyDismissedCycleIds);
    if (raw == null || raw.isEmpty) return false;
    return raw.split(',').contains(cycleId);
  }

  /// Records that the user dismissed the closeout prompt for [cycleId].
  Future<void> dismissCycle(String cycleId) async {
    final raw = await _getSetting(keyDismissedCycleIds);
    final Set<String> ids = raw != null && raw.isNotEmpty ? raw.split(',').toSet() : {};
    ids.add(cycleId);
    await _setSetting(keyDismissedCycleIds, ids.join(','));
  }
}
