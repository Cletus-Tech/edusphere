import 'package:flutter/material.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/feature_placeholder.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'audit_log/audit_log_screen.dart';
import 'learning_materials/admin_learning_materials_screen.dart';

/// Admin Dashboard entry point (Stage 3.5). Nothing in this app builds an
/// "Admin Dashboard" before this stage — the spec's "Create a new
/// Learning Materials section inside the Admin Dashboard" is read as: the
/// dashboard shell is new too, and it is built as a real extension point
/// (a grid of modules) rather than a single-purpose screen, so a later
/// stage can drop in "Users & Roles" or "Reports" as another tile without
/// touching this one.
///
/// Only [_AdminModuleTile] for Learning Materials is fully wired in this
/// stage; the others navigate to [FeaturePlaceholder] (the same "coming
/// soon" pattern Stage 1 already uses for not-yet-built tabs) so the
/// dashboard reads as a genuine hub, not a dead end, without overbuilding
/// modules the spec didn't ask for.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Manage EduSphere content and moderation from one place.',
              style: AppTextStyles.bodyMedium(bodyColor)),
          const SizedBox(height: 20),
          _AdminModuleTile(
            icon: Icons.folder_copy_rounded,
            accent: AppColors.primaryBlue,
            title: 'Learning Materials',
            description: 'Create, publish, and organize course content.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminLearningMaterialsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.receipt_long_rounded,
            accent: AppColors.secondaryIndigo,
            title: 'Audit Log',
            description: 'See who did what, and when, across the admin tools.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuditLogScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.flag_rounded,
            accent: AppColors.highlightOrange,
            title: 'Moderation & Reports',
            description: 'Review flagged community posts and comments.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Moderation & Reports')),
                  body: const FeaturePlaceholder(
                    icon: Icons.flag_rounded,
                    title: 'Moderation & Reports',
                    description: 'A dedicated moderation queue is coming to the Admin Dashboard soon.',
                    accent: AppColors.highlightOrange,
                    upcoming: ['Report queue', 'Bulk actions', 'Audit log'],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.manage_accounts_rounded,
            accent: AppColors.secondaryIndigo,
            title: 'Users & Roles',
            description: 'Manage accounts, roles, and institution access.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Users & Roles')),
                  body: const FeaturePlaceholder(
                    icon: Icons.manage_accounts_rounded,
                    title: 'Users & Roles',
                    description: 'User and role management is coming to the Admin Dashboard soon.',
                    accent: AppColors.secondaryIndigo,
                    upcoming: ['Role assignment', 'Institution access', 'Account suspension'],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.settings_suggest_rounded,
            accent: AppColors.accentGreen,
            title: 'App Settings',
            description: 'Feature flags, banners, and upload limits.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('App Settings')),
                  body: const FeaturePlaceholder(
                    icon: Icons.settings_suggest_rounded,
                    title: 'App Settings',
                    description: 'A dedicated settings screen is coming to the Admin Dashboard soon.',
                    accent: AppColors.accentGreen,
                    upcoming: ['Feature flags', 'Banners', 'Upload limits'],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminModuleTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AdminModuleTile({
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
