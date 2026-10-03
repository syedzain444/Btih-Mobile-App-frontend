import 'package:btih_andriod_app/utils/auth_validation.dart';

mixin ValidationMixin {
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email or username required';
    }
    final email = value.trim();
    final emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}");
    if (email.contains('@') && !emailRegex.hasMatch(email)) {
      return 'Enter a valid email';
    }
    if (email.length < 3) return 'Too short';
    return null;
  }

  String? validatePassword(String? value) =>
      AuthValidation.validatePassword(value);

  String? validateConfirmPassword(String? password, String? confirm) =>
      AuthValidation.validateConfirmPassword(password, confirm);
}
