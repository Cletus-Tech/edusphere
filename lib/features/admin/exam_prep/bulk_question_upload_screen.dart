import 'package:flutter/widgets.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/content_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/exam_model.dart';
import '../../../repositories/learning_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/import/csv_import_screen.dart';
import '../../../shared/import/csv_import_spec.dart';
import '../../../shared/import/csv_utils.dart';
import '../../../shared/import/import_types.dart';
import 'question_manager_screen.dart' show supportedQuestionTypes;

/// [Iterable.firstWhere] with no matching element instead of throwing —
/// `package:collection`'s `firstOrNull` isn't a dependency here, so this
/// stays a plain local helper rather than adding one just for this.
T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

/// Bulk CSV question import for one exam — the multi-question companion
/// to [QuestionManagerScreen]'s single-question form. Reuses the exact
/// same [QuestionModel] construction and `correctAnswers` conventions
/// that form already established (option text for choice types,
/// "true"/"false" for true-false, literal accepted strings for
/// fill-in-the-blank/short-answer) so a bulk-imported question and a
/// manually-added one score identically in `exam_scoring.dart`.
///
/// Column format, one row per question (header row required, skipped):
/// type, text, options, correct, explanation, difficulty, topic, points
///
/// - type: singleChoice | multipleChoice | trueFalse | fillInTheBlank | shortAnswer
/// - options: pipe-separated, e.g. "Paris|London|Berlin" — blank for
///   fillInTheBlank/shortAnswer
/// - correct: pipe-separated. For choice types, must exactly match
///   option text from the options column (case-sensitive). For
///   trueFalse: "true" or "false". For fillInTheBlank/shortAnswer:
///   pipe-separated accepted literal answers.
/// - explanation, difficulty (easy/medium/hard), topic, points: optional
///
/// Stage 6.2.1 — this screen's own file-picking/parsing/preview/
/// upload-progress code was extracted into `CsvImportScreen` +
/// `CsvImportSpec` (see `lib/shared/import/`) as the reusable
/// foundation for future bulk-import modules (Institutions, Faculties,
/// Departments, Levels, Semesters, Courses, Learning Materials — see
/// Stage 6.1's audit). This class is now a thin wrapper supplying the
/// question-specific parsing/save/audit rules below, unchanged from
/// before this refactor — behavior for bulk question import is
/// identical, just no longer duplicated when the next module is built.
class BulkQuestionUploadScreen extends StatelessWidget {
  final ExamModel exam;
  const BulkQuestionUploadScreen({super.key, required this.exam});

  @override
  Widget build(BuildContext context) {
    return CsvImportScreen<QuestionModel>(spec: _QuestionImportSpec(exam));
  }
}

class _QuestionImportSpec implements CsvImportSpec<QuestionModel> {
  final ExamModel exam;
  final QuestionRepository repository = QuestionRepository();
  _QuestionImportSpec(this.exam);

  @override
  String get screenTitle => 'Bulk Upload Questions';

  @override
  List<String> get allowedExtensions => const ['csv'];

  @override
  List<String> get columnOrder =>
      const ['type', 'text', 'options', 'correct', 'explanation', 'difficulty', 'topic', 'points'];

  @override
  String get formatHelpTitle => 'CSV format';

  @override
  String get formatHelpBody =>
      'One header row (skipped), then one question per row:\n\n'
      'type, text, options, correct, explanation, difficulty, topic, points\n\n'
      '• type: singleChoice, multipleChoice, trueFalse, fillInTheBlank, or shortAnswer\n'
      '• options: pipe-separated, e.g. Paris|London|Berlin (blank for fillInTheBlank/shortAnswer)\n'
      '• correct: pipe-separated — must match option text exactly for choice questions, '
      '"true"/"false" for trueFalse, or accepted answers for fillInTheBlank/shortAnswer\n'
      '• explanation, difficulty, topic, points are optional';

