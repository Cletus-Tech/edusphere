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

const _indexBasedTypes = {QuestionType.singleChoice, QuestionType.multipleChoice, QuestionType.trueFalse};

/// One question found to need repair, with the fix already computed —
/// [_RepairFinding.isResolvable] false means every entry in
/// `correctAnswers` failed both checks (not already a valid index, and
/// doesn't match any option's text either) and needs a person to look
/// at it directly; this tool never guesses in that case.
class _RepairFinding {
  final QuestionModel original;
  final List<String>? repairedAnswers; // null when unresolvable
  final int? repairedOptionIndex;
  const _RepairFinding({required this.original, this.repairedAnswers, this.repairedOptionIndex});

  bool get isResolvable => repairedAnswers != null;
}

/// Stage CBT-REFACTOR Phase 1 — "fixing the uploader only fixes future
/// uploads." This scans every existing question of an index-based type
/// ([QuestionType.singleChoice]/[multipleChoice]/[trueFalse] — the
/// types [exam_scoring.dart]'s `_isAnswerCorrect` compares against a
/// stringified option index) for the exact bug
/// `bulk_question_upload_screen.dart` and `question_manager_screen.dart`
/// both had before this stage: `correctAnswers` holding option *text*
/// or literal `"true"`/`"false"` instead of an index string. Detected,
/// previewed, and repaired here — never auto-guessed past what can be
/// verified against the question's own `options` list.
///
/// [fillInTheBlank]/[shortAnswer] are excluded — their `correctAnswers`
/// were never index-based (see `exam_scoring.dart`), so there's nothing
/// for this tool to check there.
class QuestionDataRepairScreen extends StatefulWidget {
  const QuestionDataRepairScreen({super.key});

  @override
  State<QuestionDataRepairScreen> createState() => _QuestionDataRepairScreenState();
}

class _QuestionDataRepairScreenState extends State<QuestionDataRepairScreen> {
  final QuestionRepository _repository = QuestionRepository();

