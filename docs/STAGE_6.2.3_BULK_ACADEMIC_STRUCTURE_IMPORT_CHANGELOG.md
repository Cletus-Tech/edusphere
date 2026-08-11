# Stage 6.2.3 — Bulk Academic Structure Import

Continues from Stage 6.2.2 (Bulk Institution Import). Adds bulk import
for the four levels beneath Institution — Faculty, Department, Level,
Semester — as **one** reusable import system, not four, per this
stage's brief.

## Audit performed before implementation

The code for this stage's screen already existed in the uploaded
project (`bulk_academic_node_import_screen.dart`, 336 lines, doc
comment already labeled "Stage 6.2.3"), but **no changelog documented
it and it was not verified working** — this audit found it, checked
it, and found two real bugs (below) rather than assuming a doc comment
meant the stage was actually done.

| Needed | Found | Status |
|---|---|---|
| `AcademicNodeModel` | `lib/models/institution_model.dart` — `nodeId`, `institutionId`, `parentId`, `name`, `code`, `order`, `isActive` | ✅ Already had every field needed. Not modified. |
| `FacultyRepository`/`DepartmentRepository`/`LevelRepository`/`SemesterRepository` | All four in `institution_repository.dart`, all `extends BaseRepository<AcademicNodeModel>` over `AppConstants.facultiesCollection`/`departmentsCollection`/`levelsCollection`/`semestersCollection` | ✅ Already existed since Stage 4.3. Not modified — reused exactly, no fifth repository created. |
| `AcademicNodeManagerScreen` (manual Add/Edit/Delete) | `lib/features/admin/academic_structure/academic_node_manager_screen.dart` | ✅ Confirmed untouched — bulk import is a second entry point, not a replacement. |
| Shared Import Framework (Stage 6.2.1) | `CsvImportSpec`/`CsvImportScreen` | ✅ Reused as-is for the *required* contract — see bug below for the one gap. |
| `AuditModules.academicStructure` | `core/enums/audit_action_type.dart` | ✅ Already existed. Reused, not duplicated. |
| Firestore collections | `faculties`/`departments`/`levels`/`semesters` (`AppConstants`) | ✅ Confirmed no new/duplicate collections. |

## Bugs found and fixed

The existing `bulk_academic_node_import_screen.dart` looked complete —
node-type selection, name-based parent resolution with a `prepare()`
pre-fetch step, full validation, audit logging — but two things kept
it from actually working:

**1. `prepare()` was never called — every import would fail with
"Institution doesn't exist," even for real data.**
`_AcademicNodeImportSpec.prepare()` is what builds the
institution/faculty/department/level name→id lookup maps `parseRow`
then reads. It was annotated `@override`, but `CsvImportSpec` (the
interface it implements) never declared a `prepare()` method, and
`CsvImportScreen._pickFile()` never called one — so the maps stayed
permanently empty and every row would resolve `institutionId` to
`null` before checking a single real value.

*Fix:* added a new, **optional** `PreparableImportSpec` interface to
`csv_import_spec.dart` (`Future<void> prepare();`) rather than adding
a required member to `CsvImportSpec` itself — that would have forced
Bulk Questions' and Bulk Institutions' specs to implement a method
they don't need. `CsvImportScreen._pickFile()` now checks `widget.spec
is PreparableImportSpec` and calls it (with a loading state) before
parsing any row. `_AcademicNodeImportSpec` now `implements
CsvImportSpec<AcademicNodeModel>, PreparableImportSpec` — one word
added, its existing `prepare()` body untouched. **No other spec was
modified and no other spec's behavior changed.**

**2. The screen was completely unreachable — no route, no button,
nowhere in the app linked to it.**
*Fix:* added a second `IconButton` to `AcademicStructureScreen`'s
AppBar, next to the existing "Bulk import institutions" one, opening
`BulkAcademicNodeImportScreen`. Manual Add/Edit/Delete FAB and list
logic on that screen are unchanged.

## Import flow (as built)

Admin taps the new AppBar icon → picks a node type (Faculty /
Department / Level / Semester, each with its own required-columns
description) → `CsvImportScreen` takes over: file picker (CSV or
JSON) → `prepare()` pre-fetches every institution/faculty/department/
level once → each row is parsed and validated synchronously against
those maps → preview (valid/invalid counts, per-row error text) →
confirm → upload with progress → success/failure summary → one audit
log entry per run via `AuditLogService`.

## Validation rules (as implemented)

- **Faculty:** Institution must exist (by name) · Faculty name required
- **Department:** Institution + Faculty must exist · Department name required
- **Level:** Institution + Department must exist · Level name required
- **Semester:** Institution + Department + Level must exist · Semester name required
- All four: `code`/`order` optional (`order` defaults to 0),
  `isActive` optional (defaults to true)
- A row's parent lookup failing (e.g. "Faculty of Science" not found
  under the named institution) invalidates that row with a specific
  message — it does not create the missing parent.

## Verification

- ✅ Manual Add/Edit/Delete for all four levels — unchanged, confirmed
  still wired to `AcademicNodeManagerScreen`'s existing FAB/menu.
- ✅ Bulk import now reachable from `AcademicStructureScreen`.
- ✅ CSV and JSON both supported (same `readCsvRows`/`readJsonRows`
  split every other module in the framework already uses).
- ✅ No duplicate `AcademicNodeModel`, repositories, or Firestore
  collections — confirmed via the audit table above.
- ✅ Routes unaffected — this stage added one `IconButton`, no new
  named route.
- ✅ Audit logging — one `AuditLogService` entry per completed run,
  via `AuditModules.academicStructure`, matching Stage 6.2.2's pattern
  exactly.

## Not built this stage (per "stop after 6.2.3")

Bulk Course Import — next stage, not started.