  @override
  ImportRowResult<QuestionModel> parseRow(CsvRow row) {
    final fields = row.fields;
    final rowNumber = row.rowNumber;

    if (fields.length < 4) {
      return ImportRowResult.invalid(
        rowNumber,
        'Expected at least type, text, options, correct — found ${fields.length} column(s).',
      );
    }

    final typeStr = fields[0].trim();
    final type = _firstWhereOrNull(QuestionType.values, (t) => t.name.toLowerCase() == typeStr.toLowerCase());
    if (type == null || !supportedQuestionTypes.contains(type)) {
      return ImportRowResult.invalid(
        rowNumber,
        '"$typeStr" isn\'t a supported type. Use one of: ${supportedQuestionTypes.map((t) => t.name).join(', ')}.',
      );
    }

    final text = fields[1].trim();
    if (text.isEmpty) {
      return ImportRowResult.invalid(rowNumber, 'Question text is empty.');
    }

    final options = fields[2].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final correctRaw = fields[3].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final isChoiceType = type == QuestionType.singleChoice || type == QuestionType.multipleChoice;

    if (isChoiceType) {
      if (options.length < 2) {
        return ImportRowResult.invalid(rowNumber, 'Choice questions need at least 2 options.');
      }
      final unmatched = correctRaw.where((c) => !options.contains(c)).toList();
      if (correctRaw.isEmpty || unmatched.isNotEmpty) {
        return ImportRowResult.invalid(
          rowNumber,
          unmatched.isNotEmpty
              ? 'Correct answer "${unmatched.first}" doesn\'t match any option text exactly.'
              : 'At least one correct answer is required.',
        );
      }
    } else if (type == QuestionType.trueFalse) {
      final v = correctRaw.isNotEmpty ? correctRaw.first.toLowerCase() : '';
      if (v != 'true' && v != 'false') {
        return ImportRowResult.invalid(
          rowNumber,
          'trueFalse correct answer must be "true" or "false", got "${correctRaw.isEmpty ? '' : correctRaw.first}".',
        );
      }
    } else if (correctRaw.isEmpty) {
      return ImportRowResult.invalid(rowNumber, 'At least one accepted answer is required.');
    }

    final explanation = fields.length > 4 ? fields[4].trim() : '';
    final difficulty = fields.length > 5
        ? _firstWhereOrNull(QuestionDifficulty.values, (d) => d.name.toLowerCase() == fields[5].trim().toLowerCase()) ??
            QuestionDifficulty.medium
        : QuestionDifficulty.medium;
    final topic = fields.length > 6 ? fields[6].trim() : '';
    final points = fields.length > 7 ? int.tryParse(fields[7].trim()) ?? 1 : 1;

    final correctOptionIndex = isChoiceType ? options.indexOf(correctRaw.first) : 0;

    return ImportRowResult.valid(
      rowNumber,
      QuestionModel(
        questionId: repository.newId(),
        examId: exam.examId,
        courseId: exam.courseId,
        text: text,
        options: isChoiceType ? options : const [],
        correctOptionIndex: correctOptionIndex < 0 ? 0 : correctOptionIndex,
        explanation: explanation.isEmpty ? null : explanation,
        difficulty: difficulty,
        topic: topic.isEmpty ? null : topic,
        type: type,
        correctAnswers: type == QuestionType.trueFalse ? [correctRaw.first.toLowerCase()] : correctRaw,
        points: points,
      ),
    );
  }

  @override
  Future<Result<void>> save(QuestionModel item) => repository.save(item);

  @override
  String describeValid(QuestionModel item) => item.text;

  @override
  void logImport(int uploadedCount) {
    AuditLogService.instance.log(
      action: AuditActionType.create,
      module: AuditModules.academicStructure,
      targetCollection: 'questions',
      targetId: exam.examId,
      targetTitle: '${exam.title} — bulk import ($uploadedCount question${uploadedCount == 1 ? '' : 's'})',
    );
  }
}
