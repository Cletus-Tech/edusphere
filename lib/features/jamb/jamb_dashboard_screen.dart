import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../core/routes/app_routes.dart';
import '../../models/course_model.dart';
import '../../models/learning_material_model.dart';
import '../../repositories/course_repository.dart';
import '../../repositories/learning_material_repository.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../exam_prep/exam_list_screen.dart';
import '../exam_prep/performance_placeholder_screen.dart';
import '../exam_prep/study_plan_placeholder_screen.dart';
import '../exam_prep/subject_browse_screen.dart';
import '../learn/learning_materials/material_detail_screen.dart';
import '../learn/learning_materials/widgets/material_card.dart';
import '../university/course_detail_screen.dart';

/// Stage 4.7 Part 1 — replaces the Stage 4.1 `JambScreen` placeholder
/// as the real `Home → JAMB` destination, following the exact
/// [WaecDashboardScreen]/`NecoDashboardScreen` shape: every tile is
/// composed from infrastructure that already existed before this
/// stage (`LearningMaterialRepository`, `SubjectRepository`,
/// `ExamRepository`, and the generic `lib/features/exam_prep/`
/// screens) with only `categoryId: 'jamb'` / `ExamType.jamb` and copy
/// changed. Nothing content-related lives in this file.
///
/// Two tiles beyond WAEC/NECO's set, per the Stage 4.7 brief — both
/// reuse existing generic pieces rather than inventing new systems:
/// - **Study Plan** → new [StudyPlanPlaceholderScreen] (honest
///   placeholder — no scheduling system exists anywhere in the app;
///   same pattern as [PerformancePlaceholderScreen]).
/// - **Recommended Materials** → the new `CourseSection.recommended`
///   tag added to [CourseSection] this stage, same tag-based approach
///   `syllabus` already used — an admin tags a material `recommended`
///   in the existing Material Editor.
///
/// The Novel System, Unified CBT Engine, offline-first support, and
/// premium gating from the Stage 4.7 brief are **not** in this file —
/// each is its own stage-sized subsystem and is being built as a
/// separate part, per the audit in this stage's changelog.
class JambDashboardScreen extends StatelessWidget {
  const JambDashboardScreen({super.key});

  static const String _categoryId = 'jamb';
  static const String _categoryLabel = 'JAMB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JAMB')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UTME prep — subjects, syllabus, and practice in one place.',
                style: AppTextStyles.bodyMedium(
                  Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const AppChip(label: 'JAMB', icon: Icons.assignment_rounded, accent: AppColors.accentViolet, selected: true),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _DashboardTile(
                    icon: Icons.menu_book_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Subjects',
                    onTap: () => _openSubjects(context),
                  ),
                  _DashboardTile(
                    icon: Icons.rule_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Syllabus',
                    onTap: () => _openSubjects(context, section: CourseSection.syllabus),
                  ),
                  _DashboardTile(
                    icon: Icons.quiz_rounded,
                    accent: AppColors.accentViolet,
                    label: 'CBT',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.cbt),
                  ),
                  _DashboardTile(
                    icon: Icons.edit_note_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Practice',
                    onTap: () => _openSubjects(context, section: CourseSection.practiceQuestions),
                  ),
                  _DashboardTile(
                    icon: Icons.history_edu_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Past Questions',
                    onTap: () => _openSubjects(context, section: CourseSection.pastQuestions),
                  ),
                  _DashboardTile(
                    icon: Icons.assignment_turned_in_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Mock Exams',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExamListScreen(examTypeId: ExamType.jamb.id, title: 'JAMB Mock Exams'),
                      ),
                    ),
                  ),
                  _DashboardTile(
                    icon: Icons.insights_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Performance',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PerformancePlaceholderScreen(title: 'JAMB Performance'),
                      ),
                    ),
                  ),
                  _DashboardTile(
                    icon: Icons.event_note_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Study Plan',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const StudyPlanPlaceholderScreen(title: 'JAMB Study Plan'),
                      ),
                    ),
                  ),
                  _DashboardTile(
                    icon: Icons.star_rounded,
                    accent: AppColors.accentViolet,
                    label: 'Recommended',
                    onTap: () => _openSubjects(context, section: CourseSection.recommended),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Recent Activity'),
              const SizedBox(height: 12),
              const _RecentActivity(categoryId: _categoryId),
            ],
          ),
        ),
      ),
    );
  }

  void _openSubjects(BuildContext context, {CourseSection? section}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubjectBrowseScreen(
          categoryId: _categoryId,
          categoryLabel: _categoryLabel,
          initialSection: section,
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final VoidCallback onTap;

  const _DashboardTile({required this.icon, required this.accent, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    return CustomCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.bodyMedium(labelColor).copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Same [LearningMaterialRepository.watchMaterialsForCourses] feed
/// [WaecDashboardScreen]/`NecoDashboardScreen` use, scoped to
/// `categoryId: 'jamb'` subjects.
class _RecentActivity extends StatelessWidget {
  final String categoryId;
  const _RecentActivity({required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CourseModel>>(
      stream: SubjectRepository().watchByCategory(categoryId),
      builder: (context, subjectSnapshot) {
        if (subjectSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: LoadingView());
        }
        final subjects = subjectSnapshot.data ?? const <CourseModel>[];
        if (subjects.isEmpty) {
          return const EmptyView(
            message: 'No JAMB subjects yet — activity will show up here once subjects and materials are added.',
            icon: Icons.access_time_rounded,
          );
        }
        final subjectIds = subjects.map((s) => s.courseId).toList();
        return StreamBuilder<List<LearningMaterialModel>>(
          stream: LearningMaterialRepository().watchMaterialsForCourses(subjectIds, limit: 8),
          builder: (context, materialSnapshot) {
            if (materialSnapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 120, child: LoadingView());
            }
            final materials = materialSnapshot.data ?? const <LearningMaterialModel>[];
            if (materials.isEmpty) {
              return const EmptyView(message: 'No recent activity yet.', icon: Icons.access_time_rounded);
            }
            return SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: materials.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 150,
                  child: MaterialCard(
                    material: materials[index],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: materials[index])),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
