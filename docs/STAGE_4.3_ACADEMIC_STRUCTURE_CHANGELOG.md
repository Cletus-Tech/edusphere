# EduSphere Stage 4.3 — Academic Structure & Education Hierarchy

Master project stage. Builds the shared academic hierarchy that every
education module (University, Polytechnic, College of Education, WAEC,
NECO, JAMB, and future exams) will sit on top of. Per the brief, this
stage does **not** implement any of those modules — only the shared
structure underneath them, plus the admin tooling to manage it and the
student-facing profile fields to select a place in it.

## Part 1 — Academic Hierarchy Audit

Before writing anything, the project was searched for existing
implementations of every entity in the brief. Nearly all of it already
existed, built during an earlier "Stage 1.2 — Backend Architecture" pass
in this same lineage:

| Entity | Status found | Location |
|---|---|---|
| Institution Type | ✅ Existed | `lib/core/enums/institution_type.dart` |
| Institution | ✅ Existed | `lib/models/institution_model.dart` (`InstitutionModel`) |
| Faculty/College | ✅ Existed | `AcademicNodeModel` (shared shape) + `FacultyRepository` |
| Department | ✅ Existed | `AcademicNodeModel` + `DepartmentRepository` |
| Level | ✅ Existed | `AcademicNodeModel` + `LevelRepository` |
| Semester | ✅ Existed | `AcademicNodeModel` + `SemesterRepository` |
| Course | ✅ Existed | `lib/models/course_model.dart` (`CourseModel`) + `CourseRepository` |
| Academic Profile (on User) | ⚠️ Partial | `UserModel` had `institutionId`/`facultyId`/`departmentId`/`levelId`; missing `institutionType`, `semesterId`, `programme` |
| Admin management UI for the above | ❌ Missing | No screens existed — only the data layer |

**Everything in the "existed" rows was reused as-is — zero new models,
zero new repositories, zero new Firestore collections.** Work this stage
was scoped to the two genuine gaps: completing the user's academic
profile fields, and building the admin management UI the data layer
never had a front end for.

## Part 2 — Academic Hierarchy

No changes. `Institution → Faculty → Department → Level → Semester →
Course` was already fully modeled and already matches this exact shape:
- `InstitutionModel` (`institutions` collection) — top of the tree.
- `AcademicNodeModel` — one shared shape for Faculty, Department, Level,
  and Semester, distinguished by which collection (`faculties`,
  `departments`, `levels`, `semesters`) and by `parentId`, rather than
  four near-identical classes.
- `CourseModel` (`courses` collection) — also shared with `subjects` for
  secondary/exam-board content, which this stage doesn't touch.

## Part 3 — User Academic Profile

**`lib/models/user_model.dart`** — added three fields, additively:
- `institutionType` (`String?`) — stored alongside `institutionId`
  rather than looked up from the institution doc on every read.
- `semesterId` (`String?`) — was the one missing hierarchy level.
- `programme` (`String?`) — free-form (ND/HND/B.Sc/B.Eng/etc.), *not* a
  new collection. The brief calls it out separately from the hierarchy
  ("Programme (if applicable)") rather than as another `AcademicNodeModel`
  tier, and building a full programme catalog would be scope creep past
  "only build the shared academic structure." A free-text field on the
  profile satisfies the requirement without inventing a collection this
  stage doesn't need.

