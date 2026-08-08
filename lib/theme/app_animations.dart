import 'package:flutter/animation.dart';

/// Stage B1 — shared animation vocabulary so later beautification
/// stages (card entrance, tab transitions, micro-interactions) reach
/// for one set of constants instead of each screen picking its own
/// duration/curve. Not wired into anything yet — later stages opt in
/// widget-by-widget, same as [AppColors]' new gradients.
class AppAnimations {
  AppAnimations._();

  /// Micro-interactions: button press, chip select, toggle.
  static const Duration fast = Duration(milliseconds: 150);

  /// Card entrance, section reveal, tab content swap.
  static const Duration medium = Duration(milliseconds: 300);

  /// Page-level transitions.
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}
