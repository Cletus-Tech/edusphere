import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/enums/content_type.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../repositories/learning_repository.dart';
import '../../services/firebase/auth_service.dart';
import '../../shared/widgets/state_views.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import 'exam_calculator_sheet.dart';
import 'exam_result_screen.dart';
import 'exam_scoring.dart';

/// Stage 4.8A Part 2 — wires `ExamListScreen`'s "Start" button to a real
/// session (create-or-resume, via [ExamSessionRepository]) and gives
/// that session a question navigator: jump between questions, answer
/// single/multiple-choice/true-false/short-answer questions, flag or
/// bookmark any question, and auto-save every change.
///
/// Stage 4.8C Part 1 adds the pieces that were deliberately deferred:
/// a timer (hard countdown + auto-submit for [ExamMode.official]/
/// [ExamMode.mock], elapsed-time display for [ExamMode.practice]),
/// the gated calculator ([ExamModel.calculatorType]),
/// per-session option shuffling ([ExamModel.shuffleOptions]), and
/// Submit — which scores the session via [scoreExamSession], writes
/// the permanent [ExamAttemptModel], and hands off to
/// [ExamResultScreen]. Still not here: the offline sync queue and
/// proctoring — separate build slices with their own new
/// dependencies.
///
/// Stage CBT-2 adds [mode] — the caller-supplied mode picker this
/// comment used to describe as future work. The CBT Center's Official/
/// Mock cards pass [ExamMode.official]/[ExamMode.mock]; every existing
/// call site (WAEC/NECO/JAMB/University Post-UTME) doesn't pass one and
/// keeps starting practice sessions exactly as before.
class ExamRunnerScreen extends StatefulWidget {
  final ExamModel exam;

  /// When set, the runner starts a fresh practice session scoped to
  /// exactly these question ids instead of the exam's full bank, and
  /// never resumes an existing session (a retry is always a new
  /// attempt). Used by [ExamReviewScreen]'s "Retry incorrect" action —
  /// spec section 15.
  final List<String>? questionIdsOverride;

  /// Stage CBT-2 — the "mode picker" this class's own doc comment
  /// anticipated. Only used when *creating* a new session; a resumed
  /// session keeps whatever mode it was created with (a student can't
  /// switch an in-progress official attempt to practice mid-way).
  /// Defaults to [ExamMode.practice] so every existing call site
  /// (WAEC/NECO/JAMB/University, none of which pass this) behaves
  /// exactly as before — this widget's public behavior is unchanged
  /// unless a caller opts in.
  final ExamMode mode;

  const ExamRunnerScreen({
    super.key,
    required this.exam,
    this.questionIdsOverride,
    this.mode = ExamMode.practice,
  });

  @override
  State<ExamRunnerScreen> createState() => _ExamRunnerScreenState();
}

class _ExamRunnerScreenState extends State<ExamRunnerScreen> {
  final _sessionRepo = ExamSessionRepository();
  final _questionRepo = QuestionRepository();

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  ExamSessionModel? _session;
  List<QuestionModel> _questions = const [];
  int _currentIndex = 0;

  final Map<String, TextEditingController> _textControllers = {};

