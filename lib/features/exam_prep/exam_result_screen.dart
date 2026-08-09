import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../shared/widgets/custom_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import 'exam_review_screen.dart';

/// Stage 4.8C Part 1 — shown once [ExamRunnerScreen] submits and scores
/// a session. Deliberately reads only the already-computed
/// [ExamAttemptModel] (never re-scores), so this screen can't drift
/// from what was actually written to `exam_attempts`.
class ExamResultScreen extends StatelessWidget {
  final ExamModel exam;
  final ExamAttemptModel attempt;

  const ExamResultScreen({super.key, required this.exam, required this.attempt});

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (!exam.showResultsImmediately) {
      return Scaffold(
        appBar: AppBar(title: Text(exam.title), automaticallyImplyLeading: false),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 48, color: bodyColor),
                  const SizedBox(height: 16),
                  Text(
                    'Submission received',
                    style: AppTextStyles.headlineSmall(titleColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your answers were recorded. This exam releases results after admin review — '
                    "you'll be notified once yours is available.",
                    style: AppTextStyles.bodyMedium(bodyColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final passColor = attempt.passed ? AppColors.success : AppColors.error;

    return Scaffold(
      appBar: AppBar(title: Text(exam.title), automaticallyImplyLeading: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: passColor.withOpacity(0.1),
                borderRadius: AppRadius.card,
              ),
              child: Column(
                children: [
                  Icon(
                    attempt.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: passColor,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${attempt.scorePercent.toStringAsFixed(1)}%',
                    style: AppTextStyles.displayLarge(passColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    attempt.passed ? 'Passed' : 'Not passed',
                    style: AppTextStyles.titleMedium(passColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pass mark: ${exam.passMarkPercent}%',
                    style: AppTextStyles.bodySmall(bodyColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Correct',
                    value: '${attempt.correctCount}',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Incorrect',
                    value: '${attempt.incorrectCount}',
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Unanswered',
                    value: '${attempt.unansweredCount}',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Time taken', style: AppTextStyles.bodyMedium(titleColor)),
                  Text(_formatDuration(attempt.timeTakenSeconds), style: AppTextStyles.bodyMedium(bodyColor)),
                ],
              ),
            ),
            if (attempt.topicBreakdown.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('By topic', style: AppTextStyles.titleMedium(titleColor)),
              const SizedBox(height: 8),
              CustomCard(
                child: Column(
                  children: attempt.topicBreakdown.entries.map((e) {
                    final data = Map<String, dynamic>.from(e.value as Map);
                    final correct = data['correct'] as int? ?? 0;
                    final total = data['total'] as int? ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(e.key, style: AppTextStyles.bodyMedium(titleColor))),
                          Text('$correct / $total', style: AppTextStyles.bodyMedium(bodyColor)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ExamReviewScreen(exam: exam, attempt: attempt)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Review Answers'),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              // This screen replaces ExamRunnerScreen in the stack (see
              // the pushReplacement in _submitExam), so a single pop
              // lands back on whatever pushed the runner — ExamListScreen.
              onPressed: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m}m ${s}s';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.headlineSmall(color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall(labelColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
