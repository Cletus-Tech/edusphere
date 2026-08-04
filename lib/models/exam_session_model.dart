import 'package:equatable/equatable.dart';
import '../core/enums/content_type.dart';
import 'firestore_model.dart';

/// `exam_sessions/{sessionId}` — Stage 4.8A. The live, mutable,
/// auto-saved record of one in-progress exam attempt. This is the
/// piece that lets "Resume interrupted exam" and "Auto-save" actually
/// work: every answer, flag, bookmark, and position change writes here
/// as the student goes, rather than only at submission.
///
/// One user should have at most one non-terminal (status `inProgress`
/// or `paused`) session per `examId` at a time — the runner is
/// responsible for finding and resuming that session instead of
/// starting a second one; this model doesn't enforce that itself since
/// Firestore security rules can't easily express "at most one".
///
/// [syncStatus] exists so offline-first behaviour (per the master
/// spec's "Permanent Education Architecture Rules") doesn't need a
/// separate model later: a session created or updated while offline is
/// written locally with `pendingSync`, and flips to `synced` once the
/// write actually reaches Firestore. The queue/replay mechanism that
/// does that flip is separate build work — this field is the contract
/// it will write to.
class ExamSessionModel extends Equatable implements FirestoreModel {
  final String sessionId;
  final String examId;
  final String userId;
  final ExamMode mode;
  final ExamSessionStatus status;

  /// questionId -> answer. Shape of the value depends on the
  /// question's `type`: a single string for single-choice/true-false/
  /// fill-in-the-blank/short-answer, a list of strings for
  /// multiple-choice, or a nested map for matching/ordering — mirrors
  /// how `QuestionModel.typeData` handles the same variability.
  final Map<String, dynamic> answers;
  final List<String> flaggedQuestionIds;
  final List<String> bookmarkedQuestionIds;

  /// The fixed order of question ids for *this* session — computed
  /// once at start (respecting `ExamModel.shuffleQuestions`) and then
  /// reused on every resume, so the student never sees questions
  /// reshuffle mid-attempt.
  final List<String> questionOrder;
  final int currentQuestionIndex;

  /// questionId -> the fixed, per-session display order of that
  /// question's options, expressed as *original* option indices (e.g.
  /// `[2, 0, 1]` means "show original option 2 first"). Computed once
  /// at session creation when `ExamModel.shuffleOptions` is on, and
  /// reused on every resume — same reasoning as [questionOrder]:
  /// nobody should see options reshuffle mid-attempt. Answers are
  /// still stored against the *original* option index, so this is
  /// purely a display concern and never affects scoring. Absent (or
  /// missing a key) means "show options in their stored order".
  final Map<String, dynamic> optionOrder;

  /// Seconds left on the clock. Null for untimed practice sessions;
  /// for official/mock sessions this is the source of truth the timer
  /// counts down from and auto-saves periodically, so a killed app or
  /// lost connection can't be used to gain extra time.
  final int? remainingSeconds;

  final DateTime startedAt;
  final DateTime lastSavedAt;
  final SyncStatus syncStatus;

  const ExamSessionModel({
    required this.sessionId,
    required this.examId,
    required this.userId,
    this.mode = ExamMode.practice,
    this.status = ExamSessionStatus.inProgress,
    this.answers = const {},
    this.flaggedQuestionIds = const [],
    this.bookmarkedQuestionIds = const [],
    this.questionOrder = const [],
    this.optionOrder = const {},
    this.currentQuestionIndex = 0,
    this.remainingSeconds,
    required this.startedAt,
    required this.lastSavedAt,
    this.syncStatus = SyncStatus.synced,
  });

