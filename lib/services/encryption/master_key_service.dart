// services/encryption/master_key_service
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'aes_box.dart';
import 'passphrase_kdf.dart';

// One wrapped copy of the master key — a passphrase wrap, or one
// recovery code's wrap. [purpose] and [recoveryIndex] exist only to
// mirror the eventual `encryption_keys` Laravel row shape
// (purpose/recovery_index/wrapped_key/salt); this type has no idea
// Laravel exists.
class KeyWrap {
  const KeyWrap({
    required this.purpose,
    required this.wrappedKeyBase64,
    required this.saltBase64,
    this.recoveryIndex,
  });
 
  final String purpose; // 'passphrase' | 'recovery'
  final String wrappedKeyBase64;
  final String saltBase64;
  final int? recoveryIndex;

   // Convert KeyWrap object into JSON for secure storage/API upload.
  Map<String, dynamic> toJson() {
    return {
      'purpose': purpose,
      'wrapped_key': wrappedKeyBase64,
      'salt': saltBase64,
      'recovery_index': recoveryIndex,
    };
  }

    // Restore KeyWrap object from JSON.
  factory KeyWrap.fromJson(Map<String, dynamic> json) {
    return KeyWrap(
      purpose: json['purpose'] as String,
      wrappedKeyBase64: json['wrapped_key'] as String,
      saltBase64: json['salt'] as String,
      recoveryIndex: json['recovery_index'] as int?,
    );
  }
}

// Everything produced by first-time setup: the wraps to upload, and the
// recovery codes to show the person exactly once. [recoveryCodes]
// deliberately isn't stored anywhere by this service after it's
// returned — the call site is responsible for displaying it and then
// letting it be garbage collected.
class EncryptionSetupResult {
  const EncryptionSetupResult({
    required this.wraps,
    required this.recoveryCodes,
  });

  final List<KeyWrap> wraps;
  final List<RecoveryCode> recoveryCodes;
}

// Owns the master key for its entire lifecycle on this device:
// generating it, wrapping it under a passphrase and recovery codes,
// unwrapping it on unlock, and caching the unwrapped key in secure
// storage while the app considers itself "unlocked."
//
// This file never talks to Laravel. [EncryptionSetupResult.wraps] is
// handed back to the caller to upload; unlocking elsewhere downloads
// wraps and passes them in here to attempt against. Keeping the
// network boundary outside this class is what makes it testable
// offline and keeps this app's offline-first rule honest — nothing in
// here assumes a connection exists.
class MasterKeyService {
  MasterKeyService._();
  static final MasterKeyService instance = MasterKeyService._();

  static const _storage = FlutterSecureStorage();
  static const _cachedKeyStorageKey = 'taskflow_master_key_cached';

  SecretKey? _cached;
 
  // True once the master key is available in memory for this session —
  // i.e. feature_key_service.dart can unwrap feature keys right now
  // without prompting for anything.
  bool get isUnlocked => _cached != null;

  // ------------------------------------------------------------- setup

  // First-time setup on the very first device: generates a brand-new
  // master key, wraps it under [passphrase] and under a fresh set of
  // recovery codes, and caches it unlocked on this device.
  //
  // Does not upload anything — the caller does that with the returned
  // wraps, then (per the offline-first rule) this device is already
  // fully usable even if that upload hasn't happened yet or fails.
  Future<EncryptionSetupResult> setUpNew(String passphrase) async {
    final masterKey = await AesBox.generateKey();
    _cached = masterKey;
    await _cacheLocally(masterKey);

    final passphraseWrap = await _wrapUnder(
      masterKey,
      secret: passphrase,
      purpose: 'passphrase',
    );

    final recoveryCodes = RecoveryCodeGenerator.generate();
    final recoveryWraps = <KeyWrap>[];
    for (var i = 0; i < recoveryCodes.length; i++) {
      final code = recoveryCodes[i];
      final kek = await PassphraseKdf.deriveKey(code.text, code.saltBase64);
      recoveryWraps.add(
        KeyWrap(
          purpose: 'recovery',
          recoveryIndex: i,
          wrappedKeyBase64: await AesBox.wrapKey(masterKey, kek),
          saltBase64: code.saltBase64,
        ),
      );
    }

    return EncryptionSetupResult(
      wraps: [passphraseWrap, ...recoveryWraps],
      recoveryCodes: recoveryCodes,
    );
  }

  // ------------------------------------------------------------ unlock

