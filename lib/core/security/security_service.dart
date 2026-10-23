import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';

const String _pinEnabledKey = 'pin_enabled';
const String _pinHashKey = 'pin_hash';
const String _pinSalt = 'money_tracker_salt_v1';

class SecurityService {
  final AppDatabase db;

  SecurityService(this.db);

  String _hashPin(String pin) {
    final bytes = utf8.encode('$pin:$_pinSalt');
    return sha256.convert(bytes).toString();
  }

  /// Checks if PIN lock is enabled.
  Future<bool> isPinEnabled() async {
    final entry = await (db.select(
      db.appSettingsTable,
    )..where((tbl) => tbl.key.equals(_pinEnabledKey))).getSingleOrNull();
    return entry?.value == 'true';
  }

  /// Verifies if [pin] matches the stored PIN hash.
  Future<bool> verifyPin(String pin) async {
    final entry = await (db.select(
      db.appSettingsTable,
    )..where((tbl) => tbl.key.equals(_pinHashKey))).getSingleOrNull();
    if (entry == null) return false;
    return entry.value == _hashPin(pin);
  }

  /// Sets a new PIN and enables PIN lock.
  Future<void> setPin(String pin) async {
    final hashed = _hashPin(pin);
    await db.transaction(() async {
      await db
          .into(db.appSettingsTable)
          .insertOnConflictUpdate(
            AppSettingsTableCompanion.insert(key: _pinHashKey, value: hashed),
          );
      await db
          .into(db.appSettingsTable)
          .insertOnConflictUpdate(
            AppSettingsTableCompanion.insert(
              key: _pinEnabledKey,
              value: 'true',
            ),
          );
    });
  }

  /// Disables PIN lock if [currentPin] is verified.
  Future<bool> disablePin(String currentPin) async {
    final isValid = await verifyPin(currentPin);
    if (!isValid) return false;

    await db
        .into(db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: _pinEnabledKey, value: 'false'),
        );
    return true;
  }

  /// Emergency/safe reset of PIN lock.
  Future<void> resetPin() async {
    await db
        .into(db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: _pinEnabledKey, value: 'false'),
        );
  }
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SecurityService(db);
});

class AppLockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

final isAppLockedProvider = NotifierProvider<AppLockedNotifier, bool>(
  AppLockedNotifier.new,
);
