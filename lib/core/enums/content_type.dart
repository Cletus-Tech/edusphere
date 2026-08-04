/// Kind of a `learning_content` document.
enum LearningContentType {
  note,
  pdf,
  video,
  audio,
  assignment,
  timetable,
  download,
  flashcard;

  String get id => name;

  static LearningContentType fromId(String id) =>
      LearningContentType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => LearningContentType.note,
      );
}

/// Kind of an `exams` document.
enum ExamType {
  cbt,
  practiceTest,
  mockExam,
  jamb,
  waec,
  neco,
  postUtme,
  professionalCertification;

  String get id => name;

  static ExamType fromId(String id) => ExamType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => ExamType.cbt,
      );
}

/// Difficulty tag on a `questions` document.
enum QuestionDifficulty {
  easy,
  medium,
  hard;

  String get id => name;

  static QuestionDifficulty fromId(String id) => QuestionDifficulty.values.firstWhere(
        (d) => d.id == id,
        orElse: () => QuestionDifficulty.medium,
      );
}

/// Stage 4.8A — the format of a `questions` document. Added alongside
/// the existing single-choice-only shape rather than replacing it:
/// `QuestionModel.type` defaults to [singleChoice] on decode, so every
/// question written before this stage (which has no `type` field at
/// all) keeps working unchanged.
///
/// Model-level support (this enum + [QuestionModel.typeData]) is added
/// for every type Stage 4.8B calls for, so that stage's question-entry
/// UI and the CBT runner's answer widgets aren't blocked waiting on a
/// second model migration — but only [singleChoice], [multipleChoice],
/// [trueFalse], [fillInTheBlank], and [shortAnswer] have real runner
/// support as of this stage. The rest decode/round-trip safely and are
/// UI/scoring work for 4.8B.
enum QuestionType {
  singleChoice,
  multipleChoice,
  trueFalse,
  fillInTheBlank,
  shortAnswer,
  longAnswer,
  matching,
  ordering,
  passageBased,
  diagramBased,
  mathematicalNotation,
  table,
  caseStudy,
  novelBased;

  String get id => name;

  static QuestionType fromId(String id) => QuestionType.values.firstWhere(
        (t) => t.id == id,
        orElse: () => QuestionType.singleChoice,
      );
}

/// Which timer/control regime an [ExamSessionModel] is running under.
/// Per the Stage 4.8A spec: official and mock sessions run an
/// admin-controlled countdown the student cannot pause or extend;
/// practice sessions are student-controlled (the runner still tracks
/// elapsed time for stats, but nothing forces submission on expiry).
enum ExamMode {
  official,
  practice,
  mock;

  String get id => name;

  static ExamMode fromId(String id) => ExamMode.values.firstWhere(
        (m) => m.id == id,
        orElse: () => ExamMode.practice,
      );
}

/// Lifecycle of one `exam_sessions` document (the live, mutable,
/// auto-saved in-progress attempt — see [ExamSessionModel]).
enum ExamSessionStatus {
  inProgress,
  paused,
  submitted,
  expired,
  abandoned;

  String get id => name;

  static ExamSessionStatus fromId(String id) => ExamSessionStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => ExamSessionStatus.inProgress,
      );
}

/// Offline-first sync state for anything written locally before it has
/// confirmed a round-trip to Firestore (sessions, attempts, autosaved
/// answers). The engine that actually queues/replays [pendingSync]
/// writes when connectivity returns is separate build work — this enum
/// exists now so the session/attempt models can carry the field from
/// day one and never need a data migration to add it later.
enum SyncStatus {
  synced,
  pendingSync,
  syncFailed;

  String get id => name;

  static SyncStatus fromId(String id) => SyncStatus.values.firstWhere(
        (s) => s.id == id,
        orElse: () => SyncStatus.synced,
      );
}

/// Admin-configurable calculator access on an [ExamModel] — "Basic",
/// "Scientific", or none at all.
enum CalculatorType {
  none,
  basic,
  scientific;

  String get id => name;

  static CalculatorType fromId(String id) => CalculatorType.values.firstWhere(
        (c) => c.id == id,
        orElse: () => CalculatorType.none,
      );
}
