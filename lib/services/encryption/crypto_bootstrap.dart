// services/encryption/crypto_bootstrap
import 'package:cryptography_flutter/cryptography_flutter.dart';

import 'feature_key_service.dart';
import 'master_key_service.dart';

/// Call once in main(), AWAITED before runApp — unlike DevModeService
/// and NotificationService, which are deliberately deferred until after
/// the first frame. Those two are safe to defer because they expose a
/// reactive listenable the UI already rebuilds from once ready;
/// MasterKeyService/FeatureKeyService don't (a plain bool read in
/// build()), so a deferred load here would let EncryptionSettingsCard's
/// first frame show "set up encryption" even on an already-set-up
/// device, until some unrelated rebuild happened to pick up the real
/// state. These are two quick secure-storage reads, not the kind of
/// slow scan NotificationService.init() does, so awaiting them doesn't
/// meaningfully delay the first frame the way that one did.
///
/// Registers the native-backed crypto implementations (faster AES-GCM
/// on real devices than the pure Dart fallback) and loads whatever this
/// device already has: a cached unlocked master key, and each feature's
/// wrap + on/off state.
///
/// Entirely local — no network calls, consistent with TaskFlow being
/// offline-first. If nothing has been set up yet (fresh install),
/// MasterKeyService.instance.isUnlocked stays false and every feature's
/// isEnabled stays false; the app works exactly as it did before any of
/// this existed.
Future<void> initEncryption() async {
  FlutterCryptography.enable();
  await MasterKeyService.instance.loadCached();
  await FeatureKeyService.instance.loadAll();
}
