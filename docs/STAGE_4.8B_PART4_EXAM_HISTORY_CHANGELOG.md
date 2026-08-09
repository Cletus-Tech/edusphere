# Stage 4.8B Part 4 — Student Exam History (spec section 17)

Targeted, self-contained addition. No CBT rules, scoring, admin
config, or review system touched.

## What existed already

`ExamAttemptRepository.watchHistoryForUser(userId)` (Stage 4.8A) — a
correct, working stream of every attempt a user has submitted, most
recent first. Nothing called it yet; this was the only genuine gap
flagged in the Part 3 audit that had zero UI built against it.

## What this part adds

**New: `lib/features/exam_prep/exam_history_screen.dart`** —
`ExamHistoryScreen(examTypeId, title)`, generic like `ExamListScreen`
and `SubjectBrowseScreen` so WAEC/NECO/JAMB (and any future board)
reuse one file instead of copies.

Design note: `ExamAttemptModel` stores `examId` but not which board an
exam belongs to, so filtering "WAEC history" vs "NECO history" means
resolving each attempt's `ExamModel` and checking `exam.type.id`. Done
with an in-memory cache (`Map<String, ExamModel?>`) keyed by `examId`
so each exam is fetched once per screen session, not once per
attempt-list rebuild. Tapping an attempt reuses the existing
`ExamResultScreen(exam, attempt)` — same results view a student sees
right after submitting, not a separate summary screen.

**Modified — one new tile each, following the existing tile-grid
pattern exactly (no layout changes otherwise):**
- `lib/features/waec/waec_dashboard_screen.dart`
- `lib/features/neco/neco_dashboard_screen.dart`
- `lib/features/jamb/jamb_dashboard_screen.dart`

## Verification

- Full-project brace/paren balance: 0 imbalanced files.
- Full-project local import resolution: 0 unresolved imports.
- Confirmed `Result`/`Success`/`Failure` pattern usage matches
  `lib/core/utils/result.dart`'s actual sealed-class shape.
- Confirmed `ExamModel.type` is an `ExamType` with `.id`, matching
  `ExamRepository.watchByType`'s existing `type` field query.
- Confirmed `ExamResultScreen`'s constructor (`exam`, `attempt`)
  matches the call site.

## Files created
- `lib/features/exam_prep/exam_history_screen.dart`

## Files modified (additive only)
- `lib/features/waec/waec_dashboard_screen.dart` — History tile + import
- `lib/features/neco/neco_dashboard_screen.dart` — History tile + import
- `lib/features/jamb/jamb_dashboard_screen.dart` — History tile + import

## Still open (unchanged from Part 3 audit)
- 9 of 14 question-type UIs (matching, ordering, passage-based,
  diagram-based, mathematical notation, table, case study,
  novel-based, long answer)
- Performance Analytics (data exists via `topicBreakdown`, no
  visualization screen yet)
- Offline sync engine
- Proctoring hooks / institutional remote exam (reserve-architecture
  only per spec)
