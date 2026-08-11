import 'package:flutter/material.dart';
import '../../../models/creator_profile_model.dart';
import '../../../repositories/creator_profile_repository.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'creator_achievements_manager_screen.dart';
import 'creator_biography_editor_screen.dart';
import 'creator_contact_editor_screen.dart';
import 'creator_documents_manager_screen.dart';
import 'creator_profile_info_editor_screen.dart';
import 'creator_projects_manager_screen.dart';
import 'creator_skills_manager_screen.dart';

/// Stage 6.3 Part 2 — Creator Profile Admin CMS hub.
///
/// Entry point is `AdminDashboardScreen -> Creator Profile` (no second
/// admin dashboard, per the Master Project Rules). Everything below
/// this screen edits the exact same [CreatorProfileModel] and the four
/// list collections Part 1 built — nothing here is a new data source.
class CreatorProfileManagementScreen extends StatelessWidget {
  const CreatorProfileManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = CreatorProfileRepository();
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Creator Profile')),
      body: StreamBuilder<CreatorProfileModel>(
        stream: repo.watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: 'Could not load the profile: ${snapshot.error}');
          }
          if (!snapshot.hasData) return const LoadingView();
          final profile = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Text(
                'Manage the public "About the Owner" page. Nothing here is hardcoded — '
                'every field below is what visitors actually see.',
                style: AppTextStyles.bodyMedium(bodyColor),
              ),
              const SizedBox(height: 20),
              _SectionTile(
                icon: Icons.badge_outlined,
                accent: AppColors.primaryBlue,
                title: 'Profile Information',
                description: 'Name, title, introduction, profile picture, and cover image.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreatorProfileInfoEditorScreen(profile: profile)),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTile(
                icon: Icons.menu_book_outlined,
                accent: AppColors.accentGreen,
                title: 'Biography',
                description: 'About me, mission, vision, and journey.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreatorBiographyEditorScreen(profile: profile)),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTile(
                icon: Icons.psychology_outlined,
                accent: AppColors.secondaryIndigo,
                title: 'Skills',
                description: 'Add, edit, reorder, and enable/disable skills.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatorSkillsManagerScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTile(
                icon: Icons.emoji_events_outlined,
                accent: AppColors.highlightOrange,
                title: 'Achievements',
                description: 'Certifications, awards, and milestones.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatorAchievementsManagerScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTile(
                icon: Icons.work_outline_rounded,
                accent: AppColors.primaryBlue,
                title: 'Projects',
                description: 'Portfolio projects with images, tech, and links.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatorProjectsManagerScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTile(
                icon: Icons.folder_shared_outlined,
                accent: AppColors.accentGreen,
                title: 'Documents',
                description: 'CV, certificates, portfolio, and other files.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatorDocumentsManagerScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _SectionTile(
                icon: Icons.alternate_email_rounded,
                accent: AppColors.secondaryIndigo,
                title: 'Contact & Social Links',
                description: 'Email, website, and social links.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreatorContactEditorScreen(profile: profile)),
                ),
              ),
              const SizedBox(height: 24),
              _PublishingCard(repo: repo, profile: profile),
            ],
          );
        },
      ),
    );
  }
}

class _PublishingCard extends StatefulWidget {
  final CreatorProfileRepository repo;
  final CreatorProfileModel profile;
  const _PublishingCard({required this.repo, required this.profile});

  @override
  State<_PublishingCard> createState() => _PublishingCardState();
}

class _PublishingCardState extends State<_PublishingCard> {
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    final result = await widget.repo.setPublished(widget.profile, value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure) {
      AppSnackbar.error(context, 'Could not update publishing status.');
      return;
    }
    AppSnackbar.success(context, value ? 'Creator Profile is now live.' : 'Creator Profile is now hidden.');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineSmall?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return CustomCard(
      child: Row(
        children: [
          Icon(
            widget.profile.isPublished ? Icons.public_rounded : Icons.lock_outline_rounded,
            color: widget.profile.isPublished ? AppColors.success : bodyColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publishing', style: AppTextStyles.titleMedium(textColor)),
                const SizedBox(height: 2),
                Text(
                  widget.profile.isPublished
                      ? 'Live — visible on the public "About" page.'
                      : 'Hidden — the public page shows an empty state.',
                  style: AppTextStyles.bodySmall(bodyColor),
                ),
              ],
            ),
          ),
          _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Switch(value: widget.profile.isPublished, onChanged: _toggle),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SectionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return CustomCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium(textColor)),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.bodySmall(bodyColor)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: bodyColor),
        ],
      ),
    );
  }
}
