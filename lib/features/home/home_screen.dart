import 'package:flutter/material.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/section_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ??
        AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    final user = AuthService().currentUser;
    final firstName = (user?.displayName?.split(' ').first.isNotEmpty ?? false)
        ? user!.displayName!.split(' ').first
        : 'there';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Good morning,\n',
                          style: AppTextStyles.bodyLarge(bodyColor),
                        ),
                        TextSpan(
                          text: '$firstName 👋',
                          style: AppTextStyles.headlineLarge(textColor),
                        ),
                      ],
                    ),
                  ),
                ),
                AppBadge(
                  showDot: true,
                  child: IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                AppAvatar(name: user?.displayName, radius: 20),
              ],
            ),
            const SizedBox(height: 20),
            const SearchField(hintText: 'Search for courses, notes, videos...'),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.splashGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('The Future of Learning is Here!',
                            style: AppTextStyles.titleMedium(Colors.white)),
                        const SizedBox(height: 4),
                        Text('Learn anytime, anywhere.',
                            style: AppTextStyles.bodySmall(
                                Colors.white.withOpacity(0.85))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryBlue,
                            minimumSize: const Size(0, 40),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onPressed: () {},
                          child: const Text('Learn More'),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.school_rounded,
                      color: Colors.white, size: 56),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Explore', actionLabel: 'See All', onActionTap: () {}),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickAccess.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final item = _quickAccess[i];
                  return SizedBox(
                    width: 78,
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: item.$3.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(item.$2, color: item.$3),
                        ),
                        const SizedBox(height: 6),
                        Text(item.$1,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall(bodyColor)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Continue Learning', actionLabel: 'See All', onActionTap: () {}),
            const SizedBox(height: 12),
            CustomCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryIndigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.code_rounded,
                        color: AppColors.secondaryIndigo),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Data Structures and Algorithms',
                            style: AppTextStyles.titleMedium(textColor)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: 0.45,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.primaryBlue),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('45% Complete',
                            style: AppTextStyles.bodySmall(bodyColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<(String, IconData, Color)> _quickAccess = [
    ('University', Icons.account_balance_rounded, AppColors.primaryBlue),
    ('JAMB', Icons.assignment_rounded, AppColors.secondaryIndigo),
    ('WAEC', Icons.school_rounded, AppColors.accentGreen),
    ('NECO', Icons.edit_document, AppColors.highlightOrange),
    ('AI Tutor', Icons.smart_toy_rounded, AppColors.secondaryIndigo),
  ];
}
