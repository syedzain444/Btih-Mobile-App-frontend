class AuthValidation {
  AuthValidation._();

  static const int minPasswordLength = 6;
  static const int minPhoneDigits = 10;

  static String? validatePatientContact(String? value) {
    final contact = value?.trim() ?? '';
    if (contact.isEmpty) {
      return 'Contact number is required';
    }

    final digitsOnly = contact.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < minPhoneDigits) {
      return 'Enter a valid contact number (at least $minPhoneDigits digits)';
    }

    if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(contact)) {
      return 'Contact number can only contain digits, spaces, + or -';
    }

    return null;
  }

  static String? validateStaffIdentifier(String? value) {
    final identifier = value?.trim() ?? '';
    if (identifier.isEmpty) {
      return 'Staff ID or email is required';
    }

    if (identifier.contains('@')) {
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(identifier)) {
        return 'Enter a valid email address';
      }
      return null;
    }

    if (identifier.length < 3) {
      return 'Staff ID must be at least 3 characters';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
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
}
