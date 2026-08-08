import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The rounded, soft-shadow surface used for every card in the mockups
/// (course cards, category cards, "Continue Learning", stat cards...).
///
/// Stage B2 adds three opt-in params — [accentColor], [gradient],
/// [elevated] — so featured/premium/module-branded cards reuse this
/// same widget instead of screens hand-rolling their own Container +
/// BoxDecoration. Every existing `CustomCard(child: ..., ...)` call
/// site is unaffected: all three default to "off."
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// A 4px left-edge stripe in this color — for module/category
  /// identity (e.g. a JAMB card in violet, WAEC in teal) without
  /// needing a whole separate "branded card" widget. Ignored when
  /// [gradient] is set, since a flat stripe would fight a gradient
  /// background.
  final Color? accentColor;

  /// Background gradient (e.g. [AppColors.featuredGradient] or
  /// [AppColors.premiumGradient]) for hero/featured/premium cards.
  /// Replaces the theme's flat card color. Callers are responsible
  /// for using light-on-gradient text/icon colors in [child] — this
  /// widget doesn't force a text color since most existing children
  /// already set explicit `AppTextStyles` colors that would just
  /// override an inherited default anyway.
  final Gradient? gradient;

  /// Use [AppShadows.elevated] (a visibly stronger shadow) instead of
  /// the default [AppShadows.soft] — for cards that should read as
  /// "above" the rest of a list (featured/highlighted content).
  /// Light theme only, matching how the existing shadow already
  /// only applies in light mode.
  final bool elevated;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accentColor,
    this.gradient,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shadow = theme.brightness == Brightness.light
        ? (elevated ? AppShadows.elevated : AppShadows.soft)
        : null;

    return Material(
      color: gradient != null ? Colors.transparent : theme.cardTheme.color,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            gradient: gradient,
            boxShadow: shadow,
            border: (accentColor != null && gradient == null)
                ? Border(left: BorderSide(color: accentColor!, width: 4))
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
