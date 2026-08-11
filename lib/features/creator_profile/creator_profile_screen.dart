import 'package:flutter/material.dart';
import '../../core/utils/url_launcher_adapter.dart';
import '../../models/creator_profile_model.dart';
import '../../repositories/creator_profile_repository.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';

/// Stage 6.3 — the public "About the Owner" page. Read-only: every
/// field comes from [CreatorProfileRepository]/[CreatorSkillRepository]
/// /etc — nothing here is a hardcoded name, bio, skill, or link, per
/// the module's core requirement. Admin editing is a separate
/// management screen (Part 2), not this file.
class CreatorProfileScreen extends StatelessWidget {
  const CreatorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = CreatorProfileRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: StreamBuilder<CreatorProfileModel>(
        stream: repo.watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(message: 'Could not load this page: ${snapshot.error}');
          }
          if (!snapshot.hasData) return const LoadingView();
          final profile = snapshot.data!;
          // Admin hasn't published a profile yet — a genuinely empty
          // state, not placeholder copy standing in for real content.
          if (!profile.hasContent) {
            return const EmptyView(
              message: 'This page hasn\'t been set up yet.',
              icon: Icons.person_outline_rounded,
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _HeroSection(profile: profile),
              if (profile.biography.isNotEmpty || profile.mission.isNotEmpty || profile.vision.isNotEmpty)
                _BiographySection(profile: profile),
              _SkillsSection(),
              _AchievementsSection(),
              _ProjectsSection(),
              _DocumentsSection(),
              if (profile.email.isNotEmpty || profile.website.isNotEmpty || profile.socialLinks.isNotEmpty)
                _ContactSection(profile: profile),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineSmall?.color ?? AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(title, style: AppTextStyles.titleMedium(textColor)),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final CreatorProfileModel profile;
  const _HeroSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final headlineColor = Theme.of(context).textTheme.headlineSmall?.color ?? AppColors.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (profile.coverImageUrl.isNotEmpty)
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Image.network(profile.coverImageUrl, fit: BoxFit.cover),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, profile.coverImageUrl.isNotEmpty ? 0 : 24, 24, 0),
          child: Column(
            children: [
              Transform.translate(
                offset: Offset(0, profile.coverImageUrl.isNotEmpty ? -36 : 0),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                  backgroundImage:
                      profile.profileImageUrl.isNotEmpty ? NetworkImage(profile.profileImageUrl) : null,
                  child: profile.profileImageUrl.isEmpty
                      ? const Icon(Icons.person_rounded, size: 44, color: AppColors.primaryBlue)
                      : null,
                ),
              ),
              if (profile.name.isNotEmpty) Text(profile.name, style: AppTextStyles.headlineSmall(headlineColor)),
              if (profile.title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(profile.title, style: AppTextStyles.bodyMedium(AppColors.primaryBlue)),
              ],
              if (profile.introduction.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(profile.introduction, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium(bodyColor)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BiographySection extends StatelessWidget {
  final CreatorProfileModel profile;
  const _BiographySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Story'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.biography.isNotEmpty) Text(profile.biography, style: AppTextStyles.bodyMedium(bodyColor)),
                if (profile.mission.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Mission', style: AppTextStyles.bodyLarge(bodyColor).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(profile.mission, style: AppTextStyles.bodyMedium(bodyColor)),
                ],
                if (profile.vision.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Vision', style: AppTextStyles.bodyLarge(bodyColor).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(profile.vision, style: AppTextStyles.bodyMedium(bodyColor)),
                ],
                if (profile.journey.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Journey', style: AppTextStyles.bodyLarge(bodyColor).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(profile.journey, style: AppTextStyles.bodyMedium(bodyColor)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorSkillModel>>(
      stream: CreatorSkillRepository().watchAll(),
      builder: (context, snapshot) {
        // Stage 6.3 Part 2: `watchAll()` returns every skill (any publish
        // state) so the Admin manager can see drafts too — the public
        // page filters to published-only here rather than the repository
        // exposing a second, near-duplicate query for one boolean.
        final skills = (snapshot.data ?? const []).where((s) => s.isPublished).toList();
        if (skills.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('Skills'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((s) => AppChip(label: s.label, selected: true)).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorAchievementModel>>(
      stream: CreatorAchievementRepository().watchAll(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const []).where((a) => a.isPublished).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
        final titleColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('Achievements'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: items
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CustomCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.emoji_events_outlined, color: AppColors.highlightOrange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(a.title,
                                          style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600)),
                                      if (a.description.isNotEmpty)
                                        Text(a.description, style: AppTextStyles.bodySmall(bodyColor)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorProjectModel>>(
      stream: CreatorProjectRepository().watchAll(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const []).where((p) => p.isPublished).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
        final titleColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('Projects'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: items
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CustomCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (p.imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                                    child: Image.network(p.imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.title,
                                          style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600)),
                                      if (p.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(p.description, style: AppTextStyles.bodyMedium(bodyColor)),
                                      ],
                                      if (p.technologies.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: p.technologies
                                              .map((t) => AppChip(label: t, selected: false, accent: AppColors.secondaryIndigo))
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorDocumentModel>>(
      stream: CreatorDocumentRepository().watchAll(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? const []).where((d) => d.isPublished).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('Documents'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: items
                    .map((d) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                              child: const Icon(Icons.description_outlined, color: AppColors.primaryBlue),
                            ),
                            title: Text(d.title),
                            subtitle: d.description.isNotEmpty
                                ? Text(d.description, style: AppTextStyles.bodySmall(bodyColor))
                                : null,
                            trailing: const Icon(Icons.download_outlined),
                            onTap: d.downloadUrl.isEmpty
                                ? null
                                : () => UrlLauncherAdapter()
                                    .launch(Uri.parse(d.downloadUrl), preferNativeApp: false),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContactSection extends StatelessWidget {
  final CreatorProfileModel profile;
  const _ContactSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final launcher = UrlLauncherAdapter();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Contact'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (profile.email.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Email'),
                  onPressed: () => launcher.launch(Uri.parse('mailto:${profile.email}'), preferNativeApp: false),
                ),
              if (profile.website.isNotEmpty)
                ActionChip(
                  avatar: const Icon(Icons.language_rounded, size: 18),
                  label: const Text('Website'),
                  onPressed: () => launcher.launch(Uri.parse(profile.website), preferNativeApp: false),
                ),
              ...profile.socialLinks.entries.map(
                (e) => ActionChip(
                  avatar: const Icon(Icons.link_rounded, size: 18),
                  label: Text(e.key),
                  onPressed: () => launcher.launch(Uri.parse(e.value), preferNativeApp: false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
