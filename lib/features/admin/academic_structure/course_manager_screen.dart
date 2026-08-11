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
import 'bulk_course_import_screen.dart';

/// Manages `courses/{courseId}` for one department + level + semester —
/// the bottom of the Stage 4.3 academic hierarchy drill-down from
/// [AcademicStructureScreen]. Reuses [CourseRepository] and
/// [CourseModel] from the Stage 1.2 backend rather than introducing a
/// separate admin-facing course model.
class CourseManagerScreen extends StatefulWidget {
  final String institutionId;
  final String departmentId;
  final String levelId;
  final String semesterId;
  final String parentLabel;

  const CourseManagerScreen({
    super.key,
    required this.institutionId,
    required this.departmentId,
    required this.levelId,
    required this.semesterId,
    required this.parentLabel,
  });

  @override
  State<CourseManagerScreen> createState() => _CourseManagerScreenState();
}

class _CourseManagerScreenState extends State<CourseManagerScreen> {
  final CourseRepository _repository = CourseRepository();
  late final Stream<List<CourseModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repository.streamCollection(
      query: (q) => q
          .where('departmentId', isEqualTo: widget.departmentId)
          .where('levelId', isEqualTo: widget.levelId)
          .where('semesterId', isEqualTo: widget.semesterId),
    );
  }

  Future<void> _openForm({CourseModel? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Course' : 'Edit Course'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: titleController,
                  hintText: 'Course title',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                AppTextField(controller: codeController, hintText: 'Course code (e.g. CPE 301)'),
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

    final course = CourseModel(
      courseId: existing?.courseId ?? _repository.newId(),
      title: titleController.text.trim(),
      code: codeController.text.trim(),
      institutionId: widget.institutionId,
      departmentId: widget.departmentId,
      levelId: widget.levelId,
      semesterId: widget.semesterId,
      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
      contentCount: existing?.contentCount ?? 0,
      isActive: existing?.isActive ?? true,
    );

    final result = await _repository.save(course);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: existing == null ? AuditActionType.create : AuditActionType.edit,
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.coursesCollection,
      targetId: course.courseId,
      targetTitle: course.title,
    );
    AppSnackbar.success(context, existing == null ? 'Course added.' : 'Course updated.');
  }

  Future<void> _delete(CourseModel course) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete ${course.title}?',
      message: 'This removes the course record. Learning materials already attached to it '
          'are not deleted, but will no longer show a valid course.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await _repository.delete(course.courseId);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: AuditActionType.delete,
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.coursesCollection,
      targetId: course.courseId,
      targetTitle: course.title,
    );
    AppSnackbar.success(context, 'Course deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            tooltip: 'Bulk import courses — not limited to this list; each row names its own '
                'institution/faculty/department/level/semester',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BulkCourseImportScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Under ${widget.parentLabel}', style: AppTextStyles.bodySmall(bodyColor)),
          ),
          Expanded(
            child: StreamBuilder<List<CourseModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return const ErrorView(message: 'Could not load courses.');
                }
                final courses = [...(snapshot.data ?? const <CourseModel>[])]
                  ..sort((a, b) => a.title.compareTo(b.title));
                if (courses.isEmpty) {
                  return const EmptyView(
                    icon: Icons.menu_book_outlined,
                    message: 'No courses yet — tap + to add the first one.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  itemCount: courses.length,
                  itemBuilder: (context, i) {
                    final course = courses[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CustomCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(course.title, style: AppTextStyles.titleMedium(textColor)),
                                  if (course.code.isNotEmpty)
                                    Text(course.code, style: AppTextStyles.bodySmall(bodyColor)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _openForm(existing: course);
                                  case 'delete':
                                    _delete(course);
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
