import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../models/course_model.dart';
import '../../models/exam_model.dart';
import '../../repositories/course_repository.dart';
import '../../repositories/learning_repository.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'exam_list_screen.dart';

/// Stage CBT-Refactor Phase 3 — the Year → Subject(s) → Paper →
/// Available Exams flow the audit found missing for WAEC.
///
/// Deliberately generic over [ExamType] (not `WaecSelectionScreen`),
/// mirroring [SubjectBrowseScreen]'s exact reasoning: Phase 4 (NECO)
/// reuses this file with `ExamType.neco` instead of a second,
/// near-identical screen — "reuse the WAEC selection infrastructure
/// where appropriate," per the refactor doc, done up front rather
/// than refactored into existence later.
///
/// [mode] is **required**, not defaulted — Stage A's audit found that
/// this screen previously had no mode parameter at all, so every
/// caller (both a board's "CBT"/official tile and its "Mock Exams"
/// tile) silently landed on [ExamListScreen]'s own default,
/// [ExamMode.practice], regardless of which tile the student actually
/// tapped. Making [mode] required forces every call site to state its
/// intent explicitly rather than re-introducing a silent default here.
///
/// Every value a student can pick comes from real, admin-configured
/// data, never a hardcoded list:
/// - **Year** — the distinct [ExamModel.year] values found among this
///   board's actual exams (via [ExamRepository.watchByType], the same
///   stream [ExamListScreen] would otherwise use), sorted newest
///   first. No current-year default, no invented range.
/// - **Subject(s)** — [SubjectRepository.watchByCategory], the exact
///   same real subject data [SubjectBrowseScreen] already lists for
///   this board. Multi-select, since a student sits several subjects.
/// - **Paper** — the distinct [ExamModel.paper] values found among
///   exams matching the selected year/subjects. The Phase 1 audit
///   found no controlled vocabulary for "paper" anywhere in the app,
///   so this deliberately isn't a hardcoded ["Paper 1", "Paper 2", ...]
///   list (that would violate the refactor doc's "no hardcoded
///   academic data" rule) — if no exam in the current selection has a
///   paper set, the step is skipped entirely and every paper is shown.
///
/// The final "View Available Exams" step hands off to the *existing*
/// [ExamListScreen] with the selected criteria plus [mode], which now
/// filters via [ExamRepository.watchByTypeWithFilters] — a real
/// server-side query, not a client-side filter over every exam of the
/// type. [ExamListScreen]'s own `supportedModes` guard (unchanged by
/// this stage) still blocks starting an exam not configured for the
/// requested mode, so passing [mode] here can only ever be more
/// restrictive than before, never less.
///
/// Known limitation (documented per the audit's Phase 9 finding, not
/// solved here): [ExamEditorScreen] sets `subjectId`/`year`/`paper` as
/// plain text fields, so an admin must type the exact subject ID that
/// matches a `subjects` document's ID rather than picking from a list.
/// A proper picker is Phase 9 (Admin Allocation) work.
class BoardExamSelectionScreen extends StatefulWidget {
  final ExamType examType;
  final String title;
  final Color accent;
  final ExamMode mode;

  const BoardExamSelectionScreen({
    super.key,
    required this.examType,
    required this.title,
    required this.mode,
    this.accent = AppColors.primaryBlue,
  });

  @override
  State<BoardExamSelectionScreen> createState() => _BoardExamSelectionScreenState();
}

class _BoardExamSelectionScreenState extends State<BoardExamSelectionScreen> {
  // Cached once rather than re-created in build(): constructing these
  // inline in build() would hand StreamBuilder a *new* Stream instance
  // (and so a new Firestore listener) on every setState from a chip
  // tap, since ExamRepository()/SubjectRepository() return a fresh
  // Stream each call.
  late final Stream<List<ExamModel>> _examsStream;
  late final Stream<List<CourseModel>> _subjectsStream;

  int? _selectedYear;
  final Set<String> _selectedSubjectIds = {};
  String? _selectedPaper;

  @override
  void initState() {
    super.initState();
    _examsStream = ExamRepository().watchByType(widget.examType.id);
    _subjectsStream = SubjectRepository().watchByCategory(widget.examType.id);
  }

  @override
  Widget build(BuildContext context) {
    final headingColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: StreamBuilder<List<ExamModel>>(
          stream: _examsStream,
          builder: (context, examSnapshot) {
            if (examSnapshot.connectionState == ConnectionState.waiting) return const LoadingView();
            if (examSnapshot.hasError) {
              return const ErrorView(message: 'Could not load exam years right now.');
            }
            final allExams = examSnapshot.data ?? const <ExamModel>[];
            final years = allExams.map((e) => e.year).whereType<int>().toSet().toList()
              ..sort((a, b) => b.compareTo(a));

            if (years.isEmpty) {
              return EmptyView(
                message: 'No ${widget.title} exams have a year configured yet.',
                icon: Icons.event_busy_outlined,
              );
            }

            final papersForSelection = _selectedYear == null
                ? const <String>[]
                : (allExams
                        .where((e) =>
                            e.year == _selectedYear &&
                            e.paper != null &&
                            (_selectedSubjectIds.isEmpty || _selectedSubjectIds.contains(e.subjectId)))
                        .map((e) => e.paper!)
                        .toSet()
                        .toList()
                      ..sort());

            final canViewExams = _selectedYear != null && _selectedSubjectIds.isNotEmpty;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    children: [
                      _StepLabel(number: 1, label: 'Select year', accent: widget.accent, color: headingColor),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: years
                            .map((y) => AppChip(
                                  label: '$y',
                                  accent: widget.accent,
                                  selected: _selectedYear == y,
                                  onTap: () => setState(() {
                                    _selectedYear = y;
                                    _selectedSubjectIds.clear();
                                    _selectedPaper = null;
                                  }),
                                ))
                            .toList(),
                      ),
                      if (_selectedYear != null) ...[
                        const SizedBox(height: 24),
                        _StepLabel(number: 2, label: 'Select subject(s)', accent: widget.accent, color: headingColor),
                        const SizedBox(height: 10),
                        StreamBuilder<List<CourseModel>>(
                          stream: _subjectsStream,
                          builder: (context, subjectSnapshot) {
                            if (subjectSnapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
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
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: subjects.map((s) {
                                final selected = _selectedSubjectIds.contains(s.courseId);
                                return AppChip(
                                  label: s.title,
                                  accent: widget.accent,
                                  selected: selected,
                                  onTap: () => setState(() {
                                    if (selected) {
                                      _selectedSubjectIds.remove(s.courseId);
                                    } else {
                                      _selectedSubjectIds.add(s.courseId);
                                    }
                                    _selectedPaper = null;
                                  }),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                      if (_selectedYear != null && _selectedSubjectIds.isNotEmpty && papersForSelection.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _StepLabel(number: 3, label: 'Select paper', accent: widget.accent, color: headingColor),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: papersForSelection
                              .map((p) => AppChip(
                                    label: p,
                                    accent: widget.accent,
                                    selected: _selectedPaper == p,
                                    onTap: () => setState(() => _selectedPaper = _selectedPaper == p ? null : p),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Optional — leave unselected to see every paper.',
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
                    onPressed: canViewExams ? () => _viewExams(context) : null,
                  ),
                ),
              ],
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
          year: _selectedYear,
          paper: _selectedPaper,
          mode: widget.mode,
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int number;
  final String label;
  final Color accent;
  final Color color;

  const _StepLabel({required this.number, required this.label, required this.accent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.titleMedium(color)),
      ],
    );
  }
}
