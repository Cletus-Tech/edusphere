import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../core/routes/app_routes.dart';
import '../../models/exam_model.dart';
import '../../repositories/learning_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/feature_placeholder.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../exam_prep/exam_list_screen.dart';
import 'my_attempts_screen.dart';

/// Stage CBT-2 — the real `/cbt` destination, replacing the Stage 4.1
/// [FeaturePlaceholder] this class used to render directly.
///
/// This is a UI-and-wiring stage only. Every capability behind it —
/// exam retrieval ([ExamRepository]), session creation/resume/timing/
/// scoring ([ExamRunnerScreen] via [ExamListScreen]), and attempt
/// history ([ExamAttemptRepository]) — is the exact engine
/// WAEC/NECO/JAMB/University Post-UTME already run on, confirmed by the
/// CBT-1 audit (`docs/STAGE_CBT-1_FOUNDATION_AUDIT.md`) and unchanged
/// by this stage except for one additive, backward-compatible change:
/// [ExamRunnerScreen] and [ExamListScreen] gained an optional `mode`
/// parameter (default [ExamMode.practice], so every pre-existing call
/// site is unaffected) so Official/Mock actually start sessions in
/// [ExamMode.official]/[ExamMode.mock] instead of just relabeling
/// practice sessions.
///
/// Visibility of the Home dashboard card that links here is already
/// governed by `FeatureKeys.cbt` through the existing
/// `DashboardConfigService` — the same mechanism every other module
/// card uses. This screen doesn't re-check the flag itself, matching
/// how [WaecDashboardScreen]/[NecoDashboardScreen]/[JambDashboardScreen]
/// don't either; gating happens once, at the card level.
///
/// Sections map onto real, distinct [ExamType]s the enum already
/// defines (`cbt` = Official, `practiceTest` = Practice, `mockExam` =
/// Mock) rather than inventing new ones — an admin creates exams under
/// whichever type belongs in which section.
///
/// Stage CBT-REFACTOR Phase 2 — per the Phase 1 audit
/// (`docs/STAGE_CBT-REFACTOR_PHASE2B_UNIFIED_SELECTION_AUDIT.md`),
/// WAEC/NECO/JAMB/University all had their own direct entry points
/// straight into [ExamListScreen], invisible to this "unified" center
/// — so this wasn't actually unified. This stage adds WAEC/NECO/JAMB/
/// Institutional cards, making this screen a real hub for every board.
///
/// Per the audit's explicit rule ("do NOT blindly create duplicate
/// cards if the existing architecture already provides an equivalent
/// route"): each board card navigates to that board's own existing
/// dashboard (`WaecDashboardScreen`/`JambDashboardScreen`/
/// `NecoDashboardScreen`/`UniversityDashboardScreen`) via its existing
/// named route, rather than jumping straight to [ExamListScreen].
/// Two reasons this is the correct Phase 2 scope, not a shortcut:
/// (1) those dashboards already carry real board-specific context
/// (subject cards, performance, history) beyond a bare exam list, so
/// linking past them would be a regression, not a simplification; and
/// (2) the actual Year → Subject → Paper / JAMB-combination selection
/// flow the audit calls for doesn't exist yet — building it here would
/// mean inventing it ad hoc instead of as its own audited phase
/// (Phases 3–6 of the refactor doc). No new selection UI, no new
/// exam-query filtering, and no changes to [ExamListScreen] or the
/// scoring engine happen in this stage.
class CbtScreen extends StatelessWidget {
  const CbtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CBT Center'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppAvatar(photoUrl: user?.photoURL, name: user?.displayName, radius: 16),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your examination and practice hub',
                style: AppTextStyles.bodyMedium(
                  Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _FeatureCard(
                icon: Icons.verified_outlined,
                accent: AppColors.primaryBlue,
                title: 'Official Exams',
                description: 'Administrator-scheduled examinations with real scoring and results.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExamListScreen(
                      examTypeId: ExamType.cbt.id,
                      title: 'Official Exams',
                      mode: ExamMode.official,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.fitness_center_outlined,
                accent: AppColors.accentGreen,
                title: 'Practice',
                description: 'Test yourself anytime — untimed, unlimited, no pressure.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExamListScreen(
                      examTypeId: ExamType.practiceTest.id,
                      title: 'Practice Exams',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.timer_outlined,
                accent: AppColors.secondaryIndigo,
                title: 'Mock Exams',
                description: 'Timed, exam-condition simulations of the real thing.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExamListScreen(
                      examTypeId: ExamType.mockExam.id,
                      title: 'Mock Exams',
                      mode: ExamMode.mock,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Examination boards',
                style: AppTextStyles.titleMedium(
                  Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.school_outlined,
                accent: AppColors.accentGreen,
                title: 'WAEC',
                description: 'West African Senior School Certificate practice and mocks.',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.waec),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.edit_document,
                accent: AppColors.highlightOrange,
                title: 'NECO',
                description: 'National Examinations Council practice and mocks.',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.neco),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.assignment_outlined,
                accent: AppColors.secondaryIndigo,
                title: 'JAMB',
                description: 'UTME subject-combination practice and mocks.',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.jamb),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.account_balance_outlined,
                accent: AppColors.primaryBlue,
                title: 'Institutional / Post-UTME',
                description: 'Course-specific CBT set by your institution.',
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.university),
              ),
              const SizedBox(height: 20),
              Text(
                'More',
                style: AppTextStyles.titleMedium(
                  Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.document_scanner_outlined,
                accent: AppColors.highlightOrange,
                title: 'Scanning Mode',
                description: 'Scan and answer past questions on the fly.',
                statusLabel: 'Coming soon',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _ScanningModeScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.history_rounded,
                accent: AppColors.primaryBlue,
                title: 'My Attempts',
                description: 'Every exam you\'ve sat, across every mode and board.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyAttemptsScreen()),
                ),
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: 'Available Official Exams',
                actionLabel: 'View All',
                onActionTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExamListScreen(
                      examTypeId: ExamType.cbt.id,
                      title: 'Official Exams',
                      mode: ExamMode.official,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _OfficialExamsPreview(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final String? statusLabel;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.onTap,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
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
                Row(
                  children: [
                    Text(title, style: AppTextStyles.titleMedium(titleColor)),
                    if (statusLabel != null) ...[
                      const SizedBox(width: 8),
                      AppChip(label: statusLabel!, accent: AppColors.highlightOrange),
                    ],
                  ],
                ),
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

/// Small live preview of real, currently-listed official exams — pulled
/// straight from [ExamRepository.watchByType] (the same query
/// [ExamListScreen] uses), capped to 3 so the CBT Center home doesn't
/// turn into a second exam list. No per-user "attempts remaining"
/// count is computed here — that requires the live per-user query
/// [ExamListScreen] already performs correctly at start-time; showing
/// a second, potentially-stale copy of that number here would risk
/// being wrong. Tapping through to "View All" is where the real,
/// authoritative gating lives.
class _OfficialExamsPreview extends StatelessWidget {
  const _OfficialExamsPreview();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExamModel>>(
      stream: ExamRepository().watchByType(ExamType.cbt.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 100, child: LoadingView());
        }
        if (snapshot.hasError) return const ErrorView(message: 'Could not load official exams right now.');

        final exams = (snapshot.data ?? const <ExamModel>[]).take(3).toList();
        if (exams.isEmpty) {
          return const EmptyView(
            message: 'No official exams scheduled right now.',
            icon: Icons.verified_outlined,
          );
        }

        return Column(
          children: [
            for (final exam in exams) ...[
              _OfficialExamPreviewCard(exam: exam),
              if (exam != exams.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _OfficialExamPreviewCard extends StatelessWidget {
  final ExamModel exam;
  const _OfficialExamPreviewCard({required this.exam});

  /// Status label per the brief's access-state list — computed only
  /// from fields already on [ExamModel] (no per-user data), same
  /// inputs [ExamListScreen] already displays as badges.
  (String, Color) get _status {
    final now = DateTime.now();
    if (exam.availableFrom != null && now.isBefore(exam.availableFrom!)) {
      return ('Upcoming', AppColors.secondaryIndigo);
    }
    if (exam.availableUntil != null && now.isAfter(exam.availableUntil!)) {
      return ('Expired', AppColors.error);
    }
    if (!exam.isActive) return ('Unavailable', AppColors.textSecondary);
    return ('Available Now', AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final (statusText, statusColor) = _status;

    return CustomCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamListScreen(
            examTypeId: ExamType.cbt.id,
            title: 'Official Exams',
            mode: ExamMode.official,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exam.title,
                  style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              AppChip(label: statusText, accent: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (exam.totalQuestions > 0)
                _InlineStat(icon: Icons.list_alt_rounded, label: '${exam.totalQuestions} Questions'),
              _InlineStat(icon: Icons.timer_outlined, label: '${exam.durationMinutes} Minutes'),
              if (exam.isPremium)
                const _InlineStat(icon: Icons.workspace_premium_outlined, label: 'Premium'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InlineStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodySmall(color)),
      ],
    );
  }
}

/// Honest "not built yet" destination for Scanning Mode — reuses the
/// exact same [FeaturePlaceholder] every other unbuilt module in
/// EduSphere renders through (see [CbtScreen]'s own pre-CBT-2 history),
/// rather than inventing a fake scan UI. Kept as its own route/widget,
/// as the brief requires, so a future stage can implement it in place
/// without touching [CbtScreen].
class _ScanningModeScreen extends StatelessWidget {
  const _ScanningModeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanning Mode')),
      body: const FeaturePlaceholder(
        icon: Icons.document_scanner_outlined,
        title: 'Scanning Mode',
        description: 'Scan a past-question paper and get an instant, structured practice session from it.',
        accent: AppColors.highlightOrange,
        upcoming: ['Camera scan', 'Auto question detection', 'Instant practice session'],
      ),
    );
  }
}
