// services/api/device_session
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// This phone's login with the server: the device token issued when it was
// linked or signed in. Secure storage, never SharedPreferences.
class DeviceSession {
  DeviceSession._();
  static final DeviceSession instance = DeviceSession._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'taskflow_device_token';
  static const _idKey = 'taskflow_device_id';

  Future<String?> token() => _storage.read(key: _tokenKey);
  Future<String?> deviceId() => _storage.read(key: _idKey);

  Future<bool> get isSignedIn async => (await token()) != null;

  Future<void> save({required String token, required String deviceId}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _idKey, value: deviceId);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _idKey);
  }
}
