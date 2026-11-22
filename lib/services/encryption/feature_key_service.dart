// services/encryption/feature_key_service
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'aes_box.dart';
import 'master_key_service.dart';

// The four things that can be independently switched to encrypted.
// Roadmap has no backing table yet (still the static 45%-complete
// card), so its toggle exists here for when that changes, but nothing
// calls encrypt/decrypt for it today.
enum EncryptedFeature { todo, contacts, expenses, roadmap }

// One feature's key, wrapped under the master key, plus whether the
// feature is actually turned on right now. A feature can have a key
// (generated the first time it was ever turned on) while currently
// being off — turning it back on reuses the same key rather than
// generating a new one and orphaning already-encrypted rows.
class FeatureKeyState {
  const FeatureKeyState({required this.enabled, this.wrappedKeyBase64});

  final bool enabled;
  final String? wrappedKeyBase64;

  bool get hasKey => wrappedKeyBase64 != null;
}

// Owns the four feature keys and their on/off state. Each key is
// generated once (on that feature's first-ever enable) and wrapped
// under the master key — never derived from the master key directly,
// so a feature key leaking doesn't expose the master key, and
// revoking/rotating one feature's key later doesn't touch the others.
//
// Local-only: the wrapped keys and toggle states live in secure
// storage on this device. Syncing them to other devices happens
// through the same wrap-upload path as the master key itself (a
// wrapped feature key is just more ciphertext Laravel stores opaquely)
// — not built here. 
class FeatureKeyService {
  FeatureKeyService._();
  static final FeatureKeyService instance = FeatureKeyService._();
 
  static const _storage = FlutterSecureStorage();

  final Map<EncryptedFeature, SecretKey> _unwrapped = {};
  final Map<EncryptedFeature, FeatureKeyState> _state = {};

  String _wrapStorageKey(EncryptedFeature f) =>
      'taskflow_feature_key_${f.name}';
  String _enabledStorageKey(EncryptedFeature f) =>
      'taskflow_feature_enabled_${f.name}';

  // Loads every feature's stored wrap + toggle from secure storage.
  // Call once at startup, after MasterKeyService.loadCached() — a
  // feature's key is only actually unwrapped into memory on demand
  // (see [keyFor]), not here, so this is cheap and doesn't require the
  // master key to already be unlocked.
  Future<void> loadAll() async {
    for (final feature in EncryptedFeature.values) {
      final wrapped = await _storage.read(key: _wrapStorageKey(feature));
      final enabledRaw = await _storage.read(key: _enabledStorageKey(feature));
      _state[feature] = FeatureKeyState(
        enabled: enabledRaw == 'true',
        wrappedKeyBase64: wrapped,
      );
    }
  }

  FeatureKeyState stateFor(EncryptedFeature feature) =>
      _state[feature] ?? const FeatureKeyState(enabled: false);

  bool isEnabled(EncryptedFeature feature) => stateFor(feature).enabled;

  // The unwrapped key for [feature], unwrapping (and caching in memory
  // for this session) from the stored wrap if needed. Requires the
  // master key to be unlocked — throws [StateError] otherwise, same as
  // MasterKeyService.currentKey.
  //
  // Returns null if the feature has never been turned on (no key
  // exists yet) — callers should generate one via [enable] first.
  Future<SecretKey?> keyFor(EncryptedFeature feature) async {
    final cached = _unwrapped[feature];
    if (cached != null) return cached;

    final wrapped = stateFor(feature).wrappedKeyBase64;
    if (wrapped == null) return null;

    final masterKey = MasterKeyService.instance.currentKey;
    final key = await AesBox.unwrapKey(wrapped, masterKey);
    _unwrapped[feature] = key;
    return key;
  }

  // Turns [feature]'s encryption on. Generates a brand-new key the
  // first time this feature is ever enabled; reuses the existing key
  // (if one was already generated, from a previous enable/disable
  // cycle) otherwise — so already-encrypted rows from before stay
  // readable rather than being orphaned under a key that no longer
  // exists.
  //
  // Does NOT migrate existing plaintext rows — that's each feature's
  // own repository's job (e.g. TodoRepository re-saving every row
  // through the now-enabled encrypt path), called by the Settings
  // toggle's onChanged after this returns.
  Future<void> enable(EncryptedFeature feature) async {
    final masterKey = MasterKeyService.instance.currentKey;
    var wrapped = stateFor(feature).wrappedKeyBase64;

    if (wrapped == null) {
      final newKey = await AesBox.generateKey();
      wrapped = await AesBox.wrapKey(newKey, masterKey);
      _unwrapped[feature] = newKey;
      await _storage.write(key: _wrapStorageKey(feature), value: wrapped);
    }

    _state[feature] = FeatureKeyState(enabled: true, wrappedKeyBase64: wrapped);
    await _storage.write(key: _enabledStorageKey(feature), value: 'true');
  }

  // Turns [feature]'s encryption off. The key itself is kept (not
  // deleted) so re-enabling later doesn't need a fresh migration of
  // rows encrypted under a now-gone key — only the enabled flag
  // changes. As with [enable], migrating existing rows back to
  // plaintext is the caller's responsibility, done before or after
  // this per the UI's own confirm step.
  Future<void> disable(EncryptedFeature feature) async {
    final wrapped = stateFor(feature).wrappedKeyBase64;
    _state[feature] = FeatureKeyState(
      enabled: false,
      wrappedKeyBase64: wrapped,
    );
    await _storage.write(key: _enabledStorageKey(feature), value: 'false');
  }

  // --------------------------------------------------- record helpers

  // Encrypts [plaintext] under [feature]'s key, with [recordId] bound
  // in as AAD so this ciphertext can't be silently moved onto a
  // different row. Throws [StateError] if the feature has no key yet
  // (call [enable] first) or the master key isn't unlocked.
  Future<String> encryptField(
    EncryptedFeature feature,
    String plaintext, {
    required String recordId,
  }) async {
    final key = await keyFor(feature);
    if (key == null) {
      throw StateError('${feature.name} has no key yet — call enable() first');
    }
    return AesBox.encryptStringToBase64(
      plaintext,
      key,
      aad: utf8.encode(recordId),
    );
  }

  Future<String> decryptField(
    EncryptedFeature feature,
    String ciphertextBase64, {
    required String recordId,
  }) async {
    final key = await keyFor(feature);
    if (key == null) {
      throw StateError('${feature.name} has no key to decrypt with');
    }
    return AesBox.decryptStringFromBase64(
      ciphertextBase64,
      key,
      aad: utf8.encode(recordId),
    );
  }
}
