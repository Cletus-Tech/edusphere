# CBT-REFACTOR Phase 1 — Critical Bug Fix + Data Integrity

Continues directly from the CBT-REFACTOR audit, which confirmed Part
1's hypothesis: bulk-imported choice questions score as permanently
wrong regardless of what a student picks. This stage fixes it, fixes a
**second, previously-unflagged instance of the same bug** the audit
didn't catch, and builds the migration tool for already-broken data.

## The bug, precisely

The runner (`exam_runner_screen.dart`) and scorer
(`exam_scoring.dart`) have always agreed on one contract: for
`singleChoice`, `multipleChoice`, and `trueFalse` questions, a
selected answer and `QuestionModel.correctAnswers` are both
stringified **option indexes** ("1", not "Abuja"; "0"/"1" for
true/false, not "true"/"false"). Two of the three places that
*produce* a `QuestionModel` didn't honor that contract:

| Producer | singleChoice/multipleChoice | trueFalse |
|---|---|---|
| `question_manager_screen.dart` (manual form) | ✅ already correct — stored `_correctOptionIndexes` as index strings | ❌ stored `_trueFalseAnswer.toString()` → literal `"true"`/`"false"` |
| `bulk_question_upload_screen.dart` (CSV/JSON import) | ❌ stored `correctRaw` → raw option **text** | ❌ stored `correctRaw.first.toLowerCase()` → literal `"true"`/`"false"` |

So: every bulk-imported choice question, **and every trueFalse
question regardless of creation method**, scored as wrong 100% of the
time. The audit's own bug report only illustrated the choice-question
case; the trueFalse instance was found while implementing this fix, by
tracing the same contract through every producer rather than just the
one the report described.

## What changed

**`lib/features/admin/exam_prep/question_manager_screen.dart`**
- Save: `trueFalse` now stores `[_trueFalseAnswer ? '0' : '1']`
  (index into `['True', 'False']`, matching the runner's own display
  order) instead of literal `.toString()` of the bool.
- Load/edit: made resilient to *both* the old broken format and the
  new correct one, rather than assuming data is already migrated —
  `int.tryParse` instead of `int.parse` for singleChoice/multipleChoice
  (a not-yet-repaired question no longer crashes the editor, it just
  shows no pre-selected answer), and trueFalse accepts `"0"`/`"1"` or
  the old `"true"`/`"false"` text during the migration window.

**`lib/features/admin/exam_prep/bulk_question_upload_screen.dart`**
- `correctAnswers` is now built from computed option indexes for
  `singleChoice`/`multipleChoice` (`correctRaw.map((c) =>
  options.indexOf(c).toString())` — safe because validation already
  guarantees every entry matches an option before this point) and from
  `"0"`/`"1"` for `trueFalse`, not raw text.
- CSV/JSON input format is **unchanged** — a person authoring an
  import file still writes option text and `"true"`/`"false"`, exactly
  as documented; only what gets *stored* changed.

**New: `lib/features/admin/exam_prep/question_data_repair_screen.dart`**
`QuestionDataRepairScreen` — the "Question Data Repair Tool" from the
brief. Scan → diagnose → preview → confirm:
- Reads every question of an index-based type (`singleChoice`,
  `multipleChoice`, `trueFalse` — `fillInTheBlank`/`shortAnswer` were
  never index-based, excluded from scanning entirely).
- A question already in the correct format is skipped silently — the
  tool only ever surfaces things that actually need fixing.
- **Resolvable**: an entry that isn't a valid index but *does* match
  an option's text (or is `"true"`/`"false"`) — the exact original bug
  pattern. Computed fix shown in preview before anything is written.
- **Needs manual review**: an entry that matches neither a valid index
  nor any option text. Never auto-repaired — surfaced separately with
  the reason, left for a person to fix directly in Question Manager.
  This tool does not guess past what it can verify against the
  question's own `options` list.
- Confirm writes each resolvable question through the existing
  `QuestionRepository.save()` (no new write path), tracks progress,
  logs one audit entry via the existing `AuditLogService` summarizing
  the batch, then re-scans so the list reflects the repaired state.

**Modified: `lib/features/admin/cbt/cbt_control_center_screen.dart`**
Added one `_SectionTile` ("Question Data Repair") to the existing CBT
Management hub, reusing the same tile pattern every other entry there
already uses.

## Verification performed

- No duplicate `.dart` filenames anywhere in `lib/`.
- `QuestionDataRepairScreen` defined exactly once.
- Brace/paren balance checked on every modified/new file.
- **Traced the full producer → runner → scoring contract by hand**
  for both a manually-created and a bulk-imported question, for both
  `singleChoice` and `trueFalse` — confirmed the stored answer and the
  runner's stored selection now match in all four cases (they didn't,
  in three of the four, before this fix).
- `AuditModules.academicStructure`, `AppColors.error`, and
  `QuestionRepository.getWhere` (used unfiltered for the scan) all
  confirmed to already exist — no new repository method or constant
  needed.

## Explicitly not done in this stage (per the brief)

- **Phase 2** (verify the full start→answer→submit→result→history→
  review flow is stable) — not run. The brief says not to build
  anything further until this is confirmed stable; that verification
  is a testing/reproduction task, not a code change, and wasn't done
  here.
- **Phases 3-5** (Examination Routing System, Role Permission
  Architecture, Smart Academic Selectors) — untouched, as instructed
  ("fix the scoring foundation" first).
- **Branch reconciliation** (flagged repeatedly since the original
  CBT-1 audit) — still unresolved.
