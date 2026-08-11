# Stage 6.2.4 — Bulk Course Import

Continues directly from Stage 6.2.3's Bulk Academic Structure Import.
Adds bulk import for Courses — the bottom of the academic hierarchy
(`CourseModel`, `courses` collection) — reusing the same
`CsvImportScreen`/`PreparableImportSpec` framework end-to-end.

## Audit performed before implementation

- **`CourseModel`** (`lib/models/course_model.dart`) already had every
  field this stage needed: `title`, `code`, `institutionId`,
  `departmentId`, `levelId`, `semesterId`, `description`, `isActive`.
  No `facultyId` field exists — a course's own stored chain is
  Institution/Department/Level/Semester, not Faculty (Faculty is an
  intermediate hop, not stored redundantly on the course itself,
  same as it isn't on Level or Semester either). **Not modified** —
  per the brief's "Do not add fields unless required," and nothing
  was missing. `categoryId`/`iconUrl`/`contentCount` exist on the
  model too (used by `SubjectRepository`'s reuse of `CourseModel` for
  exam-board subjects) but aren't part of this import — left `null`/
  default, matching how they behave for any other university course.
- **`CourseRepository`** (`lib/repositories/course_repository.dart`)
  already provides `save()`/`newId()` via `BaseRepository` — used
  as-is, no changes.
- **`CourseManagerScreen`** — existing manual Add/Edit/Delete
  (`_openForm`/`_delete`, wired to the FAB and each course row's
  menu) — confirmed present, confirmed unmodified except its AppBar
  (see below).
- **Import Framework** — `CsvImportScreen`, `CsvImportSpec`, and
  `PreparableImportSpec` (added Stage 6.2.3) reused exactly as
  `_AcademicNodeImportSpec` uses them. No new import engine.
- **Firestore collections** — `courses` (existing, via
  `AppConstants.coursesCollection`); `institutions`/`faculties`/
  `departments`/`levels`/`semesters` (existing, read-only here for
  name-resolution). No new collection.

## Placement decision

The brief's flow diagram places this under "Course Management" →
"Add Course" + "Bulk Import Courses." In this codebase,
`CourseManagerScreen` **is** Course Management — but it's
permanently scoped to one institution + department + level + semester
(all four are required constructor parameters, since courses are
reached by drilling down through that hierarchy). The brief's own
validation list asks for a full Institution → Faculty → Department →
Level → Semester check **per row**, which only makes sense if one
import file can cover courses across multiple departments/semesters —
something a screen fixed to one semester can't represent.

So this follows the same placement Stage 6.2.3's
`BulkAcademicNodeImportScreen` already established: a standalone,
unscoped entry point (each row is fully self-contained) reachable
from **both**:
- `AcademicStructureScreen`'s AppBar (third bulk-import icon,
  alongside the existing Institutions and Faculty/Department/Level/
  Semester ones), and
- `CourseManagerScreen`'s AppBar (new — that screen had no AppBar
  actions before this stage), so it's discoverable exactly where the
  brief's diagram shows it, with a tooltip clarifying it isn't
  limited to the semester currently being viewed.

Both open the identical `BulkCourseImportScreen` — no duplicated
logic, two entry points to one screen.

## What this stage adds

**New: `lib/features/admin/academic_structure/bulk_course_import_screen.dart`**
— `BulkCourseImportScreen` (thin wrapper, same shape as
`BulkAcademicNodeImportScreen`) + `_CourseImportSpec`, implementing
both `CsvImportSpec<CourseModel>` and `PreparableImportSpec`.

`prepare()` pre-fetches Institutions, Faculties, Departments, Levels,
and Semesters once each, building name-keyed lookup maps —
one deliberate difference from Stage 6.2.3's own department cache:
that stage keyed departments by `institutionId|name` (fine for
building the tree, since a department's own row already carries
`institutionId`); this stage keys departments by **`facultyId|name`**
instead, and levels/semesters by their direct parent's id. That's
what makes `Department "X" not found under selected Faculty` — the
brief's own example error — a real, precise check (a same-named
department under a *different* faculty in the same institution
correctly fails) rather than an institution-wide name match that
would let it slip through.

`columnOrder`: `institutionName, facultyName, departmentName,
levelName, semesterName, code, title, description, isActive`.
`parseRow` walks the chain top-down, failing fast with the specific
missing/misplaced entity named in the error (matching the brief's
"the user should know exactly what failed" requirement) — Institution
→ Faculty (under that institution) → Department (under that
*specific* faculty) → Level (under that department) → Semester
(under that level) → then `code`/`title` required, `description`
optional, `isActive` optional (defaults `true`, same blank-handling
as Stage 6.2.3).

`logImport` uses `AuditModules.academicStructure` (courses are part
of the academic tree, same module Stage 6.2.3's import logs under) —
records the uploaded count, mirroring Stage 6.2.3's audit shape
exactly.

**`lib/features/admin/academic_structure/academic_structure_screen.dart`**
— one new AppBar `IconButton` (courses, third alongside the existing
two) + one new import. Nothing else changed.

**`lib/features/admin/academic_structure/course_manager_screen.dart`**
— added an `AppBar` (previously title-only, no `actions`) with one
`IconButton` opening `BulkCourseImportScreen` + one new import.
`_openForm`/`_delete`/the FAB/the course list — all unchanged.

## Verification checklist

- ✅ Manual course creation (`_openForm()`, FAB) — unchanged.
- ✅ Course editing (`_openForm(existing: course)`) — unchanged.
- ✅ Course deletion (`_delete()`) — unchanged.
- ✅ Bulk CSV import — via `CsvImportScreen`'s existing
  `readCsvRows`, unaffected by this stage.
- ✅ Bulk JSON import — via `CsvImportScreen`'s existing
  `readJsonRows(content, spec.columnOrder)`, unaffected.
- ✅ Validation — full 5-level chain, fails on the first broken link
  with a specific, row-numbered message; a department that exists but
  under the wrong faculty is correctly rejected (see placement
  decision above).
- ✅ Audit logging — `AuditLogService.instance.log(...)` via
  `logImport`, same shape as Stage 6.2.3.
- ✅ No duplicate files — one new screen file; two existing files got
  one AppBar icon each, nothing duplicated.
- ✅ No duplicate collections — `courses` (existing) is the only
  collection written to; the other five are read-only lookups.
- ✅ No broken routes — both entry points are `Navigator.push`, same
  mechanism Stage 6.2.2/6.2.3's bulk-import icons already use; no
  named-route table entries needed or touched.

## Completion report

**Status: Stage 6.2.4 complete.** One new file
(`bulk_course_import_screen.dart`), two existing files each given one
additional AppBar icon (`academic_structure_screen.dart`,
`course_manager_screen.dart`). No model, repository, or collection
changes — `CourseModel`/`CourseRepository`/`courses` all reused
as-is. No import-framework changes were needed this time (Stage
6.2.3 already added `PreparableImportSpec` for exactly this kind of
async pre-fetch need).

**Per the brief: stopping here.** Learning Material bulk upload is a
separate, not-yet-started stage.
