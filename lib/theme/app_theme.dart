import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Radii and elevation constants shared by every rounded surface in the app.
class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(lg));
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.light,
      primary: AppColors.primaryBlue,
      secondary: AppColors.secondaryIndigo,
      tertiary: AppColors.accentGreen,
      error: AppColors.error,
      surface: AppColors.surfaceWhite,
    ),
    fontFamily: 'Poppins',
    textTheme: TextTheme(
      displayLarge: AppTextStyles.displayLarge(AppColors.textPrimary),
      headlineLarge: AppTextStyles.headlineLarge(AppColors.textPrimary),
      headlineSmall: AppTextStyles.headlineSmall(AppColors.textPrimary),
      titleMedium: AppTextStyles.titleMedium(AppColors.textPrimary),
      bodyLarge: AppTextStyles.bodyLarge(AppColors.textPrimary),
      bodyMedium: AppTextStyles.bodyMedium(AppColors.textSecondary),
      bodySmall: AppTextStyles.bodySmall(AppColors.textSecondary),
      labelLarge: AppTextStyles.labelLarge(AppColors.surfaceWhite),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.backgroundLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: AppTextStyles.headlineSmall(AppColors.textPrimary),
    ),
    cardTheme: CardTheme(
      color: AppColors.surfaceWhite,
      elevation: 0,
      shape:
          const RoundedRectangleBorder(borderRadius: AppRadius.card),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.surfaceWhite,
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: AppTextStyles.labelLarge(AppColors.surfaceWhite),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryBlue,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: AppTextStyles.labelLarge(AppColors.primaryBlue),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceWhite,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: AppTextStyles.bodyMedium(AppColors.textSecondary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceWhite,
      selectedItemColor: AppColors.primaryBlue,
      unselectedItemColor: Color(0xFF94A3B8),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 12,
    ),
    dividerColor: const Color(0xFFE2E8F0),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.dark,
      primary: const Color(0xFF60A5FA),
      secondary: AppColors.secondaryIndigo,
      tertiary: AppColors.accentGreen,
      error: AppColors.error,
      surface: AppColors.darkSurface,
    ),
    fontFamily: 'Poppins',
    textTheme: TextTheme(
      displayLarge: AppTextStyles.displayLarge(AppColors.textPrimaryDark),
      headlineLarge: AppTextStyles.headlineLarge(AppColors.textPrimaryDark),
      headlineSmall: AppTextStyles.headlineSmall(AppColors.textPrimaryDark),
      titleMedium: AppTextStyles.titleMedium(AppColors.textPrimaryDark),
      bodyLarge: AppTextStyles.bodyLarge(AppColors.textPrimaryDark),
      bodyMedium: AppTextStyles.bodyMedium(AppColors.textSecondaryDark),
      bodySmall: AppTextStyles.bodySmall(AppColors.textSecondaryDark),
      labelLarge: AppTextStyles.labelLarge(AppColors.surfaceWhite),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      titleTextStyle: AppTextStyles.headlineSmall(AppColors.textPrimaryDark),
    ),
    cardTheme: CardTheme(
      color: AppColors.darkSurface,
      elevation: 0,
      shape:
          const RoundedRectangleBorder(borderRadius: AppRadius.card),
      margin: EdgeInsets.zero,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF60A5FA),
        foregroundColor: AppColors.darkBackground,
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: AppTextStyles.labelLarge(AppColors.darkBackground),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF60A5FA),
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
        textStyle: AppTextStyles.labelLarge(const Color(0xFF60A5FA)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: AppTextStyles.bodyMedium(AppColors.textSecondaryDark),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: Color(0xFF60A5FA),
      unselectedItemColor: Color(0xFF64748B),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 12,
    ),
    dividerColor: const Color(0xFF334155),
  );
}
