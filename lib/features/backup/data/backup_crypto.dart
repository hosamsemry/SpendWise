import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:money_tracker/core/security/security_service.dart';
import 'package:money_tracker/features/backup/domain/backup_data.dart';

/// The password is wrong, or the encrypted backup was modified or damaged
/// (AES-GCM cannot tell these apart, by design).
class WrongBackupPasswordException extends BackupException {
  const WrongBackupPasswordException([
    super.message = 'Wrong password, or the backup file is damaged.',
  ]);
}

/// Password-based encryption for backup files.
///
/// File format: a JSON envelope (still a `.json` file)
/// ```json
/// {
///   "format": "spendwise-encrypted-backup", "version": 1,
///   "kdf": {"name": "pbkdf2-sha256", "iterations": 600000, "salt": "<b64>"},
///   "cipher": {"name": "aes-256-gcm", "nonce": "<b64>"},
///   "ciphertext": "<b64>", "mac": "<b64>"
/// }
/// ```
/// The header (everything except ciphertext and mac) is authenticated as
/// AES-GCM associated data, so changing the salt, nonce, iterations or
/// algorithm names makes decryption fail instead of silently changing them.
class BackupCrypto {
  // Kept from when the app was called SpendWise: it identifies the file
  // format, and existing encrypted backups must keep opening.
  static const String formatId = 'spendwise-encrypted-backup';
  static const int formatVersion = 1;
  static const int defaultIterations = 600000;

  /// Upper bound accepted when reading a file, so a crafted backup cannot
  /// freeze the app with an enormous key-derivation cost.
  static const int maxIterations = 5000000;
  static const int minPasswordLength = 8;

  static const int _saltLength = 16;
  static const int _keyLength = 32;

  final int iterations;
  final bool runInBackground;

  const BackupCrypto({
    this.iterations = defaultIterations,
    this.runInBackground = true,
  });

  /// Whether [content] is an encrypted backup envelope (vs. a plain backup).
  static bool isEncrypted(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> && decoded['format'] == formatId;
    } on FormatException {
      return false;
    }
  }

  Future<String> encrypt(String plainJson, String password) async {
    if (password.length < minPasswordLength) {
      throw ArgumentError(
        'Backup password must be at least $minPasswordLength characters',
      );
    }
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final header = _header(iterations: iterations, salt: salt, nonce: nonce);

    final key = await _deriveKey(password, salt, iterations);
    final box = await algorithm.encrypt(
      utf8.encode(plainJson),
      secretKey: SecretKey(key),
      nonce: nonce,
      aad: _aad(header),
    );

    return const JsonEncoder.withIndent('  ').convert({
      ...header,
      'ciphertext': base64.encode(box.cipherText),
      'mac': base64.encode(box.mac.bytes),
    });
  }

  /// Returns the plain backup JSON. Throws [WrongBackupPasswordException] for
  /// a wrong password or tampered file, [InvalidBackupFormatException] for a
  /// malformed envelope.
  Future<String> decrypt(String envelopeJson, String password) async {
    final Map<String, dynamic> env;
    try {
      final decoded = jsonDecode(envelopeJson);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      env = decoded;
    } on FormatException {
      throw const InvalidBackupFormatException('Corrupt encrypted backup.');
    }

    if (env['format'] != formatId) {
      throw const InvalidBackupFormatException('Not an encrypted backup.');
    }
    if (env['version'] != formatVersion) {
      throw const IncompatibleBackupException(
        'Encrypted backup was made by a newer version of Paydial.',
      );
    }

    final kdf = env['kdf'];
    final cipher = env['cipher'];
    if (kdf is! Map ||
        cipher is! Map ||
        kdf['name'] != 'pbkdf2-sha256' ||
        cipher['name'] != 'aes-256-gcm') {
      throw const InvalidBackupFormatException('Unsupported backup encryption.');
    }
    final rounds = kdf['iterations'];
    if (rounds is! int || rounds < 1 || rounds > maxIterations) {
      throw const InvalidBackupFormatException('Invalid key-derivation settings.');
    }

    final Uint8List salt;
    final Uint8List nonce;
    final Uint8List cipherText;
    final Uint8List mac;
    try {
      salt = base64.decode(kdf['salt'] as String);
      nonce = base64.decode(cipher['nonce'] as String);
      cipherText = base64.decode(env['ciphertext'] as String);
      mac = base64.decode(env['mac'] as String);
    } catch (_) {
      throw const InvalidBackupFormatException('Corrupt encrypted backup.');
    }

    final header = _header(iterations: rounds, salt: salt, nonce: nonce);
    final key = await _deriveKey(password, salt, rounds);
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
        aad: _aad(header),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const WrongBackupPasswordException();
    } on FormatException {
      throw const InvalidBackupFormatException('Corrupt encrypted backup.');
    }
  }

  static Map<String, dynamic> _header({
    required int iterations,
    required List<int> salt,
    required List<int> nonce,
  }) =>
      {
        'format': formatId,
        'version': formatVersion,
        'kdf': {
          'name': 'pbkdf2-sha256',
          'iterations': iterations,
          'salt': base64.encode(salt),
        },
        'cipher': {'name': 'aes-256-gcm', 'nonce': base64.encode(nonce)},
      };

  /// Canonical bytes of the header used as associated data.
  static List<int> _aad(Map<String, dynamic> header) =>
      utf8.encode(jsonEncode(header));

  Future<Uint8List> _deriveKey(String password, Uint8List salt, int rounds) {
    if (!runInBackground) {
      return Future.value(pbkdf2HmacSha256(password, salt, rounds, _keyLength));
    }
    return Isolate.run(
      () => pbkdf2HmacSha256(password, salt, rounds, _keyLength),
    );
  }
}
