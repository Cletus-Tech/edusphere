import 'package:flutter/material.dart';
import '../../../core/enums/content_type.dart';
import '../../../models/exam_model.dart';
import '../../../models/exam_session_model.dart';
import '../../../repositories/learning_repository.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../exam_prep/exam_manager_screen.dart';
import '../exam_prep/question_data_repair_screen.dart';
import 'cbt_attempt_management_screen.dart';
import 'cbt_settings_screen.dart';

/// Stage CBT-3 — "CBT Management" entry point inside the Admin
/// Dashboard. The landing view doubles as the brief's "CBT Dashboard"
/// (stats up top, computed from real [ExamRepository]/
/// [ExamAttemptRepository] data — never invented) and the section list
/// (below it) into the rest of CBT administration.
///
/// This is a control surface over the existing CBT engine — it creates
/// no exam/question/attempt model, repository, or scoring logic of its
/// own. "Official Exams"/"Practice Exams"/"Mock Exams" all open the
/// same, already-existing [ExamManagerScreen] pre-filtered by
/// [ExamType] (see that screen's `initialTypeFilter`) rather than three
/// new list screens. "Questions" opens the same [ExamManagerScreen]
/// unfiltered, because there is no cross-exam question bank in this
/// codebase — [QuestionManagerScreen]/[BulkQuestionUploadScreen] both
/// require a specific [ExamModel] (confirmed by reading their
/// constructors), so "pick an exam, then manage its questions" via its
/// existing popup menu *is* the real entry point, not a placeholder.
///
/// The brief's "Access Rules" and "CBT Settings" sections are
/// deliberately one tile/screen ([CbtSettingsScreen]) rather than two —
/// both edit the exact same platform-wide `settings/cbt` document, so
/// splitting them would mean two UIs racing to save the same doc.
/// Likewise, a separate "CBT Analytics" tile was not built: everything
/// honestly derivable from existing data is already the dashboard
/// stats below; anything beyond that (trends over time, per-subject
/// breakdowns) isn't obtainable from the current architecture without
/// inventing data, which the brief explicitly disallows.
class CbtControlCenterScreen extends StatelessWidget {
  const CbtControlCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CBT Management')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const _CbtDashboardStats(),
          const SizedBox(height: 24),
          _SectionTile(
            icon: Icons.verified_outlined,
            accent: AppColors.primaryBlue,
            title: 'Official Exams',
            description: 'Create, edit, publish, and schedule official examinations.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamManagerScreen(initialTypeFilter: ExamType.cbt)),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTile(
            icon: Icons.fitness_center_outlined,
            accent: AppColors.accentGreen,
            title: 'Practice Exams',
            description: 'Manage self-testing exams.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamManagerScreen(initialTypeFilter: ExamType.practiceTest)),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTile(
            icon: Icons.timer_outlined,
            accent: AppColors.secondaryIndigo,
            title: 'Mock Exams',
            description: 'Manage timed, exam-condition simulations.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamManagerScreen(initialTypeFilter: ExamType.mockExam)),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTile(
            icon: Icons.quiz_outlined,
            accent: AppColors.highlightOrange,
            title: 'Questions',
            description: 'Select an exam to manage, import, or edit its questions.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExamManagerScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTile(
            icon: Icons.fact_check_outlined,
            accent: AppColors.primaryBlue,
            title: 'Attempt Management',
            description: 'Review and, if genuinely necessary, remove a recorded attempt.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CbtAttemptManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTile(
            icon: Icons.tune_rounded,
            accent: AppColors.secondaryIndigo,
            title: 'CBT Settings',
            description: 'Platform-wide access rules and Practice/Mock availability defaults.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CbtSettingsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SectionTile(
            icon: Icons.build_circle_outlined,
            accent: AppColors.error,
            title: 'Question Data Repair',
            description: 'One-time migration for questions imported before the CBT-REFACTOR '
                'Phase 1 scoring fix — scans, previews, and repairs on confirmation.',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuestionDataRepairScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Real statistics only. Exam counts come from an unfiltered read of
/// [ExamRepository] (small collection — every count here is exact, the
/// same data [ExamManagerScreen] already loads for its own list).
/// Attempts intentionally do NOT claim to be a platform-wide total —
/// no count/aggregation capability exists anywhere in this codebase
/// (confirmed by inspection), and fetching the entire, potentially
/// large `exam_attempts` collection just to count it would be its own
/// new performance liability. It's labeled as bounded instead of
/// silently presented as complete.
class _CbtDashboardStats extends StatelessWidget {
  const _CbtDashboardStats();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExamModel>>(
      stream: ExamRepository().streamCollection(),
      builder: (context, examSnapshot) {
        if (examSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: LoadingView());
        }
        if (examSnapshot.hasError) return const ErrorView(message: 'Could not load CBT statistics.');

        final exams = examSnapshot.data ?? const <ExamModel>[];
        final now = DateTime.now();
        final active = exams.where((e) => e.isActive).length;
        final inactive = exams.length - active;
        final upcoming = exams.where((e) => e.isActive && e.availableFrom != null && now.isBefore(e.availableFrom!)).length;
        final expired = exams.where((e) => e.isActive && e.availableUntil != null && now.isAfter(e.availableUntil!)).length;
        final official = exams.where((e) => e.type == ExamType.cbt).length;
        final practice = exams.where((e) => e.type == ExamType.practiceTest).length;
        final mock = exams.where((e) => e.type == ExamType.mockExam).length;
        final premium = exams.where((e) => e.isPremium).length;

        return StreamBuilder<List<ExamAttemptModel>>(
          stream: ExamAttemptRepository().watchRecentForAdmin(),
          builder: (context, attemptSnapshot) {
            final attemptCount = attemptSnapshot.data?.length;
            final attemptCapped = attemptCount != null && attemptCount >= 100;

            return CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CBT Dashboard', style: AppTextStyles.titleMedium(AppColors.textPrimary)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 20,
                    runSpacing: 14,
                    children: [
                      _Stat(label: 'Total Exams', value: '${exams.length}'),
                      _Stat(label: 'Official', value: '$official'),
                      _Stat(label: 'Practice', value: '$practice'),
                      _Stat(label: 'Mock', value: '$mock'),
                      _Stat(label: 'Active', value: '$active', color: AppColors.success),
                      _Stat(label: 'Disabled', value: '$inactive', color: AppColors.textSecondary),
                      _Stat(label: 'Upcoming', value: '$upcoming', color: AppColors.secondaryIndigo),
                      _Stat(label: 'Expired', value: '$expired', color: AppColors.error),
                      _Stat(label: 'Premium', value: '$premium', color: AppColors.highlightOrange),
                      _Stat(
                        label: attemptCapped ? 'Attempts (100+)' : 'Attempts',
                        value: attemptCount == null ? '—' : '$attemptCount',
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.titleMedium(color ?? AppColors.textPrimary).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall(bodyColor)),
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
