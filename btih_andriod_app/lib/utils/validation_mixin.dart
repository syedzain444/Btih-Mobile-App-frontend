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

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? validateConfirmPassword(String? password, String? confirm) {
    if (confirm == null || confirm.isEmpty) return 'Confirm your password';
    if (password != confirm) return 'Passwords do not match';
    return null;
  }
}
