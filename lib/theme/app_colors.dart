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

  // Stage B1 — expanded palette for the beautification pass. Additive
  // only: every constant above is untouched, so nothing that already
  // reads AppColors.primaryBlue/etc. changes behavior. These give
  // later stages purposeful per-module/per-purpose accents instead of
  // reusing blue for everything (the brief's "not a generic blue app"
  // requirement) — e.g. JAMB -> violet, WAEC -> teal, NECO -> a green
  // variant distinct from accentGreen's "success" meaning.
  static const Color accentViolet = Color(0xFF7C3AED);
  static const Color accentPurple = Color(0xFF9333EA);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentTeal = Color(0xFF0D9488);

  /// Stage B5 — the "green variant distinct from [accentGreen]'s
  /// success meaning" the Stage B1 comment above already reserved for
  /// NECO's module identity (JAMB/WAEC got [accentViolet]/[accentTeal]
  /// in B5; NECO needed its own token rather than reusing accentGreen,
  /// which reads as "success/correct" everywhere else in the app).
  static const Color necoEmerald = Color(0xFF15803D);

  /// Distinct from [highlightOrange] (used today as a generic
  /// attention/highlight accent, e.g. exam-card badges) — this is
  /// specifically for warning/caution states (low time remaining,
  /// destructive-adjacent confirmations) so the two purposes don't
  /// share one token as the app grows more status-aware.
  static const Color warningAmber = Color(0xFFF59E0B);

  /// Section 27 — premium content's dedicated accent. Not reused from
  /// [highlightOrange]/[warningAmber] on purpose: premium needs to
  /// read as "special," not "caution."
  static const Color premiumGold = Color(0xFFCA8A04);
  static const Color premiumGoldDark = Color(0xFFEAB308);

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

  // Stage B1 — reusable gradients for later stages' hero/featured/
  // premium cards (brief sections 5 & 7), so each screen references
  // one shared token instead of hand-rolling its own LinearGradient.
  // Deliberately not applied anywhere yet — later stages opt in.
  static const LinearGradient featuredGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, accentViolet],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [premiumGold, Color(0xFFF59E0B)],
  );

  // Category chip accents, cycled through for cards/icons
  static const List<Color> categoryAccents = [
    primaryBlue,
    secondaryIndigo,
    accentGreen,
    highlightOrange,
  ];
}
