import 'package:flutter/material.dart';
import '../../shared/widgets/custom_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_settings/admin_app_settings_screen.dart';
import 'academic_structure/academic_structure_screen.dart';
import 'audit_log/audit_log_screen.dart';
import 'creator_profile/creator_profile_management_screen.dart';
import 'exam_prep/exam_manager_screen.dart';
import 'exam_prep/subject_manager_screen.dart';
import 'learning_materials/admin_learning_materials_screen.dart';
import 'moderation/moderation_screen.dart';
import 'users/admin_users_screen.dart';

/// Admin Dashboard entry point (Stage 3.5). Nothing in this app builds an
/// "Admin Dashboard" before this stage — the spec's "Create a new
/// Learning Materials section inside the Admin Dashboard" is read as: the
/// dashboard shell is new too, and it is built as a real extension point
/// (a grid of modules) rather than a single-purpose screen, so a later
/// stage can drop in new modules as another tile without touching this
/// one.
///
/// Stage 2 wires every tile to a real screen — Learning Materials, Audit
/// Log, Moderation & Reports, Users & Roles, and now App Settings.
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
            icon: Icons.account_tree_rounded,
            accent: AppColors.accentGreen,
            title: 'Academic Structure',
            description: 'Institutions, faculties, departments, levels, semesters, and courses.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AcademicStructureScreen()),
            ),
          ),
          const SizedBox(height: 12),
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
              MaterialPageRoute(builder: (_) => const ModerationScreen()),
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
              MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.quiz_rounded,
            accent: AppColors.primaryBlue,
            title: 'Exams',
            description: 'Configure exams and questions for the CBT Engine — JAMB, WAEC, NECO, '
                'university courses, and practice tests all share this.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamManagerScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.menu_book_rounded,
            accent: AppColors.accentGreen,
            title: 'WAEC Subjects',
            description: 'Add and manage subjects for the WAEC module. Study materials, '
                'syllabus, and past questions are managed from Learning Materials.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SubjectManagerScreen(categoryId: 'waec', categoryLabel: 'WAEC'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.edit_document,
            accent: AppColors.highlightOrange,
            title: 'NECO Subjects',
            description: 'Add and manage subjects for the NECO module. Study materials, '
                'syllabus, and past questions are managed from Learning Materials.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SubjectManagerScreen(categoryId: 'neco', categoryLabel: 'NECO'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.assignment_rounded,
            accent: AppColors.secondaryIndigo,
            title: 'JAMB Subjects',
            description: 'Add and manage subjects for the JAMB module. Study materials, '
                'syllabus, and past questions are managed from Learning Materials.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SubjectManagerScreen(categoryId: 'jamb', categoryLabel: 'JAMB'),
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
              MaterialPageRoute(builder: (_) => const AdminAppSettingsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _AdminModuleTile(
            icon: Icons.badge_rounded,
            accent: AppColors.primaryBlue,
            title: 'Creator Profile',
            description: 'Manage the public "About the Owner" page — bio, skills, achievements, '
                'projects, documents, and contact links.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatorProfileManagementScreen()),
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
