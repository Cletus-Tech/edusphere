import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'app_chip.dart';

/// Stage B2 — Section 27's "consistent visual language for premium
/// content." Deliberately a thin wrapper around [AppChip] rather than
/// a new styled widget from scratch: it exists so every screen that
/// shows a premium indicator (exam cards, learning materials, course
/// content) uses the exact same icon/color instead of each screen
/// picking its own crown icon and gold shade.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppChip(
      label: 'Premium',
      icon: Icons.workspace_premium_rounded,
      accent: AppColors.premiumGold,
      selected: true,
    );
  }
}
