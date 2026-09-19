import 'dart:async';

import 'package:btih_andriod_app/screens/patient_main_shell.dart';
import 'package:btih_andriod_app/screens/welcome_screen.dart';
import 'package:btih_andriod_app/services/guest_session.dart';
import 'package:btih_andriod_app/services/notification_service.dart';
import 'package:btih_andriod_app/services/push_notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists JWT, patient identity, and session expiry (1h 35m).
class AuthSession {
  AuthSession._();

  /// Session lifetime from login: 1 hour 35 minutes.
  static const Duration sessionDuration = Duration(hours: 1, minutes: 35);

  static const _tokenKey = 'auth_token';
  static const _tokenTypeKey = 'auth_token_type';
  static const _mrNoKey = 'auth_mr_no';
  static const _firstNameKey = 'auth_first_name';
  static const _lastNameKey = 'auth_last_name';
  static const _profileImageUrlKey = 'auth_profile_image_url';
  static const _loggedInKey = 'auth_is_logged_in';
  static const _expiresAtKey = 'auth_expires_at';

  static GlobalKey<NavigatorState>? navigatorKey;

  static String? _token;
  static String _tokenType = 'Bearer';
  static String? _mrNo;
  static String? _firstName;
  static String? _lastName;
  static String? _profileImageUrl;
  static bool _isLoggedIn = false;
  static DateTime? _expiresAt;
  static Timer? _expiryTimer;

  static String? get token => _token;
  static String? get mrNo => _mrNo;
  static String? get profileImageUrl => _profileImageUrl;
  static DateTime? get expiresAt => _expiresAt;
  static String get displayName {
    final first = _firstName?.trim() ?? '';
    final last = _lastName?.trim() ?? '';
    final full = '$first $last'.trim();
    if (full.isNotEmpty) return full;
    if (first.isNotEmpty) return first;
    return 'Patient';
  }

  static Duration? get timeRemaining {
    if (_expiresAt == null) return null;
    final remaining = _expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static bool get isExpired {
    if (_expiresAt == null) return false;
    return DateTime.now().isAfter(_expiresAt!);
  }

  static bool get isLoggedIn =>
      _isLoggedIn &&
      _token != null &&
      _token!.isNotEmpty &&
      _mrNo != null &&
      !isExpired;

  static Map<String, String> get authHeaders {
    if (_token == null || _token!.isEmpty || isExpired) return {};
    return {'Authorization': '$_tokenType $_token'};
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _tokenType = prefs.getString(_tokenTypeKey) ?? 'Bearer';
    _mrNo = prefs.getString(_mrNoKey);
    _firstName = prefs.getString(_firstNameKey);
    _lastName = prefs.getString(_lastNameKey);
    _profileImageUrl = prefs.getString(_profileImageUrlKey);
    _isLoggedIn = prefs.getBool(_loggedInKey) ?? false;

    final expiresRaw = prefs.getString(_expiresAtKey);
    if (expiresRaw != null && expiresRaw.isNotEmpty) {
      _expiresAt = DateTime.tryParse(expiresRaw);
    }

    if (!_isLoggedIn || _token == null || _token!.isEmpty || _mrNo == null) {
      _isLoggedIn = false;
      return;
    }

    // Sessions saved before expiry support must log in again.
    if (_expiresAt == null || isExpired) {
      await clear();
      return;
    }

    _scheduleExpiryTimer();
  }

  static Map<String, String> parseLoginIdentity(Map<String, dynamic> response) {
    final mrData = response['mR_NO'] ??
        response['MR_NO'] ??
        response['mrNo'] ??
        response['mr_NO'];

    var mrNo = '';
    var firstName = response['firstName']?.toString() ?? '';
    var lastName = response['lastName']?.toString() ?? '';

    if (mrData is Map) {
      mrNo = (mrData['mrNo'] ?? mrData['MrNo'] ?? mrData['MR_NO'])
              ?.toString() ??
          '';
      firstName = (mrData['firstName'] ?? mrData['FirstName'])?.toString() ??
          firstName;
      lastName =
          (mrData['lastName'] ?? mrData['LastName'])?.toString() ?? lastName;
    } else if (mrData != null) {
      mrNo = mrData.toString();
    }

    if (firstName.isEmpty) {
      firstName = response['firstName']?.toString() ?? 'Patient';
    }
    if (lastName.isEmpty) {
      lastName = response['lastName']?.toString() ?? '';
    }

    return {'mrNo': mrNo, 'firstName': firstName, 'lastName': lastName};
  }

  /// Keeps dashboard greeting in sync after profile edits.
  static Future<void> updateProfileName({
    required String firstName,
    String lastName = '',
  }) async {
    _firstName = firstName.trim();
    _lastName = lastName.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_firstNameKey, _firstName!);
    await prefs.setString(_lastNameKey, _lastName ?? '');
  }

