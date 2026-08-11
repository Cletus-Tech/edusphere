# Stage 6.2.2 — Bulk Institution Import

Continues directly from Stage 6.2.1's Shared CSV Import Framework.
Adds bulk import for institutions — the top of the academic hierarchy
(`InstitutionModel`, `institutions` collection) — reusing that
framework end-to-end, plus one deliberate, additive extension to it:
JSON support, which this stage's brief asked for alongside CSV.

## Audit performed before implementation

- **`InstitutionModel`** (`lib/models/institution_model.dart`) already
  had every field this stage needed: `name`, `shortName`, `type`
  (`InstitutionType` enum), `state`/`country` (location), `isActive`.
  **Not modified** — nothing was missing.
- **`InstitutionRepository`** (`lib/repositories/institution_repository.dart`)
  already provides `save()`/`newId()` via `BaseRepository` — used
  as-is, no changes.
- **Existing manual management screen:**
  `AcademicStructureScreen` (`lib/features/admin/academic_structure/
  academic_structure_screen.dart`) already has full manual Add/Edit
  (`_openForm`)/Delete (`_delete`) for institutions, confirmed
  unchanged and still wired to the same FAB.
- **Firestore collection:** single `institutions` collection
  (`AppConstants.institutionsCollection`), confirmed no second
  collection exists or was created.
- **Existing validators:** the manual form only hard-requires `name`
  (`shortName`/`type` are optional there, `type` falling back to
  `university`). This bulk import is intentionally a little stricter
  — see `bulk_institution_import_screen.dart`'s doc comment for why.

## What this stage adds

**New: `lib/features/admin/academic_structure/bulk_institution_import_screen.dart`**
`BulkInstitutionImportScreen` (thin wrapper, same shape as
`BulkQuestionUploadScreen`) + `_InstitutionImportSpec implements
CsvImportSpec<InstitutionModel>`. Column format: `name, shortName,
type, state, country, isActive` — `name`/`shortName`/`type` required,
`state` optional, `country` defaults to `"Nigeria"` (matching the
model's own default), `isActive` defaults to `true` if blank
(matching the model's own default). Saves through the existing
`InstitutionRepository`, logs through the existing
`AuditLogService.instance.log(...)` with `AuditModules
.academicStructure`.

**Modified: `lib/features/admin/academic_structure/academic_structure_screen.dart`**
Added one `IconButton` ("Bulk import institutions") to the existing
AppBar, pushing `BulkInstitutionImportScreen`. The manual "Add
Institution" FAB, `_openForm`, and `_delete` are all unchanged.

## Framework extension: JSON support (Stage 6.2.1 → 6.2.2)

This stage's brief asked for CSV *and* JSON. Rather than build a
second, parallel screen/preview/progress stack for JSON, the Stage
6.2.1 framework was extended additively:

- **New: `lib/shared/import/json_utils.dart`** — `readJsonRows()`
  parses a top-level JSON array of objects and, using a spec's new
  `columnOrder` (below), converts each object into the exact same
  `CsvRow` shape a CSV row already produces. A `CsvImportSpec
  .parseRow()` implementation never has to know or care which format a
  row came from — both arrive positionally identical.
- **Modified: `lib/shared/import/csv_import_spec.dart`** — added one
  new required getter, `List<String> get columnOrder`, documenting the
  positional column order `parseRow` reads. `_QuestionImportSpec`
  (Stage 6.2.1's only existing implementer) was updated with its
  already-documented column order (`type, text, options, correct,
  explanation, difficulty, topic, points`) — a one-line addition, not
  a behavior change.
- **Modified: `lib/shared/import/csv_import_screen.dart`** —
  `_pickFile()` now branches on the picked file's extension: `.json`
  goes through `readJsonRows`, everything else (including the existing
  `.csv` path) is unchanged. Malformed files (invalid JSON, non-array
  top level) now surface a whole-file error via `AppSnackbar.error`
  instead of silently producing zero rows.
- `_QuestionImportSpec.allowedExtensions` stays `['csv']` only —
  question import's file-picker behavior is unchanged.
  `_InstitutionImportSpec.allowedExtensions` is `['csv', 'json']`.

## Verification performed

- No duplicate `.dart` filenames anywhere in `lib/`.
- `InstitutionModel` and `InstitutionRepository` each still defined
  exactly once; `InstitutionModel` confirmed **not modified** (audit
  found nothing missing that would have required it).
- Single `institutions` Firestore collection constant
  (`AppConstants.institutionsCollection`) — no second collection
  introduced.
- Brace/paren balance checked on every new and modified file.
- Manual Add/Edit/Delete institution flow (`_openForm`/`_delete`)
  confirmed still present and unchanged in `academic_structure_screen.dart`.
- `_QuestionImportSpec`'s CSV parsing path confirmed unaffected by the
  `columnOrder` addition — `readCsvRows` doesn't consume it; only
  `readJsonRows` does.

## Remaining tasks (not done in this stage)

- **Bulk Faculties/Departments/Levels/Semesters/Courses/Learning
  Materials** — still not built, per Stage 6.1/6.2.1's explicit
  scope. `AcademicNodeModel` (shared shape for faculties through
  semesters) is a natural next `CsvImportSpec` target, following the
  exact pattern this stage and Stage 6.2.1 established.
- **No Import Center hub** — bulk institution import is reached from
  `AcademicStructureScreen`'s AppBar, same as bulk question import is
  reached from `QuestionManagerScreen` — each module's entry point
  still lives on its own manager screen, not a unified hub.
- **Branch reconciliation** (flagged in Stage 6.1, still unresolved)
  — this work exists only in this "final"-branch project, not yet
  merged with GitHub `main`.
