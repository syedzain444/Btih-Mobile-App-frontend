import 'dart:convert';

import 'package:btih_andriod_app/services/auth_session.dart';
import 'package:btih_andriod_app/services/security_devices_service.dart';
import 'package:btih_andriod_app/services/security_preferences_service.dart';
import 'package:btih_andriod_app/utils/ip_file.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PIN app lock for logged-in patients.
///
/// Uses [SharedPreferences] (not flutter_secure_storage) so Android Keystore
/// failures cannot crash Security Settings / App Lock. PIN hash is also synced
/// to the backend when the API is available.
class AppLockService extends ChangeNotifier {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  /// Fixed length for set PIN and unlock screen (must stay in sync).
  static const int pinLength = 4;

  static const _pinPrefPrefix = 'app_pin_hash_v2_';
  static const _pinClearedForFixedLengthKey = 'app_pin_cleared_fixed4_v1';

  bool _locked = false;

  bool get isLocked => _locked;

  /// Biometric unlock is reserved for a future release.
  bool get biometricAvailable => false;

  Future<void> init() async {
    // One-time: clear old variable-length PINs so users re-set a 4-digit PIN.
    await _clearLegacyPinsIfNeeded();
    final mrNo = AuthSession.mrNo?.trim();
    if (mrNo != null && mrNo.isNotEmpty && AuthSession.isLoggedIn) {
      await reconcileWithServer(mrNo);
    }
  }

  /// Align local PIN state with `GET /api/AppPin/status`.
  Future<void> reconcileWithServer(String mrNo) async {
    final trimmed = mrNo.trim();
    if (trimmed.isEmpty || !AuthSession.isLoggedIn) return;

    try {
      final response = await ApiConfig.client.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/AppPin/status?mrNo=${Uri.encodeQueryComponent(trimmed)}',
        ),
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );
      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body);
      if (body is! Map) return;
      final serverHasPin = body['hasPin'] == true;
      final localHasPin = await hasPin(trimmed);

      if (!serverHasPin && localHasPin) {
        // Server cleared PIN — drop local hash so lock does not stay armed.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pinKey(trimmed));
        await SecurityPreferencesService.setPinLockEnabled(trimmed, false);
        if (_locked) {
          _locked = false;
          notifyListeners();
        }
      } else if (serverHasPin && !localHasPin) {
        // PIN exists on server but not on this device — require re-setup locally.
        await SecurityPreferencesService.setPinLockEnabled(trimmed, false);
      }
    } catch (e) {
      debugPrint('AppLockService.reconcileWithServer failed: $e');
    }
  }

  Future<void> _clearLegacyPinsIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_pinClearedForFixedLengthKey) == true) return;

      final keys = prefs.getKeys().toList();
      for (final key in keys) {
        if (key.startsWith(_pinPrefPrefix) ||
            key.startsWith('app_pin_hash_') ||
            key.contains('_pin_lock')) {
          await prefs.remove(key);
        }
      }

      final mrNo = AuthSession.mrNo?.trim();
      if (mrNo != null && mrNo.isNotEmpty) {
        await SecurityPreferencesService.setPinLockEnabled(mrNo, false);
        await SecurityPreferencesService.setLockOnBackground(mrNo, false);
        try {
          await ApiConfig.client.post(
            Uri.parse('${ApiConfig.baseUrl}/api/AppPin/clear'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...AuthSession.authHeaders,
            },
            body: jsonEncode({'mrNo': mrNo}),
          );
        } catch (_) {}
      }

      await prefs.setBool(_pinClearedForFixedLengthKey, true);
      if (_locked) {
        _locked = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('AppLockService._clearLegacyPinsIfNeeded failed: $e');
    }
  }

  Future<bool> isLockConfigured(String mrNo) async {
    final pinEnabled = await SecurityPreferencesService.getPinLockEnabled(mrNo);
    return pinEnabled && await hasPin(mrNo);
  }

  Future<bool> shouldLockOnResume(String mrNo) async {
    if (!AuthSession.isLoggedIn || mrNo.trim().isEmpty) return false;
    final lockBackground =
        await SecurityPreferencesService.getLockOnBackground(mrNo);
    if (!lockBackground) return false;
    return isLockConfigured(mrNo);
  }

  void lock() {
    if (!_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  void unlock() {
    if (_locked) {
      _locked = false;
      notifyListeners();
    }
  }

  Future<bool> hasPin(String mrNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_pinKey(mrNo));
      return stored != null && stored.isNotEmpty;
    } catch (e) {
      debugPrint('AppLockService.hasPin failed: $e');
      return false;
    }
  }

  Future<void> setPin(String mrNo, String pin) async {
    final trimmedMr = mrNo.trim();
    final normalized = pin.trim();
    if (trimmedMr.isEmpty) {
      throw ArgumentError('MR number is required');
    }
    if (!_isValidPin(normalized)) {
      throw ArgumentError('PIN must be exactly $pinLength digits');
    }

    final hash = hashPin(trimmedMr, normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey(trimmedMr), hash);
    await SecurityPreferencesService.setPinLockEnabled(trimmedMr, true);

    // Best-effort server sync — local PIN still works if API is down.
    try {
      final label = await SecurityDevicesService.currentDeviceLabel();
      await ApiConfig.client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/AppPin/set'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({
          'mrNo': trimmedMr,
          'pinHash': hash,
          'deviceLabel': label,
        }),
      );
    } catch (e) {
      debugPrint('AppLockService.setPin API sync failed: $e');
    }
  }

  Future<void> clearPin(String mrNo) async {
    final trimmedMr = mrNo.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey(trimmedMr));
    } catch (_) {}
    await SecurityPreferencesService.setPinLockEnabled(trimmedMr, false);

    try {
      await ApiConfig.client.post(
        Uri.parse('${ApiConfig.baseUrl}/api/AppPin/clear'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({'mrNo': trimmedMr}),
      );
    } catch (e) {
      debugPrint('AppLockService.clearPin API sync failed: $e');
    }
  }

  Future<bool> verifyPin(String mrNo, String pin) async {
    try {
      final normalized = pin.trim();
      if (!_isValidPin(normalized)) return false;
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_pinKey(mrNo));
      if (stored == null || stored.isEmpty) return false;
      return stored == hashPin(mrNo, normalized);
    } catch (e) {
      debugPrint('AppLockService.verifyPin failed: $e');
      return false;
    }
  }

  static bool _isValidPin(String pin) =>
      RegExp('^\\d{$pinLength}\$').hasMatch(pin);

  /// Public so Forgot-PIN reset can persist the same hash format.
  String hashPin(String mrNo, String pin) {
    final bytes = utf8.encode('${mrNo.trim()}::${pin.trim()}');
    return sha256.convert(bytes).toString();
  }

  String _pinKey(String mrNo) => '$_pinPrefPrefix${mrNo.trim()}';
}
