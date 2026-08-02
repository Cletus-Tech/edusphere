import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../shared/widgets/feature_placeholder.dart';

class AiTutorScreen extends StatelessWidget {
  const AiTutorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.smart_toy_rounded,
      title: 'AI Tutor',
      description:
          'Your personal AI study assistant — ask questions, get explanations, and work through practice problems in a live chat.',
      accent: AppColors.secondaryIndigo,
      upcoming: ['Ask a question', 'Explain a topic', 'Practice problems'],
    );
  }
}
