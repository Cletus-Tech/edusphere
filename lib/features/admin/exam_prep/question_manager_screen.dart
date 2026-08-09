import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/content_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/exam_model.dart';
import '../../../repositories/learning_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'bulk_question_upload_screen.dart';

/// Only these five [QuestionType]s have real answer-entry UI in
/// [ExamRunnerScreen] and real scoring in `exam_scoring.dart` as of
/// Stage 4.8B — see the Part 1 audit. The other nine decode/round-trip
/// fine but have no student-facing input widget yet, so building an
/// admin editor for them here would create content nobody can actually
/// answer. Restricting the type picker to this list keeps what admins
/// can create in sync with what students can actually sit.
const supportedQuestionTypes = [
  QuestionType.singleChoice,
  QuestionType.multipleChoice,
  QuestionType.trueFalse,
  QuestionType.fillInTheBlank,
  QuestionType.shortAnswer,
];

/// Admin CRUD for `questions/{questionId}` scoped to one exam — Stage
/// 4.8B Part 2, paired with [ExamEditorScreen].
class QuestionManagerScreen extends StatefulWidget {
  final ExamModel exam;
  const QuestionManagerScreen({super.key, required this.exam});

  @override
  State<QuestionManagerScreen> createState() => _QuestionManagerScreenState();
}

