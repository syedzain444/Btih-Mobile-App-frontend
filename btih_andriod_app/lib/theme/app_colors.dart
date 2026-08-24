import 'package:flutter/material.dart';

/// Deep, muted red + pastel blush palette.
/// Deliberately avoids vivid/fire-engine red — reads calm, elegant, clinical.
class AppColors {
  AppColors._();

  // Core red family
  static const Color primaryRed = Color(0xFFA62639); // deep muted red — buttons, key text
  static const Color deepRed = Color(0xFF7D1D2B); // darker end for gradients / pressed states
  static const Color rustRed = Color(0xFFC24957); // mid-tone, used in gradients

  // Pastels / surfaces
  static const Color softRed = Color(0xFFF6DEE1); // pastel chip / icon backgrounds
  static const Color lightMaroon = Color(0xFFEDD5D9); // section headers, tap highlights
  static const Color blush = Color(0xFFFBEEEF); // soft pink wash for top section
  static const Color scaffoldBg = Color(0xFFFFF8F8); // near-white page background
  static const Color white = Color(0xFFFFFFFF);

  // Text
  static const Color darkText = Color(0xFF2C2224);
  static const Color greyText = Color(0xFF8C7678);

  // Structure
  static const Color fieldBorder = Color(0xFFF0DCDE);
  static const Color shadow = Color(0xFF7D1D2B);
  static const Color fieldFill = Color(0xFFF9F2F3);
}