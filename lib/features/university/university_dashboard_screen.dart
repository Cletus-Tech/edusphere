import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../models/course_model.dart';
import '../../models/institution_model.dart';
import '../../models/learning_material_model.dart';
import '../../models/user_model.dart';
import '../../repositories/course_repository.dart';
import '../../repositories/institution_repository.dart';
import '../../repositories/learning_material_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../learn/learning_materials/material_detail_screen.dart';
import '../learn/learning_materials/widgets/material_card.dart';
import '../profile/academic_profile_screen.dart';
import 'course_detail_screen.dart';
import 'institution_browse_screen.dart';
import 'institution_detail_screen.dart';

/// Stage 4.4 Part 2 — the University Dashboard: `Home → University`'s
/// real destination, replacing the old shortcut where the dashboard's
/// "University" tile just opened the Learn tab directly (see the
/// removed comment on `HomeScreen._tabForKey` — Stage 4.1 left that
/// note explaining it was a stand-in until this exact module existed).
///
/// Everything here is composed from repositories/screens that already
/// existed before this stage: [UserRepository] (for the signed-in
/// student's saved academic profile — Stage 4.3), [InstitutionRepository]
/// /[CourseRepository]/[LearningMaterialRepository] (Stage 1.2/3.5), and
/// [InstitutionBrowseScreen]/[CourseDetailScreen] (this stage, but
/// themselves built only from existing repositories — see their own
/// doc comments).
class UniversityDashboardScreen extends StatelessWidget {
  const UniversityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('University')),
      body: SafeArea(
        child: uid == null
            ? const ErrorView(message: 'Please sign in to continue.')
            : StreamBuilder<UserModel?>(
                stream: UserRepository().watchUser(uid),
                builder: (context, userSnapshot) {
                  final profile = userSnapshot.data;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppChip(
                          label: 'University',
                          icon: Icons.account_balance_rounded,
                          accent: AppColors.primaryBlue,
                          selected: true,
                        ),
                        const SizedBox(height: 16),
                        _QuickActionsRow(
                          onBrowse: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const InstitutionBrowseScreen()),
                          ),
                          onCbt: () => Navigator.of(context).pushNamed(AppRoutes.cbt),
                        ),
                        const SizedBox(height: 24),
                        if (profile?.institutionId != null && profile!.institutionId!.isNotEmpty) ...[
                          SectionHeader(
                            title: 'My University',
                            actionLabel: 'View',
                            onActionTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InstitutionDetailScreen(institutionId: profile.institutionId!),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MyInstitutionCard(institutionId: profile.institutionId!),
                          const SizedBox(height: 24),
                        ],
                        if (profile?.departmentId != null &&
                            profile?.levelId != null &&
                            profile!.departmentId!.isNotEmpty &&
                            profile.levelId!.isNotEmpty) ...[
                          const SectionHeader(title: 'My Courses'),
                          const SizedBox(height: 12),
                          _MyCoursesList(departmentId: profile.departmentId!, levelId: profile.levelId!),
                          const SizedBox(height: 24),
                        ],
                        if (profile == null || profile.institutionId == null || profile.institutionId!.isEmpty)
                          _SetupProfileCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AcademicProfileScreen()),
                            ),
                          ),
                        const SizedBox(height: 24),
                        SectionHeader(
                          title: 'Recent Materials',
                          actionLabel: 'See All',
                          onActionTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const _RecentMaterialsFullList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RecentMaterialsPreview(institutionId: profile?.institutionId),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onBrowse;
  final VoidCallback onCbt;

  const _QuickActionsRow({required this.onBrowse, required this.onCbt});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Row(
      children: [
        Expanded(
          child: CustomCard(
            onTap: onBrowse,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.search_rounded, color: AppColors.primaryBlue),
                const SizedBox(height: 8),
                const Text('Search Universities', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Browse & select your institution', style: TextStyle(fontSize: 12, color: bodyColor)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomCard(
            onTap: onCbt,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.quiz_rounded, color: AppColors.secondaryIndigo),
                const SizedBox(height: 8),
                const Text('CBT Practice', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Coming soon', style: TextStyle(fontSize: 12, color: bodyColor)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SetupProfileCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return CustomCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: AppColors.highlightOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Set up your academic profile', style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Pick your university to see your courses and materials here.',
                  style: AppTextStyles.bodySmall(bodyColor),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: bodyColor),
        ],
      ),
    );
  }
}

class _MyInstitutionCard extends StatelessWidget {
  final String institutionId;
  const _MyInstitutionCard({required this.institutionId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InstitutionModel?>(
      stream: InstitutionRepository().streamById(institutionId),
      builder: (context, snapshot) {
        final institution = snapshot.data;
        if (institution == null) return const SizedBox.shrink();
        final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
        final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
        return CustomCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => InstitutionDetailScreen(institutionId: institutionId)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  institution.name,
                  style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: bodyColor),
            ],
          ),
        );
      },
    );
  }
}

class _MyCoursesList extends StatelessWidget {
  final String departmentId;
  final String levelId;
  const _MyCoursesList({required this.departmentId, required this.levelId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CourseModel>>(
      stream: CourseRepository().watchByDepartmentAndLevel(departmentId: departmentId, levelId: levelId),
      builder: (context, snapshot) {
        final courses = snapshot.data ?? const <CourseModel>[];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 60, child: LoadingView());
        }
        if (courses.isEmpty) {
          return const EmptyView(message: 'No courses found for your level yet.', icon: Icons.menu_book_outlined);
        }
        final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
        final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
        return Column(
          children: courses
              .take(5)
              .map(
                (course) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CustomCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: AppTextStyles.bodyMedium(titleColor).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: bodyColor),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RecentMaterialsPreview extends StatelessWidget {
  final String? institutionId;
  const _RecentMaterialsPreview({this.institutionId});

  @override
  Widget build(BuildContext context) {
    final repository = LearningMaterialRepository();
    final stream = (institutionId != null && institutionId!.isNotEmpty)
        ? repository.watchMaterials(institutionId: institutionId, limit: 6)
        : repository.watchRecentlyAdded(limit: 6);
    return StreamBuilder<List<LearningMaterialModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 120, child: LoadingView());
        }
        final materials = snapshot.data ?? const <LearningMaterialModel>[];
        if (materials.isEmpty) {
          return const EmptyView(message: 'No materials to show yet.', icon: Icons.folder_open_rounded);
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
  }
}

/// "See All" destination for the Recent Materials preview row — a plain
/// grid over the same stream, rather than yet another bespoke list
/// screen.
class _RecentMaterialsFullList extends StatelessWidget {
  const _RecentMaterialsFullList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Materials')),
      body: SafeArea(
        child: StreamBuilder<List<LearningMaterialModel>>(
          stream: LearningMaterialRepository().watchRecentlyAdded(limit: 50),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            final materials = snapshot.data ?? const <LearningMaterialModel>[];
            if (materials.isEmpty) {
              return const EmptyView(message: 'No materials to show yet.', icon: Icons.folder_open_rounded);
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemCount: materials.length,
              itemBuilder: (context, index) => MaterialCard(
                material: materials[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: materials[index])),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
