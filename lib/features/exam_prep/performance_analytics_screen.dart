import 'package:flutter/material.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../repositories/learning_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'exam_attempt_resolver.dart';
import 'exam_result_screen.dart';

/// Spec section 16 ("Performance Analytics") — the other genuine gap
/// flagged in the Stage 4.8B Part 3 audit alongside Student Exam
/// History. Every number here reads data that already exists
/// ([ExamAttemptModel]'s scoring fields, written by [ExamScoring] at
/// submission) — this screen adds no new scoring pipeline, only
/// aggregation and display, per the audit's own note that
/// `topicBreakdown` "already has the data."
///
/// Difficulty Analysis and a scored Performance Graph are *not* built
/// here: [QuestionModel.difficulty] exists, but no attempt stores a
/// per-difficulty breakdown the way it does for topics, and building
/// that would mean changing [ExamScoring] and re-deriving every past
/// attempt — real new scope, not a display gap. Left for a future
/// stage; see this file's own changelog entry.
///
/// Same board-filtering approach as [ExamHistoryScreen], sharing the
/// [ExamAttemptResolver] rather than duplicating the examId → exam
/// join logic.
class PerformanceAnalyticsScreen extends StatefulWidget {
  final String examTypeId;
  final String title;

  const PerformanceAnalyticsScreen({super.key, required this.examTypeId, required this.title});

  @override
  State<PerformanceAnalyticsScreen> createState() => _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState extends State<PerformanceAnalyticsScreen> {
  final ExamAttemptResolver _resolver = ExamAttemptResolver();

  @override
  Widget build(BuildContext context) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const SafeArea(
          child: EmptyView(message: 'Sign in to see your performance.', icon: Icons.insights_rounded),
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
            if (snapshot.hasError) return const ErrorView(message: 'Could not load your performance data right now.');

            final allAttempts = snapshot.data ?? const <ExamAttemptModel>[];
            if (allAttempts.isEmpty) {
              return const EmptyView(
                message: 'No attempts yet. Sit a mock exam or practice set to see your performance here.',
                icon: Icons.insights_rounded,
              );
            }

            _resolver.ensureCached(allAttempts, () {
              if (mounted) setState(() {});
            });
            final matched = _resolver.matchType(allAttempts, widget.examTypeId);

            if (matched.isEmpty && _resolver.isResolving(allAttempts)) return const LoadingView();
            if (matched.isEmpty) {
              return EmptyView(
                message: 'No ${widget.title.toLowerCase()} yet. Sit a mock exam or practice set to see your performance here.',
                icon: Icons.insights_rounded,
              );
            }

            // Most recent first (as returned by the repository) — flip
            // for the trend strip so it reads left-to-right chronologically.
            final chronological = matched.reversed.toList();
            final topics = _aggregateTopics(matched.map((m) => m.$1));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _SummaryGrid(attempts: matched.map((m) => m.$1).toList()),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Score Trend'),
                const SizedBox(height: 12),
                _ScoreTrend(attempts: chronological.map((m) => m.$1).toList()),
                if (topics.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Strong Topics'),
                  const SizedBox(height: 12),
                  _TopicList(topics: topics.take(3).toList()),
                  if (topics.length > 3) ...[
                    const SizedBox(height: 24),
                    const SectionHeader(title: 'Weak Topics'),
                    const SizedBox(height: 12),
                    _TopicList(topics: topics.reversed.take(3).toList()),
                  ],
                ],
                const SizedBox(height: 24),
                const SectionHeader(title: 'Recent Attempts'),
                const SizedBox(height: 12),
                ...matched.take(5).map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AttemptRow(attempt: m.$1, exam: m.$2),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Sums correct/total per topic across every matched attempt, then
  /// sorts strongest-first by percent correct. Ties broken by more
  /// questions seen (a 9/10 topic ranks above a 3/3 topic — more
  /// signal, same idea [ExamScoring] already uses per-attempt).
  List<_TopicStat> _aggregateTopics(Iterable<ExamAttemptModel> attempts) {
    final totals = <String, (int correct, int total)>{};
    for (final attempt in attempts) {
      for (final entry in attempt.topicBreakdown.entries) {
        final data = Map<String, dynamic>.from(entry.value as Map);
        final correct = data['correct'] as int? ?? 0;
        final total = data['total'] as int? ?? 0;
        final existing = totals[entry.key] ?? (0, 0);
        totals[entry.key] = (existing.$1 + correct, existing.$2 + total);
      }
    }
    final stats = totals.entries
        .where((e) => e.value.$2 > 0)
        .map((e) => _TopicStat(topic: e.key, correct: e.value.$1, total: e.value.$2))
        .toList()
      ..sort((a, b) {
        final byPercent = b.percent.compareTo(a.percent);
        return byPercent != 0 ? byPercent : b.total.compareTo(a.total);
      });
    return stats;
  }
}

class _TopicStat {
  final String topic;
  final int correct;
  final int total;
  const _TopicStat({required this.topic, required this.correct, required this.total});
  double get percent => total == 0 ? 0 : correct / total;
}

class _SummaryGrid extends StatelessWidget {
  final List<ExamAttemptModel> attempts;
  const _SummaryGrid({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final count = attempts.length;
    final avgScore = attempts.map((a) => a.scorePercent).reduce((a, b) => a + b) / count;
    final passRate = attempts.where((a) => a.passed).length / count * 100;
    final totalQuestions = attempts.fold<int>(0, (sum, a) => sum + a.totalQuestions);
    final totalSeconds = attempts.fold<int>(0, (sum, a) => sum + a.timeTakenSeconds);
    final avgSecondsPerQuestion = totalQuestions == 0 ? 0 : totalSeconds / totalQuestions;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        _StatCard(label: 'Attempts', value: '$count', color: AppColors.primaryBlue),
        _StatCard(label: 'Average Score', value: '${avgScore.toStringAsFixed(0)}%', color: AppColors.secondaryIndigo),
        _StatCard(label: 'Pass Rate', value: '${passRate.toStringAsFixed(0)}%', color: AppColors.success),
        _StatCard(
          label: 'Avg. Time / Question',
          value: '${avgSecondsPerQuestion.toStringAsFixed(0)}s',
          color: AppColors.highlightOrange,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: AppTextStyles.headlineSmall(color).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall(bodyColor)),
        ],
      ),
    );
  }
}

