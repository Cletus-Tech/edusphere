# EduSphere Stage 4.4 — University Learning Module

Master project stage. Builds the University education module on top of
the academic hierarchy Stage 4.3 established — the first real content
module for that hierarchy. Per the brief, WAEC/NECO/JAMB are out of
scope this stage; only University.

## Part 1 — Audit of Existing Learning System

Before writing anything, the project was searched for an existing
University/course browsing UI. None existed — Stage 4.1 had aliased the
Home dashboard's "University" quick-access tile straight to the Learn
tab (`LearningLibraryScreen`) as an explicit stand-in, documented in its
own doc comment as such. Everything below this line was genuinely new
UI, but it is composed entirely from repositories, models, and screens
that already existed:

| Needed for | Reused as-is |
|---|---|
| Institution data | `InstitutionModel`, `InstitutionRepository.watchActive()` |
| Faculty/Department/Level/Semester | `AcademicNodeModel`, `FacultyRepository`/`DepartmentRepository`/`LevelRepository`/`SemesterRepository` (all Stage 4.3) |
| Course data | `CourseModel`, `CourseRepository.watchByDepartmentAndLevel()` |
| Course materials | `LearningMaterialModel`, `LearningMaterialRepository.watchMaterials(courseId: ...)` — already supported this filter before this stage |
| Material cards/detail | `MaterialCard`, `MaterialDetailScreen` (Stage 3.5) |
| Full search/filter UI | `LearningLibraryScreen` (Stage 3.5) — already accepted an optional `courseId` |
| User's saved academic profile | `UserModel.institutionId/departmentId/levelId`, `UserRepository.watchUser()` (Stage 4.3) |
| Admin CRUD for universities/faculties/departments/courses | `AcademicStructureScreen`, `AcademicNodeManagerScreen`, `CourseManagerScreen` (Stage 4.3) — **Part 5 of this stage's brief is already satisfied by existing Stage 4.3 work; no admin screens were added or changed.** |

**Zero new models, zero new repositories, zero new Firestore
collections, zero new admin screens.**

## Part 2 — University Dashboard

**New: `lib/features/university/university_dashboard_screen.dart`** —
`UniversityDashboardScreen`, the real destination for `Home →
University`, replacing the Stage 4.1 stand-in. Contains:
- Search Universities / Browse Institutions quick action
- My University (only shown if the signed-in student has saved an
  `institutionId` via `AcademicProfileScreen`, Stage 4.3)
- My Courses (only shown if `departmentId` + `levelId` are saved)
- A prompt to complete the academic profile if it isn't set yet,
  linking directly to the existing `AcademicProfileScreen`
- Recent Materials (institution-scoped if the student has one set,
  otherwise the general recent feed — reuses
  `LearningMaterialRepository.watchRecentlyAdded`)
- CBT Practice tile — per Part 7, this **does not build CBT**. It
  pushes the existing `/cbt` route (`CbtScreen`, a Stage 4.1
  placeholder), which is the prepared integration point for a future
  CBT stage.

**`lib/core/routes/app_routes.dart`** — added `AppRoutes.university`
(`/university`), registered to `UniversityDashboardScreen`, following
the exact pattern already used for `jamb`/`waec`/`neco`/`cbt`.

**`lib/features/home/home_screen.dart`** — removed the Stage 4.1
`'university': _tabLearn` stand-in from `_tabForKey`; added
`'university': AppRoutes.university` to `_routeForKey`. The Home
dashboard's University tile now opens the real module instead of the
Learn tab.

## Part 3 — Institution Selection

**New: `lib/features/university/institution_browse_screen.dart`** —
`InstitutionBrowseScreen`. Search + browse, scoped to
`InstitutionType.university` by default via a constructor parameter
(so Stage 4.5+ Polytechnic/College of Education work can reuse this
same screen with a different type instead of duplicating it — the same
reuse discipline Stage 4.3 used for `AcademicNodeManagerScreen`).
Client-side search over `InstitutionRepository.watchActive()`'s live
stream, matching `LearningLibraryScreen`'s existing search pattern.

**New: `lib/features/university/institution_detail_screen.dart`** —
`InstitutionDetailScreen`. Shows the institution's name/state, then a
"Browse Faculties & Courses" entry into the drill-down chain.

## Part 4 — Course Navigation

**New: `lib/features/university/widgets/academic_node_browser_screen.dart`**
— `AcademicNodeBrowserScreen`, one generic read-only list screen that
handles Faculties, Departments, Levels, *and* Semesters — the
student-facing counterpart to Stage 4.3's `AcademicNodeManagerScreen`,
which proved this "one screen, four levels" pattern for the admin CRUD
side. `InstitutionDetailScreen` chains four instances of it together
(Faculty → Department → Level → Semester), each reusing the exact
`watchByX` repository method Stage 4.3 already built.

**New: `lib/features/university/course_browse_screen.dart`** —
`CourseBrowseScreen`, the bottom of the drill-down. Reuses
`CourseRepository.watchByDepartmentAndLevel` exactly as-is. **Known
limitation, not introduced by this stage:** that method filters by
department + level only, not semester — so within one department/level,
courses from every semester appear together. Fixing this would mean
changing a Stage 4.3 repository method and its Firestore query shape,
which is out of scope for "reuse, don't rebuild" — flagged here for a
future stage instead of silently worked around.

**New: `lib/features/university/course_detail_screen.dart`** —
`CourseDetailScreen`. Shows course title/code/description, then section
chips (Notes, Videos, Assignments, Timetable, Downloads, Past
Questions, Practice Questions, Flashcards) over
`LearningMaterialRepository.watchMaterials(courseId: ...)` — the same
repository call `LearningLibraryScreen` uses, just course-scoped.
"Search all materials" pushes the actual `LearningLibraryScreen`
pre-scoped to this course, for full search/type-filter.

