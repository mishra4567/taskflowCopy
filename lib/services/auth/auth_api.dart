// services/auth/auth_api
import '../../config/device_info.dart';
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

  AuthResult _parseAuthResult(ApiResponse r) => _parse(() {
    final data = r.data;

    final user = data['user'];
    if (user is! Map) {
      throw const FormatException('Missing user information');
    }

    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Missing authentication token');
    }

    // Laravel Sanctum plain-text token format: ID|secret
    final tokenParts = token.split('|');

    if (tokenParts.length != 2 || tokenParts.first.isEmpty) {
      throw const FormatException('Invalid authentication token');
    }

    return AuthResult(
      deviceToken: token,
      deviceId: tokenParts.first,
      userId: user['id'].toString(),
      name: user['name'] as String,
      email: user['email'] as String,
    );
  });

  // [device] supplies device_name, platform and timezone in the snake_case
  // keys Laravel's validation expects (DeviceDetails.toAuthJson).
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required DeviceDetails device,
  }) async {
    final r = await _client.send(
      'POST',
      'auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        ...device.toAuthJson(),
      },
    );
    return _parseAuthResult(r);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    required DeviceDetails device,
  }) async {
    final r = await _client.send(
      'POST',
      'auth/login',
      body: {'email': email, 'password': password, ...device.toAuthJson()},
    );
    return _parseAuthResult(r);
  }

  // Revokes only this phone's device token — other linked phones stay
  // signed in. The caller clears its own local DeviceSession regardless
  // of whether this call succeeds (see AccountService.signOut).
  Future<void> logout() => _client.send('POST', 'auth/logout', auth: true);

  Future<AccountInfo> me() async {
    final r = await _client.send('GET', 'auth/me', auth: true);
    return _parse(
      () => AccountInfo(
        userId: r.data['userId'].toString(),
        name: r.data['name'] as String,
        email: r.data['email'] as String,
      ),
    );
  }
}
