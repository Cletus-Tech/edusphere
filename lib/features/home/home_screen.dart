import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../models/app_settings_models.dart';
import '../../models/engagement_models.dart';
import '../../models/learning_material_model.dart';
import '../../repositories/engagement_repository.dart';
import '../../repositories/learning_material_repository.dart';
import '../../services/config/dashboard_config_service.dart';
import '../../services/firebase/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/section_header.dart';
import '../learn/learning_materials/material_detail_screen.dart';
import 'notifications_screen.dart';

/// Home tab. Stage 2 replaces every no-op button from the Stage 1 mockup
/// with a real destination: [DashboardConfigService] (already running
/// since `main.dart`) drives the hero banner and quick-access row,
/// [NotificationRepository] drives the bell's unread badge, and
/// [LearningMaterialRepository.watchRecentlyAdded] replaces the
/// hardcoded "Data Structures — 45%" card (no progress-tracking system
/// exists yet — see docs/ARCHITECTURE.md — so this shows real recent
/// content instead of fabricating a completion percentage).
///
/// [onNavigateToTab] lets quick actions / "See All" switch bottom-nav
/// tabs without pushing a second Navigator stack on top of [HomeShell]'s
/// `IndexedStack`.
class HomeScreen extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;

  const HomeScreen({super.key, required this.onNavigateToTab});

  static const int _tabHome = 0;
  static const int _tabLearn = 1;
  static const int _tabCommunity = 2;
  static const int _tabAiTutor = 3;
  static const int _tabProfile = 4;

  /// Dashboard-card / quick-access keys that already have a real
  /// destination in this app. Everything else (marketplace,
  /// scholarships, parents_portal, professional_exams, cbt) has no
  /// screen yet, so it's told to the user honestly instead of
  /// pretending to navigate.
  static const Map<String, int> _tabForKey = {
    'home': _tabHome,
    'learn': _tabLearn,
    'university': _tabLearn,
    'jamb': _tabLearn,
    'waec': _tabLearn,
    'neco': _tabLearn,
    'community': _tabCommunity,
    'ai_tutor': _tabAiTutor,
    'profile': _tabProfile,
  };

  static const List<(String, IconData, Color)> _fallbackQuickAccess = [
    ('university', Icons.account_balance_rounded, AppColors.primaryBlue),
    ('jamb', Icons.assignment_rounded, AppColors.secondaryIndigo),
    ('waec', Icons.school_rounded, AppColors.accentGreen),
    ('neco', Icons.edit_document, AppColors.highlightOrange),
    ('ai_tutor', Icons.smart_toy_rounded, AppColors.secondaryIndigo),
  ];

  static const Map<String, IconData> _iconByName = {
    'account_balance': Icons.account_balance_rounded,
    'assignment': Icons.assignment_rounded,
    'school': Icons.school_rounded,
    'edit_document': Icons.edit_document,
    'smart_toy': Icons.smart_toy_rounded,
    'groups': Icons.groups_rounded,
    'menu_book': Icons.menu_book_rounded,
  };

  void _openTile(BuildContext context, String key, {String? deepLink}) {
    if (deepLink != null && AppRoutes.routes.containsKey(deepLink)) {
      Navigator.of(context).pushNamed(deepLink);
      return;
    }
    final tab = _tabForKey[key];
    if (tab != null) {
      onNavigateToTab(tab);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text("This module isn't available yet."),
      ),
    );
  }

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
                _NotificationBell(uid: user?.uid),
                AppAvatar(name: user?.displayName, radius: 20),
              ],
            ),
            const SizedBox(height: 20),
            const SearchField(hintText: 'Search for courses, notes, videos...'),
            const SizedBox(height: 20),
            _HeroBanner(onLearnMore: () => _openTile(context, 'learn')),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Explore',
              actionLabel: 'See All',
              onActionTap: () => onNavigateToTab(_tabLearn),
            ),
            const SizedBox(height: 12),
            _QuickAccessRow(onTileTap: (key, deepLink) => _openTile(context, key, deepLink: deepLink)),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recently Added',
              actionLabel: 'See All',
              onActionTap: () => onNavigateToTab(_tabLearn),
            ),
            const SizedBox(height: 12),
            _RecentMaterials(
              onOpenMaterial: (material) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: material)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bell icon with a real unread-count badge instead of the Stage 1
/// always-on dot, backed by [NotificationRepository.watchByUser].
class _NotificationBell extends StatelessWidget {
  final String? uid;
  const _NotificationBell({required this.uid});

