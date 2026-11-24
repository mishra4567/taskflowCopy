// ./lib/services/encryption/key_wrap_store
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'master_key_service.dart';

// Wraps waiting to be uploaded. Offline-first: setup succeeds locally, and
// the upload happens whenever the person signs in. Clear after a 2xx.
class KeyWrapStore {
  KeyWrapStore._();
  static const _storage = FlutterSecureStorage();
  static const _pendingKey = 'taskflow_key_wraps_pending_upload';

  static Future<void> savePending(List<KeyWrap> wraps) => _storage.write(
    key: _pendingKey,
    value: jsonEncode([for (final w in wraps) w.toJson()]),
  );

  static Future<List<KeyWrap>> pending() async {
    final raw = await _storage.read(key: _pendingKey);
    if (raw == null) return const [];
    return [
      for (final j in jsonDecode(raw) as List)
        KeyWrap.fromJson(Map<String, dynamic>.from(j as Map)),
    ];
  }

  static Future<void> clearPending() => _storage.delete(key: _pendingKey);
}
