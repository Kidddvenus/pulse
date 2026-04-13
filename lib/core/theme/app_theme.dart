import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onSurface: AppColors.textPrimaryLight,
        surfaceContainerHighest: AppColors.textSecondaryLight, // Using this for secondary text conceptually
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: AppColors.textPrimaryLight),
        bodyLarge: GoogleFonts.outfit(color: AppColors.textPrimaryLight),
        bodyMedium: GoogleFonts.outfit(color: AppColors.textSecondaryLight),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBgLight,
        hintStyle: GoogleFonts.outfit(color: AppColors.textSecondaryLight),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondaryLight),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        onSurface: AppColors.textPrimaryDark,
        surfaceContainerHighest: AppColors.textSecondaryDark,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: AppColors.textPrimaryDark),
        bodyLarge: GoogleFonts.outfit(color: AppColors.textPrimaryDark),
        bodyMedium: GoogleFonts.outfit(color: AppColors.textSecondaryDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBgDark,
        hintStyle: GoogleFonts.outfit(color: AppColors.textSecondaryDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.glassBorderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 4,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondaryDark),
    );
  }
}
