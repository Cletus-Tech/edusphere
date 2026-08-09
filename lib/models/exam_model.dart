import 'package:equatable/equatable.dart';
import '../core/enums/content_type.dart';
import 'firestore_model.dart';

/// `exams/{examId}` — a sittable exam, shared by every board (CBT
/// practice, JAMB, WAEC, NECO, university course exams, ...) via
/// [ExamType] rather than a per-board model. `questionIds` stays empty
/// for large banks; large exams instead query `questions` by `examId`
/// so a single exam document never needs to hold thousands of ids.
///
/// Stage 4.8A adds the admin-controlled-configuration fields the CBT
/// Engine Core spec calls for (calculator, negative marking, shuffle,
/// attempt limits, availability window, premium/offline gating). Every
/// new field has a default matching today's actual behaviour
/// (calculator off, no negative marking, no shuffle, unlimited
/// attempts, always available, free, online-only), so every [ExamModel]
/// document written before this stage decodes exactly as it did
/// before — nothing here requires a data migration.
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

  // --- Stage 4.8A: admin-controlled configuration -----------------------
  final CalculatorType calculatorType;
  final bool negativeMarkingEnabled;
  final int negativeMarkPercent;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final int? attemptLimit; // null = unlimited
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final bool isPremium;
  final bool offlineAvailable;
  final bool proctoringEnabled;
  final List<ExamMode> supportedModes;

  // --- Stage 4.8B: navigation rules (spec section 11) --------------------
  // All default to today's actual runner behaviour (free navigation,
  // flagging on, review screen shown) so existing documents decode
  // unchanged.
  final bool allowBackNavigation;
  final bool allowFlagging;
  final bool allowSkipping;
  final bool requireReviewBeforeSubmit;
  final bool showResultsImmediately;

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
    this.calculatorType = CalculatorType.none,
    this.negativeMarkingEnabled = false,
    this.negativeMarkPercent = 0,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.attemptLimit,
    this.availableFrom,
    this.availableUntil,
    this.isPremium = false,
    this.offlineAvailable = false,
    this.proctoringEnabled = false,
    this.supportedModes = const [ExamMode.official, ExamMode.practice, ExamMode.mock],
    this.allowBackNavigation = true,
    this.allowFlagging = true,
    this.allowSkipping = true,
    this.requireReviewBeforeSubmit = false,
    this.showResultsImmediately = true,
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
      calculatorType: CalculatorType.fromId(map['calculatorType'] as String? ?? ''),
      negativeMarkingEnabled: map['negativeMarkingEnabled'] as bool? ?? false,
      negativeMarkPercent: map['negativeMarkPercent'] as int? ?? 0,
      shuffleQuestions: map['shuffleQuestions'] as bool? ?? false,
      shuffleOptions: map['shuffleOptions'] as bool? ?? false,
      attemptLimit: map['attemptLimit'] as int?,
      availableFrom: FirestoreConvert.dateTimeOrNull(map['availableFrom']),
      availableUntil: FirestoreConvert.dateTimeOrNull(map['availableUntil']),
      isPremium: map['isPremium'] as bool? ?? false,
      offlineAvailable: map['offlineAvailable'] as bool? ?? false,
      proctoringEnabled: map['proctoringEnabled'] as bool? ?? false,
      supportedModes: FirestoreConvert.stringList(map['supportedModes']).isEmpty
          ? const [ExamMode.official, ExamMode.practice, ExamMode.mock]
          : FirestoreConvert.stringList(map['supportedModes']).map(ExamMode.fromId).toList(),
      allowBackNavigation: map['allowBackNavigation'] as bool? ?? true,
      allowFlagging: map['allowFlagging'] as bool? ?? true,
      allowSkipping: map['allowSkipping'] as bool? ?? true,
      requireReviewBeforeSubmit: map['requireReviewBeforeSubmit'] as bool? ?? false,
      showResultsImmediately: map['showResultsImmediately'] as bool? ?? true,
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
        'calculatorType': calculatorType.id,
        'negativeMarkingEnabled': negativeMarkingEnabled,
        'negativeMarkPercent': negativeMarkPercent,
        'shuffleQuestions': shuffleQuestions,
        'shuffleOptions': shuffleOptions,
        'attemptLimit': attemptLimit,
        if (availableFrom != null) 'availableFrom': FirestoreConvert.toTimestamp(availableFrom!),
        if (availableUntil != null) 'availableUntil': FirestoreConvert.toTimestamp(availableUntil!),
        'isPremium': isPremium,
        'offlineAvailable': offlineAvailable,
        'proctoringEnabled': proctoringEnabled,
        'supportedModes': supportedModes.map((m) => m.id).toList(),
        'allowBackNavigation': allowBackNavigation,
        'allowFlagging': allowFlagging,
        'allowSkipping': allowSkipping,
        'requireReviewBeforeSubmit': requireReviewBeforeSubmit,
        'showResultsImmediately': showResultsImmediately,
      };

  /// Whether the exam is inside its admin-set availability window right
  /// now (both bounds optional — an unset bound means "no limit" on
  /// that side).
  bool get isCurrentlyAvailable {
    final now = DateTime.now();
    if (availableFrom != null && now.isBefore(availableFrom!)) return false;
    if (availableUntil != null && now.isAfter(availableUntil!)) return false;
    return isActive;
  }

  @override
  String get id => examId;

  @override
  List<Object?> get props => [examId, title, type, isActive];
}

