// services/auth/auth_api
import '../api/api_client.dart';

// What a successful register/login returns: this phone's own device
// token (same shape pairing hands a newly-linked phone) plus the
// account's basic details.
class AuthResult {
  const AuthResult({
    required this.deviceToken,
    required this.deviceId,
    required this.userId,
    required this.name,
    required this.email,
  });

  final String deviceToken;
  final String deviceId;
  final String userId;
  final String name;
  final String email;
}

class AccountInfo {
  const AccountInfo({
    required this.userId,
    required this.name,
    required this.email,
  });

  final String userId;
  final String name;
  final String email;
}

class AuthApi {
  AuthApi._();
  static final AuthApi instance = AuthApi._();

  final ApiClient _client = ApiClient.instance;

  // A server answering with the wrong shape is reported as a failed
  // request, not a crash — same guard pairing_api.dart uses.
  T _parse<T>(T Function() read) {
    try {
      return read();
    } on TypeError {
      throw ApiException(0, message: 'The server sent an unexpected answer.');
    } on FormatException {
      throw ApiException(0, message: 'The server sent an unexpected answer.');
    }
  }

  AuthResult _parseAuthResult(ApiResponse r) => _parse(
    () => AuthResult(
      deviceToken: r.data['deviceToken'] as String,
      deviceId: r.data['deviceId'].toString(),
      userId: r.data['userId'].toString(),
      name: r.data['name'] as String,
      email: r.data['email'] as String,
    ),
  );

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String deviceName,
    required String platform,
  }) async {
    final r = await _client.send(
      'POST',
      '/api/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'deviceName': deviceName,
        'platform': platform,
      },
    );
    return _parseAuthResult(r);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    required String deviceName,
    required String platform,
  }) async {
    final r = await _client.send(
      'POST',
      '/api/login',
      body: {
        'email': email,
        'password': password,
        'deviceName': deviceName,
        'platform': platform,
      },
    );
    return _parseAuthResult(r);
  }

  // Revokes only this phone's device token — other linked phones stay
  // signed in. The caller clears its own local DeviceSession regardless
  // of whether this call succeeds (see AccountService.signOut).
  Future<void> logout() => _client.send('POST', '/api/logout', auth: true);

  Future<AccountInfo> me() async {
    final r = await _client.send('GET', '/api/me', auth: true);
    return _parse(
      () => AccountInfo(
        userId: r.data['userId'].toString(),
        name: r.data['name'] as String,
        email: r.data['email'] as String,
      ),
    );
  }
}
