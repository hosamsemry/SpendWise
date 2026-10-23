import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';

const String biometricEnabledKey = 'biometrics_enabled';

class BiometricService {
  final AppDatabase db;
  final LocalAuthentication _auth;

  BiometricService(this.db, {LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Checks if the device has biometric hardware capable of enrollment/authentication.
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if biometric unlocking is enabled in user settings.
  Future<bool> isBiometricsEnabled() async {
    final entry = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals(biometricEnabledKey)))
        .getSingleOrNull();
    return entry?.value == 'true';
  }

  /// Enables or disables biometric unlocking.
  Future<void> setBiometricsEnabled(bool enabled) async {
    await db.into(db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(
            key: biometricEnabledKey,
            value: enabled.toString(),
          ),
        );
  }

  /// Prompts the system biometric sheet (fingerprint/face recognition).
  Future<bool> authenticate({
    String reason = 'Authenticate to unlock SpendWise',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BiometricService(db);
});