  @override
  Widget build(BuildContext context) {
    final id = uid;
    final button = IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: const Icon(Icons.notifications_none_rounded),
    );

    if (id == null) return button;

    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationRepository().watchByUser(id),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data?.any((n) => !n.isRead) ?? false;
        return AppBadge(showDot: hasUnread, child: button);
      },
    );
  }
}

/// Hero card. Shows the first active `banners/*` document
/// (`DashboardConfigService.instance.activeBanners`) when the admin has
/// published one; otherwise falls back to the original static copy so
/// the screen never looks broken/empty before any Firestore content
/// exists.
class _HeroBanner extends StatelessWidget {
  final VoidCallback onLearnMore;
  const _HeroBanner({required this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardConfigModel>(
      stream: DashboardConfigService.instance.watch(),
      builder: (context, snapshot) {
        final banners = DashboardConfigService.instance.activeBanners;
        final banner = banners.isNotEmpty ? banners.first : null;

        return Container(
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
                    Text(
                      banner?.title ?? 'The Future of Learning is Here!',
                      style: AppTextStyles.titleMedium(Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banner == null ? 'Learn anytime, anywhere.' : ' ',
                      style: AppTextStyles.bodySmall(Colors.white.withOpacity(0.85)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: onLearnMore,
                      child: const Text('Learn More'),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.school_rounded, color: Colors.white, size: 56),
            ],
          ),
        );
      },
    );
  }
}

/// Quick-access row. Reads `settings/dashboard`'s `cards` (kind ==
/// `quick_action`) via [DashboardConfigService.visibleCards] so an admin
/// can add/reorder/hide tiles remotely; falls back to the original five
/// static tiles — now with real taps — when no dashboard doc has been
/// published yet.
class _QuickAccessRow extends StatelessWidget {
  final void Function(String key, String? deepLink) onTileTap;
  const _QuickAccessRow({required this.onTileTap});

  static const _palette = [
    AppColors.primaryBlue,
    AppColors.secondaryIndigo,
    AppColors.accentGreen,
    AppColors.highlightOrange,
  ];

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return StreamBuilder<DashboardConfigModel>(
      stream: DashboardConfigService.instance.watch(),
      builder: (context, snapshot) {
        final configuredCards = DashboardConfigService.instance
            .visibleCards()
            .where((c) => c.kind == 'quick_action' || c.kind == 'feature')
            .toList();

        final useFallback = configuredCards.isEmpty;

        return SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: useFallback ? HomeScreen._fallbackQuickAccess.length : configuredCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final String key;
              final String title;
              final IconData icon;
              final Color color;
              final String? deepLink;

              if (useFallback) {
                final item = HomeScreen._fallbackQuickAccess[i];
                key = item.$1;
                title = switch (key) {
                  'university' => 'University',
                  'jamb' => 'JAMB',
                  'waec' => 'WAEC',
                  'neco' => 'NECO',
                  'ai_tutor' => 'AI Tutor',
                  _ => key,
                };
                icon = item.$2;
                color = item.$3;
                deepLink = null;
              } else {
                final card = configuredCards[i];
                key = card.key;
                title = card.title;
                icon = HomeScreen._iconByName[card.iconName] ?? Icons.widgets_rounded;
                color = _palette[i % _palette.length];
                deepLink = card.deepLink;
              }

              return GestureDetector(
                onTap: () => onTileTap(key, deepLink),
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(icon, color: color),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall(bodyColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Replaces the hardcoded "Data Structures and Algorithms — 45%" card
/// with real, live content: the most recently published learning
/// materials, via [LearningMaterialRepository.watchRecentlyAdded]. No
/// fake progress bar is shown since no progress-tracking system exists
/// yet (see docs/ARCHITECTURE.md's Phase 4 note).
class _RecentMaterials extends StatelessWidget {
  final ValueChanged<LearningMaterialModel> onOpenMaterial;
  const _RecentMaterials({required this.onOpenMaterial});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return StreamBuilder<List<LearningMaterialModel>>(
      stream: LearningMaterialRepository().watchRecentlyAdded(limit: 3),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.6)),
          );
        }
        final materials = snapshot.data!;
        if (materials.isEmpty) {
          return CustomCard(
            child: Text(
              'No learning materials have been published yet.',
              style: AppTextStyles.bodyMedium(bodyColor),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < materials.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              CustomCard(
                onTap: () => onOpenMaterial(materials[i]),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: materials[i].type.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(materials[i].type.icon, color: materials[i].type.color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            materials[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium(textColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            materials[i].type.label,
                            style: AppTextStyles.bodySmall(bodyColor),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: bodyColor),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
