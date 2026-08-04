import 'package:flutter/material.dart';
import '../../shared/widgets/feature_placeholder.dart';
import '../../theme/app_colors.dart';

/// Stage 4.7 — no study-plan/scheduling system exists anywhere in
/// EduSphere yet, same gap [PerformancePlaceholderScreen] documents for
/// progress tracking. An honest placeholder rather than a fabricated
/// plan with no real data behind it. Generic (not JAMB-specific) so
/// WAEC/NECO/University can reuse it directly once they want a Study
/// Plan tile too.
class StudyPlanPlaceholderScreen extends StatelessWidget {
  final String title;
  const StudyPlanPlaceholderScreen({super.key, this.title = 'Study Plan'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const FeaturePlaceholder(
        icon: Icons.event_note_rounded,
        title: 'Study Plan',
        description:
            'A personalized daily/weekly study schedule built from your subjects, weak topics, and exam date — coming once Performance tracking is live.',
        accent: AppColors.primaryBlue,
        upcoming: ['Daily study goals', 'Subject-weighted scheduling', 'Countdown to exam date'],
      ),
    );
  }
}