/// Hand-rolled bar strip — the project has no charting dependency in
/// `pubspec.yaml`, so this follows the same "plain [Container] sizing"
/// approach already used for progress/score visuals elsewhere rather
/// than adding one for a single screen.
class _ScoreTrend extends StatelessWidget {
  final List<ExamAttemptModel> attempts;
  const _ScoreTrend({required this.attempts});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final recent = attempts.length > 10 ? attempts.sublist(attempts.length - 10) : attempts;

    return CustomCard(
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: recent.map((attempt) {
            final heightFraction = (attempt.scorePercent.clamp(0, 100)) / 100;
            final barColor = attempt.passed ? AppColors.success : AppColors.error;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${attempt.scorePercent.toStringAsFixed(0)}',
                      style: AppTextStyles.bodySmall(bodyColor).copyWith(fontSize: 9),
                    ),
                    const SizedBox(height: 4),
                    FractionallySizedBox(
                      heightFactor: heightFraction <= 0 ? 0.02 : heightFraction.toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TopicList extends StatelessWidget {
  final List<_TopicStat> topics;
  const _TopicList({required this.topics});

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return CustomCard(
      child: Column(
        children: topics.map((topic) {
          final percent = (topic.percent * 100).clamp(0, 100);
          final barColor = topic.percent >= 0.7
              ? AppColors.success
              : (topic.percent >= 0.4 ? AppColors.highlightOrange : AppColors.error);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(topic.topic, style: AppTextStyles.bodyMedium(titleColor))),
                    Text(
                      '${topic.correct}/${topic.total} (${percent.toStringAsFixed(0)}%)',
                      style: AppTextStyles.bodySmall(bodyColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: topic.percent.clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: bodyColor.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  final ExamAttemptModel attempt;
  final ExamModel exam;
  const _AttemptRow({required this.attempt, required this.exam});

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
                Text(exam.title, style: AppTextStyles.bodyMedium(titleColor).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_formatDate(attempt.submittedAt), style: AppTextStyles.bodySmall(bodyColor)),
              ],
            ),
          ),
          Text(
            '${attempt.scorePercent.toStringAsFixed(0)}%',
            style: AppTextStyles.bodyMedium(scoreColor).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
