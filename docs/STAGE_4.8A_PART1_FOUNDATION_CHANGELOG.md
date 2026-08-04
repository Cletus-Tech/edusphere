# Stage 4.8A — Unified CBT Engine Core — Part 1: Foundation

Part 1 of the CBT Engine build. This is the **data/model/rules
foundation** the runner UI (navigator, palette, timers, calculator,
etc.) will sit on — not a working exam screen yet. Scoped this way on
purpose: the full 4.8A spec is a multi-thousand-line feature and every
piece of it (session state, resume, offline, premium gating,
attempt limits) depends on this layer existing correctly first.

## Audit performed before writing anything

- `lib/features/cbt/cbt_screen.dart` — placeholder only, wired to a
  Control Center feature flag. No real UI.
- `lib/models/exam_model.dart` — `ExamModel` and `QuestionModel`
  already existed (single-choice only, no admin config).
- `lib/repositories/learning_repository.dart` — **`ExamRepository` and
  `QuestionRepository` already existed** in this file (not their own
  files, historically colocated with `LearningContentRepository`).
  Extended in place rather than creating new repository files, to
  avoid the exact duplicate-repository situation the spec warns
  against.
- `lib/features/exam_prep/exam_list_screen.dart` — already streams
  real `ExamModel` data via `ExamRepository.watchByType`; "Start"
  currently shows a "coming soon" snackbar. This is the screen a later
  part of 4.8A will wire to the real engine.
- `AppConstants.cbtQuestionsCollection` ('cbt_questions') — unused
  dead constant from an earlier stage. Left in place (not deleted,
  per "don't remove until verified unused" precedent) but commented
  to warn against wiring new code to it, since `questionsCollection`
  ('questions') is the real, populated question bank every exam type
  already shares.

## What this part adds

**`lib/core/enums/content_type.dart`**
- `QuestionType` — all 14 types from the 4.8A/4.8B spec (single-choice
  through novel-based). Defaults to `singleChoice` on decode so every
  question written before this stage keeps working.
- `ExamMode` (official / practice / mock), `ExamSessionStatus`,
  `SyncStatus`, `CalculatorType`.

**`lib/models/exam_model.dart`**
- `ExamModel`: added `calculatorType`, `negativeMarkingEnabled` +
  `negativeMarkPercent`, `shuffleQuestions`, `shuffleOptions`,
  `attemptLimit`, `availableFrom`/`availableUntil`, `isPremium`,
  `offlineAvailable`, `proctoringEnabled`, `supportedModes` — every
  item on the spec's admin-controlled-configuration list. All default
  to today's actual behavior, so no data migration is needed.
- `QuestionModel`: added `type`, `correctAnswers` (generalized,
  multi-type answer key), `typeData` (type-specific structured data —
  matching pairs, ordering sequence, passage text, etc., same pattern
  as `ExamModel.metadata`), `points`, `premiumExplanation`. The
  original `correctOptionIndex`/`options` fields are untouched, not
  deprecated — they're still what single-choice questions use.

**`lib/models/exam_session_model.dart`** (new file)
- `ExamSessionModel` — the live, auto-saved, resumable in-progress
  attempt (`exam_sessions/{id}`): answers map, flagged/bookmarked
  question ids, per-session question order (for shuffle-once-not-every-
  resume), remaining seconds, `syncStatus` for offline-first.
- `ExamAttemptModel` — the permanent submitted-result record
  (`exam_attempts/{id}`): score, correct/incorrect/unanswered counts,
  time taken, pass/fail, and a `topicBreakdown` map populated at
  scoring time so Stage 4.8B's weak/strong-topic detection has data to
  read without a later backfill.
- Kept as two collections, not one with a status field, because
  sessions get overwritten on every autosave while attempts are
  read-heavy permanent history — mixing those patterns on one document
  would make every keystroke's autosave contend with analytics reads.

**`lib/repositories/learning_repository.dart`**
- `ExamSessionRepository` — `findResumableSession`,
  `watchResumableSessions`, `autoSave`.
- `ExamAttemptRepository` — `watchHistoryForUser`,
  `fetchAttemptsForExam` (attempt-limit / retake checks).
- Both added next to the existing `ExamRepository`/`QuestionRepository`
  in this file rather than new files, matching where those already
  lived.

**`firestore.rules`**
- `exam_sessions`: owner read/write, staff read-only (support/grading),
  no staff write — a session should only ever reflect what the student
  actually did.
- `exam_attempts`: owner + staff read, owner create, admin-only
  update/delete — a submitted result is meant to be permanent.

**`firestore.indexes.json`**
- `exam_sessions`: `(userId, examId, status)` for resume lookup,
  `(userId, status)` for the resumable-sessions list.
- `exam_attempts`: `(userId, submittedAt desc)` for performance
  history, `(userId, examId)` for attempt-limit checks.

## What this part does NOT include (deferred to later 4.8A parts)

- No UI: no navigator, question palette, flag/bookmark buttons, timer
  display, or calculator widget yet.
- No actual scoring logic (the fields exist on `ExamAttemptModel`;
  nothing computes them yet).
- No offline queue/replay engine — `SyncStatus` fields exist on both
  new models so nothing here will need a migration when that engine is
  built, but the engine itself (local write queue, connectivity
  listener, replay-on-reconnect) is separate work.
- `exam_list_screen.dart`'s "Start" button still shows the "coming
  soon" snackbar — wiring it to actually create/resume a session is
  the next part.
- Full type-specific runner/scoring support only exists for
  single-choice, multiple-choice, true-false, fill-in-the-blank, and
  short-answer. Matching/ordering/passage/diagram/math-notation/table/
  case-study/long-answer/novel-based decode and store correctly via
  `typeData` but have no answer-entry UI or scorer yet (4.8B).
