import 'dart:convert';

import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class AuthService {
  static Future<void> clearAuthData() => AuthSession.clear();

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
        message.contains('Failed to fetch') ||
        message.contains('Failed host lookup') ||
        message.contains('Connection refused') ||
        message.contains('Connection closed') ||
        message.contains('Connection timed out') ||
        message.contains('Network is unreachable') ||
        message.contains('Software caused connection abort') ||
        message.contains('TimeoutException') ||
        message.contains('Cannot reach the HMIS API server');
  }

  String _networkErrorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '');
    if (kIsWeb &&
        (raw.contains('Failed to fetch') || raw.contains('ClientException'))) {
      return 'Cannot reach the API from Chrome.\n\n'
          'The hospital API uses HTTPS with a self-signed certificate.\n\n'
          'Try one of these:\n'
          '1. Run run_chrome.bat (ignores cert errors for dev)\n'
          '2. Open ${ApiConfig.baseUrl}/swagger in Chrome, click Advanced, then Proceed\n'
          '3. Hot restart the app (R) and try login again';
    }
    return raw;
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
                ? ApiConfig.client.post(
                    uri,
                    headers: headers,
                    body: body != null ? jsonEncode(body) : null,
                  )
                : ApiConfig.client.get(uri, headers: headers))
            .timeout(ApiConfig.requestTimeout);

        final decoded = _decodeMap(response.body);
        final success = decoded?['success'];

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (success == false) {
            throw _parseErrorResponse(response);
          }

          if (decoded != null) {
            Map<String, dynamic> result = Map<String, dynamic>.from(decoded);
            final dataMap = _extractDataMap(decoded);
            if (dataMap != null) {
              result.addAll(dataMap);
            }

            if (path == '/api/Auth/login' || path == '/api/Auth/register') {
              await AuthSession.saveFromLoginResponse(result);
            }

            return result;
          }

          return {'success': true};
        }

        if (response.statusCode == 401 && AuthSession.isLoggedIn) {
          await AuthSession.handleUnauthorized();
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
          _networkErrorMessage(e),
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

  static Map<String, dynamic>? _extractDataMap(Map<String, dynamic> decoded) {
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  /// OTP returned by the API when SMS delivery fails but OTP was cached server-side.
  static String? extractDebugOtp(Map<String, dynamic> response) {
    for (final key in ['debugOtp', 'DebugOtp', 'debug_otp']) {
      final value = response[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final data = response['data'];
    if (data is Map) {
      for (final key in ['debugOtp', 'DebugOtp', 'debug_otp']) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> login({
    required String contactNo,
    required String password,
  }) async {
    await clearAuthData();
    return _request(
      method: 'POST',
      path: '/api/Auth/login',
      body: {
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

  Future<Map<String, dynamic>> verifyPhoneByMrNo(String mrNo) {
    return _request(
      method: 'POST',
      path: '/api/Auth/verifyPhoneNo',
      query: {'mrno': mrNo.trim()},
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
      body: {
        'mrNo': mrno.trim(),
        'patientPassword': patientPassword,
      },
    );
  }

  Future<Map<String, dynamic>> sendRegistrationOtp(String phoneNumber) {
    return _request(
      method: 'POST',
      path: '/api/Auth/send-registration-otp',
      query: {'phoneNumber': phoneNumber.trim()},
    );
  }

  Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String firstName,
    String? lastName,
    required String password,
    required String confirmPassword,
    required String otp,
    required bool acceptTerms,
  }) {
    return _request(
      method: 'POST',
      path: '/api/Auth/register',
      body: {
        'phoneNumber': phoneNumber.trim(),
        'firstName': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'lastName': lastName.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
        'otp': otp.trim(),
        'acceptTerms': acceptTerms,
      },
    );
  }
}
