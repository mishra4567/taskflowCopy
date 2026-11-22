// services/encryption/passphrase_kdf
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';

// Turns a passphrase (or a recovery code) plus a stored salt into a
// key-encryption key (KEK) via Argon2id — the thing that actually wraps
// the master key. Never used to encrypt real data directly; its only
// job is unwrapping/wrapping the master key in master_key_service.dart.
//
// The salt is not secret — it's fine to store it in Laravel in plain
// text, same row as the wrapped key it belongs to. What makes this safe
// is that Argon2id is deliberately slow and memory-hard, so even a
// leaked salt doesn't make guessing the passphrase cheap.
class PassphraseKdf {
  PassphraseKdf._();

  // Memory 64 MiB, 3 passes, single lane: a deliberately slow-and-costly
  // profile for a phone (not a server endpoint hit per-request), in line
  // with OWASP's Argon2id mobile guidance. Changing these numbers later
  // would silently break every existing wrap — if they ever need to
  // change, store the parameters alongside the salt, not just here.
  static const _memorySize = 64 * 1024; // KiB
  static const _iterations = 3;
  static const _parallelism = 1;
  static const _saltLength = 16;
  static const _keyLength = 32; // 256-bit, matches AesBox's key size
 
  static final Argon2id _algorithm = Argon2id(
    memory: _memorySize,
    iterations: _iterations,
    parallelism: _parallelism,
    hashLength: _keyLength,
  );

  // A fresh random salt for a new passphrase or recovery-code wrap.
  // Base64, since that's what travels through JSON to Laravel and back.
  static String generateSaltBase64() {
    final bytes = Uint8List(_saltLength);
    final random = Random.secure();
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  // Derives the KEK for [secret] (the passphrase, or one recovery
  // code's text) under [saltBase64]. The same secret + salt always
  // derives the same key — that's what lets a later unlock attempt
  // reproduce the KEK that originally wrapped the master key.
    static Future<SecretKey> deriveKey(String secret, String saltBase64) async {
    final salt = base64Decode(saltBase64);
    // Plain bytes cross the isolate boundary; the SecretKey is rebuilt here.
    final bytes = await Isolate.run(() async {
      final key = await _algorithm.deriveKeyFromPassword(
        password: secret,
        nonce: salt,
      );
      return key.extractBytes();
    });
    return SecretKey(bytes);
  }
}

// One recovery code: the text shown to the person once, plus the salt
// its KEK was derived with. [salt] has to be remembered alongside the
// wrapped master key it unlocks — see EncryptionKeyBundle below.
class RecoveryCode {
  const RecoveryCode({required this.text, required this.saltBase64});

  final String text;
  final String saltBase64;
}

// Generates a set of recovery codes. Each is independent: using one
// (and then discarding it — see master_key_service.dart) never affects
// the others still unused.
//
// Codes are grouped digits rather than mixed-case/symbol strings —
// easier to read aloud or type back in on the rare occasion they're
// actually needed, at the cost of a slightly larger code to keep the
// same entropy. 8 groups of 4 digits = 32 digits, ~106 bits — far more
// than enough for something Argon2id-derived and rarely attempted.
class RecoveryCodeGenerator {
  RecoveryCodeGenerator._();

  static const _count = 8;
  static const _groups = 8;
  static const _digitsPerGroup = 4;

  static List<RecoveryCode> generate() {
    final random = Random.secure();
    return List.generate(_count, (_) {
      final groups = List.generate(
        _groups,
        (_) => random
            .nextInt(pow(10, _digitsPerGroup).toInt())
            .toString()
            .padLeft(_digitsPerGroup, '0'),
      );
      return RecoveryCode( 
        text: groups.join('-'),
        saltBase64: PassphraseKdf.generateSaltBase64(),
      );
    });
  }
}
