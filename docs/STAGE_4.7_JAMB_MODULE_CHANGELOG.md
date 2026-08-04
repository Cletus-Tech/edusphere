# EduSphere Stage 4.7 — JAMB Module

Master project stage. The Stage 4.7 brief bundles four subsystems, each
roughly stage-sized on its own: (1) a JAMB Dashboard reusing WAEC/NECO
infrastructure, (2) a Unified CBT Engine, (3) a full Novel System, and
(4) offline-first support + premium gating. Building all four in one
pass risked untested, unreviewable code, so this is split into parts —
same reasoning WAEC split into Parts 1–5. **This changelog covers Part
1 only.**

## Part 1 — Project Audit

| Needed for | Found | Status / decision |
|---|---|---|
| Subjects/Syllabus/Practice/Past Questions | `SubjectRepository`, `LearningMaterialRepository`, `CourseSection` (`exam_prep/`, `university/course_detail_screen.dart`) | ✅ Existed since Stage 4.5 (WAEC), unchanged — same infra WAEC/NECO already run on |
| Mock Exams | `ExamRepository`/`ExamModel`, `ExamType.jamb` (already in `content_type.dart` since Stage 1.2), `ExamListScreen` | ✅ Existed, unused for JAMB until this stage |
| CBT | `/cbt` route (`CbtScreen`) | ⚠️ Still just a placeholder — no timer/scoring/practice-mock modes. **Unified CBT Engine is a separate, not-yet-built part** — JAMB's CBT tile links to the same honest placeholder WAEC/NECO use, not a real engine |
| Performance | `PerformancePlaceholderScreen(title)` | ✅ Already generic, reused directly with `title: 'JAMB Performance'` |
| Study Plan | Nothing — no scheduling/study-plan system exists anywhere in the app | ❌ Genuine gap. Built `StudyPlanPlaceholderScreen`, same honest-placeholder pattern as Performance, generic so WAEC/NECO can adopt it too |
| Recommended Materials | Nothing — no featured/recommended flag on `LearningMaterialModel` | ❌ Genuine gap. Added `CourseSection.recommended` (tag `'recommended'`), same tag-based approach `syllabus` already used — admin tags a material `recommended` in the existing Material Editor, no schema change |
| Novel System | Nothing anywhere in the app | ❌ Not in scope for this part — separate stage |
| Offline-first | No caching/sync layer exists anywhere in the app | ❌ Not in scope for this part — cross-cutting, affects more than JAMB, separate stage |
| Premium gating | No entitlement system exists yet | ❌ Not in scope for this part — separate stage |

## Part 2 — JAMB Dashboard

**New: `lib/features/jamb/jamb_dashboard_screen.dart`** —
`JambDashboardScreen`, replacing the Stage 4.1 `JambScreen` placeholder
(deleted this stage — fully superseded, not orphaned, same as
`WaecScreen` was in Stage 4.5). Near-identical shape to
`WaecDashboardScreen`/`NecoDashboardScreen`, with `categoryId: 'jamb'`
/ `ExamType.jamb`, plus two tiles WAEC/NECO don't have:

- **Study Plan** → `StudyPlanPlaceholderScreen` (new, generic)
- **Recommended** → `SubjectBrowseScreen` deep-linked to the new
  `CourseSection.recommended`

Tiles: Subjects, Syllabus, CBT, Practice, Past Questions, Mock Exams,
Performance, Study Plan, Recommended, plus a Recent Activity strip —
matching the brief's list minus "JAMB Dashboard" itself (the screen)
and "Recent Activity" (the strip, not a tile).

**`lib/core/routes/app_routes.dart`** — `jamb` route now builds
`JambDashboardScreen`. `HomeScreen._routeForKey['jamb']` already
pointed at `AppRoutes.jamb` since Stage 4.1, so the Home dashboard's
JAMB tile needed no change.

**`lib/features/university/course_detail_screen.dart`** — added
`CourseSection.recommended` to the existing enum. Available to
University/WAEC/NECO too, not JAMB-gated.

**`lib/features/exam_prep/study_plan_placeholder_screen.dart`** —
new, generic `StudyPlanPlaceholderScreen(title)`, same shape as
`PerformancePlaceholderScreen`.

## Not in scope for Part 1 (tracked, not forgotten)

- **Unified CBT Engine** — real timer, scoring, practice/mock modes.
  WAEC, NECO, and JAMB's Mock Exams/CBT tiles all currently point at
  the same honest placeholder and should all switch to this engine
  once it exists, rather than each building its own.
- **Novel System** — annual prescribed novel, chapter navigation,
  reading progress, bookmarks, highlights, notes, in-novel search,
  chapter quizzes, admin novel replacement, offline reading, premium
  gating. Structure-only per the brief — no copyrighted text ships
  with the app; the module loads whatever the admin provides.
- **Offline-first support** — caching/sync for novel, notes, PDFs,
  question banks, flashcards, downloads, and reading progress. No
  caching layer exists anywhere in the app today; this is bigger than
  JAMB alone.
- **Premium architecture** — premium novel/explanations/mock
  exams/downloads, configurable from the Admin Control Center. No
  entitlement system exists yet to hang this off of.
- **Admin JAMB management** — subjects/syllabus/practice/mock exams
  already manageable through the existing Course/Subject manager and
  Material Editor (same as WAEC/NECO); a dedicated "Annual prescribed
  novel" admin screen depends on the Novel System existing first.
