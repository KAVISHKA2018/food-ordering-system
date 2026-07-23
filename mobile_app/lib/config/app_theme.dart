import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFE8865A);      // warm orange (from your Figma)
  static const primaryDark = Color(0xFFD9713F);
  static const background = Color(0xFFFFFFFF);
  static const cardBackground = Color(0xFFF7F7F7);
  static const textDark = Color(0xFF2B2B2B);
  static const textGrey = Color(0xFF8E8E8E);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}