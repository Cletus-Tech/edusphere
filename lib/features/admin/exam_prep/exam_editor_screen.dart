import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/content_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/exam_model.dart';
import '../../../repositories/learning_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Create/edit screen for one [ExamModel] — every admin-configurable
/// field from the CBT spec's section 18 in one place: identity,
/// question/timing settings, marking, navigation rules, calculator,
/// results visibility, access/offline, and attempts. Stage 4.8B Part 2.
class ExamEditorScreen extends StatefulWidget {
  final ExamModel? existing;
  const ExamEditorScreen({super.key, this.existing});

  @override
  State<ExamEditorScreen> createState() => _ExamEditorScreenState();
}

class _ExamEditorScreenState extends State<ExamEditorScreen> {
  final ExamRepository _repository = ExamRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _courseIdController;
  late final TextEditingController _subjectIdController;
  late final TextEditingController _yearController;
  late final TextEditingController _paperController;
  late final TextEditingController _durationController;
  late final TextEditingController _totalQuestionsController;
  late final TextEditingController _passMarkController;
  late final TextEditingController _negativeMarkController;
  late final TextEditingController _attemptLimitController;

  late ExamType _type;
  late bool _isActive;
  late CalculatorType _calculatorType;
  late bool _negativeMarkingEnabled;
  late bool _shuffleQuestions;
  late bool _shuffleOptions;
  late bool _isPremium;
  late bool _offlineAvailable;
  late bool _proctoringEnabled;
  late Set<ExamMode> _supportedModes;
  late bool _allowBackNavigation;
  late bool _allowFlagging;
  late bool _allowSkipping;
  late bool _requireReviewBeforeSubmit;
  late bool _showResultsImmediately;
  DateTime? _availableFrom;
  DateTime? _availableUntil;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _courseIdController = TextEditingController(text: e?.courseId ?? '');
    _subjectIdController = TextEditingController(text: e?.subjectId ?? '');
    _yearController = TextEditingController(text: e?.year?.toString() ?? '');
    _paperController = TextEditingController(text: e?.paper ?? '');
    _durationController = TextEditingController(text: (e?.durationMinutes ?? 60).toString());
    _totalQuestionsController = TextEditingController(text: (e?.totalQuestions ?? 0).toString());
    _passMarkController = TextEditingController(text: (e?.passMarkPercent ?? 50).toString());
    _negativeMarkController = TextEditingController(text: (e?.negativeMarkPercent ?? 0).toString());
    _attemptLimitController = TextEditingController(text: e?.attemptLimit?.toString() ?? '');

