// services/encryption/aes_box
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

// Thrown when decryption fails — a wrong key, a tampered ciphertext, or
// a corrupted value. AES-GCM is authenticated: it does not decrypt into
// garbage silently, it refuses outright. Never caught to "fall back" to
// anything; a failure here means the data cannot be trusted.
class DecryptionFailedException implements Exception {
  const DecryptionFailedException([this.message = 'Decryption failed']);
  final String message;
  @override
  String toString() => message;
}
 
// One AES-256-GCM encrypt/decrypt pair, plus the base64 packing used
// everywhere a ciphertext needs to sit in a JSON field or a text
// database column. Every box this file produces is self-contained — the
// nonce travels with the ciphertext — so callers never manage nonces
// themselves.
//
// Wire format (what actually gets stored): base64(nonce ++ ciphertext ++
// mac). Fixed 12-byte nonce, fixed 16-byte GCM tag, so unpacking needs no
// length prefix.
class AesBox {
  AesBox._();

  static final AesGcm _algorithm = AesGcm.with256bits();
  static const _nonceLength = 12;
  static const _macLength = 16;

  // A fresh random 256-bit key — used for the master key and for each
  // feature key. Never derived from anything; purely random.
  static Future<SecretKey> generateKey() => _algorithm.newSecretKey();

  // Encrypts [plaintext] under [key], with [aad] (additional
  // authenticated data) bound into the tag if given — e.g. a record's
  // own id, so a ciphertext can't silently be copied onto a different
  // row. Returns the packed wire-format string.
  static Future<String> encryptToBase64(
    List<int> plaintext,
    SecretKey key, {
    List<int> aad = const [],
  }) async {
    final box = await _algorithm.encrypt(plaintext, secretKey: key, aad: aad);
    final packed = Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    return base64Encode(packed);
  }

  static Future<String> encryptStringToBase64(
    String plaintext,
    SecretKey key, {
    List<int> aad = const [],
  }) {
    return encryptToBase64(utf8.encode(plaintext), key, aad: aad);
  }

  // Reverses [encryptToBase64]. Throws [DecryptionFailedException] on
  // any failure — wrong key, tampered bytes, or [aad] that doesn't match
  // what was used to encrypt.
  static Future<Uint8List> decryptFromBase64(
    String packedBase64,
    SecretKey key, {
    List<int> aad = const [],
  }) async {
    final Uint8List packed;
    try {
      packed = base64Decode(packedBase64);
    } on FormatException {
      throw const DecryptionFailedException('Not valid base64');
    }
    if (packed.length < _nonceLength + _macLength) {
      throw const DecryptionFailedException('Ciphertext too short');
    }

    final nonce = packed.sublist(0, _nonceLength);
    final mac = packed.sublist(packed.length - _macLength);
    final cipherText = packed.sublist(_nonceLength, packed.length - _macLength);

    try {
      final clear = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: aad,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const DecryptionFailedException(
        'Wrong key, or the data was tampered with',
      );
    }
  }

  static Future<String> decryptStringFromBase64(
    String packedBase64,
    SecretKey key, {
    List<int> aad = const [],
  }) async {
    final bytes = await decryptFromBase64(packedBase64, key, aad: aad);
    return utf8.decode(bytes);
  }

  // ------------------------------------------------------- key packing

  // A SecretKey's raw bytes, for wrapping (encrypting one key under
  // another) or for writing into secure storage. Never logged, never
  // sent anywhere unwrapped.
  static Future<Uint8List> keyBytes(SecretKey key) async {
    return Uint8List.fromList(await key.extractBytes());
  }

  static SecretKey keyFromBytes(List<int> bytes) => SecretKey(bytes);

  // Encrypts [key]'s raw bytes under [wrappingKey] — this is "key
  // wrapping": the master key wrapping a feature key, or a
  // passphrase/recovery KEK wrapping the master key. Same AES-GCM box
  // format as any other ciphertext; a wrapped key is just encrypted data
  // whose plaintext happens to be another key.
  static Future<String> wrapKey(SecretKey key, SecretKey wrappingKey) async {
    return encryptToBase64(await keyBytes(key), wrappingKey);
  }

  static Future<SecretKey> unwrapKey(
    String wrappedBase64,
    SecretKey wrappingKey,
  ) async {
    final bytes = await decryptFromBase64(wrappedBase64, wrappingKey);
    return keyFromBytes(bytes);
  }
}
 