import 'package:shared_preferences/shared_preferences.dart';

/// Local security preferences stored per patient MR number.
class SecurityPreferencesService {
  SecurityPreferencesService._();

  static const _prefix = 'security_prefs_';

  static String _key(String mrNo, String suffix) => '$_prefix${mrNo.trim()}_$suffix';

  static Future<bool> getMaskSensitiveFields(String mrNo) =>
      _getBool(mrNo, 'mask_sensitive', defaultValue: false);

  static Future<void> setMaskSensitiveFields(String mrNo, bool value) =>
      _setBool(mrNo, 'mask_sensitive', value);

  static Future<bool> getHideNotificationPreview(String mrNo) =>
      _getBool(mrNo, 'hide_notif_preview', defaultValue: false);

  static Future<void> setHideNotificationPreview(String mrNo, bool value) =>
      _setBool(mrNo, 'hide_notif_preview', value);

  static Future<bool> getBiometricUnlock(String mrNo) =>
      _getBool(mrNo, 'biometric_unlock', defaultValue: false);

  static Future<void> setBiometricUnlock(String mrNo, bool value) =>
      _setBool(mrNo, 'biometric_unlock', value);

  static Future<bool> getPinLockEnabled(String mrNo) =>
      _getBool(mrNo, 'pin_lock', defaultValue: false);

  static Future<void> setPinLockEnabled(String mrNo, bool value) =>
      _setBool(mrNo, 'pin_lock', value);

  static Future<bool> getLockOnBackground(String mrNo) =>
      _getBool(mrNo, 'lock_background', defaultValue: false);

  static Future<void> setLockOnBackground(String mrNo, bool value) =>
      _setBool(mrNo, 'lock_background', value);

  static String maskCnic(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.length <= 6) return '••••••';
    return '${trimmed.substring(0, 5)}•••••-${trimmed.substring(trimmed.length - 1)}';
  }

  static String maskPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '••••';
    final last4 = digits.substring(digits.length - 4);
    return '•••• •••$last4';
  }

  static String maskMobileDisplay(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Not registered';
    return maskPhone(trimmed);
  }

  static Future<bool> _getBool(
    String mrNo,
    String suffix, {
    required bool defaultValue,
  }) async {
    if (mrNo.trim().isEmpty) return defaultValue;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(mrNo, suffix)) ?? defaultValue;
  }

  static Future<void> _setBool(String mrNo, String suffix, bool value) async {
    if (mrNo.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(mrNo, suffix), value);
  }
}
