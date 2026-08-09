import 'package:flutter/material.dart';

/// Single source of truth for every color used across EduSphere.
/// Values are copied directly from the approved EduSphere design mockups.
/// Do not introduce new colors outside this file — extend it instead.
class AppColors {
  AppColors._();

  // Brand
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryIndigo = Color(0xFF4F46E5);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color highlightOrange = Color(0xFFF59E0B);

  // Surfaces
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Status
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);

  // Gradients (splash / welcome hero)
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryIndigo, primaryBlue],
  );

  static const LinearGradient darkSplashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), secondaryIndigo],
  );

  // Category chip accents, cycled through for cards/icons
  static const List<Color> categoryAccents = [
    primaryBlue,
    secondaryIndigo,
    accentGreen,
    highlightOrange,
  ];
}
