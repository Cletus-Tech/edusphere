import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../core/routes/app_routes.dart';
import '../../models/course_model.dart';
import '../../models/learning_material_model.dart';
import '../../repositories/course_repository.dart';
import '../../repositories/learning_material_repository.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../exam_prep/exam_list_screen.dart';
import '../exam_prep/performance_placeholder_screen.dart';
import '../exam_prep/subject_browse_screen.dart';
import '../learn/learning_materials/material_detail_screen.dart';
import '../learn/learning_materials/widgets/material_card.dart';

/// Stage 4.6 Part 2 — replaces the Stage 4.1 `NecoScreen` placeholder
/// as the real `Home → NECO` destination.
///
/// This is a deliberate near-duplicate of [WaecDashboardScreen], exactly
/// as that file's own doc comment anticipated: every tile here is
/// composed from the same shared, category-agnostic infrastructure
/// (`LearningMaterialRepository`, `SubjectRepository`, `ExamRepository`,
/// `QuestionRepository`, and the generic `lib/features/exam_prep/`
/// screens) with only `categoryId: 'neco'` / `ExamType.neco` and the
/// NECO-specific copy changed. Nothing content-related lives in this
/// file — subjects, notes, videos, practice/past questions, downloads,
/// and flashcards are all Learning Materials under the hood, so this
/// module needs no new Firestore collections, repositories, or admin
/// CRUD screens of its own (see [SubjectManagerScreen] and
/// [AdminLearningMaterialsScreen], both already category-driven).
///
/// Offline/premium/admin-controlled-visibility support: not
/// implemented at this layer by design. Those are properties of the
/// underlying `LearningMaterialModel`/`CourseModel` records and the
/// shared repositories that read them — this dashboard just displays
/// whatever those repositories return, so once offline caching,
/// premium gating, or admin-controlled visibility land in the shared
/// Learning Materials layer, every module (WAEC, NECO, JAMB, University)
/// gets them automatically with no changes needed here.
class NecoDashboardScreen extends StatelessWidget {
  const NecoDashboardScreen({super.key});

  static const String _categoryId = 'neco';
  static const String _categoryLabel = 'NECO';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NECO')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SSCE prep — subjects, notes, and practice in one place.',
                style: AppTextStyles.bodyMedium(AppColors.textSecondary),
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
                        builder: (_) => ExamListScreen(examTypeId: ExamType.neco.id, title: 'NECO Mock Exams'),
                      ),
                    ),
                  ),
                  _DashboardTile(
                    icon: Icons.quiz_rounded,
                    accent: AppColors.secondaryIndigo,
                    label: 'CBT',
                    // Stage 4.6 Part 4 — CBT engine itself isn't built yet
                    // (WAEC's tile has the same forward reference); this
                    // just proves the module already knows how to launch
                    // it via the shared route the moment it exists.
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.cbt),
                  ),
                  _DashboardTile(
                    icon: Icons.history_edu_rounded,
                    accent: AppColors.primaryBlue,
                    label: 'Past Questions',
                    onTap: () => _openSubjects(context, section: CourseSection.pastQuestions),
                  ),
                  _DashboardTile(
                    icon: Icons.style_rounded,
                    accent: AppColors.secondaryIndigo,
                    label: 'Flashcards',
                    onTap: () => _openSubjects(context, section: CourseSection.flashcards),
                  ),
                  _DashboardTile(
                    icon: Icons.insights_rounded,
                    accent: AppColors.highlightOrange,
                    label: 'Performance',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PerformancePlaceholderScreen(title: 'NECO Performance'),
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
                    icon: Icons.download_rounded,
                    accent: AppColors.primaryBlue,
                    label: 'Downloads',
                    onTap: () => _openSubjects(context, section: CourseSection.downloads),
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
          Text(label, style: AppTextStyles.bodyMedium(AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Same pattern as [WaecDashboardScreen]'s `_RecentActivity`: fetches
/// the NECO subject list once, then reuses
/// [LearningMaterialRepository.watchMaterialsForCourses] to show recent
/// materials across every NECO subject as a module-scoped feed.
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
            message: 'No NECO subjects yet — activity will show up here once subjects and materials are added.',
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
