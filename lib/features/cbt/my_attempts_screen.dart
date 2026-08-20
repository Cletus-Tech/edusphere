import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../repositories/learning_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../exam_prep/exam_attempt_resolver.dart';
import '../exam_prep/exam_result_screen.dart';

/// Stage CBT-2's "My Attempts" — every exam this student has submitted,
/// across every board and mode, in one list. Reuses exactly what
/// [ExamHistoryScreen] already reuses: [ExamAttemptRepository.
/// watchHistoryForUser] for the data and [ExamAttemptResolver] for the
/// examId -> [ExamModel] join (via its new [ExamAttemptResolver.
/// matchAll], the unfiltered counterpart to the `matchType` that
/// screen uses for one board at a time). No new attempt-history data
/// source was created.
class MyAttemptsScreen extends StatefulWidget {
  const MyAttemptsScreen({super.key});

  @override
  State<MyAttemptsScreen> createState() => _MyAttemptsScreenState();
}

class _MyAttemptsScreenState extends State<MyAttemptsScreen> {
  final ExamAttemptResolver _resolver = ExamAttemptResolver();

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Attempts')),
        body: const SafeArea(
          child: EmptyView(message: 'Sign in to see your exam attempts.', icon: Icons.history_rounded),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Attempts')),
      body: SafeArea(
        child: StreamBuilder<List<ExamAttemptModel>>(
          stream: ExamAttemptRepository().watchHistoryForUser(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            if (snapshot.hasError) return const ErrorView(message: 'Could not load your attempts right now.');

            final allAttempts = snapshot.data ?? const <ExamAttemptModel>[];
            if (allAttempts.isEmpty) {
              return const EmptyView(
                message: 'No exams attempted yet. Every exam you sit — official, practice, or mock — shows up here.',
                icon: Icons.history_rounded,
              );
            }

            _resolver.ensureCached(allAttempts, () {
              if (mounted) setState(() {});
            });
            final matched = _resolver.matchAll(allAttempts);

            if (matched.isEmpty && _resolver.isResolving(allAttempts)) return const LoadingView();
            if (matched.isEmpty) {
              return const EmptyView(message: 'No exams attempted yet.', icon: Icons.history_rounded);
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: matched.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final (attempt, exam) = matched[index];
                return _AttemptTile(attempt: attempt, exam: exam);
              },
            );
          },
        ),
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  final ExamAttemptModel attempt;
  final ExamModel exam;

  const _AttemptTile({required this.attempt, required this.exam});

  Color get _modeAccent => switch (attempt.mode) {
        ExamMode.official => AppColors.primaryBlue,
        ExamMode.mock => AppColors.secondaryIndigo,
        ExamMode.practice => AppColors.accentGreen,
      };

  String get _modeLabel => switch (attempt.mode) {
        ExamMode.official => 'Official',
        ExamMode.mock => 'Mock',
        ExamMode.practice => 'Practice',
      };

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final scoreColor = attempt.passed ? AppColors.success : AppColors.error;

    return CustomCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ExamResultScreen(exam: exam, attempt: attempt)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exam.title,
                        style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppChip(label: _modeLabel, accent: _modeAccent),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _InlineStat(icon: Icons.event_outlined, label: _formatDate(attempt.submittedAt)),
                    _InlineStat(icon: Icons.timer_outlined, label: _formatDuration(attempt.timeTakenSeconds)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${attempt.scorePercent.toStringAsFixed(0)}%',
                style: AppTextStyles.titleMedium(scoreColor).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(attempt.passed ? 'Passed' : 'Failed', style: AppTextStyles.bodySmall(scoreColor)),
            ],
          ),
          Icon(Icons.chevron_right_rounded, color: bodyColor),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
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
