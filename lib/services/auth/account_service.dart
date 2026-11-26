// services/auth/account_service
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';
import '../api/device_session.dart';
import 'auth_api.dart';
import '../../config/device_info.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

// A message safe to show the person for anything sign-in/up can throw.
// Mirrors describePairingError's shape so the two read consistently.
String describeAuthError(Object error) {
  if (error is AuthException) return error.message;
  if (error is ApiException) {
    if (error.statusCode == 422) {
      final errors = error.data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      return error.message ?? "That doesn't look right.";
    }
    if (error.statusCode == 401) {
      return 'Wrong email or password.';
    }
    if (error.statusCode == 409) {
      return 'An account already exists with that email.';
    }
    if (error.isNetwork) {
      return "Couldn't reach the server. Check your connection and try again.";
    }
    return error.message ?? 'Something went wrong. Try again.';
  }
  return 'Something went wrong. Try again.';
}

// Owns this phone's account session: signing in/up/out, and a locally
// cached name/email so the Account row on More has something to show
// without a network call every time it builds — consistent with
// TaskFlow being offline-first.
//
// A ChangeNotifier so the Account row (and the Devices "NOT LINKED"
// badge, if it reads isSignedIn from here) rebuild on sign-in/out
// without the More screen needing to poll anything.
class AccountService extends ChangeNotifier {
  AccountService._();
  static final AccountService instance = AccountService._();

  static const _storage = FlutterSecureStorage();
  static const _nameKey = 'taskflow_account_name';
  static const _emailKey = 'taskflow_account_email';

  String? _name;
  String? _email;

  bool get isSignedIn => _name != null;
  String? get name => _name;
  String? get email => _email;

  // Call once at startup, alongside initEncryption() — reads the cached
  // name/email so isSignedIn/name/email are correct on the very first
  // frame, matching why initEncryption() is awaited rather than
  // deferred (see crypto_bootstrap.dart).
  Future<void> loadCached() async {
    final signedIn = await DeviceSession.instance.isSignedIn;
    if (!signedIn) return;
    _name = await _storage.read(key: _nameKey);
    _email = await _storage.read(key: _emailKey);
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? deviceName,
    String? platform,
  }) async {
     final device = await DeviceInfoConfig.getDeviceInfo();
    final result = await AuthApi.instance.register(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      device: device,
    );
    await _applySignedIn(result);
  }

  Future<void> signIn({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
  }) async {
     final device = await DeviceInfoConfig.getDeviceInfo();
    final result = await AuthApi.instance.login(
      email: email,
      password: password,
      device: device,
    );
    await _applySignedIn(result);
  }

  Future<void> _applySignedIn(AuthResult result) async {
    await DeviceSession.instance.save(
      token: result.deviceToken,
      deviceId: result.deviceId,
    );
    _name = result.name;
    _email = result.email;
    await _storage.write(key: _nameKey, value: result.name);
    await _storage.write(key: _emailKey, value: result.email);
    notifyListeners();
  }

  // Signs this phone out: revokes its device token server-side (best
  // effort — a network failure here doesn't stop the local sign-out,
  // since staying stuck "signed in" with no way to reach the server
  // would violate the offline-first rule) and clears everything local.
  //
  // Deliberately does NOT lock the master key (MasterKeyService.lock())
  // — signing out of the account is a separate concept from losing
  // access to already-downloaded encrypted data on this phone. Call
  // MasterKeyService.instance.lock() too if the intent is "forget this
  // phone entirely."
  Future<void> signOut() async {
    try {
      await AuthApi.instance.logout();
    } catch (_) {
      // Best effort — see above.
    }
    await DeviceSession.instance.clear();
    await _storage.delete(key: _nameKey);
    await _storage.delete(key: _emailKey);
    _name = null;
    _email = null;
    notifyListeners();
  }

  // Refreshes name/email from the server — call after linking a second
  // phone via pairing (which only stores a device token, not account
  // details) or whenever the More screen's Account row is opened, so a
  // name changed on another device shows up here too. Silently does
  // nothing on failure; whatever's cached locally keeps showing.
  Future<void> refresh() async {
    if (!await DeviceSession.instance.isSignedIn) return;
    try {
      final info = await AuthApi.instance.me();
      _name = info.name;
      _email = info.email;
      await _storage.write(key: _nameKey, value: info.name);
      await _storage.write(key: _emailKey, value: info.email);
      notifyListeners();
    } catch (_) {
      // Offline, or a transient server error — keep showing cached info.
    }
  }
}
