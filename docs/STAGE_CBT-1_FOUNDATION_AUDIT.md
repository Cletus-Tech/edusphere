# Stage CBT-1 — Foundation, Existing Engine Audit & Non-Destructive Integration

**No code was changed in this stage.** Per the stage brief, CBT-1 is an
audit-and-architecture-plan deliverable, not a build. Every finding below
was confirmed by reading the actual project source
(`edusphere_master_project_2026-08-11_audited.zip`) — nothing here is
assumed.

## Headline finding

**The CBT engine is not missing — it already exists, is substantially
complete, and is already live behind WAEC, NECO, JAMB, and University
Post-UTME.** The one gap is that the generic `/cbt` entry point
(`CbtScreen`) is still the Stage 4.1 placeholder, while a real, working
exam engine has been built up around it since. This is the same shape of
issue as the "CBT Practice" label bug fixed earlier this project — a
route that looks unbuilt but isn't — except here the *destination itself*
(not just a label) is the stale piece.

---

## 1–8. Existing CBT architecture audit

### Models (`lib/models/`)
| Model | Collection | Role |
|---|---|---|
| `ExamModel` | `exams` | One sittable exam. Shared across every board via `ExamType` (`cbt`, `practiceTest`, `mockExam`, `jamb`, `waec`, `neco`, `postUtme`, `professionalCertification`) rather than a model per board. Already carries the full admin-config surface: `calculatorType`, `negativeMarkingEnabled`/`negativeMarkPercent`, `shuffleQuestions`/`shuffleOptions`, `attemptLimit`, `availableFrom`/`availableUntil` (+ `isCurrentlyAvailable` getter), `isPremium`, `offlineAvailable`, `proctoringEnabled`, `supportedModes: List<ExamMode>`, and navigation rules (`allowBackNavigation`, `allowFlagging`, `allowSkipping`, `requireReviewBeforeSubmit`, `showResultsImmediately`). |
| `QuestionModel` | `questions` | One bank question, reusable across exams. `QuestionType` covers 14 formats; 5 (`singleChoice`, `multipleChoice`, `trueFalse`, `fillInTheBlank`, `shortAnswer`) have real runner + scoring support today, the rest decode safely but have no answer UI yet (by design — the admin editor restricts its type picker to the 5 that work, so nothing gets created that a student couldn't actually answer). |
| `ExamSessionModel` | `exam_sessions` | The live, mutable, auto-saved in-progress attempt. Carries `mode: ExamMode`, per-session fixed `questionOrder`/`optionOrder` (computed once so shuffle never re-shuffles mid-attempt), `remainingSeconds`, and `syncStatus: SyncStatus` (see §8, offline). |
| `ExamAttemptModel` | `exam_attempts` | The immutable post-submission result: score, pass/fail, per-topic breakdown, time taken. Deliberately a separate collection from sessions so constant autosave writes never contend with history/analytics reads. |

### The mode concept already exists — `ExamMode`
`lib/core/enums/content_type.dart` already defines:
```dart
enum ExamMode { official, practice, mock; ... }
```
threaded through `ExamModel.supportedModes`, `ExamSessionModel.mode`, and
`ExamAttemptModel.mode`. **This is exactly the "official vs. practice"
abstraction CBT-1 asked me to introduce if missing — it's not missing.**
No new enum, field, or model is needed for CBT mode.

### Repositories (`lib/repositories/learning_repository.dart`)
- `ExamRepository` — `watchByType(examTypeId)` (active exams only)
- `ExamSessionRepository` — `findResumableSession`, `watchResumableSessions`, `autoSave` (resume-in-progress support)
- `ExamAttemptRepository` — `watchHistoryForUser`, `fetchAttemptsForExam` (attempt-limit checks read this)
- `QuestionRepository` — `fetchPageForExam` (paged, not whole-bank loads)

All extend the shared `BaseRepository<T>` — no parallel data-access layer.

### Screens
**Student-facing** (`lib/features/exam_prep/`): `exam_list_screen.dart`
(lists exams for one `examTypeId`, enforces availability window +
attempt limit before allowing start), `exam_runner_screen.dart` (883
lines — the actual timed session: navigation, palette, flagging,
bookmarking, autosave, calculator sheet, submission), `exam_scoring.dart`,
`exam_result_screen.dart`, `exam_review_screen.dart`,
`exam_history_screen.dart`, `performance_analytics_screen.dart`,
`exam_attempt_resolver.dart` (resume-vs-new-session routing),
`subject_browse_screen.dart`, `study_plan_placeholder_screen.dart`
(honest placeholder), `exam_calculator_sheet.dart`.

**Admin-facing** (`lib/features/admin/exam_prep/`): `exam_manager_screen.dart`
+ `exam_editor_screen.dart` (full CRUD over every `ExamModel` config
field), `question_manager_screen.dart` (CRUD, restricted to the 5
runner-supported types), `bulk_question_upload_screen.dart` (CSV import),
`subject_manager_screen.dart` (CRUD over `subjects`, per exam category).

**Board dashboards**: `waec_dashboard_screen.dart`, `neco_dashboard_screen.dart`,
`jamb_dashboard_screen.dart`, and University's `university_dashboard_screen.dart`
all navigate into the **same** `ExamListScreen(examTypeId: ExamType.X.id, ...)`
→ `ExamRunnerScreen` — confirmed by grep, not assumed. One engine, four
front doors. This is already the "shared execution engine, different
access surfaces" pattern the stage brief asks for.

**The one placeholder**: `lib/features/cbt/cbt_screen.dart` (`/cbt` route)
is still `FeaturePlaceholder` — a "coming soon" screen with no
`examTypeId` and no link to the real engine. Its own doc comment already
names this precisely: it's meant to become "the Unified CBT Engine" hub.

### Routes (`lib/core/routes/app_routes.dart`)
Single central route table (`AppRoutes`), no duplicate routing system.
Relevant existing entries: `jamb`, `waec`, `neco`, `cbt`, `university` —
all registered, all resolved through one `Map<String, WidgetBuilder>`.

### Admin-configurable entry point — already wired
`FeatureKeys.cbt = 'cbt'` (`lib/models/app_settings_models.dart`) is
already a recognized dashboard-card key. `HomeScreen._routeForKey` already
maps `'cbt' -> AppRoutes.cbt`. **The admin can already attach a Home
dashboard card with key `cbt` and it will resolve to the CBT Center
route** — today that's the placeholder; once CBT-2 replaces `CbtScreen`
with the real hub, this wiring needs zero changes. This satisfies the
"CBT Center entry point" requirement's architecture ask for this stage —
nothing to add.

### Firestore collections in use (`lib/core/constants/app_constants.dart`)
`exams`, `questions`, `exam_sessions`, `exam_attempts`, `subjects` — all
existing, all correctly referenced by the repositories above. No
duplicate or shadow collection found anywhere in the project for exam
data.

---

## 9. Offline capabilities — audited, not assumed

`ExamSessionModel.syncStatus: SyncStatus` (`synced` / `pendingSync` /
`syncFailed`) exists on the model, and `ExamModel.offlineAvailable`
exists as a per-exam flag. **There is no queue/replay engine that
actually performs offline writes and syncs them** — confirmed by
searching the whole `lib/` tree for any consumer of `pendingSync` beyond
the model/enum definitions themselves; none exists. This matches the
model's own doc comment, which describes the field as "the contract [a
future queue/replay mechanism] will write to." Offline is a schema seat
reserved, not a working feature — exactly the state CBT-1 should leave
it in.

