import 'package:equatable/equatable.dart';
import '../core/enums/content_type.dart';
import 'firestore_model.dart';

/// `exams/{examId}` — a sittable exam. `questionIds` stays empty for
/// large banks; large exams instead query `questions` by `examId` so a
/// single exam document never needs to hold thousands of ids.
class ExamModel extends Equatable implements FirestoreModel {
  final String examId;
  final String title;
  final ExamType type;
  final String? courseId;
  final String? subjectId;
  final int durationMinutes;
  final int totalQuestions;
  final int passMarkPercent;
  final bool isActive;
  final Map<String, dynamic> metadata;

  const ExamModel({
    required this.examId,
    required this.title,
    required this.type,
    this.courseId,
    this.subjectId,
    this.durationMinutes = 60,
    this.totalQuestions = 0,
    this.passMarkPercent = 50,
    this.isActive = true,
    this.metadata = const {},
  });

  factory ExamModel.fromMap(Map<String, dynamic> map, String examId) {
    return ExamModel(
      examId: examId,
      title: map['title'] as String? ?? '',
      type: ExamType.fromId(map['type'] as String? ?? ''),
      courseId: map['courseId'] as String?,
      subjectId: map['subjectId'] as String?,
      durationMinutes: map['durationMinutes'] as int? ?? 60,
      totalQuestions: map['totalQuestions'] as int? ?? 0,
      passMarkPercent: map['passMarkPercent'] as int? ?? 50,
      isActive: map['isActive'] as bool? ?? true,
      metadata: FirestoreConvert.map(map['metadata']),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type.id,
        'courseId': courseId,
        'subjectId': subjectId,
        'durationMinutes': durationMinutes,
        'totalQuestions': totalQuestions,
        'passMarkPercent': passMarkPercent,
        'isActive': isActive,
        'metadata': metadata,
      };

  @override
  String get id => examId;

  @override
  List<Object?> get props => [examId, title, type, isActive];
}

/// `questions/{questionId}` — a single question bank entry, reusable
/// across exams, practice tests, and scanning-mode-style review.
class QuestionModel extends Equatable implements FirestoreModel {
  final String questionId;
  final String examId;
  final String? courseId;
  final String text;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;
  final QuestionDifficulty difficulty;
  final String? topic;
  final List<String> tags;
  final String? imageUrl;

  const QuestionModel({
    required this.questionId,
    required this.examId,
    this.courseId,
    required this.text,
    this.options = const [],
    required this.correctOptionIndex,
    this.explanation,
    this.difficulty = QuestionDifficulty.medium,
    this.topic,
    this.tags = const [],
    this.imageUrl,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> map, String questionId) {
    return QuestionModel(
      questionId: questionId,
      examId: map['examId'] as String? ?? '',
      courseId: map['courseId'] as String?,
      text: map['text'] as String? ?? '',
      options: FirestoreConvert.stringList(map['options']),
      correctOptionIndex: map['correctOptionIndex'] as int? ?? 0,
      explanation: map['explanation'] as String?,
      difficulty: QuestionDifficulty.fromId(map['difficulty'] as String? ?? ''),
      topic: map['topic'] as String?,
      tags: FirestoreConvert.stringList(map['tags']),
      imageUrl: map['imageUrl'] as String?,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'examId': examId,
        'courseId': courseId,
        'text': text,
        'options': options,
        'correctOptionIndex': correctOptionIndex,
        'explanation': explanation,
        'difficulty': difficulty.id,
        'topic': topic,
        'tags': tags,
        'imageUrl': imageUrl,
      };

  @override
  String get id => questionId;

  @override
  List<Object?> get props => [questionId, examId, text, correctOptionIndex];
}