  Timer? _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadOrCreateSession();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOrCreateSession() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _loadError = 'You need to be signed in to start an exam.';
      });
      return;
    }

    final bankLimit = widget.exam.totalQuestions > 0 ? widget.exam.totalQuestions : 50;
    final fullBank = await _questionRepo.fetchPageForExam(widget.exam.examId, limit: bankLimit);
    final override = widget.questionIdsOverride;
    final bank = override == null
        ? fullBank
        : fullBank.where((q) => override.contains(q.questionId)).toList();
    if (bank.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = 'No questions have been added to this exam yet.';
      });
      return;
    }
    final byId = {for (final q in bank) q.questionId: q};

    // A retry (questionIdsOverride set) always starts a brand-new
    // session scoped to just those questions — resuming an old session
    // here would pull back the full original bank, defeating the point.
    var session = override == null ? await _sessionRepo.findResumableSession(uid, widget.exam.examId) : null;

    if (session == null) {
      final order = bank.map((q) => q.questionId).toList();
      if (widget.exam.shuffleQuestions) order.shuffle();

      final optionOrder = <String, dynamic>{};
      if (widget.exam.shuffleOptions) {
        for (final q in bank) {
          if (q.options.isEmpty) continue;
          final indices = List<int>.generate(q.options.length, (i) => i)..shuffle();
          optionOrder[q.questionId] = indices;
        }
      }

      // Stage CBT-2: was `const mode = ExamMode.practice` — the runner's
      // own doc comment called this "the mode picker" the day one
      // existed. `widget.mode` defaults to practice, so every call site
      // that doesn't pass one keeps today's exact behavior.
      final mode = widget.mode;
      final now = DateTime.now();
      session = ExamSessionModel(
        sessionId: _sessionRepo.newId(),
        examId: widget.exam.examId,
        userId: uid,
        mode: mode,
        status: ExamSessionStatus.inProgress,
        questionOrder: order,
        optionOrder: optionOrder,
        remainingSeconds: mode == ExamMode.practice ? null : widget.exam.durationMinutes * 60,
        startedAt: now,
        lastSavedAt: now,
      );
      await _sessionRepo.save(session);
    }

    final ordered = session.questionOrder.map((id) => byId[id]).whereType<QuestionModel>().toList();
    if (ordered.isEmpty) {
      setState(() {
        _loading = false;
        _loadError = "This session's questions could not be loaded.";
      });
      return;
    }

    for (final q in ordered) {
      if (q.type == QuestionType.fillInTheBlank || q.type == QuestionType.shortAnswer) {
        final existing = session.answers[q.questionId];
        _textControllers[q.questionId] = TextEditingController(text: existing is String ? existing : '');
      }
    }

    setState(() {
      _session = session;
      _questions = ordered;
      _currentIndex = session!.currentQuestionIndex.clamp(0, ordered.length - 1);
      _elapsedSeconds = DateTime.now().difference(session.startedAt).inSeconds.clamp(0, 1 << 30);
      _loading = false;
    });
    _markVisited(_currentIndex);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final session = _session;
    if (session == null || !mounted || _submitting) return;

    if (session.mode == ExamMode.practice) {
      setState(() => _elapsedSeconds++);
      return;
    }

    // Official/mock: hard countdown the student can't pause or extend.
    final remaining = (session.remainingSeconds ?? widget.exam.durationMinutes * 60) - 1;
    if (remaining <= 0) {
      _ticker?.cancel();
      _submitExam(auto: true);
      return;
    }
    setState(() {
      _elapsedSeconds++;
      _session = session.copyWith(remainingSeconds: remaining);
    });
    if (remaining % 10 == 0) _sessionRepo.autoSave(_session!);
  }

  String _formatClock(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  Future<void> _submitExam({bool auto = false}) async {
    final session = _session;
    if (session == null || _submitting) return;

    if (!auto) {
      final answered = session.answers.length;
      final unanswered = _questions.length - answered;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Submit exam?'),
          content: Text(
            unanswered > 0
                ? "You've answered $answered of ${_questions.length} questions — $unanswered left unanswered. "
                    "You can't change answers after submitting."
                : "You've answered all ${_questions.length} questions. You can't change answers after submitting.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep working')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    _ticker?.cancel();
    setState(() => _submitting = true);

    final result = scoreExamSession(exam: widget.exam, session: session, questions: _questions);
    final now = DateTime.now();

    final attemptRepo = ExamAttemptRepository();
    final attempt = ExamAttemptModel(
      attemptId: attemptRepo.newId(),
      examId: widget.exam.examId,
      userId: session.userId,
      sessionId: session.sessionId,
      mode: session.mode,
      totalQuestions: result.totalQuestions,
      correctCount: result.correctCount,
      incorrectCount: result.incorrectCount,
      unansweredCount: result.unansweredCount,
      scorePercent: result.scorePercent,
      passed: result.passed,
      timeTakenSeconds: now.difference(session.startedAt).inSeconds,
      topicBreakdown: result.topicBreakdown,
      submittedAt: now,
    );

    await attemptRepo.save(attempt);
    await _sessionRepo.save(session.copyWith(status: ExamSessionStatus.submitted, lastSavedAt: now));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ExamResultScreen(exam: widget.exam, attempt: attempt)),
    );
  }

  Future<void> _autoSave() async {
    final session = _session;
    if (session == null) return;
    final updated = session.copyWith(currentQuestionIndex: _currentIndex);
    setState(() => _session = updated);
    await _sessionRepo.autoSave(updated);
  }

  void _setAnswer(String questionId, dynamic value) {
    final session = _session;
    if (session == null) return;
    final answers = Map<String, dynamic>.from(session.answers)..[questionId] = value;
    setState(() => _session = session.copyWith(answers: answers));
    _sessionRepo.autoSave(_session!.copyWith(currentQuestionIndex: _currentIndex));
  }

  void _toggleFlag(String questionId) {
    final session = _session;
    if (session == null) return;
    final flagged = List<String>.from(session.flaggedQuestionIds);
    flagged.contains(questionId) ? flagged.remove(questionId) : flagged.add(questionId);
    setState(() => _session = session.copyWith(flaggedQuestionIds: flagged));
    _sessionRepo.autoSave(_session!.copyWith(currentQuestionIndex: _currentIndex));
  }

  void _toggleBookmark(String questionId) {
    final session = _session;
    if (session == null) return;
    final bookmarked = List<String>.from(session.bookmarkedQuestionIds);
    bookmarked.contains(questionId) ? bookmarked.remove(questionId) : bookmarked.add(questionId);
    setState(() => _session = session.copyWith(bookmarkedQuestionIds: bookmarked));
    _sessionRepo.autoSave(_session!.copyWith(currentQuestionIndex: _currentIndex));
  }

  void _jumpTo(int index) {
    if (!widget.exam.allowBackNavigation && index < _currentIndex) return;
    setState(() => _currentIndex = index);
    _markVisited(index);
    _autoSave();
  }

  void _markVisited(int index) {
    final session = _session;
    if (session == null || index < 0 || index >= _questions.length) return;
    final questionId = _questions[index].questionId;
    if (session.visitedQuestionIds.contains(questionId)) return;
    final visited = List<String>.from(session.visitedQuestionIds)..add(questionId);
    _session = session.copyWith(visitedQuestionIds: visited);
  }

  void _goNext() {
    if (_currentIndex >= _questions.length - 1) return;
    _jumpTo(_currentIndex + 1);
  }

  void _goPrevious() {
    if (_currentIndex <= 0) return;
    _jumpTo(_currentIndex - 1);
  }

  Future<void> _openPalette() async {
    final session = _session;
    if (session == null) return;
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuestionPaletteSheet(
        questions: _questions,
        currentIndex: _currentIndex,
        answers: session.answers,
        flagged: session.flaggedQuestionIds,
        visited: session.visitedQuestionIds,
      ),
    );
    if (target != null) _jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(widget.exam.title)), body: const LoadingView());
    }
    if (_loadError != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exam.title)),
        body: ErrorView(message: _loadError ?? 'Something went wrong.'),
      );
    }

    if (_submitting) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.exam.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final session = _session!;
    final question = _questions[_currentIndex];
    final isFlagged = session.flaggedQuestionIds.contains(question.questionId);
    final isBookmarked = session.bookmarkedQuestionIds.contains(question.questionId);
    final displayOrder = (session.optionOrder[question.questionId] as List?)?.map((e) => e as int).toList();
    final isTimed = session.mode != ExamMode.practice;
    final clockLabel = isTimed
        ? _formatClock(session.remainingSeconds ?? widget.exam.durationMinutes * 60)
        : _formatClock(_elapsedSeconds);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _autoSave();
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
          actions: [
            IconButton(
              tooltip: 'Question palette',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _openPalette,
            ),
            if (widget.exam.calculatorType != CalculatorType.none)
              IconButton(
                tooltip: 'Calculator',
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () => showExamCalculatorSheet(context, widget.exam.calculatorType),
              ),
            IconButton(
              tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark question',
              icon: Icon(isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded),
              onPressed: () => _toggleBookmark(question.questionId),
            ),
            if (widget.exam.allowFlagging)
              IconButton(
                tooltip: isFlagged ? 'Remove flag' : 'Flag for review',
                icon: Icon(
                  isFlagged ? Icons.flag_rounded : Icons.flag_outlined,
                  color: isFlagged ? AppColors.highlightOrange : null,
                ),
                onPressed: () => _toggleFlag(question.questionId),
              ),
            TextButton(
              onPressed: () => _submitExam(),
              child: Text(
                'Submit',
                style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isTimed ? Icons.timer_outlined : Icons.schedule_outlined,
                    size: 16,
                    color: isTimed && (session.remainingSeconds ?? 999) < 60
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    clockLabel,
                    style: AppTextStyles.bodySmall(
                      isTimed && (session.remainingSeconds ?? 999) < 60 ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _QuestionNavigator(
                questions: _questions,
                currentIndex: _currentIndex,
                answers: session.answers,
                flagged: session.flaggedQuestionIds,
                visited: session.visitedQuestionIds,
                onJump: _jumpTo,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _QuestionBody(
                    question: question,
                    answer: session.answers[question.questionId],
                    displayOrder: displayOrder,
                    textController: _textControllers[question.questionId],
                    onAnswerChanged: (value) => _setAnswer(question.questionId, value),
                  ),
                ),
              ),
              _NavBar(
                canGoPrevious: widget.exam.allowBackNavigation && _currentIndex > 0,
                canGoNext: _currentIndex < _questions.length - 1 &&
                    (widget.exam.allowSkipping || session.answers[question.questionId] != null),
                onPrevious: _goPrevious,
                onNext: _goNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionNavigator extends StatelessWidget {
  final List<QuestionModel> questions;
  final int currentIndex;
  final Map<String, dynamic> answers;
  final List<String> flagged;
  final List<String> visited;
  final ValueChanged<int> onJump;

  const _QuestionNavigator({
    required this.questions,
    required this.currentIndex,
    required this.answers,
    required this.flagged,
    required this.visited,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final q = questions[index];
          final isCurrent = index == currentIndex;
          final isAnswered = answers[q.questionId] != null;
          final isFlagged = flagged.contains(q.questionId);
          final isVisited = visited.contains(q.questionId);

          Color background;
          Color foreground;
          if (isCurrent) {
            background = AppColors.primaryBlue;
            foreground = Colors.white;
          } else if (isFlagged) {
            background = AppColors.highlightOrange.withOpacity(0.15);
            foreground = AppColors.highlightOrange;
          } else if (isAnswered) {
            background = AppColors.accentGreen.withOpacity(0.15);
            foreground = AppColors.accentGreen;
          } else if (isVisited) {
            background = AppColors.textSecondary.withOpacity(0.18);
            foreground = AppColors.textPrimary;
          } else {
            background = AppColors.textSecondary.withOpacity(0.1);
            foreground = AppColors.textSecondary;
          }

          return GestureDetector(
            onTap: () => onJump(index),
            child: Container(
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: isFlagged && !isCurrent ? Border.all(color: AppColors.highlightOrange) : null,
              ),
              child: Text('${index + 1}', style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  final QuestionModel question;
  final dynamic answer;
  /// Original option indices in this session's fixed display order
  /// (see [ExamSessionModel.optionOrder]). Null means "show options in
  /// their stored order" — either shuffling is off for this exam, or
  /// this question has no options list to shuffle.
  final List<int>? displayOrder;
  final TextEditingController? textController;
  final ValueChanged<dynamic> onAnswerChanged;

  const _QuestionBody({
    required this.question,
    required this.answer,
    required this.displayOrder,
    required this.textController,
    required this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.text, style: AppTextStyles.bodyLarge(textColor).copyWith(height: 1.4)),
        const SizedBox(height: 20),
        _buildAnswerInput(context),
      ],
    );
  }

  Widget _buildAnswerInput(BuildContext context) {
    switch (question.type) {
      case QuestionType.singleChoice:
        final order = displayOrder ?? List<int>.generate(question.options.length, (i) => i);
        return Column(
          children: order.map((originalIndex) {
            final value = originalIndex.toString();
            return RadioListTile<String>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: answer as String?,
              // ignore: deprecated_member_use
              onChanged: (v) => onAnswerChanged(v),
              title: Text(question.options[originalIndex]),
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        );

      case QuestionType.trueFalse:
        final options = question.options.length == 2 ? question.options : const ['True', 'False'];
        final order = displayOrder ?? List<int>.generate(options.length, (i) => i);
        return Column(
          children: order.map((originalIndex) {
            final value = originalIndex.toString();
            return RadioListTile<String>(
              value: value,
              // ignore: deprecated_member_use
              groupValue: answer as String?,
              // ignore: deprecated_member_use
              onChanged: (v) => onAnswerChanged(v),
              title: Text(options[originalIndex]),
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        );

      case QuestionType.multipleChoice:
        final selected = (answer is List) ? List<String>.from(answer as List) : <String>[];
        final order = displayOrder ?? List<int>.generate(question.options.length, (i) => i);
        return Column(
          children: order.map((originalIndex) {
            final value = originalIndex.toString();
            return CheckboxListTile(
              value: selected.contains(value),
              onChanged: (checked) {
                final next = List<String>.from(selected);
                checked == true ? next.add(value) : next.remove(value);
                onAnswerChanged(next);
              },
              title: Text(question.options[originalIndex]),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            );
          }).toList(),
        );

      case QuestionType.fillInTheBlank:
      case QuestionType.shortAnswer:
        return TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: 'Type your answer', border: OutlineInputBorder()),
          onChanged: onAnswerChanged,
        );

      default:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Text(
            "This question type isn't supported in the practice runner yet.",
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
    }
  }
}

class _NavBar extends StatelessWidget {
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _NavBar({
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.textSecondary.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: canGoPrevious ? onPrevious : null,
              child: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: canGoNext ? onNext : null,
              child: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full grid question palette — Stage 4.8B. The horizontal strip in
/// [_QuestionNavigator] is fine for a glance, but a JAMB/WAEC-length
/// exam (60-250 questions) needs something scannable at a glance, plus
/// First/Last jump and an explicit legend, per the spec's "professional
/// CBT navigation" requirement. Returns the tapped index via
/// `Navigator.pop(context, index)`; the caller (`_openPalette`) is
/// responsible for actually jumping and marking it visited.
class _QuestionPaletteSheet extends StatelessWidget {
  final List<QuestionModel> questions;
  final int currentIndex;
  final Map<String, dynamic> answers;
  final List<String> flagged;
  final List<String> visited;

  const _QuestionPaletteSheet({
    required this.questions,
    required this.currentIndex,
    required this.answers,
    required this.flagged,
    required this.visited,
  });

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final answeredCount = questions.where((q) => answers[q.questionId] != null).length;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Question Palette · $answeredCount/${questions.length} answered',
                      style: AppTextStyles.titleMedium(
                        Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _LegendDot(color: AppColors.primaryBlue, label: 'Current'),
                  _LegendDot(color: AppColors.accentGreen, label: 'Answered'),
                  _LegendDot(color: AppColors.highlightOrange, label: 'Flagged'),
                  _LegendDot(color: bodyColor.withOpacity(0.5), label: 'Visited'),
                  _LegendDot(color: bodyColor.withOpacity(0.2), label: 'Unvisited'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final q = questions[index];
                  final isCurrent = index == currentIndex;
                  final isAnswered = answers[q.questionId] != null;
                  final isFlagged = flagged.contains(q.questionId);
                  final isVisited = visited.contains(q.questionId);

                  Color background;
                  Color foreground;
                  if (isCurrent) {
                    background = AppColors.primaryBlue;
                    foreground = Colors.white;
                  } else if (isFlagged) {
                    background = AppColors.highlightOrange.withOpacity(0.18);
                    foreground = AppColors.highlightOrange;
                  } else if (isAnswered) {
                    background = AppColors.accentGreen.withOpacity(0.18);
                    foreground = AppColors.accentGreen;
                  } else if (isVisited) {
                    background = bodyColor.withOpacity(0.18);
                    foreground = bodyColor;
                  } else {
                    background = bodyColor.withOpacity(0.08);
                    foreground = bodyColor.withOpacity(0.7);
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context, index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(10),
                        border: isFlagged && !isCurrent
                            ? Border.all(color: AppColors.highlightOrange)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, 0),
                      child: const Text('First'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, questions.length - 1),
                      child: const Text('Last'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodySmall(bodyColor)),
      ],
    );
  }
}
