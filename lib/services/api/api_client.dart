// services/api/api_client
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../config/api_config.dart';
import 'device_session.dart';

class ApiException implements Exception {
  ApiException(
    this.statusCode, {
    this.code,
    this.message,
    this.data = const {},
  });

  // 0 means the request never got an answer (no connection, timeout).
  final int statusCode;

  // Machine-readable reason from the server, e.g. 'device_limit_reached'.
  final String? code;
  final String? message;
  final Map<String, dynamic> data;

  bool get isNetwork => statusCode == 0;

  @override
  String toString() => message ?? code ?? 'Request failed ($statusCode)';
}

class ApiResponse {
  const ApiResponse(this.statusCode, this.data);
  final int statusCode;
  final Map<String, dynamic> data;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _timeout = Duration(seconds: 15);

  // Any 2xx returns (202 included — "still pending" is a normal answer);
  // everything else throws [ApiException]. [auth] adds this phone's
  // device token, and fails with 'not_signed_in' if it has none.
  Future<ApiResponse> send(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
    bool auth = false,
  }) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client
          .openUrl(method, Uri.parse('$apiBaseUrl$path'))
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (auth) {
        final token = await DeviceSession.instance.token();
        if (token == null) {
          throw ApiException(
            401,
            code: 'not_signed_in',
            message: "This phone isn't signed in.",
          );
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }

      final response = await request.close().timeout(_timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);

      var data = <String, dynamic>{};
      if (text.isNotEmpty) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) data = Map<String, dynamic>.from(decoded);
        } catch (_) {
          // A non-JSON body (an HTML error page) just means no details.
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(response.statusCode, data);
      }
      throw ApiException(
        response.statusCode,
        code: data['code'] as String?,
        message: data['message'] as String?,
        data: data,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(0, message: 'The server took too long to answer.');
    } on IOException {
      throw ApiException(0, message: 'No connection to the server.');
    } finally {
      client.close();
    }
  }
}
