import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/content_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/exam_model.dart';
import '../../../repositories/learning_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import 'exam_editor_screen.dart';
import 'question_manager_screen.dart';

/// Admin CRUD entry point for `exams/{examId}` — Stage 4.8B Part 2.
/// Was the biggest gap the Part 1 audit found: [ExamModel] already had
/// every admin-configurable field the CBT spec calls for (Stage 4.8A),
/// but nothing in the app could actually create or edit one — every
/// exam in Firestore had to be hand-written. This screen (plus
/// [ExamEditorScreen] and [QuestionManagerScreen]) closes that gap.
class ExamManagerScreen extends StatefulWidget {
  const ExamManagerScreen({super.key});

  @override
  State<ExamManagerScreen> createState() => _ExamManagerScreenState();
}

class _ExamManagerScreenState extends State<ExamManagerScreen> {
  final ExamRepository _repository = ExamRepository();
  ExamType? _typeFilter;

  Future<void> _delete(ExamModel exam) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete ${exam.title}?',
      message: 'This removes the exam record. Its questions and any student attempts/sessions '
          'already recorded are not deleted, but will no longer show a valid exam.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await _repository.delete(exam.examId);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.log(
      action: AuditActionType.delete,
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.examsCollection,
      targetId: exam.examId,
      targetTitle: exam.title,
    );
    AppSnackbar.success(context, 'Exam deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Exams')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExamEditorScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(label: 'All', selected: _typeFilter == null, onTap: () => setState(() => _typeFilter = null)),
                ),
                for (final type in ExamType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(
                      label: type.name,
                      selected: _typeFilter == type,
                      onTap: () => setState(() => _typeFilter = type),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ExamModel>>(
              stream: _repository.streamCollection(query: (q) => q.orderBy('title')),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return const ErrorView(message: 'Could not load exams.');
                }
                final exams = (snapshot.data ?? const <ExamModel>[])
                    .where((e) => _typeFilter == null || e.type == _typeFilter)
                    .toList();
                if (exams.isEmpty) {
                  return const EmptyView(
                    icon: Icons.quiz_outlined,
                    message: 'No exams yet — tap + to create the first one.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                  itemCount: exams.length,
                  itemBuilder: (context, i) {
                    final exam = exams[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CustomCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ExamEditorScreen(existing: exam)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(exam.title,
                                            style: AppTextStyles.titleMedium(textColor),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      if (!exam.isActive) ...[
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
                                      if (exam.isPremium) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.highlightOrange.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('Premium', style: AppTextStyles.bodySmall(AppColors.highlightOrange)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    '${exam.type.name} · ${exam.durationMinutes} min · pass ${exam.passMarkPercent}%',
                                    style: AppTextStyles.bodySmall(bodyColor),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => ExamEditorScreen(existing: exam)));
                                  case 'questions':
                                    Navigator.push(context,
                                        MaterialPageRoute(builder: (_) => QuestionManagerScreen(exam: exam)));
                                  case 'delete':
                                    _delete(exam);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit configuration')),
                                PopupMenuItem(value: 'questions', child: Text('Manage questions')),
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
