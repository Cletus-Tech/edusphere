# Stage 4.8B — Unified CBT Engine — Part 3: Review System + audit of Part 2

## Audit: what was already on disk

Before writing anything, I audited the project against the Part 1 gap
table (from `STAGE_4.8B_PART1_NAVIGATION_CHANGELOG.md`). Two full parts
had already been built and were sitting on disk, complete and
consistent:

- **`STAGE_4.8B_PART2_ADMIN_CONFIGURATION_CHANGELOG.md`** — closes gap
  #18 (Admin Exam Configuration), the item Part 1 flagged as highest
  priority. `ExamManagerScreen` (list/filter/delete), `ExamEditorScreen`
  (every admin-configurable field from spec section 18: identity,
  question settings, timing, marking, navigation rules, calculator,
  results visibility, access/offline, attempts), and
  `QuestionManagerScreen` (CRUD for the 5 scored question types,
  deliberately restricted from all 14 — see that file's own doc comment
  for why) all exist, are wired into `AdminDashboardScreen`, and pass a
  full import/brace/duplicate-class check.
- **Results-visibility gating** (part of gap #14) — also already done:
  `ExamResultScreen` checks `exam.showResultsImmediately` and shows a
  "submission received, results pending" state when it's off, instead
  of always revealing the score.

I verified rather than re-built these — reading every file end to end,
checking `QuestionModel`/`ExamModel` field references against their
actual definitions, and running the same import-resolution +
brace-balance + duplicate-class checks used in every prior stage. No
bugs found; nothing needed fixing.

## What this part adds: Review System (spec section 15)

The next item on the Part 1 roadmap. New: **`lib/features/exam_prep/
exam_review_screen.dart`** — `ExamReviewScreen`.

- Reads the already-scored `ExamSessionModel` (via `sessionId` on the
  `ExamAttemptModel`) and the exam's `QuestionModel`s in the session's
  fixed `questionOrder` — never re-scores, so review can't drift from
  what was actually submitted.
- Per question: student's answer, correct answer (only shown when
  wrong), and explanation if the admin set one.
- **Retry incorrect questions** — the spec explicitly calls this out
  under section 15. Required extending `ExamRunnerScreen` with an
  optional `questionIdsOverride` param: when set, the runner starts a
  fresh practice session scoped to just those question ids and
  deliberately skips `findResumableSession` (resuming an old session
  there would silently pull back the *original* full bank, defeating
  the retry). This was a real, bounded change to existing code, not a
  new file — kept the runner's existing session-creation logic and
  scoring untouched otherwise.
- Wired a "Review Answers" button into `ExamResultScreen`.

**Bug caught and fixed while building this:** `AppRadius.sm` is a
`double` (a corner radius value), not a `BorderRadius` — an explanation
box's `BoxDecoration` needed `BorderRadius.circular(AppRadius.sm)`, not
`AppRadius.sm` directly. Caught before packaging, not left for a build
to surface.

## Known simplification

Review visibility isn't a separate admin-configurable flag yet — it's
implicitly available whenever `showResultsImmediately` is on. The spec
asks for "review visibility must be configurable" as its own setting
(distinct from result visibility). Given the scope already covered this
part, that's a small, clearly-scoped follow-up (one more `ExamModel`
field + one more switch in `ExamEditorScreen`) rather than something
folded in here without being called out.

## Updated roadmap (from Part 1, adjusted for what's now done)

1. ~~Admin exam configuration UI~~ — ✅ done (Part 2)
2. ~~Review/retry screen + results visibility gating~~ — ✅ done (Part 2
   had gating; this part adds review/retry)
3. **Remaining question-type UI** (spec #3/#4) — biggest single chunk
   left; matching, ordering, passage, diagram, table, math-notation,
   case-study, long-answer, novel-based. Can be done type-by-type
   without touching the runner's navigation/timer/scoring shell.
4. **Student exam history** (spec #17) — `ExamAttemptRepository.
   watchHistoryForUser` already exists (Stage 4.8A); no screen calls it
   yet. Small, self-contained, high value — good next slice.
5. **Performance analytics** (spec #16) — `performance_placeholder_
   screen.dart` is still a placeholder; `ExamAttemptModel.
   topicBreakdown` already has the data.
6. **Offline sync engine** (spec #9) — the `SyncStatus` contract is
   ready on both `ExamSessionModel` and `ExamAttemptModel`; this is
   genuinely new infrastructure (local queue, connectivity listener,
   replay-on-reconnect), not an extension of existing files.
7. **Proctoring event hooks** (spec #24) and **institutional remote
   exam** (spec #25) — explicitly spec'd as reserve-the-architecture-
   only for now; lowest priority until an actual proctoring requirement
   exists.

## Files created
- `lib/features/exam_prep/exam_review_screen.dart`

## Files modified (additive only)
- `lib/features/exam_prep/exam_runner_screen.dart` — `questionIdsOverride`
  param + scoped session creation.
- `lib/features/exam_prep/exam_result_screen.dart` — "Review Answers"
  button.

## Files verified, not modified
- `lib/features/admin/exam_prep/exam_manager_screen.dart`
- `lib/features/admin/exam_prep/exam_editor_screen.dart`
- `lib/features/admin/exam_prep/question_manager_screen.dart`
- `lib/models/exam_model.dart`
