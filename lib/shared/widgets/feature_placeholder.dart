import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_chip.dart';

/// Consistent "coming soon" placeholder for feature tabs that only have
/// navigation wired up in Stage 1. Keeps every tab on-brand instead of
/// falling back to default Flutter styling.
class FeaturePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final List<String> upcoming;

  const FeaturePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    this.upcoming = const [],
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ??
        AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: accent),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTextStyles.headlineLarge(textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTextStyles.bodyMedium(bodyColor),
              textAlign: TextAlign.center,
            ),
            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: upcoming
                    .map((label) => AppChip(label: label, accent: accent))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Coming soon',
                style: AppTextStyles.caption(bodyColor.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
