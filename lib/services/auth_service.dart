import 'dart:async';
import 'dart:convert';

import 'package:btih_andriod_app/services/auth_exceptions.dart';
import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/trusted_device_service.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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
        // Keep a host we just recovered to (e.g. .93 after tunnel refused).
        // Only re-resolve if nothing is pinned yet.
        if (!ApiConfig.isResolved) {
          await ApiConfig.ensureResolved(force: true);
        }
      } else {
        final reachable = await ApiConfig.ensureResolved(force: false);
        if (!reachable && !ApiConfig.isResolved) {
          throw AuthApiException(
            ApiConfig.connectionHelpMessage,
            type: AuthErrorType.network,
          );
        }
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

            if ((path == '/api/Auth/login' ||
                    path == '/api/Auth/verify-login-otp' ||
                    path == '/api/Auth/register') &&
                result['requiresOtp'] != true) {
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
          if (attempt == 0 && e.isNetworkError) {
            await _recoverApiHostAfterNetworkFailure();
            continue;
          }
          rethrow;
        }
        if (attempt == 0 && _isNetworkError(e)) {
          await _recoverApiHostAfterNetworkFailure();
          continue;
        }
        if (e is TimeoutException) {
          if (attempt == 0) {
            await _recoverApiHostAfterNetworkFailure();
            continue;
          }
          throw AuthApiException(
            'Cannot reach the API (${ApiConfig.baseUrl}).\n\n'
            'Join hospital Wi‑Fi and open ${ApiConfig.productionSwaggerUrl}\n'
            'or run run-dev.bat option 3 (USB tunnel) with the phone connected.',
            type: AuthErrorType.network,
          );
        }
        throw AuthApiException(
          _friendlyNetworkMessage(e),
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

  Future<void> _recoverApiHostAfterNetworkFailure() async {
    if (ApiConfig.isUsingProductionUsbTunnel) {
      // Tunnel refused / dead → try live hospital host.
      await ApiConfig.preferDirectProduction();
      return;
    }
    if (ApiConfig.baseUrl.contains(ApiConfig.productionApiHost)) {
      // Direct .93 failed → try USB tunnel only if it responds.
      final switched = await ApiConfig.preferProductionUsbTunnel();
      if (!switched) {
        ApiConfig.invalidate();
      }
      return;
    }
    ApiConfig.invalidate();
  }

  String _friendlyNetworkMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('Connection refused') &&
        (raw.contains('127.0.0.1:7078') || raw.contains('127.0.0.1'))) {
      return 'USB tunnel is not running (connection refused to 127.0.0.1:7078).\n\n'
          'Fix one of these:\n'
          '1. Run run-dev.bat → option 3 with the phone on USB\n'
          '2. Or join hospital Wi‑Fi so the app can use ${ApiConfig.productionBaseUrl}';
    }
    return _networkErrorMessage(error);
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
    bool useTrustedDevice = true,
  }) async {
    try {
      await clearAuthData();
    } catch (e) {
      debugPrint('AuthService.clearAuthData during login: $e');
    }

    final trimmedContact = contactNo.trim();
    final body = <String, dynamic>{
      'contactNo': trimmedContact,
      'password': password,
    };

    // SMS bypass number: omit deviceInstallId so the server returns a full
    // login success without OTP (works even if backend allowlist is not deployed).
    final smsBypass =
        TrustedDeviceService.isTemporarySmsBypassContact(trimmedContact);

    if (useTrustedDevice && !smsBypass) {
      try {
        body.addAll(
          await TrustedDeviceService.buildLoginDevicePayload(
            contactNo: trimmedContact,
          ),
        );
      } catch (e) {
        debugPrint('Trusted device payload skipped: $e');
      }
    } else if (smsBypass) {
      debugPrint(
        'SMS bypass contact $trimmedContact — skipping device/OTP challenge',
      );
    }

    final response = await _request(
      method: 'POST',
      path: '/api/Auth/login',
      body: body,
    );

    await _persistDeviceTrustToken(
      contactNo: trimmedContact,
      response: response,
    );

    return response;
  }

  Future<void> _persistDeviceTrustToken({
    required String contactNo,
    required Map<String, dynamic> response,
  }) async {
    final trustToken = response['deviceTrustToken']?.toString();
    final mrNo = response['mrNo']?.toString();
    if (trustToken != null &&
        trustToken.isNotEmpty &&
        mrNo != null &&
        mrNo.isNotEmpty) {
      await TrustedDeviceService.saveTrustToken(
        contactNo: contactNo,
        mrNo: mrNo,
        token: trustToken,
      );
    }
  }

  Future<Map<String, dynamic>> verifyLoginOtp({
    required String loginChallengeId,
    required String otp,
    required String contactNo,
    bool trustDevice = true,
  }) async {
    Map<String, String> devicePayload;
    try {
      devicePayload = await TrustedDeviceService.buildLoginDevicePayload(
        contactNo: contactNo.trim(),
      );
    } catch (e) {
      debugPrint('verifyLoginOtp device payload skipped: $e');
      devicePayload = {
        'deviceInstallId': 'fallback-${DateTime.now().millisecondsSinceEpoch}',
        'platform': 'android',
        'deviceLabel': 'This device',
      };
    }

    final response = await _request(
      method: 'POST',
      path: '/api/Auth/verify-login-otp',
      body: {
        'loginChallengeId': loginChallengeId,
        'otp': otp.trim(),
        'deviceInstallId': devicePayload['deviceInstallId'],
        'deviceLabel': devicePayload['deviceLabel'],
        'platform': devicePayload['platform'],
        'trustDevice': trustDevice,
      },
    );

    await _persistDeviceTrustToken(
      contactNo: contactNo.trim(),
      response: response,
    );

    return response;
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

  /// Checks contact + password without clearing the active session.
  Future<void> verifyPassword({
    required String contactNo,
    required String password,
  }) async {
    final trimmedContact = contactNo.trim();
    final body = <String, dynamic>{
      'contactNo': trimmedContact,
      'password': password,
    };

    try {
      body.addAll(
        await TrustedDeviceService.buildLoginDevicePayload(
          contactNo: trimmedContact,
        ),
      );
    } catch (_) {}

    final response = await _request(
      method: 'POST',
      path: '/api/Auth/login',
      body: body,
      retryOnNetworkError: false,
    );

    final requiresOtp = response['requiresOtp'] == true ||
        (response['loginChallengeId']?.toString().trim().isNotEmpty ?? false);
    final hasIdentity =
        (response['mrNo'] ?? response['mr_no'] ?? response['MR_NO']) != null;
    final hasToken =
        (response['token'] ?? response['accessToken'] ?? response['jwt']) !=
            null;

    if (requiresOtp || hasIdentity || hasToken || response['success'] == true) {
      return;
    }

    throw AuthApiException(
      'Current password is incorrect',
      type: AuthErrorType.unauthorized,
      statusCode: 401,
    );
  }

  /// Logged-in password change — updates PATIENT_MST for the next login.
  Future<Map<String, dynamic>> changePassword({
    required String mrno,
    required String contactNo,
    required String currentPassword,
    required String newPassword,
  }) {
    return _request(
      method: 'POST',
      path: '/api/Auth/changePassword',
      body: {
        'mrNo': mrno.trim(),
        'contactNo': contactNo.trim(),
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<Map<String, dynamic>> updatePassword({
    required String mrno,
    required String patientPassword,
    String? contactNo,
  }) async {
    final response = await _request(
      method: 'POST',
      path: '/api/Auth/updatePassword',
      body: {
        'mrNo': mrno.trim(),
        'patientPassword': patientPassword,
      },
    );

    await TrustedDeviceService.clearTrustTokenForMrNo(mrno.trim());
    if (contactNo != null && contactNo.trim().isNotEmpty) {
      await TrustedDeviceService.clearTrustTokenForContact(contactNo.trim());
    }

    return response;
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
