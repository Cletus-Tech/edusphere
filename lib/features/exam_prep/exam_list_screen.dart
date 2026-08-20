import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../../repositories/learning_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'exam_runner_screen.dart';

/// Stage 4.5 Part 4 — lists [ExamModel] documents for one [ExamType],
/// reusing [ExamRepository.watchByType] exactly as it already existed
/// (unused by any screen before this stage). This is the "establish
/// navigation and data flow" half of Part 4: real exam metadata
/// (title, duration, question count, pass mark) loads and displays
/// correctly.
///
/// Stage 4.8A Part 2: tapping "Start" now actually opens
/// [ExamRunnerScreen], which finds-or-creates the session itself —
/// this screen doesn't need to know about [ExamSessionRepository] at
/// all, keeping the create-or-resume logic in one place.
///
/// Stage 4.8C Part 1 (Institution Controls): "Start" now enforces the
/// two admin-controlled rules that are checkable *before* a session
/// exists — [ExamModel.isCurrentlyAvailable] (the availability window)
/// and [ExamModel.attemptLimit] (checked only when there's no
/// resumable session already, since resuming an in-progress attempt
/// isn't a new one). Calculator policy and negative marking are read
/// by the runner/scoring logic instead — there's nothing to gate here
/// until those exist.
///
/// Generic like [SubjectBrowseScreen]: any future board (NECO, JAMB)
/// reuses this with a different [examTypeId] instead of a copy.
class ExamListScreen extends StatelessWidget {
  final String examTypeId;
  final String title;

  /// Stage CBT-2 — threaded straight through to [ExamRunnerScreen].
  /// Defaults to [ExamMode.practice] so WAEC/NECO/JAMB/University
  /// (none of which pass this) keep starting practice sessions exactly
  /// as they did before this stage.
  final ExamMode mode;

  const ExamListScreen({super.key, required this.examTypeId, required this.title, this.mode = ExamMode.practice});

  Future<void> _startExam(BuildContext context, ExamModel exam) async {
    if (!exam.isCurrentlyAvailable) {
      final message = exam.availableFrom != null && DateTime.now().isBefore(exam.availableFrom!)
          ? 'This exam opens on ${_formatDate(exam.availableFrom!)}.'
          : exam.availableUntil != null && DateTime.now().isAfter(exam.availableUntil!)
              ? 'This exam closed on ${_formatDate(exam.availableUntil!)}.'
              : 'This exam is not currently available.';
      if (context.mounted) _showBlockedDialog(context, 'Exam unavailable', message);
      return;
    }

    // Stage CBT-2: an exam can restrict which modes it's sittable
    // under (ExamModel.supportedModes) — e.g. an exam authored as
    // official-only shouldn't be startable from a practice entry
    // point. Existing callers that don't pass `mode` default to
    // `practice`, and every exam defaults `supportedModes` to all
    // three, so this is a no-op for every pre-CBT-2 call site.
    if (!exam.supportedModes.contains(mode)) {
      if (context.mounted) {
        _showBlockedDialog(context, 'Not available in this mode', 'This exam isn\'t offered as ${mode.id}.');
      }
      return;
    }

    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      if (context.mounted) _showBlockedDialog(context, 'Sign in required', 'You need to be signed in to start an exam.');
      return;
    }

    // Resuming an existing attempt is never blocked by the attempt
    // limit — the limit caps how many *new* attempts a student can
    // start, not whether they can finish one already in progress.
    final resumable = await ExamSessionRepository().findResumableSession(uid, exam.examId);
    if (resumable == null && exam.attemptLimit != null) {
      final pastAttempts = await ExamAttemptRepository().fetchAttemptsForExam(uid, exam.examId);
      if (pastAttempts.length >= exam.attemptLimit!) {
        if (context.mounted) {
          _showBlockedDialog(
            context,
            'Attempt limit reached',
            "You've used all ${exam.attemptLimit} attempt${exam.attemptLimit == 1 ? '' : 's'} for this exam.",
          );
        }
        return;
      }
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ExamRunnerScreen(exam: exam, mode: mode)),
      );
    }
  }

  void _showBlockedDialog(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: StreamBuilder<List<ExamModel>>(
          stream: ExamRepository().watchByType(examTypeId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            if (snapshot.hasError) return const ErrorView(message: 'Could not load exams right now.');
            final exams = snapshot.data ?? const <ExamModel>[];
            if (exams.isEmpty) {
              return EmptyView(message: 'No $title have been added yet.', icon: Icons.quiz_outlined);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final exam = exams[index];
                return CustomCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: AppTextStyles.bodyLarge(
                          Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _ExamStat(icon: Icons.timer_outlined, label: '${exam.durationMinutes} min'),
                          if (exam.totalQuestions > 0)
                            _ExamStat(icon: Icons.list_alt_rounded, label: '${exam.totalQuestions} questions'),
                          _ExamStat(icon: Icons.flag_outlined, label: 'Pass: ${exam.passMarkPercent}%'),
                          if (exam.attemptLimit != null)
                            _ExamStat(
                              icon: Icons.repeat_rounded,
                              label: '${exam.attemptLimit} attempt${exam.attemptLimit == 1 ? '' : 's'}',
                            ),
                          if (exam.negativeMarkingEnabled)
                            _ExamStat(icon: Icons.remove_circle_outline, label: '-${exam.negativeMarkPercent}% per wrong'),
                          if (exam.isPremium)
                            const _ExamStat(icon: Icons.workspace_premium_outlined, label: 'Premium'),
                          if (!exam.isCurrentlyAvailable)
                            const _ExamStat(icon: Icons.event_busy_outlined, label: 'Unavailable'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(
                          onPressed: () => _startExam(context, exam),
                          child: const Text('Start'),
                        ),
                      ),
                    ],
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

class _ExamStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ExamStat({required this.icon, required this.label});

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
