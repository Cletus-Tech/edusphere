import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/course_model.dart';
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
  late final Stream<List<CourseModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repository.watchByCategory(widget.categoryId);
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
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  itemCount: subjects.length,
                  itemBuilder: (context, i) {
                    final subject = subjects[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CustomCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subject.title, style: AppTextStyles.titleMedium(textColor)),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
