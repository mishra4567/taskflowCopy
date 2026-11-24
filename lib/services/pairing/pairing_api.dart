// services/pairing/pairing_api
import '../api/api_client.dart';
import 'dart:convert';

class PairingSessionInfo {
  const PairingSessionInfo({
    required this.sessionId,
    required this.pollSecret,
    required this.expiresAt,
  });
  final String sessionId;

  // Stays on the new phone. Never put in the QR.
  final String pollSecret;
  final DateTime expiresAt;
}

class PairingLookup {
  const PairingLookup({required this.deviceName, required this.platform});
  final String deviceName;
  final String platform;
}

class PairingResult {
  const PairingResult({
    required this.deviceToken,
    required this.deviceId,
    this.approverPublicKey,
    this.encryptedMasterKey,
  });
  final String deviceToken;
  final String deviceId;

  // Both null when the approving phone has no encryption set up.
  final String? approverPublicKey;
  final String? encryptedMasterKey;
}

class PairingApi {
  PairingApi._();
  static final PairingApi instance = PairingApi._();

  final ApiClient _client = ApiClient.instance;

  String _path(String sessionId, [String suffix = '']) =>
      '/api/pairing-sessions/${Uri.encodeComponent(sessionId)}$suffix';

  // A server answering with the wrong shape is reported as a failed
  // request, not a crash.
  T _parse<T>(T Function() read) {
    try {
      return read();
    } on TypeError {
      throw ApiException(0, message: 'The server sent an unexpected answer.');
    } on FormatException {
      throw ApiException(0, message: 'The server sent an unexpected answer.');
    }
  }

  Future<PairingSessionInfo> createSession({
    required String deviceName,
    required String platform,
    required String publicKey,
  }) async {
    final r = await _client.send(
      'POST',
      '/api/pairing-sessions',
      body: {
        'deviceName': deviceName,
        'platform': platform,
        'publicKey': publicKey,
      },
    );
    return _parse(
      () => PairingSessionInfo(
        sessionId: r.data['sessionId'] as String,
        pollSecret: r.data['pollSecret'] as String,
        expiresAt: DateTime.parse(r.data['expiresAt'] as String),
      ),
    );
  }

  Future<PairingLookup> lookup(String sessionId) async {
    final r = await _client.send(
      'GET',
      _path(sessionId, '/lookup'),
      auth: true,
    );
    return _parse(
      () => PairingLookup(
        deviceName: r.data['deviceName'] as String,
        platform: r.data['platform'] as String,
      ),
    );
  }

  Future<void> approve(
    String sessionId, {
    String? approverPublicKey,
    String? encryptedMasterKey,
  }) async {
    await _client.send(
      'POST',
      _path(sessionId, '/approve'),
      auth: true,
      body: {
        'approverPublicKey': approverPublicKey,
        'encryptedMasterKey': encryptedMasterKey,
      },
    );
  }

  // Null while the other phone hasn't approved yet. The server hands the
  // result out once, then deletes the session.
  Future<PairingResult?> poll(String sessionId, String pollSecret) async {
    final r = await _client.send(
      'GET',
      _path(sessionId),
      headers: {'X-Poll-Secret': pollSecret},
    );
    if (r.statusCode == 202) return null;
    return _parse(
      () => PairingResult(
        deviceToken: r.data['deviceToken'] as String,
        deviceId: r.data['deviceId'].toString(),
        approverPublicKey: r.data['approverPublicKey'] as String?,
        encryptedMasterKey: r.data['encryptedMasterKey'] as String?,
      ),
    );
  }
}
