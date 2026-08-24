import 'dart:convert';

import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static void clearAuthData() {}

  Uri _apiUri(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, dynamic>? _decodeMap(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkError(Object error) {
    final message = error.toString();
    return message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('Failed host lookup') ||
        message.contains('Connection refused') ||
        message.contains('Connection closed') ||
        message.contains('Connection timed out') ||
        message.contains('Network is unreachable') ||
        message.contains('Software caused connection abort') ||
        message.contains('TimeoutException') ||
        message.contains('Cannot reach the HMIS API server');
  }

  AuthErrorType _typeFromStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return AuthErrorType.unauthorized;
    }
    if (statusCode == 400) return AuthErrorType.validation;
    if (statusCode >= 500) return AuthErrorType.server;
    return AuthErrorType.unknown;
  }

  AuthApiException _parseErrorResponse(http.Response response) {
    final decoded = _decodeMap(response.body);
    final message = decoded?['message']?.toString() ??
        'Request failed (${response.statusCode})';
    final errors = decoded?['errors'] is List
        ? (decoded!['errors'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return AuthApiException(
      errors.isNotEmpty ? '$message\n${errors.join('\n')}' : message,
      type: _typeFromStatus(response.statusCode),
      statusCode: response.statusCode,
      errors: errors,
    );
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool retryOnNetworkError = true,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt < (retryOnNetworkError ? 2 : 1); attempt++) {
      if (attempt > 0) {
        ApiConfig.invalidate();
      }

      final reachable = await ApiConfig.ensureResolved(force: attempt > 0);
      if (!reachable) {
        throw AuthApiException(
          ApiConfig.connectionHelpMessage,
          type: AuthErrorType.network,
        );
      }

      try {
        final uri = _apiUri(path, query);
        final headers = {
          'accept': '*/*',
          if (body != null) 'Content-Type': 'application/json',
        };

        final response = await (method == 'POST'
                ? http.post(
                    uri,
                    headers: headers,
                    body: body != null ? jsonEncode(body) : null,
                  )
                : http.get(uri, headers: headers))
            .timeout(ApiConfig.requestTimeout);

        final decoded = _decodeMap(response.body);
        final success = decoded?['success'];

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (success == false) {
            throw _parseErrorResponse(response);
          }

          if (decoded != null) {
            if (decoded['data'] is Map<String, dynamic>) {
              return {
                ...decoded,
                ...(decoded['data'] as Map<String, dynamic>),
              };
            }
            return decoded;
          }

          return {'success': true};
        }

        throw _parseErrorResponse(response);
      } catch (e) {
        lastError = e;
        if (e is AuthApiException) {
          if (attempt == 0 && e.isNetworkError) continue;
          rethrow;
        }
        if (attempt == 0 && _isNetworkError(e)) continue;
        throw AuthApiException(
          e.toString().replaceFirst('Exception: ', ''),
          type: AuthErrorType.network,
        );
      }
    }

    throw lastError is AuthApiException
        ? lastError
        : AuthApiException(
            ApiConfig.connectionHelpMessage,
            type: AuthErrorType.network,
          );
  }

  Future<Map<String, dynamic>> login({
    required String contactNo,
    required String password,
  }) async {
    clearAuthData();
    return _request(
      method: 'POST',
      path: '/api/Auth/login',
      body: {
        'contactNo': contactNo.trim(),
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String contactNo,
    required String password,
  }) {
    return _request(
      method: 'POST',
      path: '/api/Auth/signup',
      body: {
        'fullName': fullName.trim(),
        'contactNo': contactNo.trim(),
        'password': password,
      },
    );
  }

  Future<Map<String, dynamic>> verifyPhoneNumber(String contactNo) {
    return _request(
      method: 'POST',
      path: '/api/Auth/verifyPhoneNo',
      query: {'ContactNo': contactNo.trim()},
    );
  }

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) {
    return _request(
      method: 'POST',
      path: '/api/Auth/send-otp',
      query: {'phoneNumber': phoneNumber.trim()},
    );
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) {
    return _request(
      method: 'POST',
      path: '/api/Auth/verify-otp',
      query: {
        'phoneNumber': phoneNumber.trim(),
        'otp': otp.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> updatePassword({
    required String mrno,
    required String patientPassword,
  }) {
    return _request(
      method: 'POST',
      path: '/api/Auth/updatePassword',
      query: {
        'mrno': mrno.trim(),
        'patientPassword': patientPassword,
      },
    );
  }
}
