import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// The rounded, soft-shadow surface used for every card in the mockups
/// (course cards, category cards, "Continue Learning", stat cards...).
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardTheme.color,
      borderRadius: AppRadius.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.card,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            boxShadow: theme.brightness == Brightness.light
                ? AppShadows.soft
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
