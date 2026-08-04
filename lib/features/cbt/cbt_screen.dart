import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../shared/widgets/feature_placeholder.dart';

/// Stage 4.1: the Unified CBT Engine (the shared timed-exam runner meant
/// to sit behind JAMB/WAEC/NECO/University practice — see `ExamModel`
/// in `models/exam_model.dart`) has no UI yet. It already has a real
/// destination here — and a toggleable `FeatureKeys.cbt` flag an admin
/// can attach to a dashboard card via the Control Center — so a card
/// configured with key `cbt` resolves to this screen instead of falling
/// through to the "not available yet" snackbar.
class CbtScreen extends StatelessWidget {
  const CbtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBT Practice')),
      body: const FeaturePlaceholder(
        icon: Icons.laptop_chromebook_rounded,
        title: 'CBT Practice',
        description:
            'A computer-based-test runner shared by every exam module — timed sessions, instant scoring, and question review, matching the real JAMB/WAEC CBT experience.',
        accent: AppColors.primaryBlue,
        upcoming: ['Timed test sessions', 'Instant scoring', 'Answer review'],
      ),
    );
  }
}
