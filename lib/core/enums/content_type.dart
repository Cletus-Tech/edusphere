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
