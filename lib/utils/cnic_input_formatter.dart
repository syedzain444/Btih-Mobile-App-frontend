import 'package:flutter/services.dart';

/// Formats Pakistani CNIC as 12345-1234567-1 while typing.
class CnicInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 13;

  static String formatDigits(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < clean.length && i < _maxDigits; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static bool isValid(String value) =>
      RegExp(r'^\d{5}-\d{7}-\d{1}$').hasMatch(value.trim());

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatDigits(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
