# Stage CBT-Refactor Phase 2B — Phase 1 Audit + Phase 2 (Unified CBT Center)

## Phase 1 — Audit (read-only, performed before any code change)

**Existing entry points into the CBT engine (5, all independent before this stage):**
- `CbtScreen`: Official → `ExamListScreen(examTypeId: ExamType.cbt.id, mode: official)`
- `CbtScreen`: Practice → `ExamListScreen(examTypeId: ExamType.practiceTest.id)`
- `CbtScreen`: Mock → `ExamListScreen(examTypeId: ExamType.mockExam.id, mode: mock)`
- `WaecDashboardScreen` → `ExamListScreen(examTypeId: ExamType.waec.id)` (2 buttons)
- `JambDashboardScreen` → `ExamListScreen(examTypeId: ExamType.jamb.id)` (2 buttons)
- `NecoDashboardScreen` → `ExamListScreen(examTypeId: ExamType.neco.id)` (2 buttons)
- `UniversityDashboardScreen` → `ExamListScreen(examTypeId: ExamType.postUtme.id)`

**Confirmed duplicate/parallel paths:** WAEC/JAMB/NECO/University push directly into
`ExamListScreen` themselves; `CbtScreen` never referenced `ExamType.waec/jamb/neco/postUtme`
at all before this stage — two systems existed side by side.

**Routes:** `/cbt`, `/waec`, `/jamb`, `/neco`, `/university` — five independent top-level
routes, no consolidation.

**`ExamType` (8 values):** `cbt`/`practiceTest`/`mockExam` wired into `CbtScreen`;
`jamb`/`waec`/`neco`/`postUtme` wired only into their own dashboards;
`professionalCertification` unused anywhere.

**`ExamMode`:** `official`/`practice`/`mock` already thread through
`ExamListScreen(mode:)` → `ExamRunnerScreen` (additive param from Stage CBT-2, default
`practice`, no existing call site affected).

**Filtering — the real gap:** `ExamRepository` has exactly one query method,
`watchByType(String typeId)` — `.where('type', ...).where('isActive', ...)`. No subject,
year, paper, course, or institution filtering exists anywhere in the query path.
Concretely: the Post-UTME list today shows every institution's Post-UTME exams mixed
together, undistinguished by course/institution.

**Academic fields already available for later phases:**
- `ExamModel.courseId`/`subjectId` exist but are never queried against.
- `CourseModel` already carries `institutionId`/`departmentId`/`levelId`/`semesterId` —
  so Institution→Faculty→Department→Level→Course resolution is possible via a
  `courseId` → `CourseModel` lookup without changing `ExamModel`.
- `AcademicNodeModel` (Faculty/Department/Level tree) is a **generic** node with no
  tier/type field — Faculty vs. Department vs. Level is only implied by tree depth.
  Flagged for whoever builds Phase 6: this needs a decision before an institution
  selector UI can filter "give me all Departments."
- **Missing entirely:** year, paper, JAMB subject-combination rules — no field anywhere
  holds these. `ExamModel.metadata` (schemaless `Map<String, dynamic>`, already exists)
  is the one candidate that avoids a model migration — flagged as an option for
  whoever scopes Phase 3/5, not decided here.

**Admin side (`ExamEditorScreen`):** already sets `type`, `courseId`/`subjectId` (raw
text fields, no picker), `supportedModes`, availability window, premium,
calculator/negative-marking. No year/paper field (doesn't exist to set). No
institution/faculty/department/level picker.

## Phase 2 — Unified CBT Center (implemented)

`CbtScreen` restructured (not replaced) to add four cards — WAEC, NECO, JAMB,
Institutional/Post-UTME — using the same existing `_FeatureCard` widget every other
card already used. Per the audit's own rule ("do NOT blindly create duplicate cards if
the existing architecture already provides an equivalent route"), each board card
navigates to that board's **existing** dashboard route (`/waec`, `/neco`, `/jamb`,
`/university`) rather than jumping straight to `ExamListScreen`:

1. Those dashboards already carry real board-specific context (subject cards,
   performance, history) beyond a bare exam list — bypassing them would be a
   regression.
2. The actual Year → Subject → Paper / JAMB-combination selection flow (Phases 3–6)
   doesn't exist yet. Building an ad hoc version of it inside this stage would mean
   guessing at architecture the audit explicitly reserved for its own phases.

Official/Practice/Mock/My Attempts/Scanning Mode cards, the "Available Official Exams"
preview, and every existing screen/model/repository are unchanged.

## What was NOT done (explicitly out of scope for Phase 2)
Phases 3–9 (WAEC/NECO/JAMB/Institutional selection flows, smart search, resource
allocation, admin allocation UI) — each needs its own audit against real subject/year
data before implementation, per the source document's own phasing and stop condition.

## Files changed
- `lib/features/cbt/cbt_screen.dart` — restructured only, per above.

## Files NOT touched
`ExamModel`, `ExamRepository`, `ExamListScreen`, `ExamRunnerScreen`,
`ExamAttemptRepository`, `WaecDashboardScreen`, `JambDashboardScreen`,
`NecoDashboardScreen`, `UniversityDashboardScreen`, Firestore rules — all unchanged.

## Verification performed
Brace/paren balance check on the modified file; import-usage check (no unused imports
introduced); confirmed `AppRoutes.waec`/`.neco`/`.jamb`/`.university` all resolve to
const-constructor routes (no required arguments), so `pushNamed` is safe.

## Known limitation
Not runtime-tested (no Flutter toolchain available in this environment) — static
review only.