  bool _scanning = false;
  bool _scanned = false;
  bool _repairing = false;
  int _repairedCount = 0;
  List<_RepairFinding> _resolvable = [];
  List<_RepairFinding> _unresolvable = [];

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _scanned = false;
    });

    // Unfiltered read — this is an admin-only maintenance tool run on
    // demand, not a screen a student's session touches, so the
    // one-time cost of reading the whole `questions` collection is
    // acceptable here in a way it wouldn't be on a student-facing path.
    final result = await _repository.getWhere(query: (q) => q);

    final resolvable = <_RepairFinding>[];
    final unresolvable = <_RepairFinding>[];

    if (result case Success(data: final questions)) {
      for (final q in questions) {
        if (!_indexBasedTypes.contains(q.type)) continue;
        final finding = _diagnose(q);
        if (finding == null) continue; // already correct, nothing to do
        (finding.isResolvable ? resolvable : unresolvable).add(finding);
      }
    }

    if (!mounted) return;
    setState(() {
      _scanning = false;
      _scanned = true;
      _resolvable = resolvable;
      _unresolvable = unresolvable;
    });
  }

  /// Returns null when [q] is already in the correct format — nothing
  /// to repair. Otherwise returns a [_RepairFinding], resolvable or not.
  _RepairFinding? _diagnose(QuestionModel q) {
    if (q.type == QuestionType.trueFalse) {
      final first = q.correctAnswers.isNotEmpty ? q.correctAnswers.first.toLowerCase() : '';
      if (first == '0' || first == '1') return null; // already correct
      if (first == 'true') return _RepairFinding(original: q, repairedAnswers: const ['0'], repairedOptionIndex: 0);
      if (first == 'false') return _RepairFinding(original: q, repairedAnswers: const ['1'], repairedOptionIndex: 1);
      return _RepairFinding(original: q); // unresolvable
    }

    // singleChoice / multipleChoice
    final alreadyValid = q.correctAnswers.every((a) {
      final i = int.tryParse(a);
      return i != null && i >= 0 && i < q.options.length;
    });
    if (alreadyValid && q.correctAnswers.isNotEmpty) return null;

    final repaired = <String>[];
    for (final a in q.correctAnswers) {
      final asIndex = int.tryParse(a);
      if (asIndex != null && asIndex >= 0 && asIndex < q.options.length) {
        repaired.add(a); // already a valid index, keep as-is
        continue;
      }
      final byText = q.options.indexOf(a);
      if (byText < 0) return _RepairFinding(original: q); // unresolvable — matches neither
      repaired.add(byText.toString());
    }
    if (repaired.isEmpty) return _RepairFinding(original: q);
    return _RepairFinding(
      original: q,
      repairedAnswers: repaired,
      repairedOptionIndex: int.tryParse(repaired.first) ?? q.correctOptionIndex,
    );
  }

  Future<void> _confirmRepair() async {
    if (_resolvable.isEmpty) return;
    setState(() {
      _repairing = true;
      _repairedCount = 0;
    });

    for (final finding in _resolvable) {
      final q = finding.original;
      final repaired = QuestionModel(
        questionId: q.questionId,
        examId: q.examId,
        courseId: q.courseId,
        text: q.text,
        options: q.options,
        correctOptionIndex: finding.repairedOptionIndex ?? q.correctOptionIndex,
        explanation: q.explanation,
        difficulty: q.difficulty,
        topic: q.topic,
        tags: q.tags,
        imageUrl: q.imageUrl,
        type: q.type,
        correctAnswers: finding.repairedAnswers!,
        typeData: q.typeData,
        points: q.points,
        premiumExplanation: q.premiumExplanation,
      );
      final result = await _repository.save(repaired);
      if (!mounted) return;
      if (result case Success()) setState(() => _repairedCount++);
    }

    if (!mounted) return;
    setState(() => _repairing = false);

    AuditLogService.instance.log(
      action: AuditActionType.edit,
      module: AuditModules.academicStructure,
      targetCollection: 'questions',
      targetId: 'bulk-repair',
      targetTitle: 'Question Data Repair: $_repairedCount question${_repairedCount == 1 ? '' : 's'} migrated to index-based correctAnswers',
    );

    if (!mounted) return;
    AppSnackbar.success(context, 'Repaired $_repairedCount question${_repairedCount == 1 ? '' : 's'}.');
    await _scan(); // re-scan so the list reflects the now-fixed state
  }

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Question Data Repair')),
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
                    Text(
                      'Fixes the CBT-REFACTOR Phase 1 bug',
                      style: AppTextStyles.bodyLarge(AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scans every single-choice, multiple-choice, and true/false question for '
                      'correctAnswers stored as option text ("Abuja") or literal true/false '
                      'instead of an option index ("1") — the fix already applied to new '
                      'questions going forward. Nothing is changed until you confirm.',
                      style: AppTextStyles.bodyMedium(bodyColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _scanning ? 'Scanning…' : (_scanned ? 'Re-scan' : 'Scan Questions'),
              onPressed: _scanning || _repairing ? null : _scan,
            ),
            if (_scanning) const Padding(padding: EdgeInsets.only(top: 20), child: LoadingView()),
            if (_scanned && !_scanning) ...[
              const SizedBox(height: 20),
              if (_resolvable.isEmpty && _unresolvable.isEmpty)
                const EmptyView(
                  message: 'No affected questions found — every question already uses the correct format.',
                  icon: Icons.check_circle_outline_rounded,
                )
              else ...[
                if (_resolvable.isNotEmpty) ...[
                  SectionHeader(title: 'Will be repaired (${_resolvable.length})'),
                  const SizedBox(height: 8),
                  ..._resolvable.map((f) => _FindingTile(finding: f, bodyColor: bodyColor)),
                  const SizedBox(height: 20),
                  if (_repairing)
                    Column(
                      children: [
                        LinearProgressIndicator(value: _repairedCount / _resolvable.length),
                        const SizedBox(height: 8),
                        Text('Repairing $_repairedCount of ${_resolvable.length}…',
                            style: AppTextStyles.bodyMedium(bodyColor)),
                      ],
                    )
                  else
                    PrimaryButton(
                      label: 'Confirm Repair (${_resolvable.length})',
                      onPressed: _confirmRepair,
                    ),
                ],
                if (_unresolvable.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  SectionHeader(title: 'Needs manual review (${_unresolvable.length})'),
                  const SizedBox(height: 4),
                  Text(
                    'These don\'t match any option in the question and any correct-answer entry '
                    'isn\'t a valid index — this tool won\'t guess. Fix these directly in Question Manager.',
                    style: AppTextStyles.bodyMedium(AppColors.error),
                  ),
                  const SizedBox(height: 8),
                  ..._unresolvable.map((f) => _FindingTile(finding: f, bodyColor: bodyColor)),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  final _RepairFinding finding;
  final Color bodyColor;
  const _FindingTile({required this.finding, required this.bodyColor});

  @override
  Widget build(BuildContext context) {
    final q = finding.original;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            finding.isResolvable ? Icons.build_circle_outlined : Icons.error_outline_rounded,
            size: 18,
            color: finding.isResolvable ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              finding.isResolvable
                  ? '${q.text}\n${q.correctAnswers} → ${finding.repairedAnswers}'
                  : '${q.text}\ncorrectAnswers: ${q.correctAnswers} (no matching option)',
              style: AppTextStyles.bodyMedium(bodyColor),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
