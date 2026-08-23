import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/combination_rule_model.dart';
import '../../../models/course_model.dart';
import '../../../repositories/combination_rule_repository.dart';
import '../../../repositories/course_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Stage 4.5 Part 5 — manages `subjects/{subjectId}` for one exam-prep
/// category (`categoryId: 'waec'` today). Deliberately not
/// `WaecSubjectManagerScreen`: mirrors [CourseManagerScreen]'s exact
/// CRUD pattern (same dialogs, same audit logging, same
/// confirm-before-delete) but targets [SubjectRepository] and
/// `categoryId` instead of [CourseRepository] and
/// department/level/semester, since subjects don't sit under the
/// University academic hierarchy. Stage 4.6 (NECO) should reuse this
/// file with `categoryId: 'neco'` rather than duplicating it.
class SubjectManagerScreen extends StatefulWidget {
  final String categoryId;
  final String categoryLabel;

  const SubjectManagerScreen({super.key, required this.categoryId, required this.categoryLabel});

  @override
  State<SubjectManagerScreen> createState() => _SubjectManagerScreenState();
}

class _SubjectManagerScreenState extends State<SubjectManagerScreen> {
  final SubjectRepository _repository = SubjectRepository();
  final CombinationRuleRepository _ruleRepository = CombinationRuleRepository();
  late final Stream<List<CourseModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repository.watchByCategory(widget.categoryId);
  }

  /// Stage CBT-Refactor Phase 5 — Part 7 admin control. Lets an admin
  /// set the compulsory subject (e.g. "Use of English" for JAMB) and
  /// required subject count for this category, rather than either
  /// being hardcoded. Reuses this exact screen (where the category's
  /// subjects already live) instead of a disconnected new admin
  /// system, per the phase brief's Part 7 instruction.
  Future<void> _openCombinationRuleDialog(List<CourseModel> subjects) async {
    final currentRule = await _ruleRepository.watchForCategory(widget.categoryId).first;
    if (!mounted) return;

    String? selectedCompulsoryId = currentRule.compulsorySubjectId;
    final countController = TextEditingController(text: '${currentRule.requiredSubjectCount}');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Subject Combination Rule'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Controls the ${widget.categoryLabel} subject-selection flow students see '
                    '(e.g. English locked + 3 more for JAMB).',
                    style: AppTextStyles.bodySmall(AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: selectedCompulsoryId,
                    decoration: const InputDecoration(labelText: 'Compulsory subject (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None')),
                      ...subjects.map((s) => DropdownMenuItem<String?>(value: s.courseId, child: Text(s.title))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCompulsoryId = v),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: countController,
                    hintText: 'Required subject count (e.g. 4)',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Enter a whole number of 1 or more';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final result = await _ruleRepository.setCompulsorySubject(
      widget.categoryId,
      selectedCompulsoryId,
      requiredSubjectCount: int.parse(countController.text.trim()),
    );
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AppSnackbar.success(context, 'Combination rule updated.');
  }

  Future<void> _openForm({CourseModel? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Subject' : 'Edit Subject'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: titleController,
                  hintText: 'Subject name (e.g. Mathematics)',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(controller: codeController, hintText: 'Subject code (optional)'),
                const SizedBox(height: 12),
                AppTextField(controller: descriptionController, hintText: 'Description (optional)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final subject = CourseModel(
      courseId: existing?.courseId ?? _repository.newId(),
      title: titleController.text.trim(),
      code: codeController.text.trim(),
      categoryId: widget.categoryId,
      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
      contentCount: existing?.contentCount ?? 0,
      isActive: existing?.isActive ?? true,
    );

    final result = await _repository.save(subject);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: existing == null ? AuditActionType.create : AuditActionType.edit,
      module: AuditModules.examPrep,
      targetCollection: AppConstants.subjectsCollection,
      targetId: subject.courseId,
      targetTitle: subject.title,
    );
    AppSnackbar.success(context, existing == null ? 'Subject added.' : 'Subject updated.');
  }

  Future<void> _delete(CourseModel subject) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete ${subject.title}?',
      message: 'This removes the subject record. Learning materials already attached to it '
          'are not deleted, but will no longer show a valid subject.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await _repository.delete(subject.courseId);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: AuditActionType.delete,
      module: AuditModules.examPrep,
      targetCollection: AppConstants.subjectsCollection,
      targetId: subject.courseId,
      targetTitle: subject.title,
    );
    AppSnackbar.success(context, 'Subject deleted.');
  }

  // Stage CBT-Refactor Phase 5 — helper for the combination-rule
  // summary line above (`package:collection`'s `firstOrNull` isn't a
  // dependency here, per this file's earlier precedent).
  String _findTitle(List<CourseModel> subjects, String id) {
    for (final s in subjects) {
      if (s.courseId == id) return s.title;
    }
    return 'Unknown subject';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.categoryLabel} Subjects')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Manage subjects for ${widget.categoryLabel}. Attach study materials, past '
              'questions, and practice content to each subject from Learning Materials.',
              style: AppTextStyles.bodySmall(bodyColor),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CourseModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return const ErrorView(message: 'Could not load subjects.');
                }
                final subjects = [...(snapshot.data ?? const <CourseModel>[])]
                  ..sort((a, b) => a.title.compareTo(b.title));
                if (subjects.isEmpty) {
                  return EmptyView(
                    icon: Icons.menu_book_outlined,
                    message: 'No ${widget.categoryLabel} subjects yet — tap + to add the first one.',
                  );
                }
                return StreamBuilder<CombinationRuleModel>(
                  stream: _ruleRepository.watchForCategory(widget.categoryId),
                  builder: (context, ruleSnapshot) {
                    final rule = ruleSnapshot.data ?? CombinationRuleModel(categoryId: widget.categoryId);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rule.compulsorySubjectId == null
                                      ? 'No combination rule set — required count: ${rule.requiredSubjectCount}'
                                      : 'Compulsory: ${_findTitle(subjects, rule.compulsorySubjectId!)} · '
                                          'Required: ${rule.requiredSubjectCount}',
                                  style: AppTextStyles.bodySmall(bodyColor),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _openCombinationRuleDialog(subjects),
                                child: const Text('Combination Rule'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                            itemCount: subjects.length,
                            itemBuilder: (context, i) {
                              final subject = subjects[i];
                              final isCompulsory = subject.courseId == rule.compulsorySubjectId;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: CustomCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(subject.title, style: AppTextStyles.titleMedium(textColor)),
                                                if (isCompulsory) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryBlue.withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'Compulsory',
                                                      style: AppTextStyles.bodySmall(AppColors.primaryBlue),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (subject.code.isNotEmpty)
                                              Text(subject.code, style: AppTextStyles.bodySmall(bodyColor)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'edit':
                                              _openForm(existing: subject);
                                            case 'delete':
                                              _delete(subject);
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
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
