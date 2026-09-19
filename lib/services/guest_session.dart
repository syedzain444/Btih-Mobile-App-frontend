import 'package:btih_andriod_app/services/guest_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guest profile for walk-in booking (persisted locally + synced to API).
class GuestSession {
  GuestSession._();

  static const _guestIdKey = 'guest_id';
  static const _fullNameKey = 'guest_full_name';
  static const _mobileKey = 'guest_mobile';
  static const _dobKey = 'guest_dob';
  static const _genderKey = 'guest_gender';

  static int? _guestId;
  static String? _fullName;
  static String? _mobileNumber;
  static String? _dateOfBirth;
  static String? _gender;

  static int? get guestId => _guestId;
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
    _guestId = prefs.getInt(_guestIdKey);
    _fullName = prefs.getString(_fullNameKey);
    _mobileNumber = prefs.getString(_mobileKey);
    _dateOfBirth = prefs.getString(_dobKey);
    _gender = prefs.getString(_genderKey);

    if (!isComplete && (_mobileNumber?.isNotEmpty == true)) {
      await _restoreFromApi(_mobileNumber!);
    }
  }

  static Future<void> save({
    int? guestId,
    required String fullName,
    required String mobileNumber,
    required String dateOfBirth,
    required String gender,
  }) async {
    _guestId = guestId;
    _fullName = fullName.trim();
    _mobileNumber = normalizePhone(mobileNumber);
    _dateOfBirth = dateOfBirth.trim();
    _gender = gender.trim();

    final prefs = await SharedPreferences.getInstance();
    if (_guestId != null) {
      await prefs.setInt(_guestIdKey, _guestId!);
    }
    await prefs.setString(_fullNameKey, _fullName!);
    await prefs.setString(_mobileKey, _mobileNumber!);
    await prefs.setString(_dobKey, _dateOfBirth!);
    await prefs.setString(_genderKey, _gender!);
  }

  static Future<void> saveFromApiResponse(Map<String, dynamic> response) async {
    final guestId = response['guestId'];
    final parsedGuestId = guestId is int
        ? guestId
        : int.tryParse(guestId?.toString() ?? '');

    await save(
      guestId: parsedGuestId,
      fullName: response['fullName']?.toString() ?? '',
      mobileNumber: response['mobileNumber']?.toString() ?? '',
      dateOfBirth: response['dateOfBirth']?.toString() ?? '',
      gender: response['gender']?.toString() ?? '',
    );
  }

  static Future<void> clear() async {
    _guestId = null;
    _fullName = null;
    _mobileNumber = null;
    _dateOfBirth = null;
    _gender = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestIdKey);
    await prefs.remove(_fullNameKey);
    await prefs.remove(_mobileKey);
    await prefs.remove(_dobKey);
    await prefs.remove(_genderKey);
  }

  static Future<bool> _restoreFromApi(String mobileNumber) async {
    try {
      final profile = await GuestService().loadProfile(mobileNumber);
      if (profile == null) {
        return false;
      }
      await saveFromApiResponse(profile);
      return isComplete;
    } catch (_) {
      return false;
    }
  }

  static String normalizePhone(String raw) {
    var digits = raw.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (digits.startsWith('92') && digits.length >= 12) {
      digits = digits.substring(2);
    }
    if (!digits.startsWith('0') && digits.length == 10) {
      digits = '0$digits';
    }
    return digits;
  }
}
