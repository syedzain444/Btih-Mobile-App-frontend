import 'package:btih_andriod_app/theme/app_colors.dart';
import 'package:btih_andriod_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.darkText,
        titleTextStyle: AppTypography.raleway(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: AppTypography.raleway(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppTypography.raleway(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AppTypography.raleway(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppTypography.roboto(
          fontSize: 14,
          color: AppColors.greyText,
        ),
        labelStyle: AppTypography.raleway(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: AppTypography.roboto(
          fontSize: 14,
          color: AppColors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
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
        labelStyle: AppTypography.raleway(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppTypography.raleway(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
