import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../shared/widgets/feature_placeholder.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      icon: Icons.groups_rounded,
      title: 'Community',
      description:
          'Connect with students across schools — share posts, ask questions, and follow classmates working on the same courses.',
      accent: AppColors.secondaryIndigo,
      upcoming: ['For You', 'Following', 'My Schools'],
    );
  }
}
