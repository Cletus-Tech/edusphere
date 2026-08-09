# Stage 4.8B — Unified CBT Engine — Part 2: Admin Exam Configuration

Continues directly from Part 1's audit, which flagged this as the
highest-priority gap: **`ExamModel` already had every admin-configurable
field the CBT spec calls for (built in Stage 4.8A), but nothing in the
app could actually create or edit one** — every exam in Firestore had to
be hand-written. This part closes that gap, and wires the navigation
rules and results-visibility field Part 1 added to the model into the
runner's actual behavior (they were stored but not yet enforced).

## What this part adds

**New: `lib/features/admin/exam_prep/exam_manager_screen.dart`**
`ExamManagerScreen` — list of all exams with a type filter chip row,
add/edit/delete, and a menu to jump straight to that exam's questions.
Reuses `ExamRepository` as-is; no new repository.

**New: `lib/features/admin/exam_prep/exam_editor_screen.dart`**
`ExamEditorScreen` — one full-screen form covering every `ExamModel`
field, organized to match the spec's section 18 categories: Identity,
Supported modes, Question settings & timing, Marking, Navigation rules,
Calculator, Results, Access & offline, Attempts. Nothing here is a new
model field — this screen is purely the UI Part 1's audit found missing
for fields that already existed since Stage 4.8A.

**New: `lib/features/admin/exam_prep/question_manager_screen.dart`**
`QuestionManagerScreen` (list) + `_QuestionEditorScreen` (create/edit),
scoped to one exam. Deliberately restricts the type picker to the five
`QuestionType`s the runner can actually render and score
(single-choice, multiple-choice, true/false, fill-in-the-blank,
short-answer) — building admin UI for the other nine would let an admin
create content no student can actually answer yet. That gap is called
out explicitly in the file's own doc comment and in the Part 1 backlog,
not silently ignored.

**`lib/shared/widgets/app_text_field.dart`** — added an optional
`maxLines` parameter (defaults to `1`, matching every existing call
site's behavior exactly). Needed for question text/explanation fields
in the new editor; forced back to `1` whenever `isPassword` is set,
since an obscured multi-line field doesn't make sense.

**`lib/features/admin/admin_dashboard_screen.dart`** — new "Exams" tile,
same pattern as every other admin module tile.

## Wiring the rules Part 1 added but didn't yet enforce

Part 1 added `allowBackNavigation`, `allowFlagging`, `allowSkipping`,
`requireReviewBeforeSubmit`, and `showResultsImmediately` to
`ExamModel` as configuration, but the runner didn't read them yet. This
part does:

- **`lib/features/exam_prep/exam_runner_screen.dart`**
  - The flag button only renders when `exam.allowFlagging` is true.
  - `_jumpTo` — the single funnel every navigation path (Previous
    button, palette tap, strip tap) goes through — now refuses to move
    to an earlier index when `allowBackNavigation` is false, so the
    rule can't be bypassed through the palette even though the
    Previous button is also disabled.
  - The Next button is disabled on an unanswered question when
    `allowSkipping` is false.
  - `requireReviewBeforeSubmit` is stored and readable but not yet
    enforced — enforcing it needs the review screen from the Part 1
    backlog (spec section 15), which doesn't exist yet. Wiring a rule
    to a screen that isn't built would be worse than leaving it
    visibly unenforced; the field's editor subtitle says so explicitly
    ("Reserved for the review/retry screen (not yet built)").

- **`lib/features/exam_prep/exam_result_screen.dart`** —
  `showResultsImmediately: false` now shows a "Submission received...
  results release after admin review" state instead of the score
  breakdown. The score is still computed and written to
  `exam_attempts` exactly as before (nothing about scoring changed) —
  only what the student's screen displays is gated. There's no admin
  "release results" action yet (that's separate work, part of spec
  section 14's remaining gap); this part only stops premature exposure.

## Compatibility

- `ExamModel`'s new navigation-rule fields (`allowBackNavigation`,
  `allowFlagging`, `allowSkipping`, `requireReviewBeforeSubmit`,
  `showResultsImmediately`) all default to today's actual pre-Stage-4.8B
  behavior (free navigation, flagging on, no review gate, immediate
  results) — every exam document written before this stage decodes and
  behaves exactly as it did before.
- `firestore.rules` already had correct `isStaff()` write access on
  both `exams` and `questions` from Stage 4.8A — verified, not modified.
- No repository changes — `ExamRepository`/`QuestionRepository` were
  already complete; only UI was missing.

## Updated spec audit (deltas from Part 1's table only)

| # | Section | Part 1 status | Now |
|---|---|---|---|
| 11 | Navigation rules | ❌ Missing | ✅ Done — fields + runner enforcement |
| 14 | Results system | ⚠️ Partial | ⚠️ Still partial — visibility gating done; no admin "release" action yet |
| 18 | Admin exam configuration | ❌ Missing | ✅ Done |

Everything else in Part 1's table is unchanged by this part — still
open: 9 of 14 question types have no answer-entry UI (#3/#4), offline
sync engine (#9), review/retry screen (#15), performance
analytics/history screens (#16/#17), premium access enforcement (#19),
exam availability states beyond `isActive` (#21), proctoring event
hooks (#24), institutional remote exam (#25).

## Completion checklist

- ✅ Admin can create/edit/delete exams end-to-end through the app
- ✅ Admin can create/edit/delete questions for the 5 supported types
- ✅ Navigation rules enforced in the runner (back nav, flagging, skip)
- ✅ Results visibility gating enforced in the results screen
- ✅ No duplicate models, repositories, or Firestore collections
- ✅ Existing exams/sessions/attempts decode unchanged
- ✅ Whole-project import + duplicate-class + brace/paren check clean