/// `questions/{questionId}` — a single question bank entry, reusable
/// across exams, practice tests, and scanning-mode-style review.
///
/// Stage 4.8A adds [type] and two generalized fields — [correctAnswers]
/// and [typeData] — so one model can represent every question format
/// the CBT spec lists, instead of a duplicate model per type.
/// [correctOptionIndex] is kept exactly as-is (not deprecated, not
/// migrated) because it's the only field pre-4.8A single-choice
/// documents have; [type] defaults to [QuestionType.singleChoice] on
/// decode when absent, so existing documents keep working through the
/// old field unchanged. New questions of any type should populate
/// [correctAnswers] instead; the CBT runner (this stage's next slice)
/// reads [correctOptionIndex] only when `type == singleChoice` and the
/// newer field is empty, for a one-way compatibility bridge.
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

  // --- Stage 4.8A: multi-type support ------------------------------------
  final QuestionType type;
  /// Generalized correct-answer set. Meaning depends on [type]: option
  /// ids/indices (as strings) for single/multiple-choice, `"true"`/
  /// `"false"` for true-false, accepted literal strings for
  /// fill-in-the-blank/short-answer. Empty for types scored manually
  /// (long answer) or scored via [typeData] (matching, ordering).
  final List<String> correctAnswers;
  /// Type-specific structured data that doesn't fit a shared shape:
  /// matching pairs, ordering sequence, passage text, table rows,
  /// math-notation markup, case-study context, etc. Mirrors the
  /// `metadata` bucket [ExamModel] already uses for the same reason —
  /// avoids a dozen nullable fields only one type each ever uses.
  final Map<String, dynamic> typeData;
  final int points;
  final bool premiumExplanation;

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
    this.type = QuestionType.singleChoice,
    this.correctAnswers = const [],
    this.typeData = const {},
    this.points = 1,
    this.premiumExplanation = false,
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
      type: QuestionType.fromId(map['type'] as String? ?? ''),
      correctAnswers: FirestoreConvert.stringList(map['correctAnswers']),
      typeData: FirestoreConvert.map(map['typeData']),
      points: map['points'] as int? ?? 1,
      premiumExplanation: map['premiumExplanation'] as bool? ?? false,
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
        'type': type.id,
        'correctAnswers': correctAnswers,
        'typeData': typeData,
        'points': points,
        'premiumExplanation': premiumExplanation,
      };

  @override
  String get id => questionId;

  @override
  List<Object?> get props => [questionId, examId, text, correctOptionIndex, type];
}
