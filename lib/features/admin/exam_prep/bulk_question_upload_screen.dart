import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/content_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/exam_model.dart';
import '../../../repositories/learning_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
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
class BulkQuestionUploadScreen extends StatefulWidget {
  final ExamModel exam;
  const BulkQuestionUploadScreen({super.key, required this.exam});

  @override
  State<BulkQuestionUploadScreen> createState() => _BulkQuestionUploadScreenState();
}

class _BulkQuestionUploadScreenState extends State<BulkQuestionUploadScreen> {
  final QuestionRepository _repository = QuestionRepository();

  String? _fileName;
  List<_ParsedRow> _rows = [];
  bool _uploading = false;
  int _uploadedCount = 0;

  int get _validCount => _rows.where((r) => r.question != null).length;
  int get _invalidCount => _rows.length - _validCount;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (picked == null || picked.files.single.path == null) return;

    final file = File(picked.files.single.path!);
    final content = await file.readAsString();
    final rows = _parseCsv(content, widget.exam, _repository);

    setState(() {
      _fileName = picked.files.single.name;
      _rows = rows;
    });
  }

  Future<void> _upload() async {
    final toUpload = _rows.where((r) => r.question != null).toList();
    if (toUpload.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadedCount = 0;
    });

    var failed = 0;
    for (final row in toUpload) {
      final result = await _repository.save(row.question!);
      if (!mounted) return;
      switch (result) {
        case Success():
          setState(() => _uploadedCount++);
        case Failure():
          failed++;
      }
    }

    if (!mounted) return;
    setState(() => _uploading = false);

    AuditLogService.instance.log(
      action: AuditActionType.create,
      module: AuditModules.academicStructure,
      targetCollection: 'questions',
      targetId: widget.exam.examId,
      targetTitle: '${widget.exam.title} — bulk import ($_uploadedCount question${_uploadedCount == 1 ? '' : 's'})',
    );

    if (!mounted) return;
    if (failed == 0) {
      AppSnackbar.success(context, 'Uploaded $_uploadedCount question${_uploadedCount == 1 ? '' : 's'}.');
      Navigator.pop(context);
    } else {
      AppSnackbar.error(context, 'Uploaded $_uploadedCount, but $failed failed. Check your connection and try re-uploading the rest.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final headlineColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Upload Questions')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CustomCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CSV format', style: AppTextStyles.bodyLarge(headlineColor).copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'One header row (skipped), then one question per row:\n\n'
                      'type, text, options, correct, explanation, difficulty, topic, points\n\n'
                      '• type: singleChoice, multipleChoice, trueFalse, fillInTheBlank, or shortAnswer\n'
                      '• options: pipe-separated, e.g. Paris|London|Berlin (blank for fillInTheBlank/shortAnswer)\n'
                      '• correct: pipe-separated — must match option text exactly for choice questions, '
                      '"true"/"false" for trueFalse, or accepted answers for fillInTheBlank/shortAnswer\n'
                      '• explanation, difficulty, topic, points are optional',
                      style: AppTextStyles.bodyMedium(bodyColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _fileName == null ? 'Choose CSV File' : 'Choose a different file',
              onPressed: _uploading ? null : _pickFile,
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Text(_fileName!, style: AppTextStyles.bodyMedium(bodyColor)),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(title: 'Preview ($_validCount valid, $_invalidCount with errors)'),
              const SizedBox(height: 8),
              ..._rows.map((row) => _RowPreview(row: row)),
              const SizedBox(height: 20),
              if (_uploading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _uploadedCount / _validCount),
                    const SizedBox(height: 8),
                    Text('Uploading $_uploadedCount of $_validCount…', style: AppTextStyles.bodyMedium(bodyColor)),
                  ],
                )
              else
                PrimaryButton(
                  label: _validCount == 0 ? 'No valid questions to upload' : 'Upload $_validCount question${_validCount == 1 ? '' : 's'}',
                  onPressed: _validCount == 0 ? null : _upload,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowPreview extends StatelessWidget {
  final _ParsedRow row;
  const _RowPreview({required this.row});

  @override
  Widget build(BuildContext context) {
    final ok = row.question != null;
    final textColor = ok
        ? Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary
        : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 18,
            color: ok ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ok ? row.question!.text : 'Row ${row.rowNumber}: ${row.error}',
              style: AppTextStyles.bodyMedium(textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedRow {
  final int rowNumber;
  final QuestionModel? question;
  final String? error;
  _ParsedRow.valid(this.rowNumber, this.question) : error = null;
  _ParsedRow.invalid(this.rowNumber, this.error) : question = null;
}

/// Minimal CSV line splitter — handles double-quoted fields so option/
/// answer text can safely contain commas (e.g. "1,000|2,000|3,000" as
/// an option list would otherwise break on a naive comma-split).
List<String> _splitCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  fields.add(buffer.toString());
  return fields.map((f) => f.trim()).toList();
}

List<_ParsedRow> _parseCsv(String content, ExamModel exam, QuestionRepository repository) {
  final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return [];

  final results = <_ParsedRow>[];
  // Row 1 is the header — data starts at row 2.
  for (var i = 1; i < lines.length; i++) {
    final rowNumber = i + 1;
    final fields = _splitCsvLine(lines[i]);
    if (fields.length < 4) {
      results.add(_ParsedRow.invalid(rowNumber, 'Expected at least type, text, options, correct — found ${fields.length} column(s).'));
      continue;
    }

    final typeStr = fields[0].trim();
    final type = _firstWhereOrNull(QuestionType.values, (t) => t.name.toLowerCase() == typeStr.toLowerCase());
    if (type == null || !supportedQuestionTypes.contains(type)) {
      results.add(_ParsedRow.invalid(rowNumber, '"$typeStr" isn\'t a supported type. Use one of: ${supportedQuestionTypes.map((t) => t.name).join(', ')}.'));
      continue;
    }

    final text = fields[1].trim();
    if (text.isEmpty) {
      results.add(_ParsedRow.invalid(rowNumber, 'Question text is empty.'));
      continue;
    }

    final options = fields[2].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final correctRaw = fields[3].split('|').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final isChoiceType = type == QuestionType.singleChoice || type == QuestionType.multipleChoice;

    if (isChoiceType) {
      if (options.length < 2) {
        results.add(_ParsedRow.invalid(rowNumber, 'Choice questions need at least 2 options.'));
        continue;
      }
      final unmatched = correctRaw.where((c) => !options.contains(c)).toList();
      if (correctRaw.isEmpty || unmatched.isNotEmpty) {
        results.add(_ParsedRow.invalid(rowNumber, unmatched.isNotEmpty
            ? 'Correct answer "${unmatched.first}" doesn\'t match any option text exactly.'
            : 'At least one correct answer is required.'));
        continue;
      }
    } else if (type == QuestionType.trueFalse) {
      final v = correctRaw.isNotEmpty ? correctRaw.first.toLowerCase() : '';
      if (v != 'true' && v != 'false') {
        results.add(_ParsedRow.invalid(rowNumber, 'trueFalse correct answer must be "true" or "false", got "${correctRaw.isEmpty ? '' : correctRaw.first}".'));
        continue;
      }
    } else if (correctRaw.isEmpty) {
      results.add(_ParsedRow.invalid(rowNumber, 'At least one accepted answer is required.'));
      continue;
    }

    final explanation = fields.length > 4 ? fields[4].trim() : '';
    final difficulty = fields.length > 5
        ? _firstWhereOrNull(QuestionDifficulty.values, (d) => d.name.toLowerCase() == fields[5].trim().toLowerCase()) ?? QuestionDifficulty.medium
        : QuestionDifficulty.medium;
    final topic = fields.length > 6 ? fields[6].trim() : '';
    final points = fields.length > 7 ? int.tryParse(fields[7].trim()) ?? 1 : 1;

    final correctOptionIndex = isChoiceType ? options.indexOf(correctRaw.first) : 0;

    results.add(_ParsedRow.valid(
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
    ));
  }
  return results;
}
