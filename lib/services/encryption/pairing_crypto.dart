// services/encryption/pairing_crypto
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'aes_box.dart';

/// A throwaway key pair for one pairing session. Never stored; if the app
/// is killed mid-pairing the session is simply restarted.
class PairingKeyPair {
  const PairingKeyPair(this.keyPair, this.publicKey);
  final SimpleKeyPair keyPair;

  /// base64url, no padding — safe inside a QR link.
  final String publicKey;
}

class ApprovalPayload {
  const ApprovalPayload({
    required this.approverPublicKey,
    required this.encryptedMasterKey,
  });
  final String approverPublicKey;
  final String encryptedMasterKey;
}

/// What the QR carries: the session id and the new device's public key.
class PairingQr {
  const PairingQr({required this.sessionId, required this.publicKey});
  final String sessionId;
  final String publicKey;

  String encode() => Uri(
    scheme: 'taskflow',
    host: 'pair',
    queryParameters: {'v': '1', 's': sessionId, 'k': publicKey},
  ).toString();

  /// Null for anything that isn't a valid TaskFlow pairing link.
  static PairingQr? parse(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'taskflow' || uri.host != 'pair') {
      return null;
    }
    final s = uri.queryParameters['s'];
    final k = uri.queryParameters['k'];
    if (uri.queryParameters['v'] != '1' || s == null || k == null) return null;
    try {
      if (_decode(k).length != 32) return null;
    } on FormatException {
      return null;
    }
    return PairingQr(sessionId: s, publicKey: k);
  }
}

List<int> _decode(String value) => base64Url.decode(base64Url.normalize(value));
String _encode(List<int> bytes) => base64UrlEncode(bytes).replaceAll('=', '');

class PairingCrypto {
  PairingCrypto._();

  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static const _info = 'taskflow-pairing-v1';

  static Future<PairingKeyPair> newKeyPair() async {
    final pair = await _x25519.newKeyPair();
    final pub = await pair.extractPublicKey();
    return PairingKeyPair(pair, _encode(pub.bytes));
  }

  // The same key on both phones: ECDH shared secret, then HKDF bound to
  // this session id so it can't be replayed into another session.
  static Future<SecretKey> _sessionKey(
    SimpleKeyPair mine,
    String theirPublicKey,
    String sessionId,
  ) async {
    final theirs = SimplePublicKey(
      _decode(theirPublicKey),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: mine,
      remotePublicKey: theirs,
    );
    return _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode(sessionId),
      info: utf8.encode(_info),
    );
  }

  /// On phone A (already linked and unlocked): encrypt the master key for
  /// the new phone. [newDevicePublicKey] MUST come from the scanned QR,
  /// never from the server.
  static Future<ApprovalPayload> encryptMasterKeyFor({
    required String newDevicePublicKey,
    required String sessionId,
    required SecretKey masterKey,
  }) async {
    final mine = await newKeyPair();
    final key = await _sessionKey(mine.keyPair, newDevicePublicKey, sessionId);
    final encrypted = await AesBox.encryptToBase64(
      await AesBox.keyBytes(masterKey),
      key,
      aad: utf8.encode(sessionId),
    );
    return ApprovalPayload(
      approverPublicKey: mine.publicKey,
      encryptedMasterKey: encrypted,
    );
  }

  /// On the new phone B: recover the master key. Throws
  /// [DecryptionFailedException] if anything was tampered with or swapped.
  static Future<SecretKey> decryptMasterKey({
    required PairingKeyPair myKeyPair,
    required String approverPublicKey,
    required String encryptedMasterKey,
    required String sessionId,
  }) async {
    final key = await _sessionKey(
      myKeyPair.keyPair,
      approverPublicKey,
      sessionId,
    );
    final bytes = await AesBox.decryptFromBase64(
      encryptedMasterKey,
      key,
      aad: utf8.encode(sessionId),
    );
    if (bytes.length != 32) {
      throw const DecryptionFailedException('Unexpected key length');
    }
    return AesBox.keyFromBytes(bytes);
  }
}
