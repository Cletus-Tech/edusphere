import 'package:flutter/material.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/institution_model.dart';
import '../../../repositories/base_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Manages one level of the academic tree — Faculty, Department, Level,
/// or Semester. All four share [AcademicNodeModel]'s shape (Stage 1.2),
/// so this single screen drives all four rather than four near-identical
/// copies: `AcademicStructureScreen` supplies the right repository,
/// labels, and `institutionId`/`parentId` for whichever level is being
/// managed, and [onOpenChild] for drilling down to the next level (or to
/// Course management at the Semester level).
///
/// Stage 4.3 — Academic Structure & Education Hierarchy.
class AcademicNodeManagerScreen extends StatefulWidget {
  final BaseRepository<AcademicNodeModel> repository;
  final String targetCollection;
  final String levelLabel; // e.g. "Faculty", "Department", "Level", "Semester"
  final String parentLabel; // name of the parent node, for the app bar subtitle
  final String institutionId;
  final String? parentId; // null only for Faculty (parent is the institution itself)
  final void Function(BuildContext context, AcademicNodeModel node)? onOpenChild;
  final String childLabel; // e.g. "Departments" — shown on each row's trailing action

  const AcademicNodeManagerScreen({
    super.key,
    required this.repository,
    required this.targetCollection,
    required this.levelLabel,
    required this.parentLabel,
    required this.institutionId,
    required this.parentId,
    required this.childLabel,
    this.onOpenChild,
  });

  @override
  State<AcademicNodeManagerScreen> createState() => _AcademicNodeManagerScreenState();
}

class _AcademicNodeManagerScreenState extends State<AcademicNodeManagerScreen> {
  late final Stream<List<AcademicNodeModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.streamCollection(
      query: (q) => q
          .where('institutionId', isEqualTo: widget.institutionId)
          .where('parentId', isEqualTo: widget.parentId),
    );
  }

  Future<void> _openForm({AcademicNodeModel? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    final orderController = TextEditingController(text: (existing?.order ?? 0).toString());
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add ${widget.levelLabel}' : 'Edit ${widget.levelLabel}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameController,
                hintText: '${widget.levelLabel} name',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(controller: codeController, hintText: 'Code (optional)'),
              const SizedBox(height: 12),
              AppTextField(
                controller: orderController,
                hintText: 'Display order',
                keyboardType: TextInputType.number,
              ),
            ],
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

    final node = AcademicNodeModel(
      nodeId: existing?.nodeId ?? widget.repository.newId(),
      institutionId: widget.institutionId,
      parentId: widget.parentId,
      name: nameController.text.trim(),
      code: codeController.text.trim().isEmpty ? null : codeController.text.trim(),
      order: int.tryParse(orderController.text.trim()) ?? 0,
      isActive: existing?.isActive ?? true,
    );

    final result = await widget.repository.save(node);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }

    AuditLogService.instance.log(
      action: existing == null ? AuditActionType.create : AuditActionType.edit,
      module: AuditModules.academicStructure,
      targetCollection: widget.targetCollection,
      targetId: node.nodeId,
      targetTitle: node.name,
    );
    AppSnackbar.success(context, existing == null ? '${widget.levelLabel} added.' : '${widget.levelLabel} updated.');
  }

  Future<void> _toggleActive(AcademicNodeModel node) async {
    final updated = AcademicNodeModel(
      nodeId: node.nodeId,
      institutionId: node.institutionId,
      parentId: node.parentId,
      name: node.name,
      code: node.code,
      order: node.order,
      isActive: !node.isActive,
    );
    final result = await widget.repository.save(updated);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: updated.isActive ? AuditActionType.restore : AuditActionType.archive,
      module: AuditModules.academicStructure,
      targetCollection: widget.targetCollection,
      targetId: node.nodeId,
      targetTitle: node.name,
    );
  }

  Future<void> _delete(AcademicNodeModel node) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete ${node.name}?',
      message: 'This removes the ${widget.levelLabel.toLowerCase()} record. '
          'Anything nested under it (e.g. ${widget.childLabel.toLowerCase()}) will be orphaned, '
          'not deleted — remove those first if you no longer need them.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await widget.repository.delete(node.nodeId);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: AuditActionType.delete,
      module: AuditModules.academicStructure,
      targetCollection: widget.targetCollection,
      targetId: node.nodeId,
      targetTitle: node.name,
    );
    AppSnackbar.success(context, '${widget.levelLabel} deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.levelLabel}s'),
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
            child: StreamBuilder<List<AcademicNodeModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return ErrorView(message: 'Could not load ${widget.levelLabel.toLowerCase()}s.');
                }
                final nodes = [...(snapshot.data ?? const <AcademicNodeModel>[])]
                  ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.name.compareTo(b.name));
                if (nodes.isEmpty) {
                  return EmptyView(
                    icon: Icons.account_tree_outlined,
                    message: 'No ${widget.levelLabel.toLowerCase()}s yet — tap + to add the first one.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                  itemCount: nodes.length,
                  itemBuilder: (context, i) {
                    final node = nodes[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CustomCard(
                        onTap: widget.onOpenChild == null ? null : () => widget.onOpenChild!(context, node),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(node.name,
                                            style: AppTextStyles.titleMedium(textColor),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      if (!node.isActive) ...[
                                        const SizedBox(width: 8),
                                        _InactiveBadge(),
                                      ],
                                    ],
                                  ),
                                  if (node.code != null && node.code!.isNotEmpty)
                                    Text(node.code!, style: AppTextStyles.bodySmall(bodyColor)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _openForm(existing: node);
                                  case 'toggle':
                                    _toggleActive(node);
                                  case 'delete':
                                    _delete(node);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(node.isActive ? 'Deactivate' : 'Reactivate'),
                                ),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                            if (widget.onOpenChild != null)
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

class _InactiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('Inactive', style: AppTextStyles.bodySmall(AppColors.textSecondary)),
    );
  }
}
