import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../repositories/learning_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'exam_attempt_resolver.dart';
import 'exam_result_screen.dart';

/// Spec section 17 ("Student Exam History") — the last un-started item
/// flagged in the Stage 4.8B Part 3 audit. [ExamAttemptRepository.
/// watchHistoryForUser] already existed (Stage 4.8A) and was already
/// correct; nothing called it yet. This screen is that missing caller.
///
/// The examId → exam join (needed to filter by board) is handled by
/// the shared [ExamAttemptResolver] — see that file's doc comment.
/// Generic like [ExamListScreen]/[SubjectBrowseScreen]: any board reuses
/// this with a different [examTypeId] instead of a copy.
class ExamHistoryScreen extends StatefulWidget {
  final String examTypeId;
  final String title;

  const ExamHistoryScreen({super.key, required this.examTypeId, required this.title});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  final ExamAttemptResolver _resolver = ExamAttemptResolver();

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const SafeArea(
          child: EmptyView(message: 'Sign in to see your exam history.', icon: Icons.history_rounded),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: StreamBuilder<List<ExamAttemptModel>>(
          stream: ExamAttemptRepository().watchHistoryForUser(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            if (snapshot.hasError) return const ErrorView(message: 'Could not load your exam history right now.');

            final allAttempts = snapshot.data ?? const <ExamAttemptModel>[];
            if (allAttempts.isEmpty) {
              return const EmptyView(
                message: 'No exams attempted yet. Your results will show up here.',
                icon: Icons.history_rounded,
              );
            }

            _resolver.ensureCached(allAttempts, () {
              if (mounted) setState(() {});
            });
            final matched = _resolver.matchType(allAttempts, widget.examTypeId);

            if (matched.isEmpty && _resolver.isResolving(allAttempts)) return const LoadingView();
            if (matched.isEmpty) {
              return EmptyView(
                message: 'No ${widget.title.toLowerCase()} attempted yet. Your results will show up here.',
                icon: Icons.history_rounded,
              );
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
                Text(exam.title, style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_formatDate(attempt.submittedAt), style: AppTextStyles.bodySmall(bodyColor)),
              ],
            ),
          ),
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
}
