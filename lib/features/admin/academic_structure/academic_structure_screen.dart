import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/institution_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/institution_model.dart';
import '../../../repositories/institution_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'academic_node_manager_screen.dart';
import 'bulk_academic_node_import_screen.dart';
import 'bulk_course_import_screen.dart';
import 'bulk_institution_import_screen.dart';
import 'course_manager_screen.dart';

/// Top of the academic hierarchy — Stage 4.3. Institutions list here;
/// tapping one drills into Faculties → Departments → Levels →
/// Semesters → Courses, each level reusing
/// [AcademicNodeManagerScreen] (or [CourseManagerScreen] at the
/// bottom), matching the reuse rule in the Stage 4.3 brief.
class AcademicStructureScreen extends StatefulWidget {
  const AcademicStructureScreen({super.key});

  @override
  State<AcademicStructureScreen> createState() => _AcademicStructureScreenState();
}

class _AcademicStructureScreenState extends State<AcademicStructureScreen> {
  final InstitutionRepository _repository = InstitutionRepository();

  Future<void> _openForm({InstitutionModel? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final shortNameController = TextEditingController(text: existing?.shortName ?? '');
    final stateController = TextEditingController(text: existing?.state ?? '');
    InstitutionType selectedType = existing?.type ?? InstitutionType.university;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Institution' : 'Edit Institution'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    hintText: 'Institution name',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(controller: shortNameController, hintText: 'Short name (e.g. FUTA)'),
                  const SizedBox(height: 12),
                  AppTextField(controller: stateController, hintText: 'State (optional)'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<InstitutionType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Institution type'),
                    items: InstitutionType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedType = v);
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

    final institution = InstitutionModel(
      institutionId: existing?.institutionId ?? _repository.newId(),
      name: nameController.text.trim(),
      shortName: shortNameController.text.trim(),
      type: selectedType,
      state: stateController.text.trim().isEmpty ? null : stateController.text.trim(),
      isActive: existing?.isActive ?? true,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    final result = await _repository.save(institution);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: existing == null ? AuditActionType.create : AuditActionType.edit,
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.institutionsCollection,
      targetId: institution.institutionId,
      targetTitle: institution.name,
    );
    AppSnackbar.success(context, existing == null ? 'Institution added.' : 'Institution updated.');
  }

  Future<void> _delete(InstitutionModel institution) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete ${institution.name}?',
      message: 'Faculties, departments, levels, semesters, and courses nested under this '
          'institution will be orphaned, not deleted — remove those first if you no longer need them.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await _repository.delete(institution.institutionId);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: AuditActionType.delete,
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.institutionsCollection,
      targetId: institution.institutionId,
      targetTitle: institution.name,
    );
    AppSnackbar.success(context, 'Institution deleted.');
  }

  void _openFaculties(InstitutionModel institution) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademicNodeManagerScreen(
          repository: FacultyRepository(),
          targetCollection: AppConstants.facultiesCollection,
          levelLabel: 'Faculty',
          parentLabel: institution.name,
          institutionId: institution.institutionId,
          parentId: null,
          childLabel: 'Departments',
          onOpenChild: (context, faculty) => _openDepartments(institution, faculty),
        ),
      ),
    );
  }

  void _openDepartments(InstitutionModel institution, AcademicNodeModel node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademicNodeManagerScreen(
          repository: DepartmentRepository(),
          targetCollection: AppConstants.departmentsCollection,
          levelLabel: 'Department',
          parentLabel: node.name,
          institutionId: institution.institutionId,
          parentId: node.nodeId,
          childLabel: 'Levels',
          onOpenChild: (context, department) => _openLevels(institution, department),
        ),
      ),
    );
  }

  void _openLevels(InstitutionModel institution, AcademicNodeModel node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademicNodeManagerScreen(
          repository: LevelRepository(),
          targetCollection: AppConstants.levelsCollection,
          levelLabel: 'Level',
          parentLabel: node.name,
          institutionId: institution.institutionId,
          parentId: node.nodeId,
          childLabel: 'Semesters',
          onOpenChild: (context, level) => _openSemesters(institution, node, level),
        ),
      ),
    );
  }

  void _openSemesters(InstitutionModel institution, AcademicNodeModel department, AcademicNodeModel level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademicNodeManagerScreen(
          repository: SemesterRepository(),
          targetCollection: AppConstants.semestersCollection,
          levelLabel: 'Semester',
          parentLabel: level.name,
          institutionId: institution.institutionId,
          parentId: level.nodeId,
          childLabel: 'Courses',
          onOpenChild: (context, semester) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseManagerScreen(
                institutionId: institution.institutionId,
                departmentId: department.nodeId,
                levelId: level.nodeId,
                semesterId: semester.nodeId,
                parentLabel: '${department.name} · ${level.name} · ${semester.name}',
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Structure'),
        actions: [
          IconButton(
            tooltip: 'Bulk import institutions',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BulkInstitutionImportScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Bulk import faculties/departments/levels/semesters',
            icon: const Icon(Icons.account_tree_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BulkAcademicNodeImportScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Bulk import courses',
            icon: const Icon(Icons.menu_book_rounded),
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
            child: Text(
              'Institutions → Faculties → Departments → Levels → Semesters → Courses.',
              style: AppTextStyles.bodySmall(bodyColor),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InstitutionModel>>(
              stream: _repository.streamCollection(query: (q) => q.orderBy('name')),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return const ErrorView(message: 'Could not load institutions.');
                }
                final institutions = snapshot.data ?? const <InstitutionModel>[];
                if (institutions.isEmpty) {
                  return const EmptyView(
                    icon: Icons.account_balance_outlined,
                    message: 'No institutions yet — tap + to add the first one.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  itemCount: institutions.length,
                  itemBuilder: (context, i) {
                    final institution = institutions[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CustomCard(
                        onTap: () => _openFaculties(institution),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(institution.name,
                                            style: AppTextStyles.titleMedium(textColor),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      if (!institution.isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.textSecondary.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('Inactive', style: AppTextStyles.bodySmall(AppColors.textSecondary)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    institution.state == null
                                        ? institution.type.label
                                        : '${institution.type.label} · ${institution.state}',
                                    style: AppTextStyles.bodySmall(bodyColor),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _openForm(existing: institution);
                                  case 'delete':
                                    _delete(institution);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
