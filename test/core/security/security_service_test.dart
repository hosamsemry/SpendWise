import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/security/security_service.dart';
import '../../test_helper.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  late AppDatabase db;
  late SecurityService securityService;

  Future<String?> storedHash() async {
    final entry = await (db.select(db.appSettingsTable)
          ..where((tbl) => tbl.key.equals('pin_hash')))
        .getSingleOrNull();
    return entry?.value;
  }

  Future<void> writeSetting(String key, String value) => db
      .into(db.appSettingsTable)
      .insertOnConflictUpdate(
        AppSettingsTableCompanion.insert(key: key, value: value),
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // Low iteration count keeps the suite fast; production uses 100k.
    securityService = SecurityService(db, iterations: 1000);
  });

  tearDown(() async {
    await db.close();
  });

  group('PBKDF2-HMAC-SHA256 test vectors', () {
    test('RFC 7914 §11: passwd / salt / c=1 / dkLen=64', () {
      final out = pbkdf2HmacSha256(
        'passwd',
        Uint8List.fromList(utf8.encode('salt')),
        1,
        64,
      );
      expect(
        _hex(out),
        '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783',
      );
    });

    test('password / salt / c=4096 / dkLen=32', () {
      final out = pbkdf2HmacSha256(
        'password',
        Uint8List.fromList(utf8.encode('salt')),
        4096,
        32,
      );
      expect(
        _hex(out),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });
  });

  group('SecurityService Tests', () {
    test('isPinEnabled returns false by default', () async {
      final enabled = await securityService.isPinEnabled();
      expect(enabled, isFalse);
    });

    test('setPin hashes PIN and enables PIN lock', () async {
      await securityService.setPin('1234');

      final enabled = await securityService.isPinEnabled();
      expect(enabled, isTrue);

      final verifyCorrect = await securityService.verifyPin('1234');
      expect(verifyCorrect, isTrue);

      final verifyWrong = await securityService.verifyPin('9999');
      expect(verifyWrong, isFalse);
    });

    test('stores self-describing PBKDF2 hash, never the PIN itself', () async {
      await securityService.setPin('1234');
      final stored = (await storedHash())!;

      final parts = stored.split(r'$');
      expect(parts, hasLength(4));
      expect(parts[0], 'pbkdf2-sha256');
      expect(parts[1], '1000');
      expect(base64.decode(parts[2]), hasLength(16));
      expect(base64.decode(parts[3]), hasLength(32));
      expect(stored, isNot(contains('1234')));
    });

    test('same PIN gets a different random salt each time', () async {
      await securityService.setPin('1234');
      final first = await storedHash();
      await securityService.setPin('1234');
      final second = await storedHash();

      expect(first, isNot(equals(second)));
      expect(await securityService.verifyPin('1234'), isTrue);
    });

    test('legacy static-salt SHA-256 hash verifies and is upgraded', () async {
      final legacy = sha256
          .convert(utf8.encode('2468:money_tracker_salt_v1'))
          .toString();
      await writeSetting('pin_hash', legacy);
      await writeSetting('pin_enabled', 'true');

      // Wrong PIN must not upgrade anything.
      expect(await securityService.verifyPin('0000'), isFalse);
      expect(await storedHash(), legacy);

      expect(await securityService.verifyPin('2468'), isTrue);
      final upgraded = (await storedHash())!;
      expect(upgraded, startsWith(r'pbkdf2-sha256$'));

      expect(await securityService.verifyPin('2468'), isTrue);
      expect(await securityService.verifyPin('0000'), isFalse);
    });

    test('hash with fewer iterations is re-hashed at current strength', () async {
      final weak = SecurityService(db, iterations: 10);
      await weak.setPin('1357');
      expect(await storedHash(), startsWith(r'pbkdf2-sha256$10$'));

      expect(await securityService.verifyPin('1357'), isTrue);
      expect(await storedHash(), startsWith(r'pbkdf2-sha256$1000$'));
    });

    test('verification uses the iteration count stored in the hash', () async {
      await securityService.setPin('1111');
      final stronger = SecurityService(db, iterations: 2000);
      expect(await stronger.verifyPin('1111'), isTrue);

      final weaker = SecurityService(db, iterations: 500);
      expect(await weaker.verifyPin('1111'), isTrue);
      // A weaker service must never downgrade an existing hash.
      expect(await storedHash(), startsWith(r'pbkdf2-sha256$2000$'));
    });

    test('malformed or missing hash never verifies', () async {
      expect(await securityService.verifyPin('1234'), isFalse);
      for (final junk in [
        '',
        'not-a-hash',
        r'pbkdf2-sha256$abc$AAAA$AAAA',
        r'pbkdf2-sha256$1000$!!!$###',
      ]) {
        await writeSetting('pin_hash', junk);
        expect(await securityService.verifyPin('1234'), isFalse, reason: junk);
      }
    });

    test('background isolate path produces verifiable hashes', () async {
      final bg = SecurityService(db, iterations: 1000, runInBackground: true);
      await bg.setPin('8642');
      expect(await bg.verifyPin('8642'), isTrue);
      expect(await securityService.verifyPin('8642'), isTrue);
    });

    test('disablePin requires correct PIN to disable lock', () async {
      await securityService.setPin('5678');

      // Attempt with wrong PIN
      final wrongResult = await securityService.disablePin('0000');
      expect(wrongResult, isFalse);
      expect(await securityService.isPinEnabled(), isTrue);

      // Attempt with correct PIN
      final correctResult = await securityService.disablePin('5678');
      expect(correctResult, isTrue);
      expect(await securityService.isPinEnabled(), isFalse);
    });

    test('resetPin disables PIN lock safely', () async {
      await securityService.setPin('4321');
      expect(await securityService.isPinEnabled(), isTrue);

      await securityService.resetPin();
      expect(await securityService.isPinEnabled(), isFalse);
    });
  });

  group('persistent PIN lockout', () {
    Future<void> failTimes(SecurityService svc, int n) async {
      for (var i = 0; i < n; i++) {
        await svc.attemptPin('0000');
      }
    }

    Future<void> expireLockout() => writeSetting(
          pinLockoutUntilKey,
          DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
        );

    test('lockout schedule escalates and is capped', () {
      expect(SecurityService.lockoutForFailures(4), Duration.zero);
      expect(SecurityService.lockoutForFailures(5), const Duration(seconds: 30));
      expect(SecurityService.lockoutForFailures(6), const Duration(seconds: 60));
      expect(SecurityService.lockoutForFailures(8), const Duration(minutes: 4));
      expect(SecurityService.lockoutForFailures(12), const Duration(hours: 1));
      expect(SecurityService.lockoutForFailures(500), const Duration(hours: 1));
    });

    test('counts down remaining attempts, then locks out', () async {
      await securityService.setPin('1234');
      final first = await securityService.attemptPin('0000');
      expect(first.success, isFalse);
      expect(first.attemptsBeforeLockout, 4);
      expect(first.isLockedOut, isFalse);

      await failTimes(securityService, 3);
      final fifth = await securityService.attemptPin('0000');
      expect(fifth.isLockedOut, isTrue);
      expect(fifth.lockout, const Duration(seconds: 30));
    });

    test('a running lockout refuses even the correct PIN', () async {
      await securityService.setPin('1234');
      await failTimes(securityService, 5);
      final result = await securityService.attemptPin('1234');
      expect(result.success, isFalse);
      expect(result.isLockedOut, isTrue);
    });

    test('lockout survives an app restart (new service instance)', () async {
      await securityService.setPin('1234');
      await failTimes(securityService, 5);

      final afterRestart = SecurityService(db, iterations: 1000);
      expect(await afterRestart.remainingLockout(), greaterThan(Duration.zero));
      expect((await afterRestart.attemptPin('1234')).success, isFalse);
    });

    test('failures keep escalating after a lockout expires', () async {
      await securityService.setPin('1234');
      await failTimes(securityService, 5);
      await expireLockout();
      final sixth = await securityService.attemptPin('0000');
      expect(sixth.lockout, const Duration(seconds: 60));
    });

    test('correct PIN after expiry clears the counter', () async {
      await securityService.setPin('1234');
      await failTimes(securityService, 5);
      await expireLockout();
      expect((await securityService.attemptPin('1234')).success, isTrue);

      final next = await securityService.attemptPin('0000');
      expect(next.attemptsBeforeLockout, 4, reason: 'counter was reset');
    });

    test('setting a new PIN or clearFailedAttempts resets lockout', () async {
      await securityService.setPin('1234');
      await failTimes(securityService, 5);
      await securityService.clearFailedAttempts();
      expect(await securityService.remainingLockout(), Duration.zero);

      await failTimes(securityService, 5);
      await securityService.setPin('5678');
      expect(await securityService.remainingLockout(), Duration.zero);
    });

    test('a lockout far in the future (clock moved back) is clamped', () async {
      await writeSetting(
        pinLockoutUntilKey,
        DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      );
      expect(await securityService.remainingLockout(), SecurityService.maxLockout);
    });
  });
}
