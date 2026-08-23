import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../core/utils/subject_combination_validator.dart';
import '../../models/combination_rule_model.dart';
import '../../models/course_model.dart';
import '../../repositories/combination_rule_repository.dart';
import '../../repositories/course_repository.dart';
import '../../repositories/learning_repository.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'exam_list_screen.dart';

/// Stage CBT-Refactor Phase 5. The compulsory-subject + fixed-count
/// combination selection flow JAMB needs — audited as structurally
/// different from [BoardExamSelectionScreen]'s Year → Subject(s) →
/// Paper drill-down (JAMB has no "paper" concept and needs a locked
/// compulsory subject + exact-count validation, not sequential
/// filtering), so this is a sibling screen rather than a branching
/// mode bolted onto that one. Reuses everything underneath it exactly
/// the same way that screen does: [SubjectRepository.watchByCategory],
/// [ExamRepository.watchByTypeWithFilters] (via the existing
/// [ExamListScreen], not a new query), [AppChip], [PrimaryButton],
/// the existing state-view widgets. Zero new CBT engine, zero new
/// exam/question/scoring system — this only decides *which* exams
/// [ExamListScreen] shows before handing off to the untouched
/// existing pipeline.
///
/// Generic over `categoryId`/[ExamType], not JAMB-only — matches
/// `BoardExamSelectionScreen`'s own precedent of anticipating reuse by
/// another board rather than hardcoding one board's name into the
/// class.
///
/// [CombinationRuleModel] (via [CombinationRuleRepository]) supplies
/// the compulsory subject and required count — nothing here hardcodes
/// "English" or "4"; an admin-unconfigured category simply falls back
/// to that model's own default (see its doc comment), not a value
/// baked into this screen.
///
/// [mode] is **required** — same Stage A fix as
/// [BoardExamSelectionScreen]: this screen previously had no mode
/// parameter, so both JAMB's "CBT" (official) tile and its "Mock
/// Exams" tile silently produced the same [ExamListScreen] call and
/// landed on [ExamMode.practice] regardless of intent.
class SubjectCombinationSelectionScreen extends StatefulWidget {
  final ExamType examType;
  final String categoryId;
  final String title;
  final Color accent;
  final ExamMode mode;

  const SubjectCombinationSelectionScreen({
    super.key,
    required this.examType,
    required this.categoryId,
    required this.title,
    required this.mode,
    this.accent = AppColors.primaryBlue,
  });

  @override
  State<SubjectCombinationSelectionScreen> createState() => _SubjectCombinationSelectionScreenState();
}

class _SubjectCombinationSelectionScreenState extends State<SubjectCombinationSelectionScreen> {
  // Cached once — see BoardExamSelectionScreen's identical comment on
  // why: a fresh Stream per build() would mean a fresh Firestore
  // listener on every setState from a chip tap.
  late final Stream<CombinationRuleModel> _ruleStream;
  late final Stream<List<CourseModel>> _subjectsStream;

  final Set<String> _selectedSubjectIds = {};
  bool _initializedCompulsory = false;

