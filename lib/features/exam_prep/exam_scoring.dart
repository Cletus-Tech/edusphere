import '../../core/enums/content_type.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';

/// Stage 4.8C Part 1 — the CBT Engine's missing piece: turns an
/// answered [ExamSessionModel] into the permanent [ExamAttemptModel]
/// record, applying [ExamModel.negativeMarkingEnabled] and computing
/// the per-topic breakdown Stage 4.8B's analytics reads.
///
/// Only the question types the runner actually collects answers for
/// ([QuestionType.singleChoice], [trueFalse], [multipleChoice],
/// [fillInTheBlank], [shortAnswer]) are auto-scored. Every other type
/// shows "not supported in the practice runner yet" instead of an
/// input (see `_QuestionBody`'s default case), so it's excluded from
/// both the question count and the point total — including one in
/// either would silently penalize a student for a question they were
/// never given a way to answer.
class ExamScoringResult {
  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final double scorePercent;
  final bool passed;
  final Map<String, dynamic> topicBreakdown;

  const ExamScoringResult({
    required this.totalQuestions,
    required this.correctCount,
    required this.incorrectCount,
    required this.unansweredCount,
    required this.scorePercent,
    required this.passed,
    required this.topicBreakdown,
  });
}

const _autoScorableTypes = {
  QuestionType.singleChoice,
  QuestionType.trueFalse,
  QuestionType.multipleChoice,
  QuestionType.fillInTheBlank,
  QuestionType.shortAnswer,
};

ExamScoringResult scoreExamSession({
  required ExamModel exam,
  required ExamSessionModel session,
  required List<QuestionModel> questions,
}) {
  final scorable = questions.where((q) => _autoScorableTypes.contains(q.type)).toList();

  int correctCount = 0;
  int incorrectCount = 0;
  int unansweredCount = 0;
  double pointsEarned = 0;
  double pointsPossible = 0;
  final topicBreakdown = <String, Map<String, int>>{};

  for (final q in scorable) {
    final answer = session.answers[q.questionId];
    pointsPossible += q.points;

    final topic = q.topic;
    if (topic != null && topic.isNotEmpty) {
      final entry = topicBreakdown.putIfAbsent(topic, () => {'correct': 0, 'total': 0});
      entry['total'] = entry['total']! + 1;
    }

    if (_isUnanswered(q, answer)) {
      unansweredCount++;
      continue;
    }

    final isCorrect = _isAnswerCorrect(q, answer);
    if (isCorrect) {
      correctCount++;
      pointsEarned += q.points;
      if (topic != null && topic.isNotEmpty) {
        topicBreakdown[topic]!['correct'] = topicBreakdown[topic]!['correct']! + 1;
      }
    } else {
      incorrectCount++;
      if (exam.negativeMarkingEnabled) {
        pointsEarned -= q.points * (exam.negativeMarkPercent / 100);
      }
    }
  }

  final scorePercent = pointsPossible > 0 ? (pointsEarned / pointsPossible * 100).clamp(0, 100).toDouble() : 0.0;

  return ExamScoringResult(
    totalQuestions: scorable.length,
    correctCount: correctCount,
    incorrectCount: incorrectCount,
    unansweredCount: unansweredCount,
    scorePercent: scorePercent,
    passed: scorePercent >= exam.passMarkPercent,
    topicBreakdown: topicBreakdown,
  );
}

bool _isUnanswered(QuestionModel q, dynamic answer) {
  if (answer == null) return true;
  if (answer is String) return answer.trim().isEmpty;
  if (answer is List) return answer.isEmpty;
  return false;
}

bool _isAnswerCorrect(QuestionModel q, dynamic answer) {
  switch (q.type) {
    case QuestionType.singleChoice:
    case QuestionType.trueFalse:
      // Bridge per QuestionModel's own doc comment: prefer the
      // generalized `correctAnswers` set; fall back to the legacy
      // `correctOptionIndex` only when it's empty.
      final correctSet =
          q.correctAnswers.isNotEmpty ? q.correctAnswers : [q.correctOptionIndex.toString()];
      return answer is String && correctSet.contains(answer);

    case QuestionType.multipleChoice:
      if (answer is! List) return false;
      final given = answer.map((e) => e.toString()).toSet();
      final correct = q.correctAnswers.toSet();
      return given.isNotEmpty && given.length == correct.length && given.containsAll(correct);

    case QuestionType.fillInTheBlank:
    case QuestionType.shortAnswer:
      if (answer is! String) return false;
      final given = answer.trim().toLowerCase();
      return q.correctAnswers.any((a) => a.trim().toLowerCase() == given);

    default:
      return false;
  }
}
