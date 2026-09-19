import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

InputDecoration authUnderlineFieldDecoration({
  required String hint,
  Widget? suffix,
  Widget? prefix,
  String? counterText,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.roboto(
      fontSize: 14,
      color: AppColors.greyText,
    ),
    prefixIcon: prefix,
    suffixIcon: suffix,
    counterText: counterText,
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.hairline, width: 1.2),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
    ),
    errorBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: AppColors.primaryRed.withValues(alpha: 0.7),
      ),
    ),
    focusedErrorBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
    ),
    errorStyle: AppTypography.roboto(
      fontSize: 12,
      color: AppColors.primaryRed,
    ),
  );
}
