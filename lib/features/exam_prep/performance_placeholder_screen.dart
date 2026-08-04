import 'package:flutter/material.dart';
import '../../shared/widgets/feature_placeholder.dart';
import '../../theme/app_colors.dart';

/// Stage 4.5 — no progress-tracking/scoring system exists anywhere in
/// EduSphere yet (see `docs/ARCHITECTURE.md`, and `HomeScreen`'s own
/// doc comment about the same gap). Rather than fabricating a
/// percentage or chart with no real data behind it, this is an honest
/// placeholder — same pattern [CbtScreen] established, and
/// `StudyPlanPlaceholderScreen` (Stage 4.7) follows for scheduling.
/// Generic (not WAEC-specific) so NECO/JAMB reuse it directly.
class PerformancePlaceholderScreen extends StatelessWidget {
  final String title;
  const PerformancePlaceholderScreen({super.key, this.title = 'Performance'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const FeaturePlaceholder(
        icon: Icons.insights_rounded,
        title: 'Performance Tracking',
        description: 'Score history, strengths by subject, and progress over time — coming once mock exams and CBT are live.',
        accent: AppColors.secondaryIndigo,
        upcoming: ['Score history', 'Subject breakdown', 'Weak-topic detection'],
      ),
    );
  }
}