**Real limitation, documented rather than papered over:** Notes/Videos
map cleanly onto `LearningMaterialType.pdf`/`.video`; Downloads maps to
"any file-based type." Assignments, Timetable, Past Questions, Practice
Questions, and Flashcards have no matching `LearningMaterialType` value
— inventing five new enum values (or a second taxonomy) was judged out
of scope for a "connect, don't rebuild" stage, so those five sections
filter on `LearningMaterialModel.tags` instead (already a first-class
field, unused by any UI until now). **Those five sections will show
empty states until an admin tags materials** `assignment`, `timetable`,
`past-questions`, `practice-questions`, or `flashcards` respectively
from the existing Material Editor — no code change needed to start
using them, but it does need a content/tagging decision from you.

## Part 5 — Admin Management

No changes. `AcademicStructureScreen` (institutions),
`AcademicNodeManagerScreen` (faculties/departments/levels/semesters),
and `CourseManagerScreen` (courses) — all Stage 4.3 — already provide
full add/edit/delete for every entity this stage's brief asks for.
Verified reachable from `AdminDashboardScreen`'s "Academic Structure"
tile; no new admin screens or routes were needed or added.

## Part 6 — User Experience

- Every new screen has a real `LoadingView`/`ErrorView`/`EmptyView`
  state (no bare `CircularProgressIndicator()`, no silent blank
  screens).
- Empty states are specific to context (e.g. "No faculties have been
  added for {institution} yet" rather than a generic "Nothing here").
- No dead buttons: every tap target either navigates somewhere real
  (verified during Part 8) or is the documented CBT placeholder, which
  itself resolves to a real (if intentionally unbuilt) screen.

## Part 7 — Future CBT Preparation

Not built, per the brief. The integration point is the existing `/cbt`
route — University Dashboard's CBT tile and (once tagged) Course
Detail's Practice Questions section are both structured so a future CBT
stage can wire `CourseModel.courseId` → question bank → `CbtScreen`
without this stage's screens needing to change.

## Part 8 — Validation

- ✅ University opens from Home (`HomeScreen` → `AppRoutes.university`
  → `UniversityDashboardScreen`)
- ✅ Institutions can be managed by Admin — unchanged, verified still
  reachable (Stage 4.3 work, not touched this stage)
- ✅ Students can navigate the full academic hierarchy: Institution →
  Faculty → Department → Level → Semester → Course
- ✅ Courses connect to Learning Materials via the existing `courseId`
  filter — no new query
- ✅ Existing modules untouched: Learning Materials, Community, Admin
  Control Center, Authentication, Firebase integration, Audit logging,
  Repository architecture, Theme system — no edits to any of their
  files this stage
- ✅ No duplicate architecture — one generic node browser handles four
  hierarchy levels; institution browse is parameterized for reuse by
  future institution types rather than copy-pasted per type
- ✅ Whole-project pass: every relative import in the new
  `lib/features/university/` directory resolves, zero duplicate
  top-level class/enum names project-wide, brace/paren balance checked
  on every file touched or added this stage

## Deliverables

**Files created:**
- `lib/features/university/university_dashboard_screen.dart`
- `lib/features/university/institution_browse_screen.dart`
- `lib/features/university/institution_detail_screen.dart`
- `lib/features/university/course_browse_screen.dart`
- `lib/features/university/course_detail_screen.dart`
- `lib/features/university/widgets/academic_node_browser_screen.dart`
- `docs/STAGE_4.4_UNIVERSITY_MODULE_CHANGELOG.md` (this file)

**Files modified:**
- `lib/core/routes/app_routes.dart` — added `university` route
- `lib/features/home/home_screen.dart` — University tile now opens the
  real module instead of the Learn tab

**Files reused (no changes):** `InstitutionModel`, `AcademicNodeModel`,
`CourseModel`, `LearningMaterialModel`, `InstitutionRepository`,
`FacultyRepository`, `DepartmentRepository`, `LevelRepository`,
`SemesterRepository`, `CourseRepository`, `LearningMaterialRepository`,
`UserRepository`, `MaterialCard`, `MaterialDetailScreen`,
`LearningLibraryScreen`, `AcademicProfileScreen`,
`AcademicStructureScreen`, `AcademicNodeManagerScreen`,
`CourseManagerScreen`, `CbtScreen`.

**Database changes:** None. No new Firestore collections, fields, or
indexes — every query this stage adds is a call to a `watchByX` method
that already existed.

**Admin changes:** None — Stage 4.3's admin tooling already covers this
stage's Part 5 requirements in full.

**Remaining limitations:**
1. `CourseRepository.watchByDepartmentAndLevel` doesn't filter by
   semester (pre-existing, not introduced this stage).
2. Assignments/Timetable/Past Questions/Practice Questions/Flashcards
   sections on the Course page depend on admins tagging materials with
   matching tag strings — they render correctly today, but will be
   empty until that tagging happens.
3. CBT is intentionally not built — the tile is a real, working link to
   the existing placeholder, not a dead button, but it doesn't run
   practice questions yet.

## Completion Checklist

- ✅ University module created
- ✅ Academic hierarchy connected
- ✅ Learning Materials connected
- ✅ Admin management prepared (verified already complete from Stage 4.3)
- ✅ No duplicate systems
- ✅ Master project updated
- ✅ Ready for Stage 4.5 — WAEC Module
