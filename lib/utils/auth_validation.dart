/// Hospital patient-portal auth validation (REQ-2026-016 / TC-016).
///
/// Login: phone format + non-empty password (legacy passwords still allowed).
/// Password create/update: full hospital complexity policy.
class AuthValidation {
  AuthValidation._();

  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;
  static const int minPhoneDigits = 10;
  static const int maxPhoneDigits = 15;

  static const String passwordPolicySummary =
      'Password must be $minPasswordLength–$maxPasswordLength characters and include '
      'uppercase, lowercase, a number, and a special character.';

  /// HMIS MR patterns such as `010-002-152`.
  static bool isMrNumber(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return false;

    var trimmed = raw;
    if (trimmed.toUpperCase().startsWith('MR')) {
      trimmed = trimmed.substring(2).replaceFirst(RegExp(r'^[\s:#\-]+'), '');
    }

    if (RegExp(r'^\d{2,4}-\d{2,5}-\d{2,6}$').hasMatch(trimmed)) {
      return true;
    }

    final asPhone = normalizePakistanPhone(raw);
    if (RegExp(r'^03\d{9}$').hasMatch(asPhone)) {
      return false;
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 7 &&
        digits.length <= 12 &&
        !digits.startsWith('03') &&
        digits.length < minPhoneDigits) {
      return true;
    }

    return false;
  }

  static String normalizeMrNumber(String raw) {
    var trimmed = raw.trim();
    if (trimmed.toUpperCase().startsWith('MR')) {
      trimmed = trimmed.substring(2).replaceFirst(RegExp(r'^[\s:#\-]+'), '');
    }
    return trimmed.trim();
  }

  /// Login identifier: MR number **or** registered mobile (REQ-2026-017).
  static String? validateLoginIdentifier(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return 'MR number or mobile number is required';
    }

    if (isMrNumber(raw)) {
      final mr = normalizeMrNumber(raw);
      if (mr.isEmpty) {
        return 'Enter a valid MR number (e.g. 010-002-152)';
      }
      return null;
    }

    return validatePatientContact(raw);
  }

  /// Returns normalized MR or phone for the login API `contactNo` field.
  static String normalizeLoginIdentifier(String raw) {
    final trimmed = raw.trim();
    if (isMrNumber(trimmed)) {
      return normalizeMrNumber(trimmed);
    }
    return normalizePakistanPhone(trimmed);
  }

  static String? validatePatientContact(String? value) {
    final contact = value?.trim() ?? '';
    if (contact.isEmpty) {
      return 'Contact number is required';
    }

    if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(contact)) {
      return 'Contact number can only contain digits, spaces, + or -';
    }

    final normalized = normalizePakistanPhone(contact);
    if (RegExp(r'^03\d{9}$').hasMatch(normalized)) {
      return null;
    }

    // Legacy HMIS contacts that are not strict 03XXXXXXXXX.
    final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= minPhoneDigits &&
        digitsOnly.length <= maxPhoneDigits) {
      return null;
    }

    return 'Enter a valid mobile number (e.g. 03XXXXXXXXX)';
  }

  /// Strict Pakistani mobile check for guest / signup flows (`03XXXXXXXXX`).
  static String? validatePakistanMobile(String? value) {
    final contact = value?.trim() ?? '';
    if (contact.isEmpty) {
      return 'Mobile number is required';
    }

    if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(contact)) {
      return 'Mobile number can only contain digits, spaces, + or -';
    }

    final normalized = normalizePakistanPhone(contact);
    if (!RegExp(r'^03\d{9}$').hasMatch(normalized)) {
      return 'Enter a valid Pakistani mobile (03XXXXXXXXX)';
    }

    return null;
  }

  static String? validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'Full name is required';
    }
    if (name.length < 2) {
      return 'Enter your full name';
    }
    if (!RegExp(r"^[a-zA-Z\s.\-']+$").hasMatch(name)) {
      return 'Name can only contain letters';
    }
    return null;
  }

  /// Login password — required only (does not enforce new complexity on legacy accounts).
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  /// Full hospital policy for register / forgot-password / change-password.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    if (value.length > maxPasswordLength) {
      return 'Password must be at most $maxPasswordLength characters';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return 'Password cannot contain spaces';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must include at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must include at least one number';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Password must include at least one special character';
    }
    return null;
  }

  static String? validateConfirmPassword(String? password, String? confirm) {
    if (confirm == null || confirm.isEmpty) {
      return 'Confirm your password';
    }
    if (password != confirm) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validatePasswordChange({
    required String? currentPassword,
    required String? newPassword,
    required String? confirmPassword,
  }) {
    if (currentPassword == null || currentPassword.isEmpty) {
      return 'Current password is required';
    }
    final policyError = validatePassword(newPassword);
    if (policyError != null) return policyError;
    final matchError = validateConfirmPassword(newPassword, confirmPassword);
    if (matchError != null) return matchError;
    if (currentPassword == newPassword) {
      return 'New password must be different from the current password';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    final otp = value?.trim() ?? '';
    if (otp.isEmpty) {
      return 'OTP is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return 'Enter a valid 6-digit OTP';
    }
    return null;
  }

  static String? validateFirstName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) {
      return 'First name is required';
    }
    if (name.length < 2) {
      return 'Enter your first name';
    }
    return null;
  }

  /// Normalizes Pakistani mobile input to `03XXXXXXXXX` for HMIS APIs.
  static String normalizePakistanPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92') && digits.length >= 12) {
      digits = '0${digits.substring(2)}';
    } else if (!digits.startsWith('0') && digits.length == 10) {
      digits = '0$digits';
    }
    return digits;
  }

  static String formatPakistanPhoneDisplay(String normalizedPhone) {
    final digits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      return '+92${digits.substring(1)}';
    }
    if (digits.startsWith('92') && digits.length == 12) {
      return '+$digits';
    }
    return normalizedPhone;
  }
}
