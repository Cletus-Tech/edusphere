import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/audit_action_type.dart';
import '../../../core/enums/content_type.dart';
import '../../../core/utils/result.dart';
import '../../../models/exam_model.dart';
import '../../../models/exam_session_model.dart';
import '../../../repositories/learning_repository.dart';
import '../../../services/audit/audit_log_service.dart';
import '../../../shared/dialogs/app_dialog.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/custom_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../exam_prep/exam_attempt_resolver.dart';
import '../../exam_prep/exam_result_screen.dart';

/// Stage CBT-3 — "Attempt Management". Read access reuses
/// [ExamAttemptRepository.watchRecentForAdmin] (new this stage, but a
/// thin, single-query extension of the existing repository — not a
/// second attempt system) and the existing [ExamAttemptResolver] for
/// the examId -> [ExamModel] join. Deletion reuses the inherited
/// `delete()` from [BaseRepository] — `firestore.rules` already
/// restricts `exam_attempts` update/delete to `isAdmin()`, so this
/// screen exposes a capability the security model already anticipated,
/// rather than adding a new one.
///
/// What this deliberately does NOT do: reset/edit an attempt's score,
/// or resume it on the student's behalf. [ExamAttemptModel] is
/// immutable-by-design once submitted (see [ExamAttemptRepository]'s
/// own doc comment on why it's a separate collection from sessions) —
/// the only admin action that respects that is delete (e.g. removing a
/// duplicate or erroneous record), never a silent edit.
class CbtAttemptManagementScreen extends StatefulWidget {
  const CbtAttemptManagementScreen({super.key});

  @override
  State<CbtAttemptManagementScreen> createState() => _CbtAttemptManagementScreenState();
}

class _CbtAttemptManagementScreenState extends State<CbtAttemptManagementScreen> {
  final ExamAttemptRepository _repository = ExamAttemptRepository();
  final ExamAttemptResolver _resolver = ExamAttemptResolver();
  ExamMode? _modeFilter;

  Future<void> _delete(ExamAttemptModel attempt, ExamModel exam) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete this attempt?',
      message: '${exam.title} — this permanently removes the attempt record. '
          'It will no longer count toward the student\'s attempt limit or history.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    final result = await _repository.delete(attempt.attemptId);
    if (!mounted) return;
    if (result case Failure(message: final m)) {
      AppSnackbar.error(context, m);
      return;
    }
    AuditLogService.instance.logDelete(
      module: AuditModules.academicStructure,
      targetCollection: AppConstants.examAttemptsCollection,
      targetId: attempt.attemptId,
      targetTitle: '${exam.title} attempt',
    );
    AppSnackbar.success(context, 'Attempt deleted.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attempt Management')),
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
                  child: AppChip(label: 'All', selected: _modeFilter == null, onTap: () => setState(() => _modeFilter = null)),
                ),
                for (final mode in ExamMode.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AppChip(
                      label: mode.name,
                      selected: _modeFilter == mode,
                      onTap: () => setState(() => _modeFilter = mode),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ExamAttemptModel>>(
              stream: _repository.watchRecentForAdmin(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LoadingView();
                if (snapshot.hasError) return const ErrorView(message: 'Could not load attempts.');

                final attempts = (snapshot.data ?? const <ExamAttemptModel>[])
                    .where((a) => _modeFilter == null || a.mode == _modeFilter)
                    .toList();
                if (attempts.isEmpty) {
                  return const EmptyView(icon: Icons.fact_check_outlined, message: 'No attempts recorded yet.');
                }

                _resolver.ensureCached(attempts, () {
                  if (mounted) setState(() {});
                });
                final matched = _resolver.matchAll(attempts);

                if (matched.isEmpty && _resolver.isResolving(attempts)) return const LoadingView();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: matched.length,
                  itemBuilder: (context, i) {
                    final (attempt, exam) = matched[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AttemptRow(
                        attempt: attempt,
                        exam: exam,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ExamResultScreen(exam: exam, attempt: attempt)),
                        ),
                        onDelete: () => _delete(attempt, exam),
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

class _AttemptRow extends StatelessWidget {
  final ExamAttemptModel attempt;
  final ExamModel exam;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AttemptRow({required this.attempt, required this.exam, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final scoreColor = attempt.passed ? AppColors.success : AppColors.error;

    return CustomCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exam.title,
                        style: AppTextStyles.bodyLarge(titleColor).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppChip(label: attempt.mode.name, accent: AppColors.secondaryIndigo),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'User ${attempt.userId} · ${_formatDate(attempt.submittedAt)}',
                  style: AppTextStyles.bodySmall(bodyColor),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${attempt.scorePercent.toStringAsFixed(0)}%', style: AppTextStyles.titleMedium(scoreColor)),
              Text(attempt.passed ? 'Passed' : 'Failed', style: AppTextStyles.bodySmall(scoreColor)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
