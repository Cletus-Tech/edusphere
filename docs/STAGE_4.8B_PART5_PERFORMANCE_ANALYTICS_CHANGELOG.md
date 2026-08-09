# Stage 4.8B Part 5 — Performance Analytics (spec section 16)

Targeted addition: a real screen for the one remaining "data exists,
no UI" gap flagged in the Part 3 audit (Student Exam History, the
other one, shipped in Part 4). No CBT rules, scoring, admin config, or
review system touched.

## Master Project audit before building

- `ExamAttemptModel` already stores everything spec section 16 asks to
  track except a per-difficulty split: `topicBreakdown`,
  `scorePercent`, `passed`, `timeTakenSeconds`, `totalQuestions` — all
  written once, at submission, by the existing `ExamScoring` /
  `ExamRunnerScreen` flow. Nothing here changes how an attempt is
  scored or stored.
- `performance_placeholder_screen.dart` was the only thing standing in
  for this screen — a static "coming soon" placeholder wired into all
  three boards' "Performance" tile, never anything else.
- Reused the `ExamAttemptResolver` built in this same part (see below)
  rather than copying `ExamHistoryScreen`'s examId → exam join logic a
  second time.

## What this part adds

**New: `lib/features/exam_prep/exam_attempt_resolver.dart`** —
`ExamAttemptResolver`, extracted from `ExamHistoryScreen`'s inline
cache-and-match logic so History and the new Performance screen share
one implementation of "resolve this student's attempts to their exam
and filter by board" instead of two copies of the same code. Per the
Master Project "no duplicate business logic" rule.

**New: `lib/features/exam_prep/performance_analytics_screen.dart`** —
`PerformanceAnalyticsScreen(examTypeId, title)`, generic like every
other `exam_prep/` screen. Shows, per board:
- **Summary grid**: Attempts, Average Score, Pass Rate, Avg. Time per
  Question — all aggregated client-side from the matched attempts.
- **Score Trend**: last 10 attempts as a hand-rolled bar strip
  (green/red by pass/fail) — no charting package exists in
  `pubspec.yaml`, so this follows the project's existing plain-
  `Container`-sizing approach rather than adding a dependency for one
  screen.
- **Strong Topics / Weak Topics**: `topicBreakdown` summed across every
  matched attempt, sorted by percent correct, shown as labeled
  progress bars.
- **Recent Attempts**: tap-through to the existing `ExamResultScreen`.

**Modified — one line each, same tile position, same tile shape:**
- `lib/features/waec/waec_dashboard_screen.dart` — Performance tile
  now opens `PerformanceAnalyticsScreen` instead of the placeholder.
- `lib/features/neco/neco_dashboard_screen.dart` — same.
- `lib/features/jamb/jamb_dashboard_screen.dart` — same, plus a stale
  doc-comment reference to the old placeholder updated.

**Removed: `lib/features/exam_prep/performance_placeholder_screen.dart`**
— fully superseded, same precedent as the Stage 4.7 `JambScreen`
deletion (not orphaned; every call site now points at the real
screen; grep-confirmed zero remaining references anywhere in `lib/`).
`study_plan_placeholder_screen.dart`'s doc comment, which referenced
this file for context, was updated rather than left stale — Study Plan
itself is untouched and still a genuine placeholder.

## Deliberately not built (real new scope, not a display gap)

- **Difficulty Analysis** / a scored "Performance Graph" — `QuestionModel.
  difficulty` exists, but no attempt stores a per-difficulty
  breakdown the way `topicBreakdown` exists for topics. Building this
  means changing `ExamScoring` and leaves every already-submitted
  attempt without the new field. Left for a future stage.
- **Recommendations** (spec section 9) — would need a rules engine
  reading weak-topic data against the learning-materials catalog;
  genuinely new logic, not a screen.

## Verification

- Full-project brace/paren balance: 0 imbalanced files.
- Full-project local import resolution: 0 unresolved imports.
- Confirmed zero remaining references to the deleted placeholder file
  anywhere in `lib/`.
- Confirmed `SectionHeader`'s only required constructor param is
  `title`, matching usage.
- Confirmed `AppTextStyles.headlineSmall` exists, matching usage.

## Files created
- `lib/features/exam_prep/exam_attempt_resolver.dart`
- `lib/features/exam_prep/performance_analytics_screen.dart`

## Files modified (additive)
- `lib/features/exam_prep/exam_history_screen.dart` — refactored to use
  the shared `ExamAttemptResolver` instead of its own inline cache
  (behavior unchanged).
- `lib/features/exam_prep/study_plan_placeholder_screen.dart` — stale
  doc-comment reference fixed.
- `lib/features/waec/waec_dashboard_screen.dart`,
  `lib/features/neco/neco_dashboard_screen.dart`,
  `lib/features/jamb/jamb_dashboard_screen.dart` — Performance tile
  repointed; import swapped.

## Files removed
- `lib/features/exam_prep/performance_placeholder_screen.dart` —
  superseded, zero remaining references.

## Still open (unchanged apart from the two items above)
- 9 of 14 question-type UIs
- Difficulty Analysis / Performance Graph (needs `ExamScoring` change)
- Recommendations engine
- Offline sync engine
- Proctoring hooks / institutional remote exam (reserve-architecture
  only per spec)
- Admin-side "view all students' attempts" screen (raised, not yet
  built — separate from the student-facing screens in this part)