## 10. Admin capabilities — already substantial
Full CRUD for exams (every config field), questions (with a
runner-support-aware type restriction), subjects, and bulk CSV question
import already exist and are wired into the Admin Dashboard. Nothing
needed here for CBT-1.

## 11. Premium/access architecture — already substantial, per-exam
`ExamModel.isPremium`, `attemptLimit`, `availableFrom`/`availableUntil`,
`isActive`/`isCurrentlyAvailable`, `offlineAvailable`, and
`proctoringEnabled` together already cover most of the
`CBTAccessPolicy` concept the brief sketched — as **per-exam** fields
rather than a separate global model. `ExamListScreen._startExam` already
enforces the availability window and attempt limit before allowing a
session to start. What does **not** exist yet: a *platform-wide* CBT
settings document (e.g., a global kill-switch for Practice Mode
independent of any one exam, or global default attempt/trial policy) —
see Recommendation 2 below. No payment gateway exists or was touched,
per the brief's explicit exclusion.

---

## 12–14. Recommended integration point / minimal additive changes / abstractions needed

**No new abstraction is required for CBT-1.** Specifically:
- **CBT mode** (§13 of the brief): already exists as `ExamMode`. Nothing to add.
- **CBT access policy** (§14 of the brief): already exists per-exam on
  `ExamModel`. The one real gap — a *global* CBT settings singleton —
  is new build work, not a CBT-1 architecture fix, and belongs in the
  Control Center stage where `AppConfigModel`/`BrandingSettingsModel`
  already establish the "singleton settings doc" pattern to extend. Not
  built now, per the brief's own "do not build all of this now"
  instruction.

