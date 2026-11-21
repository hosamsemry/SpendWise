import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/providers/database_providers.dart';

const String _pinEnabledKey = 'pin_enabled';
const String _pinHashKey = 'pin_hash';

/// Static salt used by the original (v1) hashing scheme. Kept only so that
/// existing installs and old backups can still be verified and upgraded.
const String _legacyPinSalt = 'money_tracker_salt_v1';

/// Prefix of the current self-describing hash format:
/// `pbkdf2-sha256$<iterations>$<base64 salt>$<base64 hash>`.
const String _pbkdf2Scheme = 'pbkdf2-sha256';

/// Stored PIN credentials use PBKDF2-HMAC-SHA256 with a random per-PIN salt.
///
/// The hash string records its own salt and iteration count, so it stays
/// verifiable after the defaults change and survives JSON backup/restore as-is.
class SecurityService {
  final AppDatabase db;

  /// PBKDF2 iteration count for newly stored PINs.
  final int iterations;

  /// Whether to run PBKDF2 on a background isolate (keeps the UI responsive).
  /// Disable in widget tests, where isolates don't complete under the fake clock.
  final bool runInBackground;

  static const int defaultIterations = 100000;
  static const int _saltLength = 16;
  static const int _keyLength = 32;

  SecurityService(
    this.db, {
    this.iterations = defaultIterations,
    this.runInBackground = true,
  }) : assert(iterations > 0);

  /// Checks if PIN lock is enabled.
  Future<bool> isPinEnabled() async {
    final entry = await _getSetting(_pinEnabledKey);
    return entry == 'true';
  }

  /// Verifies if [pin] matches the stored PIN hash.
  ///
  /// Legacy (static-salt SHA-256) hashes and hashes with fewer iterations than
  /// [iterations] are transparently upgraded after a successful verification.
  Future<bool> verifyPin(String pin) async {
    final stored = await _getSetting(_pinHashKey);
    if (stored == null || stored.isEmpty) return false;

    final parsed = _ParsedPinHash.tryParse(stored);
    if (parsed != null) {
      final candidate = await _derive(pin, parsed.salt, parsed.iterations);
      final ok = _constantTimeEquals(candidate, parsed.hash);
      if (ok && parsed.iterations < iterations) {
        await _storeHash(pin);
      }
      return ok;
    }

    // Legacy v1 format: hex SHA-256 of "$pin:$_legacyPinSalt".
    final legacy = sha256.convert(utf8.encode('$pin:$_legacyPinSalt')).bytes;
    final ok = _constantTimeEquals(
      Uint8List.fromList(legacy),
      _tryDecodeHex(stored),
    );
    if (ok) {
      await _storeHash(pin);
    }
    return ok;
  }

  /// Sets a new PIN and enables PIN lock.
  Future<void> setPin(String pin) async {
    final hashed = await _hashNewPin(pin);
    await db.transaction(() async {
      await _setSetting(_pinHashKey, hashed);
      await _setSetting(_pinEnabledKey, 'true');
    });
  }

  /// Disables PIN lock if [currentPin] is verified.
  Future<bool> disablePin(String currentPin) async {
    final isValid = await verifyPin(currentPin);
    if (!isValid) return false;

    await _setSetting(_pinEnabledKey, 'false');
    return true;
  }

  /// Emergency/safe reset of PIN lock.
  Future<void> resetPin() async {
    await _setSetting(_pinEnabledKey, 'false');
  }

  Future<void> _storeHash(String pin) async {
    await _setSetting(_pinHashKey, await _hashNewPin(pin));
  }

  Future<String> _hashNewPin(String pin) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final hash = await _derive(pin, salt, iterations);
    return '$_pbkdf2Scheme\$$iterations\$${base64.encode(salt)}\$${base64.encode(hash)}';
  }

  Future<Uint8List> _derive(String pin, Uint8List salt, int rounds) {
    if (!runInBackground) {
      return Future.value(pbkdf2HmacSha256(pin, salt, rounds, _keyLength));
    }
    return Isolate.run(() => pbkdf2HmacSha256(pin, salt, rounds, _keyLength));
  }

  Future<String?> _getSetting(String key) async {
    final entry = await (db.select(
      db.appSettingsTable,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return entry?.value;
  }

  Future<void> _setSetting(String key, String value) async {
    await db
        .into(db.appSettingsTable)
        .insertOnConflictUpdate(
          AppSettingsTableCompanion.insert(key: key, value: value),
        );
  }
}

class _ParsedPinHash {
  final int iterations;
  final Uint8List salt;
  final Uint8List hash;

  const _ParsedPinHash(this.iterations, this.salt, this.hash);

  static _ParsedPinHash? tryParse(String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _pbkdf2Scheme) return null;
    final rounds = int.tryParse(parts[1]);
    if (rounds == null || rounds <= 0) return null;
    try {
      return _ParsedPinHash(
        rounds,
        base64.decode(parts[2]),
        base64.decode(parts[3]),
      );
    } on FormatException {
      return null;
    }
  }
}

/// PBKDF2 (RFC 8018) with HMAC-SHA256. Top-level so it can run in an isolate;
/// public so it can be checked against published test vectors.
Uint8List pbkdf2HmacSha256(
  String password,
  Uint8List salt,
  int iterations,
  int keyLength,
) {
  final hmac = Hmac(sha256, utf8.encode(password));
  const blockSize = 32;
  final blockCount = (keyLength + blockSize - 1) ~/ blockSize;
  final output = BytesBuilder(copy: false);

  for (var block = 1; block <= blockCount; block++) {
    final blockIndex = Uint8List(4)
      ..buffer.asByteData().setUint32(0, block, Endian.big);
    var u = hmac.convert([...salt, ...blockIndex]).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    output.add(t);
  }

  return Uint8List.sublistView(output.takeBytes(), 0, keyLength);
}

bool _constantTimeEquals(Uint8List a, Uint8List? b) {
  if (b == null || a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

Uint8List? _tryDecodeHex(String hex) {
  if (hex.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
    return null;
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
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
