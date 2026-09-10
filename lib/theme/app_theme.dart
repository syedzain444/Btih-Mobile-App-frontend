import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryRed,
        onPrimary: AppColors.white,
        secondary: AppColors.duskMaroon,
        onSecondary: AppColors.white,
        tertiary: AppColors.rustRed,
        surface: AppColors.white,
        onSurface: AppColors.darkText,
        surfaceTint: AppColors.primaryRed,
        error: AppColors.primaryRed,
        onError: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      canvasColor: AppColors.white,
      dividerColor: AppColors.hairline,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.duskMaroon,
        foregroundColor: AppColors.white,
        iconTheme: const IconThemeData(color: AppColors.white),
        titleTextStyle: AppTypography.raleway(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.primaryRed.withValues(alpha: 0.45),
          elevation: 0,
          // Width 0 allows buttons in Row/Flex; full-width buttons use parent constraints.
          minimumSize: const Size(0, 52),
          textStyle: AppTypography.raleway(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryRed,
          textStyle: AppTypography.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryRed,
          side: const BorderSide(color: AppColors.primaryRed, width: 1.3),
          minimumSize: const Size(0, 52),
          textStyle: AppTypography.raleway(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        labelStyle: AppTypography.roboto(
          fontSize: 14,
          color: AppColors.greyText,
        ),
        floatingLabelStyle: AppTypography.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryRed,
        ),
        hintStyle: AppTypography.roboto(
          fontSize: 14,
          color: AppColors.greyText,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.hairline, width: 1.2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.7)),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
        ),
        errorStyle: AppTypography.roboto(
          fontSize: 12,
          color: AppColors.primaryRed,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.fieldBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.softRed,
        labelStyle: AppTypography.roboto(
          fontSize: 12,
          color: AppColors.darkText,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.duskMaroon,
        contentTextStyle: AppTypography.roboto(
          fontSize: 14,
          color: AppColors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: AppTypography.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        contentTextStyle: AppTypography.roboto(
          fontSize: 14,
          color: AppColors.greyText,
          height: 1.4,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryRed,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.blush,
        selectedItemColor: AppColors.primaryRed,
        unselectedItemColor: AppColors.greyText,
        selectedLabelStyle: AppTypography.raleway(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTypography.raleway(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryRed,
        unselectedLabelColor: AppColors.greyText,
        indicatorColor: AppColors.primaryRed,
        labelStyle: AppTypography.raleway(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTypography.raleway(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
      ),
    );
  }
}
