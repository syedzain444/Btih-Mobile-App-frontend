import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide typography using Montserrat, Raleway, and Roboto.
///
/// - **Montserrat** — display headings, hero titles, patient names
/// - **Raleway** — app bars, section titles, buttons, labels
/// - **Roboto** — body text, captions, form fields, descriptions
class AppTypography {
  AppTypography._();

  static TextStyle montserrat({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.montserrat(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  static TextStyle raleway({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.raleway(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  static TextStyle roboto({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return GoogleFonts.roboto(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
    );
  }

  /// MR numbers, codes, and other fixed-width-style labels.
  static TextStyle mono({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
  }) {
    return roboto(
      fontSize: fontSize ?? 13,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      letterSpacing: letterSpacing ?? 0.6,
    );
  }

  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: montserrat(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      displayMedium: montserrat(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      displaySmall: montserrat(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
        height: 1.1,
      ),
      headlineLarge: montserrat(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      headlineMedium: montserrat(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      headlineSmall: montserrat(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      titleLarge: raleway(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      titleMedium: raleway(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.darkText,
      ),
      titleSmall: raleway(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      bodyLarge: roboto(
        fontSize: 16,
        color: AppColors.darkText,
        height: 1.5,
      ),
      bodyMedium: roboto(
        fontSize: 14,
        color: AppColors.darkText,
        height: 1.4,
      ),
      bodySmall: roboto(
        fontSize: 12,
        color: AppColors.greyText,
        height: 1.35,
      ),
      labelLarge: raleway(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      labelMedium: raleway(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
        letterSpacing: 0.5,
      ),
      labelSmall: raleway(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.greyText,
      ),
    );
  }
}