  factory ExamSessionModel.fromMap(Map<String, dynamic> map, String sessionId) {
    return ExamSessionModel(
      sessionId: sessionId,
      examId: map['examId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      mode: ExamMode.fromId(map['mode'] as String? ?? ''),
      status: ExamSessionStatus.fromId(map['status'] as String? ?? ''),
      answers: FirestoreConvert.map(map['answers']),
      flaggedQuestionIds: FirestoreConvert.stringList(map['flaggedQuestionIds']),
      bookmarkedQuestionIds: FirestoreConvert.stringList(map['bookmarkedQuestionIds']),
      questionOrder: FirestoreConvert.stringList(map['questionOrder']),
      optionOrder: FirestoreConvert.map(map['optionOrder']),
      currentQuestionIndex: map['currentQuestionIndex'] as int? ?? 0,
      remainingSeconds: map['remainingSeconds'] as int?,
      startedAt: FirestoreConvert.dateTime(map['startedAt']),
      lastSavedAt: FirestoreConvert.dateTime(map['lastSavedAt']),
      syncStatus: SyncStatus.fromId(map['syncStatus'] as String? ?? ''),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'examId': examId,
        'userId': userId,
        'mode': mode.id,
        'status': status.id,
        'answers': answers,
        'flaggedQuestionIds': flaggedQuestionIds,
        'bookmarkedQuestionIds': bookmarkedQuestionIds,
        'questionOrder': questionOrder,
        'optionOrder': optionOrder,
        'currentQuestionIndex': currentQuestionIndex,
        'remainingSeconds': remainingSeconds,
        'startedAt': FirestoreConvert.toTimestamp(startedAt),
        'lastSavedAt': FirestoreConvert.toTimestamp(lastSavedAt),
        'syncStatus': syncStatus.id,
      };

  ExamSessionModel copyWith({
    ExamSessionStatus? status,
    Map<String, dynamic>? answers,
    List<String>? flaggedQuestionIds,
    List<String>? bookmarkedQuestionIds,
    int? currentQuestionIndex,
    int? remainingSeconds,
    DateTime? lastSavedAt,
    SyncStatus? syncStatus,
  }) {
    return ExamSessionModel(
      sessionId: sessionId,
      examId: examId,
      userId: userId,
      mode: mode,
      status: status ?? this.status,
      answers: answers ?? this.answers,
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      bookmarkedQuestionIds: bookmarkedQuestionIds ?? this.bookmarkedQuestionIds,
      questionOrder: questionOrder,
      optionOrder: optionOrder,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      startedAt: startedAt,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  bool get isResumable => status == ExamSessionStatus.inProgress || status == ExamSessionStatus.paused;

  @override
  String get id => sessionId;

  @override
  List<Object?> get props => [sessionId, examId, userId, status];
}

/// `exam_attempts/{attemptId}` — Stage 4.8A. The immutable-once-written
/// result record created when an [ExamSessionModel] is submitted (or
/// expires). Kept as a separate collection from `exam_sessions` rather
/// than just changing the session's status, because sessions are meant
/// to be cheap to overwrite constantly (every autosave) while attempts
/// are the permanent record analytics, performance history, and
/// retake-limit checks all read — mixing those access patterns on one
/// document would make every autosave contend with history reads.
///
/// [topicBreakdown] is populated at scoring time (per-question `topic`
/// tally) specifically so Stage 4.8B's weak-topic/strong-topic
/// detection has real per-attempt data to aggregate over from day one,
/// instead of needing a backfill migration once that stage lands.
class ExamAttemptModel extends Equatable implements FirestoreModel {
  final String attemptId;
  final String examId;
  final String userId;
  final String sessionId;
  final ExamMode mode;

  final int totalQuestions;
  final int correctCount;
  final int incorrectCount;
  final int unansweredCount;
  final double scorePercent;
  final bool passed;
  final int timeTakenSeconds;

  /// topic -> {"correct": n, "total": n}
  final Map<String, dynamic> topicBreakdown;

  final DateTime submittedAt;
  final SyncStatus syncStatus;

  const ExamAttemptModel({
    required this.attemptId,
    required this.examId,
    required this.userId,
    required this.sessionId,
    this.mode = ExamMode.practice,
    this.totalQuestions = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.unansweredCount = 0,
    this.scorePercent = 0,
    this.passed = false,
    this.timeTakenSeconds = 0,
    this.topicBreakdown = const {},
    required this.submittedAt,
    this.syncStatus = SyncStatus.synced,
  });

  factory ExamAttemptModel.fromMap(Map<String, dynamic> map, String attemptId) {
    return ExamAttemptModel(
      attemptId: attemptId,
      examId: map['examId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      mode: ExamMode.fromId(map['mode'] as String? ?? ''),
      totalQuestions: map['totalQuestions'] as int? ?? 0,
      correctCount: map['correctCount'] as int? ?? 0,
      incorrectCount: map['incorrectCount'] as int? ?? 0,
      unansweredCount: map['unansweredCount'] as int? ?? 0,
      scorePercent: (map['scorePercent'] as num?)?.toDouble() ?? 0,
      passed: map['passed'] as bool? ?? false,
      timeTakenSeconds: map['timeTakenSeconds'] as int? ?? 0,
      topicBreakdown: FirestoreConvert.map(map['topicBreakdown']),
      submittedAt: FirestoreConvert.dateTime(map['submittedAt']),
      syncStatus: SyncStatus.fromId(map['syncStatus'] as String? ?? ''),
    );
  }

  @override
  Map<String, dynamic> toMap() => {
        'examId': examId,
        'userId': userId,
        'sessionId': sessionId,
        'mode': mode.id,
        'totalQuestions': totalQuestions,
        'correctCount': correctCount,
        'incorrectCount': incorrectCount,
        'unansweredCount': unansweredCount,
        'scorePercent': scorePercent,
        'passed': passed,
        'timeTakenSeconds': timeTakenSeconds,
        'topicBreakdown': topicBreakdown,
        'submittedAt': FirestoreConvert.toTimestamp(submittedAt),
        'syncStatus': syncStatus.id,
      };

  @override
  String get id => attemptId;

  @override
  List<Object?> get props => [attemptId, examId, userId, submittedAt];
}
