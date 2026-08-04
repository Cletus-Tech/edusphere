import 'package:flutter/material.dart';
import '../../models/institution_model.dart';
import '../../repositories/institution_repository.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'course_browse_screen.dart';
import 'widgets/academic_node_browser_screen.dart';

/// Stage 4.4 Part 3/4 — an institution's landing page, and the start of
/// the drill-down chain: Institution → Faculty → Department → Level →
/// Semester → Course. Every step reuses the existing
/// [FacultyRepository]/[DepartmentRepository]/[LevelRepository]/
/// [SemesterRepository]/[CourseRepository] methods Stage 4.3 already
/// built (`watchByInstitution`, `watchByFaculty`, `watchByDepartment`,
/// `watchByLevel`, `watchByDepartmentAndLevel`) — no new queries.
class InstitutionDetailScreen extends StatelessWidget {
  final String institutionId;
  const InstitutionDetailScreen({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context) {
    final institutionRepository = InstitutionRepository();
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<InstitutionModel?>(
          stream: institutionRepository.streamById(institutionId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            final institution = snapshot.data;
            if (institution == null) {
              return const ErrorView(message: 'This university could not be found.');
            }
            return CustomScrollView(
              slivers: [
                SliverAppBar(title: Text(institution.name), pinned: true),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          institution.name,
                          style: AppTextStyles.headlineLarge(
                            Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary,
                          ),
                        ),
                        if (institution.state != null && institution.state!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${institution.state}, ${institution.country ?? "Nigeria"}',
                              style: AppTextStyles.bodyMedium(AppColors.textSecondary),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Material(
                          color: AppColors.primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openFaculties(context, institution),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Icon(Icons.account_tree_rounded, color: AppColors.primaryBlue),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Browse Faculties & Courses',
                                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openFaculties(BuildContext context, InstitutionModel institution) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AcademicNodeBrowserScreen(
          title: 'Faculties',
          nodesStream: FacultyRepository().watchByInstitution(institution.institutionId),
          emptyMessage: 'No faculties have been added for ${institution.name} yet.',
          onNodeTap: (context, faculty) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AcademicNodeBrowserScreen(
                title: faculty.name,
                nodesStream: DepartmentRepository().watchByFaculty(faculty.nodeId),
                emptyMessage: 'No departments have been added for ${faculty.name} yet.',
                onNodeTap: (context, department) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AcademicNodeBrowserScreen(
                      title: department.name,
                      nodesStream: LevelRepository().watchByDepartment(department.nodeId),
                      emptyMessage: 'No levels have been added for ${department.name} yet.',
                      onNodeTap: (context, level) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AcademicNodeBrowserScreen(
                            title: '${level.name} — Semesters',
                            nodesStream: SemesterRepository().watchByLevel(level.nodeId),
                            emptyMessage: 'No semesters have been added for ${level.name} yet.',
                            onNodeTap: (context, semester) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CourseBrowseScreen(
                                  departmentId: department.nodeId,
                                  levelId: level.nodeId,
                                  levelName: '${department.name} · ${level.name}',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
