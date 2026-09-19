import 'package:shared_preferences/shared_preferences.dart';

/// Local notification preference toggles (per patient MR).
class NotificationPreferencesService {
  NotificationPreferencesService._();

  static const _prefix = 'notif_prefs_';

  static String _key(String mrNo, String suffix) =>
      '$_prefix${mrNo.trim()}_$suffix';

  static Future<bool> getPushEnabled(String mrNo) =>
      _getBool(mrNo, 'push', defaultValue: true);

  static Future<bool> getAppointmentAlerts(String mrNo) =>
      _getBool(mrNo, 'appointments', defaultValue: true);

  static Future<bool> getMedicationAlerts(String mrNo) =>
      _getBool(mrNo, 'medications', defaultValue: true);

  static Future<bool> getBillingAlerts(String mrNo) =>
      _getBool(mrNo, 'billing', defaultValue: true);

  static Future<void> setPushEnabled(String mrNo, bool value) =>
      _setBool(mrNo, 'push', value);

  static Future<void> setAppointmentAlerts(String mrNo, bool value) =>
      _setBool(mrNo, 'appointments', value);

  static Future<void> setMedicationAlerts(String mrNo, bool value) =>
      _setBool(mrNo, 'medications', value);

  static Future<void> setBillingAlerts(String mrNo, bool value) =>
      _setBool(mrNo, 'billing', value);

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
