import 'package:shared_preferences/shared_preferences.dart';

/// In-memory guest profile for walk-in booking (no MR number stored).
class GuestSession {
  GuestSession._();

  static const _fullNameKey = 'guest_full_name';
  static const _mobileKey = 'guest_mobile';
  static const _dobKey = 'guest_dob';
  static const _genderKey = 'guest_gender';

  static String? _fullName;
  static String? _mobileNumber;
  static String? _dateOfBirth;
  static String? _gender;

  static String? get fullName => _fullName;
  static String? get mobileNumber => _mobileNumber;
  static String? get dateOfBirth => _dateOfBirth;
  static String? get gender => _gender;

  static String get displayName =>
      (_fullName?.trim().isNotEmpty == true) ? _fullName!.trim() : 'Guest';

  static bool get isComplete =>
      _fullName?.trim().isNotEmpty == true &&
      _mobileNumber?.trim().isNotEmpty == true &&
      _dateOfBirth?.trim().isNotEmpty == true &&
      _gender?.trim().isNotEmpty == true;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _fullName = prefs.getString(_fullNameKey);
    _mobileNumber = prefs.getString(_mobileKey);
    _dateOfBirth = prefs.getString(_dobKey);
    _gender = prefs.getString(_genderKey);
  }

  static Future<void> save({
    required String fullName,
    required String mobileNumber,
    required String dateOfBirth,
    required String gender,
  }) async {
    _fullName = fullName.trim();
    _mobileNumber = normalizePhone(mobileNumber);
    _dateOfBirth = dateOfBirth.trim();
    _gender = gender.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fullNameKey, _fullName!);
    await prefs.setString(_mobileKey, _mobileNumber!);
    await prefs.setString(_dobKey, _dateOfBirth!);
    await prefs.setString(_genderKey, _gender!);
  }

  static Future<void> clear() async {
    _fullName = null;
    _mobileNumber = null;
    _dateOfBirth = null;
    _gender = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_fullNameKey);
    await prefs.remove(_mobileKey);
    await prefs.remove(_dobKey);
    await prefs.remove(_genderKey);
  }

  static String normalizePhone(String raw) {
    return raw.trim().replaceAll(RegExp(r'[\s\-]'), '');
  }
}
