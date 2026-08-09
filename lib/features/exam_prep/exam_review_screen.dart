import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../core/utils/result.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../repositories/learning_repository.dart';
import '../../shared/widgets/custom_card.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import 'exam_runner_screen.dart';

/// Answer review — spec section 15 ("Review System"), the biggest
/// self-contained gap left after Stage 4.8B Part 2 (Admin Configuration).
/// Reads only what [ExamRunnerScreen] already wrote — the scored
/// [ExamSessionModel.answers] and the exam's [QuestionModel]s — so this
/// screen can never disagree with what was actually submitted; it does
/// not re-score anything.
///
/// Only meaningful for the five question types with real scoring today
/// (single/multiple-choice, true/false, fill-in-the-blank, short-answer)
/// — see the Stage 4.8B Part 1 audit for the other nine.
class ExamReviewScreen extends StatefulWidget {
  final ExamModel exam;
  final ExamAttemptModel attempt;

  const ExamReviewScreen({super.key, required this.exam, required this.attempt});

  @override
  State<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends State<ExamReviewScreen> {
  final ExamSessionRepository _sessionRepository = ExamSessionRepository();
  final QuestionRepository _questionRepository = QuestionRepository();

  bool _loading = true;
  String? _loadError;
  ExamSessionModel? _session;
  List<QuestionModel> _questions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessionResult = await _sessionRepository.getById(widget.attempt.sessionId);
    final session = switch (sessionResult) {
      Success(data: final data) => data,
      Failure() => null,
    };
    if (session == null) {
      setState(() {
        _loading = false;
        _loadError = 'This session could not be found — it may have been removed.';
      });
      return;
    }

    final questions = <QuestionModel>[];
    for (final id in session.questionOrder) {
      final result = await _questionRepository.getById(id);
      if (result case Success(data: final q)) {
        if (q != null) questions.add(q);
      }
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _questions = questions;
      _loading = false;
    });
  }

  List<QuestionModel> get _incorrectQuestions {
    final session = _session;
    if (session == null) return const [];
    return _questions.where((q) {
      final given = session.answers[q.questionId];
      return given == null || !_isCorrect(q, given);
    }).toList();
  }

  bool _isCorrect(QuestionModel q, dynamic given) {
    switch (q.type) {
      case QuestionType.singleChoice:
      case QuestionType.trueFalse:
        return given is String && q.correctAnswers.contains(given);
      case QuestionType.multipleChoice:
        if (given is! List) return false;
        final givenSet = given.map((e) => e.toString()).toSet();
        return givenSet.length == q.correctAnswers.length && givenSet.containsAll(q.correctAnswers);
      case QuestionType.fillInTheBlank:
      case QuestionType.shortAnswer:
        if (given is! String) return false;
        final normalized = given.trim().toLowerCase();
        return q.correctAnswers.any((a) => a.trim().toLowerCase() == normalized);
      default:
        return false; // Unsupported types aren't scored — see class doc.
    }
  }

  String _formatAnswer(QuestionModel q, dynamic value) {
    if (value == null) return 'No answer';
    switch (q.type) {
      case QuestionType.singleChoice:
      case QuestionType.trueFalse:
        final index = int.tryParse(value.toString());
        return index != null && index >= 0 && index < q.options.length ? q.options[index] : value.toString();
      case QuestionType.multipleChoice:
        if (value is! List) return value.toString();
        return value
            .map((v) {
              final index = int.tryParse(v.toString());
              return index != null && index >= 0 && index < q.options.length ? q.options[index] : v.toString();
            })
            .join(', ');
      default:
        return value.toString();
    }
  }

  Future<void> _retryIncorrect() async {
    final incorrect = _incorrectQuestions;
    if (incorrect.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamRunnerScreen(
          exam: widget.exam,
          questionIdsOverride: incorrect.map((q) => q.questionId).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam.title} · Review'),
        actions: [
          if (_incorrectQuestions.isNotEmpty)
            TextButton(
              onPressed: _retryIncorrect,
              child: Text('Retry ${_incorrectQuestions.length} wrong', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : _loadError != null
                ? ErrorView(message: _loadError!)
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      final given = _session!.answers[q.questionId];
                      final correct = _isCorrect(q, given);
                      final statusColor = given == null
                          ? bodyColor
                          : (correct ? AppColors.success : AppColors.error);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CustomCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    given == null
                                        ? Icons.remove_circle_outline_rounded
                                        : (correct ? Icons.check_circle_rounded : Icons.cancel_rounded),
                                    color: statusColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${index + 1}. ${q.text}',
                                      style: AppTextStyles.titleMedium(titleColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('Your answer: ${_formatAnswer(q, given)}',
                                  style: AppTextStyles.bodyMedium(statusColor)),
                              if (!correct) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Correct answer: ${_formatAnswer(q, given is List ? q.correctAnswers : q.correctAnswers.isNotEmpty ? q.correctAnswers.first : null)}',
                                  style: AppTextStyles.bodyMedium(AppColors.success),
                                ),
                              ],
                              if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: bodyColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Text(q.explanation!, style: AppTextStyles.bodySmall(bodyColor)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
