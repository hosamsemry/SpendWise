import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/features/backup/data/backup_crypto.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';

void main() {
  // Low iteration count keeps the suite fast; production uses 600k.
  const crypto = BackupCrypto(iterations: 1000);
  const plain = '{"metadata":{"appName":"SpendWise"},"data":{"note":"سلام ✓"}}';
  const password = 'correct horse battery';

  Map<String, dynamic> decode(String s) => jsonDecode(s) as Map<String, dynamic>;

  test('round-trips text, including non-ASCII', () async {
    final env = await crypto.encrypt(plain, password);
    expect(await crypto.decrypt(env, password), plain);
  });

  test('envelope is self-describing and contains no plaintext', () async {
    final env = await crypto.encrypt(plain, password);
    final json = decode(env);
    expect(json['format'], BackupCrypto.formatId);
    expect(json['kdf']['iterations'], 1000);
    expect(base64.decode(json['kdf']['salt']), hasLength(16));
    expect(base64.decode(json['cipher']['nonce']), hasLength(12));
    expect(env, isNot(contains('SpendWise')));
    expect(BackupCrypto.isEncrypted(env), isTrue);
    expect(BackupCrypto.isEncrypted(plain), isFalse);
    expect(BackupCrypto.isEncrypted('not json'), isFalse);
  });

  test('same input encrypts differently each time (random salt + nonce)', () async {
    final a = decode(await crypto.encrypt(plain, password));
    final b = decode(await crypto.encrypt(plain, password));
    expect(a['kdf']['salt'], isNot(b['kdf']['salt']));
    expect(a['ciphertext'], isNot(b['ciphertext']));
  });

  test('wrong password is rejected', () async {
    final env = await crypto.encrypt(plain, password);
    expect(
      () => crypto.decrypt(env, 'wrong password!'),
      throwsA(isA<WrongBackupPasswordException>()),
    );
  });

  test('tampering with ciphertext or authenticated header is detected', () async {
    final env = decode(await crypto.encrypt(plain, password));

    final flipped = Map<String, dynamic>.from(env);
    final bytes = base64.decode(env['ciphertext']);
    bytes[0] ^= 0x01;
    flipped['ciphertext'] = base64.encode(bytes);
    expect(
      () => crypto.decrypt(jsonEncode(flipped), password),
      throwsA(isA<WrongBackupPasswordException>()),
    );

    // Swapping the salt (part of the AAD) must also fail, not just re-key.
    final resalted = jsonDecode(jsonEncode(env)) as Map<String, dynamic>;
    resalted['kdf']['salt'] = base64.encode(List<int>.filled(16, 7));
    expect(
      () => crypto.decrypt(jsonEncode(resalted), password),
      throwsA(isA<WrongBackupPasswordException>()),
    );
  });

  test('rejects hostile or malformed envelopes without hanging', () async {
    final env = decode(await crypto.encrypt(plain, password));

    final huge = jsonDecode(jsonEncode(env)) as Map<String, dynamic>;
    huge['kdf']['iterations'] = 1 << 40;
    expect(
      () => crypto.decrypt(jsonEncode(huge), password),
      throwsA(isA<InvalidBackupFormatException>()),
    );

    final weirdCipher = jsonDecode(jsonEncode(env)) as Map<String, dynamic>;
    weirdCipher['cipher']['name'] = 'none';
    expect(
      () => crypto.decrypt(jsonEncode(weirdCipher), password),
      throwsA(isA<InvalidBackupFormatException>()),
    );

    final newer = Map<String, dynamic>.from(env)..['version'] = 99;
    expect(
      () => crypto.decrypt(jsonEncode(newer), password),
      throwsA(isA<IncompatibleBackupException>()),
    );

    expect(
      () => crypto.decrypt('{oops', password),
      throwsA(isA<InvalidBackupFormatException>()),
    );
  });

  test('enforces a minimum password length', () {
    expect(() => crypto.encrypt(plain, 'short'), throwsArgumentError);
  });

  test('background isolate path interoperates', () async {
    const bg = BackupCrypto(iterations: 1000, runInBackground: true);
    final env = await bg.encrypt(plain, password);
    expect(await crypto.decrypt(env, password), plain);
  });

  test('decrypts a golden v1 envelope (format must stay readable)', () async {
    // Produced by BackupCrypto v1 on 2026-11-21. If this fails, existing
    // users' encrypted backups would no longer restore.
    const golden = r'''{"format": "spendwise-encrypted-backup", "version": 1, "kdf": {"name": "pbkdf2-sha256", "iterations": 1000, "salt": "9QpN2Lls3RU9QP+964qz5A=="}, "cipher": {"name": "aes-256-gcm", "nonce": "7woThfTyCvv2VE3N"}, "ciphertext": "Hz70N86gR6JMcrgdwaXd", "mac": "h3qq/33JVE8BMVyeG4EMJA=="}''';
    expect(await crypto.decrypt(golden, 'golden-password'), '{"golden":true}');
  });
}