  @override
  void initState() {
    super.initState();
    _ruleStream = CombinationRuleRepository().watchForCategory(widget.categoryId);
    _subjectsStream = SubjectRepository().watchByCategory(widget.categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final headingColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} Subject Combination')),
      body: SafeArea(
        child: StreamBuilder<CombinationRuleModel>(
          stream: _ruleStream,
          builder: (context, ruleSnapshot) {
            if (ruleSnapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            if (ruleSnapshot.hasError) {
              return const ErrorView(message: 'Could not load the subject combination rule right now.');
            }
            final rule = ruleSnapshot.data ?? CombinationRuleModel(categoryId: widget.categoryId);

            return StreamBuilder<List<CourseModel>>(
              stream: _subjectsStream,
              builder: (context, subjectSnapshot) {
                if (subjectSnapshot.connectionState == ConnectionState.waiting) return const LoadingView();
                if (subjectSnapshot.hasError) {
                  return const ErrorView(message: 'Could not load subjects right now.');
                }
                final subjects = subjectSnapshot.data ?? const <CourseModel>[];
                if (subjects.isEmpty) {
                  return EmptyView(
                    message: 'No ${widget.title} subjects have been added yet.',
                    icon: Icons.menu_book_outlined,
                  );
                }

                // Auto-select + lock the compulsory subject exactly
                // once real subject data has arrived — not in
                // initState(), since the rule/subject streams may not
                // have delivered data yet at that point.
                if (!_initializedCompulsory) {
                  _initializedCompulsory = true;
                  if (rule.compulsorySubjectId != null &&
                      subjects.any((s) => s.courseId == rule.compulsorySubjectId)) {
                    _selectedSubjectIds.add(rule.compulsorySubjectId!);
                  }
                }

                final status = SubjectCombinationValidator.validate(
                  selectedSubjectIds: _selectedSubjectIds,
                  rule: rule,
                );
                final atLimit = _selectedSubjectIds.length >= rule.requiredSubjectCount;
                final compulsorySubject = rule.compulsorySubjectId == null
                    ? null
                    : _findById(subjects, rule.compulsorySubjectId!);
                final selectableSubjects =
                    subjects.where((s) => s.courseId != rule.compulsorySubjectId).toList()
                      ..sort((a, b) => a.title.compareTo(b.title));

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${widget.title} Subject Combination', style: AppTextStyles.titleMedium(headingColor)),
                          Text(
                            'Selected: ${_selectedSubjectIds.length} / ${rule.requiredSubjectCount}',
                            style: AppTextStyles.bodyMedium(widget.accent).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        children: [
                          if (compulsorySubject != null) ...[
                            Text('Compulsory', style: AppTextStyles.bodySmall(bodyColor)),
                            const SizedBox(height: 8),
                            AppChip(
                              label: '${compulsorySubject.title} — Selected · Required',
                              accent: widget.accent,
                              selected: true,
                              // No onTap — locked, per the brief's
                              // "English is automatically selected and
                              // locked."
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            compulsorySubject != null ? 'Choose the remaining subjects' : 'Choose your subjects',
                            style: AppTextStyles.bodySmall(bodyColor),
                          ),
                          const SizedBox(height: 8),
                          _SearchableSubjectGrid(
                            subjects: selectableSubjects,
                            selectedIds: _selectedSubjectIds,
                            accent: widget.accent,
                            allowMoreSelections: !atLimit,
                            onToggle: (id) => setState(() {
                              if (_selectedSubjectIds.contains(id)) {
                                _selectedSubjectIds.remove(id);
                              } else if (!atLimit) {
                                _selectedSubjectIds.add(id);
                              }
                            }),
                          ),
                          if (status == SubjectCombinationStatus.incomplete) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Select ${rule.requiredSubjectCount - _selectedSubjectIds.length} more '
                              'subject${rule.requiredSubjectCount - _selectedSubjectIds.length == 1 ? '' : 's'} to continue.',
                              style: AppTextStyles.bodySmall(bodyColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: PrimaryButton(
                        label: 'View Available Exams',
                        onPressed: status == SubjectCombinationStatus.valid ? () => _viewExams(context) : null,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _viewExams(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamListScreen(
          examTypeId: widget.examType.id,
          title: '${widget.title} Exams',
          subjectIds: _selectedSubjectIds.toList(),
          mode: widget.mode,
        ),
      ),
    );
  }

  // `package:collection`'s `firstOrNull` isn't a dependency here (per
  // bulk_question_upload_screen.dart's own doc comment) — plain manual
  // lookup instead.
  CourseModel? _findById(List<CourseModel> subjects, String id) {
    for (final s in subjects) {
      if (s.courseId == id) return s;
    }
    return null;
  }
}

/// Stage CBT-Refactor Phase 5 — search + selectable-chip grid with a
/// clear selected-summary, per the brief's Part 4 ("Do NOT make
/// students scroll through a massive unorganized list... Search...
/// Clear selected-subject summary... Easy removal/deselection").
/// A new small widget, not a duplicate of any existing component —
/// audited: no existing searchable-multiselect-with-summary widget was
/// found to reuse (`BoardExamSelectionScreen`'s subject step is a bare
/// `Wrap` of chips with no search, since WAEC/NECO subject lists were
/// short enough not to need one; JAMB's Part 4 explicitly calls out
/// "There may be many JAMB subjects").
class _SearchableSubjectGrid extends StatefulWidget {
  final List<CourseModel> subjects;
  final Set<String> selectedIds;
  final Color accent;
  final bool allowMoreSelections;
  final ValueChanged<String> onToggle;

  const _SearchableSubjectGrid({
    required this.subjects,
    required this.selectedIds,
    required this.accent,
    required this.allowMoreSelections,
    required this.onToggle,
  });

  @override
  State<_SearchableSubjectGrid> createState() => _SearchableSubjectGridState();
}

class _SearchableSubjectGridState extends State<_SearchableSubjectGrid> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final selectedSubjects = widget.subjects.where((s) => widget.selectedIds.contains(s.courseId)).toList();
    final filtered = _query.isEmpty
        ? widget.subjects
        : widget.subjects.where((s) => s.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedSubjects.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedSubjects
                .map((s) => Chip(
                      label: Text(s.title),
                      onDeleted: () => widget.onToggle(s.courseId),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      backgroundColor: widget.accent.withOpacity(0.12),
                      side: BorderSide(color: widget.accent.withOpacity(0.3)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          decoration: InputDecoration(
            hintText: 'Search subjects',
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No subjects match your search.', style: AppTextStyles.bodySmall(bodyColor)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filtered.map((s) {
              final selected = widget.selectedIds.contains(s.courseId);
              final disabled = !selected && !widget.allowMoreSelections;
              return Opacity(
                opacity: disabled ? 0.4 : 1,
                child: AppChip(
                  label: s.title,
                  accent: widget.accent,
                  selected: selected,
                  onTap: disabled ? null : () => widget.onToggle(s.courseId),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
