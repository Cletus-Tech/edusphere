import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Poppins type scale. Every screen should pull styles from here rather
/// than hand-rolling TextStyle so type stays consistent app-wide.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle displayLarge(Color c) =>
      _base(size: 32, weight: FontWeight.w700, color: c, height: 1.2);

  static TextStyle headlineLarge(Color c) =>
      _base(size: 24, weight: FontWeight.w700, color: c, height: 1.25);

  static TextStyle headlineSmall(Color c) =>
      _base(size: 20, weight: FontWeight.w600, color: c, height: 1.3);

  static TextStyle titleMedium(Color c) =>
      _base(size: 16, weight: FontWeight.w600, color: c, height: 1.4);

  static TextStyle bodyLarge(Color c) =>
      _base(size: 15, weight: FontWeight.w400, color: c, height: 1.5);

  static TextStyle bodyMedium(Color c) =>
      _base(size: 14, weight: FontWeight.w400, color: c, height: 1.5);

  static TextStyle bodySmall(Color c) =>
      _base(size: 12, weight: FontWeight.w400, color: c, height: 1.4);

  static TextStyle labelLarge(Color c) => _base(
        size: 15,
        weight: FontWeight.w600,
        color: c,
        letterSpacing: 0.2,
      );

  static TextStyle caption(Color c) =>
      _base(size: 11, weight: FontWeight.w500, color: c, letterSpacing: 0.3);

  // Convenience shortcuts for the most common (light-mode default) cases
  static TextStyle get h1 => headlineLarge(AppColors.textPrimary);
  static TextStyle get h2 => headlineSmall(AppColors.textPrimary);
  static TextStyle get body => bodyMedium(AppColors.textPrimary);
}
