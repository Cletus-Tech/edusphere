import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../models/course_model.dart';
import '../../models/learning_material_model.dart';
import '../../repositories/course_repository.dart';
import '../../repositories/learning_material_repository.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../exam_prep/board_exam_selection_screen.dart';
import '../exam_prep/exam_history_screen.dart';
import '../exam_prep/performance_analytics_screen.dart';
import '../exam_prep/subject_browse_screen.dart';
import '../learn/learning_materials/material_detail_screen.dart';
import '../learn/learning_materials/widgets/material_card.dart';
import '../university/course_detail_screen.dart';

/// Stage 4.5 Part 2 — replaces the Stage 4.1 `WaecScreen` placeholder
/// as the real `Home → WAEC` destination. Every tile below is composed
/// from screens/repositories that already existed (Stage 3.5's
/// [LearningMaterialRepository], Stage 1.2's [SubjectRepository]/
/// [ExamRepository]/[QuestionRepository], and this stage's generic
/// `lib/features/exam_prep/` screens) — nothing content-related is
/// WAEC-specific at the data layer, only at the parameters passed in
/// here, so Stage 4.6 (NECO) can copy this one file's shape with
/// `categoryId: 'neco'` / `ExamType.neco` instead of rebuilding.
class WaecDashboardScreen extends StatelessWidget {
  const WaecDashboardScreen({super.key});

  static const String _categoryId = 'waec';
  static const String _categoryLabel = 'WAEC';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WAEC')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WASSCE prep — subjects, notes, and practice in one place.',
                style: AppTextStyles.bodyMedium(
                  Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
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
                    accent: AppColors.accentGreen,
                    label: 'Subjects',
                    onTap: () => _openSubjects(context),
                  ),
                  _DashboardTile(
                    icon: Icons.description_rounded,
                    accent: AppColors.primaryBlue,
                    label: 'Study Notes',
                    onTap: () => _openSubjects(context, section: CourseSection.notes),
                  ),
                  _DashboardTile(
                    icon: Icons.play_circle_rounded,
                    accent: AppColors.secondaryIndigo,
                    label: 'Video Lessons',
                    onTap: () => _openSubjects(context, section: CourseSection.videos),
                  ),
                  _DashboardTile(
                    icon: Icons.edit_note_rounded,
                    accent: AppColors.highlightOrange,
                    label: 'Practice Questions',
                    onTap: () => _openSubjects(context, section: CourseSection.practiceQuestions),
                  ),
                  _DashboardTile(
                    icon: Icons.assignment_turned_in_rounded,
                    accent: AppColors.accentGreen,
                    label: 'Mock Exams',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BoardExamSelectionScreen(
                          examType: ExamType.waec,
                          title: 'WAEC',
                          accent: AppColors.accentGreen,
                          mode: ExamMode.mock,
                        ),
                      ),
                    ),
                  ),
                  _DashboardTile(
                    icon: Icons.quiz_rounded,
                    accent: AppColors.secondaryIndigo,
                    label: 'CBT',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BoardExamSelectionScreen(
                          examType: ExamType.waec,
                          title: 'WAEC',
                          accent: AppColors.accentGreen,
                          mode: ExamMode.official,
                        ),
                      ),
                    ),
                  ),
                  _DashboardTile(
                    icon: Icons.history_edu_rounded,
                    accent: AppColors.primaryBlue,
                    label: 'Past Questions',
                    onTap: () => _openSubjects(context, section: CourseSection.pastQuestions),
                  ),
                  _DashboardTile(
                    icon: Icons.insights_rounded,
                    accent: AppColors.highlightOrange,
                    label: 'Performance',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PerformanceAnalyticsScreen(examTypeId: ExamType.waec.id, title: 'WAEC Performance'),
                      ),
                    ),
                  ),
                  _DashboardTile(
                    icon: Icons.rule_rounded,
                    accent: AppColors.accentGreen,
                    label: 'Syllabus',
                    onTap: () => _openSubjects(context, section: CourseSection.syllabus),
                  ),
                  _DashboardTile(
                    icon: Icons.history_rounded,
                    accent: AppColors.primaryBlue,
                    label: 'History',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExamHistoryScreen(examTypeId: ExamType.waec.id, title: 'WAEC History'),
                      ),
                    ),
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

/// Fetches the WAEC subject list once, then reuses
/// [LearningMaterialRepository.watchMaterialsForCourses] (new this
/// stage) to show recent materials across every WAEC subject — a
/// module-scoped feed rather than the global "recently added" list.
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
            message: 'No WAEC subjects yet — activity will show up here once subjects and materials are added.',
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
