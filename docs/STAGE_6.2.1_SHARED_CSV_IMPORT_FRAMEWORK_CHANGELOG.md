# Stage 6.2.1 — Shared CSV Import Framework

Continues directly from Stage 6.1's audit, which found the pieces
Stage 6.1's brief asked for **already existed, just locked inside one
screen**: `BulkQuestionUploadScreen` already had real CSV file
selection, parsing, per-row validation, a preview list, upload
progress, a success/failure summary, and audit logging — everything
Stage 6.1 asked the future Import Center to support — but every piece
of that was private to `bulk_question_upload_screen.dart`, so
Institutions/Faculties/Departments/Levels/Semesters/Courses/Learning
Materials bulk import would each have had to reimplement all of it
from scratch. This stage extracts that logic into a reusable
framework, with **zero behavior change** to bulk question import.

## What this stage adds

**New: `lib/shared/import/csv_utils.dart`**
`CsvRow`, `splitCsvLine()`, `readCsvRows()` — the quoted-field-aware
CSV line splitter and header-skipping row reader, extracted verbatim
from `BulkQuestionUploadScreen`'s private `_splitCsvLine`/`_parseCsv`
line-splitting logic. Same behavior (handles `"1,000|2,000"`-style
quoted commas; skips blank lines; header row required by default), now
shared instead of duplicated per module.

**New: `lib/shared/import/import_types.dart`**
`ImportRowResult<T>` (mirrors the old private `_ParsedRow`, generic
over the parsed type instead of hardcoded to `QuestionModel`) and
`ImportRunSummary` (upload-phase success/failure counts, returned to
the caller via `Navigator.pop` so a future Import Center hub screen
can show a run history without re-deriving it).

**New: `lib/shared/import/csv_import_spec.dart`**
`CsvImportSpec<T>` — the abstract contract a bulk-import module
implements once: `parseRow`, `save`, `describeValid` (preview text),
`logImport` (audit logging), plus title/help-text/allowed-extensions.
Nothing module-specific lives outside this; nothing framework-level
lives inside it.

**New: `lib/shared/import/csv_import_screen.dart`**
`CsvImportScreen<T>` — the reusable screen driving steps 1-9 from this
stage's brief (file selection → parsing → data conversion → preview →
row validation/error display → import confirmation → progress
tracking → success/failure summary) against whatever `CsvImportSpec`
it's given. Direct extraction of `BulkQuestionUploadScreen`'s State
class and build method — same widget structure, same UI, generic over
`T` instead of hardcoded to `QuestionModel`.

## What changed

**Modified: `lib/features/admin/exam_prep/bulk_question_upload_screen.dart`**
Reduced from one 346-line screen to a ~40-line `StatelessWidget`
wrapper (`BulkQuestionUploadScreen`, same constructor signature —
`question_manager_screen.dart`'s call site needed no changes) plus a
`_QuestionImportSpec implements CsvImportSpec<QuestionModel>` holding
exactly the question-specific rules that used to be inline: the same
column format, the same per-row validation messages, the same
`QuestionModel` construction (`correctOptionIndex`, `correctAnswers`
conventions unchanged — manual and bulk-imported questions still score
identically), the same audit log call
(`AuditModules.academicStructure`, same target/title format). No
parsing rule, error message, or Firestore write changed.

## Verification performed

- No duplicate `.dart` filenames anywhere in `lib/` (checked via full
  filename scan).
- `BulkQuestionUploadScreen` defined exactly once.
- Brace/paren balance checked on every new and modified file.
- No remaining references to the old private `_ParsedRow`,
  `_splitCsvLine`, or `_parseCsv` symbols anywhere in the codebase
  (only doc-comment mentions, for context).
- `question_manager_screen.dart`'s `BulkQuestionUploadScreen(exam:
  widget.exam)` call site is unchanged and still compiles against the
  new constructor.
- `dart:io`/`file_picker` imports moved fully into
  `csv_import_screen.dart`; confirmed no longer imported by
  `bulk_question_upload_screen.dart`, which no longer needs them.

## What Stage 6.1's future modules get for free

Any future bulk-import screen (Bulk Institutions, Bulk Faculties, Bulk
Departments, Bulk Levels, Bulk Semesters, Bulk Courses, Bulk Learning
Materials) now needs only:

1. A model-specific `CsvImportSpec<T>` implementation (parse rules +
   `save()` call into that entity's existing repository + audit log
   call) — the same shape `_QuestionImportSpec` is now.
2. `CsvImportScreen<T>(spec: MyNewSpec())` as its entry point.

No new file-picker plumbing, no new preview/progress/summary UI, no
new CSV parsing.

## Remaining tasks (not done in this stage, per Stage 6.1/6.2.1's scope)

- **No new bulk-import modules were built** — Institutions, Faculties,
  Departments, Levels, Semesters, Courses, and Learning Materials all
  still only support manual single-item creation. Stage 6.1's brief
  explicitly deferred this ("do not implement all bulk import modules
  yet"); this stage only built the foundation they'll use.
- **`BulkQuestionUploadScreen`/`_QuestionImportSpec` is still scoped to
  one `ExamModel`** — a category/subject-aware bulk-question entry
  point (so an admin can bulk-import questions across an exam board
  without picking one exam first) wasn't part of this stage's scope
  and remains open from Stage 6.1's audit.
- **No Import Center hub screen** — each bulk-import module (question
  import today) is still reached from its own manager screen
  (`QuestionManagerScreen`'s "Bulk upload from CSV" action), not a
  unified `Admin → Import Center` entry point. `ImportRunSummary` was
  added specifically so a future hub could show run history, but no
  such hub exists yet.
- **Excel/JSON/Word-PDF formats** — still CSV-only, as Stage 6.1's own
  text marked those "(future)".
- **Branch reconciliation flagged in Stage 6.1's audit is still
  unresolved** — this stage's work exists only in this "final"-branch
  zip, not yet merged with whatever is canonical on GitHub `main`.