class _QuestionManagerScreenState extends State<QuestionManagerScreen> {
  final QuestionRepository _repository = QuestionRepository();
  late final Stream<List<QuestionModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repository.streamCollection(query: (q) => q.where('examId', isEqualTo: widget.exam.examId));
  }

  Future<void> _delete(QuestionModel question) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete this question?',
      message: 'This cannot be undone. Any in-progress sessions that already loaded this '
          'question keep their answer, but it will no longer count toward scoring on resubmission.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await _repository.delete(question.questionId);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: AuditActionType.delete,
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.questionsCollection,
      targetId: question.questionId,
      targetTitle: question.text,
    );
    AppSnackbar.success(context, 'Question deleted.');
  }

  Future<void> _openEditor({QuestionModel? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QuestionEditorScreen(exam: widget.exam, existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam.title} · Questions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Bulk upload from CSV',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BulkQuestionUploadScreen(exam: widget.exam)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<QuestionModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return const ErrorView(message: 'Could not load questions.');
          }
          final questions = snapshot.data ?? const <QuestionModel>[];
          if (questions.isEmpty) {
            return const EmptyView(
              icon: Icons.help_outline_rounded,
              message: 'No questions yet — tap + to add the first one.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final q = questions[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CustomCard(
                  onTap: () => _openEditor(existing: q),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${i + 1}. ${q.text}',
                                style: AppTextStyles.titleMedium(textColor),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(
                              '${q.type.name} · ${q.difficulty.name} · ${q.points} pt${q.points == 1 ? '' : 's'}',
                              style: AppTextStyles.bodySmall(bodyColor),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _openEditor(existing: q);
                            case 'delete':
                              _delete(q);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuestionEditorScreen extends StatefulWidget {
  final ExamModel exam;
  final QuestionModel? existing;
  const _QuestionEditorScreen({required this.exam, this.existing});

  @override
  State<_QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<_QuestionEditorScreen> {
  final QuestionRepository _repository = QuestionRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _textController;
  late final TextEditingController _explanationController;
  late final TextEditingController _topicController;
  late final TextEditingController _pointsController;
  late final TextEditingController _shortAnswerController;
  late List<TextEditingController> _optionControllers;
  late Set<int> _correctOptionIndexes;
  late QuestionType _type;
  late QuestionDifficulty _difficulty;
  bool _trueFalseAnswer = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _textController = TextEditingController(text: e?.text ?? '');
    _explanationController = TextEditingController(text: e?.explanation ?? '');
    _topicController = TextEditingController(text: e?.topic ?? '');
    _pointsController = TextEditingController(text: (e?.points ?? 1).toString());
    _shortAnswerController = TextEditingController(
      text: e != null && (e.type == QuestionType.fillInTheBlank || e.type == QuestionType.shortAnswer)
          ? e.correctAnswers.join(', ')
          : '',
    );

    _type = e?.type ?? QuestionType.singleChoice;
    _difficulty = e?.difficulty ?? QuestionDifficulty.medium;

    final options = (e?.options.isNotEmpty ?? false) ? e!.options : ['', ''];
    _optionControllers = options.map((o) => TextEditingController(text: o)).toList();

    if (e != null && e.type == QuestionType.multipleChoice) {
      _correctOptionIndexes = e.correctAnswers.map(int.parse).toSet();
    } else if (e != null && e.type == QuestionType.singleChoice) {
      _correctOptionIndexes = {
        e.correctAnswers.isNotEmpty ? int.parse(e.correctAnswers.first) : e.correctOptionIndex,
      };
    } else {
      _correctOptionIndexes = {0};
    }

    if (e != null && e.type == QuestionType.trueFalse) {
      _trueFalseAnswer = e.correctAnswers.isNotEmpty ? e.correctAnswers.first == 'true' : true;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _explanationController.dispose();
    _topicController.dispose();
    _pointsController.dispose();
    _shortAnswerController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() => setState(() => _optionControllers.add(TextEditingController()));

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers.removeAt(index).dispose();
      _correctOptionIndexes = _correctOptionIndexes
          .where((i) => i != index)
          .map((i) => i > index ? i - 1 : i)
          .toSet();
    });
  }

  bool get _isChoiceType => _type == QuestionType.singleChoice || _type == QuestionType.multipleChoice;
  bool get _isTextType => _type == QuestionType.fillInTheBlank || _type == QuestionType.shortAnswer;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isChoiceType && _correctOptionIndexes.isEmpty) {
      AppSnackbar.error(context, 'Mark at least one option as correct.');
      return;
    }
    if (_isChoiceType && _optionControllers.any((c) => c.text.trim().isEmpty)) {
      AppSnackbar.error(context, 'Every option needs text.');
      return;
    }

    setState(() => _saving = true);

    final options = _isChoiceType ? _optionControllers.map((c) => c.text.trim()).toList() : <String>[];
    final correctAnswers = switch (_type) {
      QuestionType.singleChoice || QuestionType.multipleChoice =>
        _correctOptionIndexes.map((i) => i.toString()).toList(),
      QuestionType.trueFalse => [_trueFalseAnswer.toString()],
      QuestionType.fillInTheBlank || QuestionType.shortAnswer => _shortAnswerController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      _ => const <String>[],
    };

    final question = QuestionModel(
      questionId: widget.existing?.questionId ?? _repository.newId(),
      examId: widget.exam.examId,
      courseId: widget.exam.courseId,
      text: _textController.text.trim(),
      options: options,
      correctOptionIndex: _type == QuestionType.singleChoice && _correctOptionIndexes.isNotEmpty
          ? _correctOptionIndexes.first
          : (widget.existing?.correctOptionIndex ?? 0),
      explanation: _explanationController.text.trim().isEmpty ? null : _explanationController.text.trim(),
      difficulty: _difficulty,
      topic: _topicController.text.trim().isEmpty ? null : _topicController.text.trim(),
      tags: widget.existing?.tags ?? const [],
      imageUrl: widget.existing?.imageUrl,
      type: _type,
      correctAnswers: correctAnswers,
      typeData: widget.existing?.typeData ?? const {},
      points: int.tryParse(_pointsController.text.trim()) ?? 1,
      premiumExplanation: widget.existing?.premiumExplanation ?? false,
    );

    final result = await _repository.save(question);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Success():
        AuditLogService.instance.log(
          action: widget.existing == null ? AuditActionType.create : AuditActionType.edit,
          module: AuditModules.academicStructure,
          targetCollection: AppConstants.questionsCollection,
          targetId: question.questionId,
          targetTitle: question.text,
        );
        AppSnackbar.success(context, widget.existing == null ? 'Question added.' : 'Question updated.');
        Navigator.pop(context);
      case Failure(message: final m):
        AppSnackbar.error(context, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New Question' : 'Edit Question')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              DropdownButtonFormField<QuestionType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Question type'),
                items: supportedQuestionTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _textController,
                hintText: 'Question text',
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              if (_isChoiceType) ...[
                const SectionHeader(title: 'Options'),
                const SizedBox(height: 8),
                Text(
                  _type == QuestionType.singleChoice
                      ? 'Tap the radio to mark the single correct option.'
                      : 'Check every option that counts as correct.',
                  style: AppTextStyles.bodySmall(AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < _optionControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        if (_type == QuestionType.singleChoice)
                          Radio<int>(
                            value: i,
                            groupValue: _correctOptionIndexes.isEmpty ? null : _correctOptionIndexes.first,
                            onChanged: (v) => setState(() => _correctOptionIndexes = {if (v != null) v}),
                          )
                        else
                          Checkbox(
                            value: _correctOptionIndexes.contains(i),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _correctOptionIndexes.add(i);
                              } else {
                                _correctOptionIndexes.remove(i);
                              }
                            }),
                          ),
                        Expanded(
                          child: AppTextField(controller: _optionControllers[i], hintText: 'Option ${i + 1}'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          onPressed: _optionControllers.length <= 2 ? null : () => _removeOption(i),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add option'),
                ),
              ],

              if (_type == QuestionType.trueFalse) ...[
                const SectionHeader(title: 'Correct answer'),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('True')),
                    ButtonSegment(value: false, label: Text('False')),
                  ],
                  selected: {_trueFalseAnswer},
                  onSelectionChanged: (s) => setState(() => _trueFalseAnswer = s.first),
                ),
              ],

              if (_isTextType) ...[
                const SectionHeader(title: 'Accepted answers'),
                const SizedBox(height: 8),
                Text(
                  'Comma-separated — any one of these (case-insensitive) is marked correct.',
                  style: AppTextStyles.bodySmall(AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _shortAnswerController,
                  hintText: 'e.g. Lagos, lagos state',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'At least one accepted answer' : null,
                ),
              ],

              const SizedBox(height: 24),
              const SectionHeader(title: 'Metadata'),
              const SizedBox(height: 12),
              DropdownButtonFormField<QuestionDifficulty>(
                value: _difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: QuestionDifficulty.values
                    .map((d) => DropdownMenuItem(value: d, child: Text(d.name)))
                    .toList(),
                onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _topicController, hintText: 'Topic (optional)'),
              const SizedBox(height: 12),
              AppTextField(
                controller: _pointsController,
                hintText: 'Points',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _explanationController, hintText: 'Explanation (optional)', maxLines: 3),

              const SizedBox(height: 32),
              PrimaryButton(label: 'Save Question', isLoading: _saving, onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}
