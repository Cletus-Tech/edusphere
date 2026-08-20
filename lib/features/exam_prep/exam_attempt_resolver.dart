import 'package:flutter/foundation.dart';
import '../../core/utils/result.dart';
import '../../models/exam_model.dart';
import '../../models/exam_session_model.dart';
import '../../repositories/learning_repository.dart';

/// [ExamAttemptModel] stores only `examId`, not which board (WAEC/NECO/
/// JAMB/...) it belongs to, so any screen that needs "this student's
/// WAEC attempts" has to resolve each attempt's [ExamModel] and check
/// `exam.type.id`. [ExamHistoryScreen] (Stage 4.8B Part 4) and
/// [PerformanceAnalyticsScreen] (Part 5) both need exactly this join —
/// extracted here once, per the Master Project "no duplicate business
/// logic" rule, instead of each screen keeping its own copy of the
/// same cache-and-match code.
///
/// One instance is meant to live for the lifetime of one screen (create
/// it in `initState`, not per-rebuild) — it caches [ExamModel] lookups
/// in memory so the same exam is never fetched twice in one screen
/// session.
class ExamAttemptResolver {
  final ExamRepository _examRepository = ExamRepository();
  final Map<String, ExamModel?> _cache = {};
  final Set<String> _pending = {};

  /// Kicks off a (deduplicated) fetch for any attempt's exam not yet
  /// cached or already in flight. Calls [onUpdated] once more exams
  /// resolve, so the caller can rebuild.
  void ensureCached(Iterable<ExamAttemptModel> attempts, VoidCallback onUpdated) {
    for (final attempt in attempts) {
      final examId = attempt.examId;
      if (_cache.containsKey(examId) || _pending.contains(examId)) continue;
      _pending.add(examId);
      _examRepository.getById(examId).then((result) {
        _cache[examId] = switch (result) {
          Success(data: final data) => data,
          Failure() => null,
        };
        _pending.remove(examId);
        onUpdated();
      });
    }
  }

  /// Attempts whose resolved exam matches [examTypeId], paired with
  /// that exam. Attempts still resolving, or whose exam failed to
  /// load, are simply omitted — check [isResolving] to tell the two
  /// cases apart from "genuinely no matches".
  List<(ExamAttemptModel, ExamModel)> matchType(Iterable<ExamAttemptModel> attempts, String examTypeId) {
    final matched = <(ExamAttemptModel, ExamModel)>[];
    for (final attempt in attempts) {
      final exam = _cache[attempt.examId];
      if (exam != null && exam.type.id == examTypeId) matched.add((attempt, exam));
    }
    return matched;
  }

  /// Every attempt whose exam has resolved, paired with that exam —
  /// the unfiltered counterpart to [matchType]. Stage CBT-2's "My
  /// Attempts" section spans every board/mode in one list, so it needs
  /// the join without the type filter [ExamHistoryScreen] applies.
  List<(ExamAttemptModel, ExamModel)> matchAll(Iterable<ExamAttemptModel> attempts) {
    final matched = <(ExamAttemptModel, ExamModel)>[];
    for (final attempt in attempts) {
      final exam = _cache[attempt.examId];
      if (exam != null) matched.add((attempt, exam));
    }
    return matched;
  }

  /// True while at least one of [attempts]' exams hasn't resolved yet.
  bool isResolving(Iterable<ExamAttemptModel> attempts) =>
      attempts.any((attempt) => !_cache.containsKey(attempt.examId));
}