  // Attempts to unwrap the master key from [wraps] (downloaded from
  // Laravel for this account) using [passphrase]. Tries only the
  // `purpose: 'passphrase'` wrap — use [unlockWithRecoveryCode] for a
  // recovery code instead, since mixing both into one guess-everything
  // method would make it easy to accidentally treat a recovery code
  // text as a passphrase attempt or vice versa.
  //
  // Returns true and caches the key on success; false (not an
  // exception) on a wrong passphrase, since that's an expected,
  // everyday outcome here, not a failure of the method itself.
  Future<bool> unlockWithPassphrase(
    String passphrase,
    List<KeyWrap> wraps,
  ) async {
    final wrap = wraps.where((w) => w.purpose == 'passphrase').firstOrNull;
    if (wrap == null) return false;
    return _tryUnwrap(wrap, passphrase);
  }

  // Attempts [recoveryCode] against every `purpose: 'recovery'` wrap in
  // [wraps] — the call site doesn't know in advance which index the
  // person's code corresponds to. Returns the matched [KeyWrap] (so the
  // caller can tell Laravel exactly which one to delete) on success, or
  // null on no match.
  Future<KeyWrap?> unlockWithRecoveryCode(
    String recoveryCode,
    List<KeyWrap> wraps,
  ) async {
    for (final wrap in wraps.where((w) => w.purpose == 'recovery')) {
      if (await _tryUnwrap(wrap, recoveryCode)) return wrap;
    }
    return null;
  }

  Future<bool> _tryUnwrap(KeyWrap wrap, String secret) async {
    try {
      final kek = await PassphraseKdf.deriveKey(secret, wrap.saltBase64);
      final masterKey = await AesBox.unwrapKey(wrap.wrappedKeyBase64, kek);
      _cached = masterKey;
      await _cacheLocally(masterKey);
      return true;
    } on DecryptionFailedException {
      // Wrong passphrase/code — not a bug, just a no-match.
      return false;
    }
  }

  // Re-wraps the already-unwrapped master key under a brand-new
  // passphrase. Called right after a successful recovery-code unlock
  // (forcing a new passphrase is what actually invalidates the old
  // one) and available any time the person wants to change it.
  // Throws if the key isn't currently unlocked.
  Future<KeyWrap> rewrapWithNewPassphrase(String newPassphrase) async {
    final key = _requireUnlocked();
    return _wrapUnder(key, secret: newPassphrase, purpose: 'passphrase');
  }

  Future<KeyWrap> _wrapUnder(
    SecretKey masterKey, {
    required String secret,
    required String purpose,
  }) async {
    final salt = PassphraseKdf.generateSaltBase64();
    final kek = await PassphraseKdf.deriveKey(secret, salt);
    return KeyWrap(
      purpose: purpose,
      wrappedKeyBase64: await AesBox.wrapKey(masterKey, kek),
      saltBase64: salt,
    );
  }

  // --------------------------------------------------------- new device

  // For a new device joining an existing account via the QR-pairing
  // flow (device_pairing_service.dart, built separately): the master
  // key arrives already unwrapped — via ECDH with the inviting device,
  // never via a passphrase on this device — and this just caches it.
  Future<void> adoptPairedKey(SecretKey masterKey) async {
    _cached = masterKey;
    await _cacheLocally(masterKey);
  }

  // -------------------------------------------------------------- local

  // Call on app start, before anything that might need the master key
  // (e.g. opening an already-unlocked session without re-prompting).
  // Leaves [isUnlocked] false if nothing was cached — a fresh install,
  // or a previous explicit [lock].
  Future<void> loadCached() async {
    final stored = await _storage.read(key: _cachedKeyStorageKey);
    if (stored == null) return;
    _cached = AesBox.keyFromBytes(base64Decode(stored));
  }

  Future<void> _cacheLocally(SecretKey key) async {
    final bytes = await AesBox.keyBytes(key);
    await _storage.write(key: _cachedKeyStorageKey, value: base64Encode(bytes));
  }

  // Clears the cached key from both memory and secure storage — e.g. on
  // explicit "lock" or sign-out. Encrypted data on disk is untouched;
  // only the ability to read it without unlocking again goes away.
  Future<void> lock() async {
    _cached = null;
    await _storage.delete(key: _cachedKeyStorageKey);
  }

  SecretKey _requireUnlocked() {
    final key = _cached;
    if (key == null) {
      throw StateError('Master key is not unlocked');
    }
    return key;
  }

  // For feature_key_service.dart — the only other file allowed to read
  // the raw master key.
  SecretKey get currentKey => _requireUnlocked();
}