All three are optional with no default-value side effects, so every
existing `UserModel(...)` construction site (`auth_service.dart`, the
admin `AcademicNodeManagerScreen`'s own user lookups, etc.) compiles
unchanged. `copyWith`, `fromMap`/`toMap`, and `Equatable.props` were
extended to match.

**New: `lib/features/profile/academic_profile_screen.dart`** —
`AcademicProfileScreen`, reachable from a new "Academic Profile" tile in
`ProfileScreen` (Account section). Cascading pickers: Institution Type →
Institution → Faculty → Department → Level → Semester, each populated
from the *same* repositories the admin screens use (a student only ever
sees institutions/faculties/etc. an admin actually created), plus a
free-text Programme field. Changing a higher-level selection clears
everything below it, both in the UI state and in what gets saved, so a
student can never end up with a Department that doesn't belong to their
Institution.

## Part 4 — Admin Management

**New directory: `lib/features/admin/academic_structure/`**

- **`academic_node_manager_screen.dart`** — `AcademicNodeManagerScreen`,
  one generic CRUD screen (list, add, edit, deactivate/reactivate,
  delete) that manages *any* level of the tree — it's handed a
  `BaseRepository<AcademicNodeModel>`, so Faculty, Department, Level, and
  Semester management is **one implementation, not four**, matching the
  brief's "no duplicate ... screens" rule.
- **`academic_structure_screen.dart`** — `AcademicStructureScreen`, the
  entry point (linked from a new "Academic Structure" tile on
  `AdminDashboardScreen`). Lists institutions with add/edit/delete, and
  wires the drill-down: tap an institution → Faculties →
  (tap a faculty) → Departments → (tap) → Levels → (tap) → Semesters →
  (tap) → Courses.
- **`course_manager_screen.dart`** — `CourseManagerScreen`, CRUD for
  courses scoped to one department + level + semester (the bottom of the
  drill-down).

Every create/edit/deactivate/delete action in all three screens logs
through the existing `AuditLogService` under a new
`AuditModules.academicStructure` module id (`lib/core/enums/
audit_action_type.dart` — additive, same pattern as every other module).

Deletes warn that nested children are orphaned, not cascade-deleted —
consistent with `firestore.rules` already denying anything but
`isInstitutionAdmin()`/`isStaff()` writes on these collections, and with
keeping delete semantics predictable rather than silently wiping a whole
subtree.

## Part 5 — Firestore Design

No new collections. Verified against the existing `firestore.rules`
(already has correct `institutions`/`faculties`/`departments`/`levels`/
`semesters`/`courses` match blocks from Stage 1.2 — no changes needed)
and `firestore.indexes.json`. Every new query this stage adds
(`AcademicNodeManagerScreen`'s `institutionId` + `parentId` equality
filter, `CourseManagerScreen`'s `departmentId` + `levelId` + `semesterId`
equality filter, `AcademicProfileScreen`'s cascading lookups) uses only
equality (`==`) filters with no `orderBy`/range on a different field, so
Firestore's automatic single-field indexes cover all of them — **no new
composite indexes required**.

## Part 6 — Validation

- ✅ Existing architecture preserved — no file under `lib/` was rewritten
  wholesale; only `user_model.dart`, `audit_action_type.dart`,
  `admin_dashboard_screen.dart`, and `profile_screen.dart` received
  additive edits.
- ✅ Learning Materials untouched (`learning_material_model.dart`,
  `learning_material_repository.dart`, admin screens — no edits).
- ✅ Community untouched (`community_models.dart`,
  `community_repository.dart` — no edits).
- ✅ Authentication untouched (`auth_service.dart` — no edits; new
  `UserModel` fields are all optional so its existing constructor calls
  compile as-is).
- ✅ No duplicate repositories — every new screen calls the existing
  `InstitutionRepository`/`FacultyRepository`/`DepartmentRepository`/
  `LevelRepository`/`SemesterRepository`/`CourseRepository`.
- ✅ No duplicate models — `AcademicNodeModel`/`InstitutionModel`/
  `CourseModel` all reused as-is.
- ✅ No duplicate routes — admin sub-screens follow the existing
  convention (direct `MaterialPageRoute` push from
  `AdminDashboardScreen`, same as Learning Materials/Audit Log/
  Moderation/Users/App Settings); nothing added to `AppRoutes`'s named
  route table, matching how every other admin screen already works.
- ✅ Whole-project pass: every relative import resolves, zero duplicate
  top-level class/enum names, brace/paren balance checked on every file
  touched this stage.

## Deliverables

**Files created:**
- `lib/features/admin/academic_structure/academic_node_manager_screen.dart`
- `lib/features/admin/academic_structure/academic_structure_screen.dart`
- `lib/features/admin/academic_structure/course_manager_screen.dart`
- `lib/features/profile/academic_profile_screen.dart`
- `docs/STAGE_4.3_ACADEMIC_STRUCTURE_CHANGELOG.md` (this file)

**Files modified (additive only):**
- `lib/models/user_model.dart` — `institutionType`, `semesterId`,
  `programme` fields.
- `lib/core/enums/audit_action_type.dart` — `AuditModules.academicStructure`.
- `lib/features/admin/admin_dashboard_screen.dart` — new tile.
- `lib/features/profile/profile_screen.dart` — new tile.

**Files/collections reused (zero changes):**
- `lib/models/institution_model.dart` (`InstitutionModel`, `AcademicNodeModel`)
- `lib/models/course_model.dart` (`CourseModel`)
- `lib/repositories/institution_repository.dart` (`InstitutionRepository`,
  `FacultyRepository`, `DepartmentRepository`, `LevelRepository`,
  `SemesterRepository`)
- `lib/repositories/course_repository.dart` (`CourseRepository`, `SubjectRepository`)
- `lib/core/enums/institution_type.dart`
- `lib/core/constants/app_constants.dart` (all Stage 1.2 collection constants)
- `lib/services/audit/audit_log_service.dart`
- `lib/shared/widgets/*`, `lib/shared/dialogs/app_dialog.dart`
- `firestore.rules`, `firestore.indexes.json` (verified, not modified)

**Firestore collections added:** none — `institutions`, `faculties`,
`departments`, `levels`, `semesters`, `courses` all already existed.

**Compatibility report:** Clean. Every new field is optional/additive;
every new screen is reached via a new tile, not a replaced one; no
existing repository, model, route, or Firestore rule changed shape.

**Remaining blockers:** None for Stage 4.3 itself. Two things worth
flagging before Stage 4.4:
1. This was reviewed by careful manual audit, not a real `flutter
   analyze`/`dart analyze` run — no Dart SDK is available in this
   environment (see the Stage 0 preview/build-capability report). Worth
   running locally before merging.
2. `programme` is intentionally free-text for now. If Stage 4.4+
   (University Module) needs a structured programme catalog (e.g. ND vs
   HND vs Direct Entry pathways with their own duration/curriculum),
   that's new scope for whichever stage actually needs it — not
   backfilled here.

## Completion Checklist

- ✅ Academic hierarchy completed (was already complete; verified)
- ✅ User academic profile extended
- ✅ Admin management prepared
- ✅ Firestore structure verified
- ✅ No duplicate code
- ✅ Master project preserved
- ✅ Ready for Stage 4.4 — University Module
