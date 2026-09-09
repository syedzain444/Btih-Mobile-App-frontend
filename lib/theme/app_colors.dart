import 'package:flutter/material.dart';

/// Unified maroon + blush palette — matches patient/staff login screens.
class AppColors {
  AppColors._();

  // Core red family
  static const Color primaryRed = Color(0xFFA62639);
  static const Color deepRed = Color(0xFF7D1D2B);
  static const Color rustRed = Color(0xFFC24957);
  static const Color duskMaroon = Color(0xFF3B0A18);

  // Pastels / surfaces
  static const Color softRed = Color(0xFFF6DEE1);
  static const Color lightMaroon = Color(0xFFEDD5D9);
  static const Color blush = Color(0xFFFBEEEF);
  static const Color scaffoldBg = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);

  // Text
  static const Color darkText = Color(0xFF2C2224);
  static const Color greyText = Color(0xFF8C7678);

  // Structure
  static const Color fieldBorder = Color(0xFFE7DFDC);
  static const Color hairline = Color(0xFFE7DFDC);
  static const Color shadow = Color(0xFF7D1D2B);
  static const Color fieldFill = Color(0xFFF9F2F3);

  // Semantic (maroon-tinted where possible)
  static const Color success = Color(0xFF7D1D2B);
  static const Color successBg = Color(0xFFF6DEE1);
  static const Color warning = Color(0xFFA62639);
  static const Color warningBg = Color(0xFFFBEEEF);
  static const Color info = Color(0xFFC24957);
  static const Color infoBg = Color(0xFFEDD5D9);

  /// Horizontal brand gradient — login header, app bars, welcome accents.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [rustRed, primaryRed, deepRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    stops: [0.0, 0.55, 1.0],
  );

  /// Hero / app-bar gradient — alias of [brandGradient] (flat, no blobs).
  static const LinearGradient heroGradient = brandGradient;

  /// Primary action button gradient (login Login button).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRed, duskMaroon],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Module / quick-action tiles — all maroon-family (no teal/purple/orange).
  static const List<({Color icon, Color background})> modulePalette = [
    (icon: primaryRed, background: softRed),
    (icon: deepRed, background: blush),
    (icon: rustRed, background: lightMaroon),
    (icon: duskMaroon, background: softRed),
    (icon: primaryRed, background: blush),
    (icon: deepRed, background: lightMaroon),
  ];

  static ({Color icon, Color background}) moduleColor(int index) {
    return modulePalette[index % modulePalette.length];
  }
}