**Recommended integration point for CBT-2**: replace `CbtScreen`'s body
with a real "CBT Center" hub — reusing `ExamListScreen` and
`ExamRunnerScreen` exactly as WAEC/NECO/JAMB/University already do,
just without a fixed `examTypeId` (list across types, or surface
official vs. practice as the primary split per the brief's `CBT Center →
Official CBT / Practice CBT → existing engine` diagram). This is a
**pure UI addition** — no model, repository, or route restructuring
needed, because the engine and the entry point already exist and are
already correctly separated from each other.

**Design reference**: the uploaded EduSphere CBT mockups (pre-exam
verification checklist, question palette with answered/unanswered/marked
states, live proctoring panel, admin live-monitoring dashboard,
post-exam integrity report) are noted as the visual direction for that
future build. None of it — camera/microphone verification, fullscreen
detection, monitoring event timeline, integrity scoring — exists in the
engine yet beyond the single `proctoringEnabled` boolean gate on
`ExamModel`, which is consistent with "do not build the complete
monitoring system in CBT-1."

## 15. Route integration plan
No route changes needed this stage. `AppRoutes.cbt` and `FeatureKeys.cbt`
already exist and already resolve end-to-end from an admin-configured
dashboard card through to `CbtScreen`. CBT-2's only routing work is
swapping what that route builds — the table entry itself doesn't change.

## 16. Documentation update
This file. No other docs required changes — the existing per-stage
changelog convention (`docs/STAGE_*.md`) is preserved.

## 17. Static consistency verification

No Flutter/Dart toolchain or network access is available in this
environment, so this is source-level static verification, not a
compiled build:

- Searched for duplicate `ExamModel`, `QuestionModel`, `ExamSessionModel`,
  `ExamAttemptModel`, `ExamMode`, or CBT-engine-equivalent
  classes anywhere in `lib/` — none found.
- Searched for a second exam-repository or exam-routing system — none found.
- Confirmed every repository referenced by `learning_repository.dart`
  (`AppConstants.examsCollection`, `.questionsCollection`,
  `.examSessionsCollection`, `.examAttemptsCollection`) is defined and
  matches what `ExamRepository`/`QuestionRepository`/
  `ExamSessionRepository`/`ExamAttemptRepository` construct with.
- Confirmed `WaecDashboardScreen`, `NecoDashboardScreen`,
  `JambDashboardScreen`, and `UniversityDashboardScreen` all import and
  navigate to the real `ExamListScreen`/`ExamRunnerScreen` — none of
  them were touched, none needed to be.
- Confirmed `CbtScreen` is the only remaining CBT-adjacent placeholder;
  it does not shadow, duplicate, or conflict with the real engine — it
  simply doesn't call into it yet.
- No emoji-based or unprofessional icon usage was introduced (nothing
  was introduced — this stage made no UI or code changes).
- Since no files were modified, there is no risk of a regression to
  existing WAEC/NECO/JAMB/University/Learning functionality this stage.

---

## Completion statement

CBT-1 is complete. Its finding is: **the requested foundation already
exists** — a shared, non-duplicated exam engine (models, repositories,
runner, scoring, admin CRUD) already sits behind four working entry
points, already supports an official/practice/mock mode distinction, and
already carries a substantial per-exam access-policy surface. The only
concrete gap is that the generic `/cbt` destination hasn't been pointed
at that engine yet, and a platform-wide (as opposed to per-exam) CBT
settings document doesn't exist. Both are scoped, additive,
UI-plus-one-model pieces of work for CBT-2 — not architecture changes,
and not anything CBT-1's "do not build ahead" rule permits starting now.

**Stopping here, as instructed, before CBT-2.**