    _type = e?.type ?? ExamType.cbt;
    _isActive = e?.isActive ?? true;
    _calculatorType = e?.calculatorType ?? CalculatorType.none;
    _negativeMarkingEnabled = e?.negativeMarkingEnabled ?? false;
    _shuffleQuestions = e?.shuffleQuestions ?? false;
    _shuffleOptions = e?.shuffleOptions ?? false;
    _isPremium = e?.isPremium ?? false;
    _offlineAvailable = e?.offlineAvailable ?? false;
    _proctoringEnabled = e?.proctoringEnabled ?? false;
    _supportedModes = {...(e?.supportedModes ?? const [ExamMode.official, ExamMode.practice, ExamMode.mock])};
    _allowBackNavigation = e?.allowBackNavigation ?? true;
    _allowFlagging = e?.allowFlagging ?? true;
    _allowSkipping = e?.allowSkipping ?? true;
    _requireReviewBeforeSubmit = e?.requireReviewBeforeSubmit ?? false;
    _showResultsImmediately = e?.showResultsImmediately ?? true;
    _availableFrom = e?.availableFrom;
    _availableUntil = e?.availableUntil;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseIdController.dispose();
    _subjectIdController.dispose();
    _yearController.dispose();
    _paperController.dispose();
    _durationController.dispose();
    _totalQuestionsController.dispose();
    _passMarkController.dispose();
    _negativeMarkController.dispose();
    _attemptLimitController.dispose();
    super.dispose();
  }

  Future<void> _pickAvailableFrom() async {
    final result = await _pickDateTime(_availableFrom);
    setState(() => _availableFrom = result);
  }

  Future<void> _pickAvailableUntil() async {
    final result = await _pickDateTime(_availableUntil);
    setState(() => _availableUntil = result);
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return initial;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return date;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_supportedModes.isEmpty) {
      AppSnackbar.error(context, 'Select at least one supported exam mode.');
      return;
    }
    setState(() => _saving = true);

    final exam = ExamModel(
      examId: widget.existing?.examId ?? _repository.newId(),
      title: _titleController.text.trim(),
      type: _type,
      courseId: _courseIdController.text.trim().isEmpty ? null : _courseIdController.text.trim(),
      subjectId: _subjectIdController.text.trim().isEmpty ? null : _subjectIdController.text.trim(),
      year: _yearController.text.trim().isEmpty ? null : int.tryParse(_yearController.text.trim()),
      paper: _paperController.text.trim().isEmpty ? null : _paperController.text.trim(),
      durationMinutes: int.tryParse(_durationController.text.trim()) ?? 60,
      totalQuestions: int.tryParse(_totalQuestionsController.text.trim()) ?? 0,
      passMarkPercent: int.tryParse(_passMarkController.text.trim()) ?? 50,
      isActive: _isActive,
      metadata: widget.existing?.metadata ?? const {},
      calculatorType: _calculatorType,
      negativeMarkingEnabled: _negativeMarkingEnabled,
      negativeMarkPercent: int.tryParse(_negativeMarkController.text.trim()) ?? 0,
      shuffleQuestions: _shuffleQuestions,
      shuffleOptions: _shuffleOptions,
      attemptLimit: _attemptLimitController.text.trim().isEmpty
          ? null
          : int.tryParse(_attemptLimitController.text.trim()),
      availableFrom: _availableFrom,
      availableUntil: _availableUntil,
      isPremium: _isPremium,
      offlineAvailable: _offlineAvailable,
      proctoringEnabled: _proctoringEnabled,
      supportedModes: _supportedModes.toList(),
      allowBackNavigation: _allowBackNavigation,
      allowFlagging: _allowFlagging,
      allowSkipping: _allowSkipping,
      requireReviewBeforeSubmit: _requireReviewBeforeSubmit,
      showResultsImmediately: _showResultsImmediately,
    );

    final result = await _repository.save(exam);
    if (!mounted) return;
    setState(() => _saving = false);

    switch (result) {
      case Success():
        AuditLogService.instance.log(
          action: widget.existing == null ? AuditActionType.create : AuditActionType.edit,
          module: AuditModules.academicStructure,
          targetCollection: AppConstants.examsCollection,
          targetId: exam.examId,
          targetTitle: exam.title,
        );
        AppSnackbar.success(context, widget.existing == null ? 'Exam created.' : 'Exam updated.');
        Navigator.pop(context);
      case Failure(message: final m):
        AppSnackbar.error(context, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New Exam' : 'Edit Exam')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const SectionHeader(title: 'Identity'),
              const SizedBox(height: 12),
              AppTextField(
                controller: _titleController,
                hintText: 'Exam title',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExamType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Exam type'),
                items: ExamType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: _courseIdController, hintText: 'Course ID (optional)'),
              const SizedBox(height: 12),
              AppTextField(controller: _subjectIdController, hintText: 'Subject ID (optional)'),
              const SizedBox(height: 12),
              // Stage CBT-Refactor Phase 3 — only meaningful for board
              // exams (WAEC/NECO), but harmless to leave visible for
              // every type: an admin creating a JAMB/CBT/practice exam
              // just leaves these blank, same as courseId/subjectId
              // above for non-course exams.
              AppTextField(controller: _yearController, hintText: 'Year, e.g. 2024 (WAEC/NECO only)'),
              const SizedBox(height: 12),
              AppTextField(controller: _paperController, hintText: 'Paper, e.g. Paper 1 (WAEC/NECO only)'),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Inactive exams are hidden from students entirely.'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Supported modes'),
              const SizedBox(height: 8),
              Text('Which modes a student may start this exam in.', style: AppTextStyles.bodySmall(bodyColor)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ExamMode.values.map((mode) {
                  final selected = _supportedModes.contains(mode);
                  return FilterChip(
                    label: Text(mode.name),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _supportedModes.add(mode);
                      } else {
                        _supportedModes.remove(mode);
                      }
                    }),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Question settings & timing'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _totalQuestionsController,
                      hintText: 'Total questions',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _durationController,
                      hintText: 'Duration (minutes)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shuffle questions'),
                value: _shuffleQuestions,
                onChanged: (v) => setState(() => _shuffleQuestions = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Shuffle options'),
                value: _shuffleOptions,
                onChanged: (v) => setState(() => _shuffleOptions = v),
              ),
              const SizedBox(height: 8),
              _DateRow(label: 'Available from', value: _availableFrom, onPick: _pickAvailableFrom),
              _DateRow(label: 'Available until', value: _availableUntil, onPick: _pickAvailableUntil),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Marking'),
              const SizedBox(height: 12),
              AppTextField(
                controller: _passMarkController,
                hintText: 'Pass mark (%)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Negative marking'),
                value: _negativeMarkingEnabled,
                onChanged: (v) => setState(() => _negativeMarkingEnabled = v),
              ),
              if (_negativeMarkingEnabled) ...[
                const SizedBox(height: 8),
                AppTextField(
                  controller: _negativeMarkController,
                  hintText: 'Negative mark (% deducted per wrong answer)',
                  keyboardType: TextInputType.number,
                ),
              ],

              const SizedBox(height: 24),
              const SectionHeader(title: 'Navigation rules'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow back navigation'),
                value: _allowBackNavigation,
                onChanged: (v) => setState(() => _allowBackNavigation = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow flagging questions'),
                value: _allowFlagging,
                onChanged: (v) => setState(() => _allowFlagging = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow skipping unanswered questions'),
                value: _allowSkipping,
                onChanged: (v) => setState(() => _allowSkipping = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require review screen before submit'),
                subtitle: const Text('Reserved for the review/retry screen (not yet built).'),
                value: _requireReviewBeforeSubmit,
                onChanged: (v) => setState(() => _requireReviewBeforeSubmit = v),
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Calculator'),
              const SizedBox(height: 8),
              DropdownButtonFormField<CalculatorType>(
                value: _calculatorType,
                decoration: const InputDecoration(labelText: 'Calculator access'),
                items: CalculatorType.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _calculatorType = v ?? _calculatorType),
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Results'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show results immediately'),
                subtitle: const Text('Off = students see "submission received" until you release results.'),
                value: _showResultsImmediately,
                onChanged: (v) => setState(() => _showResultsImmediately = v),
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Access & offline'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Premium'),
                subtitle: const Text('Access enforcement wires into the future subscription system.'),
                value: _isPremium,
                onChanged: (v) => setState(() => _isPremium = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Offline available'),
                value: _offlineAvailable,
                onChanged: (v) => setState(() => _offlineAvailable = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Proctoring enabled'),
                subtitle: const Text('Reserves this exam for the future Proctoring Engine.'),
                value: _proctoringEnabled,
                onChanged: (v) => setState(() => _proctoringEnabled = v),
              ),

              const SizedBox(height: 24),
              const SectionHeader(title: 'Attempts'),
              const SizedBox(height: 8),
              AppTextField(
                controller: _attemptLimitController,
                hintText: 'Attempt limit (leave blank for unlimited)',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 32),
              PrimaryButton(label: 'Save Exam', isLoading: _saving, onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  const _DateRow({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? '$label: not set' : '$label: ${value!.toLocal()}'.split('.').first,
              style: AppTextStyles.bodyMedium(bodyColor),
            ),
          ),
          TextButton(onPressed: onPick, child: const Text('Set')),
        ],
      ),
    );
  }
}
