import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFE8865A);
  static const Color textDark = Color(0xFF2B2B2B);
  static const Color textGrey = Color(0xFF8E8E8E);
  static const Color cardBackground = Color(0xFFF5F5F5);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      useMaterial3: true,
    );
  }
}