  static Future<void> updateProfileImageUrl(String? url) async {
    final trimmed = url?.trim();
    _profileImageUrl =
        (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (_profileImageUrl == null) {
      await prefs.remove(_profileImageUrlKey);
    } else {
      await prefs.setString(_profileImageUrlKey, _profileImageUrl!);
    }
  }

  static DateTime resolveExpiresAt(Map<String, dynamic> response) {
    final expiresAtRaw = response['expiresAt']?.toString();
    if (expiresAtRaw != null && expiresAtRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(expiresAtRaw);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    final expiresInSeconds = int.tryParse(
      response['expiresInSeconds']?.toString() ?? '',
    );
    if (expiresInSeconds != null && expiresInSeconds > 0) {
      return DateTime.now().add(Duration(seconds: expiresInSeconds));
    }

    return DateTime.now().add(sessionDuration);
  }

  /// True when a JWT was saved and the session has not expired.
  static bool get hasValidToken =>
      _token != null && _token!.isNotEmpty && !isExpired;

  static Future<void> saveFromLoginResponse(
    Map<String, dynamic> response,
  ) async {
    final token = response['token']?.toString();
    final identity = parseLoginIdentity(response);
    final mrNo = identity['mrNo'] ?? '';
    if (mrNo.isEmpty) {
      throw StateError('Login response did not include MR number');
    }

    if (token == null || token.isEmpty) {
      throw StateError('Login response did not include JWT token');
    }

    _token = token;
    _tokenType = response['tokenType']?.toString() ?? 'Bearer';
    _mrNo = mrNo;
    _firstName = identity['firstName'] ?? 'Patient';
    _lastName = identity['lastName'] ?? '';
    _expiresAt = resolveExpiresAt(response);
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token!);
    await prefs.setString(_tokenTypeKey, _tokenType);
    await prefs.setString(_mrNoKey, _mrNo!);
    await prefs.setString(_firstNameKey, _firstName!);
    await prefs.setString(_lastNameKey, _lastName ?? '');
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_expiresAtKey, _expiresAt!.toIso8601String());
    await NotificationService.instance.reloadForCurrentUser();
    if (!kIsWeb) {
      await PushNotificationService.instance.registerForCurrentUser();
    }
    await GuestSession.clear();
    _scheduleExpiryTimer();
  }

  /// Clears session and returns to welcome (same as dashboard logout).
  static Future<void> logOut() async {
    await clear();
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  static Future<void> clear() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _token = null;
    _tokenType = 'Bearer';
    _mrNo = null;
    _firstName = null;
    _lastName = null;
    _profileImageUrl = null;
    _expiresAt = null;
    _isLoggedIn = false;
    if (!kIsWeb) {
      await PushNotificationService.instance.clearOnLogout();
    }
    await NotificationService.instance.clearForLogout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenTypeKey);
    await prefs.remove(_mrNoKey);
    await prefs.remove(_firstNameKey);
    await prefs.remove(_lastNameKey);
    await prefs.remove(_profileImageUrlKey);
    await prefs.remove(_loggedInKey);
    await prefs.remove(_expiresAtKey);
  }

  static Future<bool> ensureValidSession() async {
    if (!_isLoggedIn || _token == null || _mrNo == null) {
      return false;
    }
    if (isExpired) {
      await handleSessionExpired();
      return false;
    }
    return true;
  }

  static Future<void> handleUnauthorized() async {
    await _redirectToWelcome(clearSession: true, sessionExpired: true);
  }

  static Future<void> handleSessionExpired() async {
    await _redirectToWelcome(clearSession: true, sessionExpired: true);
  }

  static Future<void> _redirectToWelcome({
    required bool clearSession,
    bool sessionExpired = false,
  }) async {
    if (!_isLoggedIn && _token == null) return;

    if (clearSession) {
      await clear();
    }

    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );

    if (sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey?.currentContext;
        if (context == null || !context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your session has expired. Please log in again.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      });
    }
  }

  static void _scheduleExpiryTimer() {
    _expiryTimer?.cancel();
    if (_expiresAt == null) return;

    final remaining = _expiresAt!.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      unawaited(handleSessionExpired());
      return;
    }

    _expiryTimer = Timer(remaining, () {
      unawaited(handleSessionExpired());
    });
  }

  static Route<dynamic>? restoredDashboardRoute() {
    if (!isLoggedIn || _mrNo == null) return null;
    return MaterialPageRoute(
      builder: (_) => PatientMainShell(
        patientMrNo: _mrNo!,
        patientName: displayName,
        isLoggedIn: true,
      ),
    );
  }
}
