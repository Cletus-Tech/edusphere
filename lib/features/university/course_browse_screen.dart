import 'package:flutter/material.dart';
import '../../models/course_model.dart';
import '../../repositories/course_repository.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'course_detail_screen.dart';

/// Stage 4.4 — bottom of the drill-down chain (Institution → Faculty →
/// Department → Level → Semester → **Course**). Reuses
/// [CourseRepository.watchByDepartmentAndLevel] exactly as Stage 4.3
/// left it; semester isn't part of that query today (the repository
/// only filters by department + level), so within a given
/// department/level every semester's courses are shown together — a
/// pre-existing repository constraint, not something this stage
/// changes.
class CourseBrowseScreen extends StatelessWidget {
  final String departmentId;
  final String levelId;
  final String levelName;

  const CourseBrowseScreen({
    super.key,
    required this.departmentId,
    required this.levelId,
    required this.levelName,
  });

  @override
  Widget build(BuildContext context) {
    final repository = CourseRepository();
    return Scaffold(
      appBar: AppBar(title: Text('$levelName Courses')),
      body: SafeArea(
        child: StreamBuilder<List<CourseModel>>(
          stream: repository.watchByDepartmentAndLevel(departmentId: departmentId, levelId: levelId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            if (snapshot.hasError) return const ErrorView(message: 'Could not load courses right now.');
            final courses = snapshot.data ?? const [];
            if (courses.isEmpty) {
              return const EmptyView(
                message: 'No courses have been added for this level yet.',
                icon: Icons.menu_book_outlined,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final course = courses[index];
                return Material(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  style: AppTextStyles.bodyLarge(
                                    Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (course.code.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(course.code, style: AppTextStyles.bodySmall(AppColors.textSecondary)),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
