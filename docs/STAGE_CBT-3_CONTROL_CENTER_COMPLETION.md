# Stage CBT-3 — CBT Control Center — Completion Report

This is a control surface over the existing CBT engine. No new exam,
question, scoring, or attempt model/repository was created — every
capability below either configures the engine CBT-1 audited and CBT-2
wired up, or extends an existing repository/screen with one additive
method or parameter.

## 1. Files created

| File | Purpose |
|---|---|
| `lib/features/admin/cbt/cbt_control_center_screen.dart` | "CBT Management" hub — real dashboard stats + navigation into every other CBT-3 screen. |
| `lib/features/admin/cbt/cbt_settings_screen.dart` | Platform-wide CBT settings editor (the brief's "Access Rules" + "CBT Settings" sections, merged — see §8). |
| `lib/features/admin/cbt/cbt_attempt_management_screen.dart` | Admin-wide attempt list + delete. |
| `docs/STAGE_CBT-3_CONTROL_CENTER_COMPLETION.md` | This report. |

## 2. Files modified

| File | Change | Why |
|---|---|---|
| `lib/core/constants/app_constants.dart` | Added `cbtSettingsDoc = 'cbt'`. | Same singleton-settings-doc pattern as `brandingSettingsDoc`/`appConfigDoc`/`uploadSettingsDoc` already in this file — one more entry, not a new pattern. |
| `lib/models/app_settings_models.dart` | Added `CbtSettingsModel` class. | See §7 (data architecture). |
| `lib/repositories/settings_repository.dart` | Added `watchCbtSettings`/`saveCbtSettings` to the existing `AppSettingsRepository`. | Extends the one class that already owns every other settings singleton; no new repository. |
| `lib/repositories/learning_repository.dart` | Added `watchRecentForAdmin(limit: 100)` to the existing `ExamAttemptRepository`. | One new query method on the existing repository — not a second attempt-data system. |
| `lib/features/admin/exam_prep/exam_manager_screen.dart` | Added optional `ExamType? initialTypeFilter` constructor param (default `null` = today's "All" behavior, unchanged); AppBar title now reflects the active filter. | Lets Official/Practice/Mock reuse this one screen instead of three near-duplicates. |
| `lib/features/admin/admin_dashboard_screen.dart` | Replaced the "Exams" tile (→ unfiltered `ExamManagerScreen`) with a "CBT Management" tile (→ the new hub). | One coherent CBT entry point instead of two overlapping ones; nothing reachable before is unreachable now — see §8. |

## 3. Existing files reused, unmodified

`ExamModel`, `QuestionModel`, `ExamSessionModel`, `ExamAttemptModel` ·
`ExamRepository`, `QuestionRepository`, `ExamSessionRepository` ·
`ExamMode`, `ExamType` · `ExamListScreen`, `ExamRunnerScreen`,
`ExamResultScreen` · `ExamEditorScreen` (still the one place per-exam
fields — `attemptLimit`, `isPremium`, `availableFrom/Until`,
`supportedModes`, `proctoringEnabled`, `offlineAvailable` — are edited;
CBT-3 added no parallel editor for any of them) · `QuestionManagerScreen`,
`BulkQuestionUploadScreen`, `SubjectManagerScreen` (all reached through
`ExamManagerScreen`'s existing per-exam actions, unchanged) ·
`ExamAttemptResolver` (its `matchAll`, added in CBT-2, is what the new
attempt-management screen reuses) · `AuditLogService` (`logDelete`,
`logSettingsChange`) · `AppColors`, `AppTextStyles`, `CustomCard`,
`AppChip`, `AppTextField`, `PrimaryButton`, `SectionHeader`,
`AppDialog`, `LoadingView`/`ErrorView`/`EmptyView`/`AppSnackbar` — no
new design-system component was invented.

## 4. Firestore changes

**None to `firestore.rules`.** `match /settings/{id}` already covers any
document id under `settings/`, including the new `settings/cbt` doc —
confirmed by reading the rule, not assumed. `exam_attempts` already
grants `isAdmin()` update/delete — the new Attempt Management screen's
delete action uses a permission the rules already anticipated, not one
newly granted.

One new Firestore document going forward: `settings/cbt` (created on
first save, via the existing `set(..., merge: true)` pattern every other
settings screen already uses). No collection, no schema change to any
existing collection, no migration.

## 5. Security-rule changes

None. See §4. RBAC gating for CBT-3's screens is inherited, not new:
they're only reachable via `AdminDashboardScreen`, which is itself only
shown by `ProfileScreen` to a user with at least one elevated
`UserRole` (`admin`/`superAdmin`/`institutionAdmin`/`moderator` —
confirmed by reading `ProfileScreen`'s existing gate). CBT-3 added no
separate role check and weakened none.

## 6. Routes changed

None. No new top-level route was added — every CBT-3 screen is reached
via `Navigator.push`, the same pattern every other admin sub-screen in
this codebase already uses (e.g. `SubjectManagerScreen`,
`AuditLogScreen`). `AppRoutes` was not touched.

## 7. Data architecture

`CbtSettingsModel` (`settings/cbt`) holds only **platform-wide
defaults** — `practiceEnabled`, `mockEnabled`,
`requirePremiumForPractice`/`ForMock`, `freeAttemptLimit`/
`trialAttemptLimit`/`premiumAttemptLimit`, `freeUserQuestionLimit`,
`offlinePracticeEnabled`. Every one of these is a genuinely new
*platform-wide* concept — none duplicates a field that already exists
per-exam on `ExamModel`. Per-exam fields (`attemptLimit`, `isPremium`,
`availableFrom`/`availableUntil`, `supportedModes`,
`proctoringEnabled`, `offlineAvailable`) were **not** touched or
shadowed; `ExamEditorScreen` remains their one editor, and this
settings doc's own doc comment states explicitly that a set per-exam
`attemptLimit` always wins over the global default.

## 8. Deliberate consolidations — stated plainly, not silently done

- **"Access Rules" and "CBT Settings"** (brief's two separate tiles) are
  **one screen**, `CbtSettingsScreen`. Both would otherwise edit the
  identical `settings/cbt` document — two screens racing to save one
  doc is the kind of duplicate configuration system the brief
  repeatedly warns against. The one screen groups them into clearly
  labeled sections ("Availability", "Access rules", "Offline") instead.
- **"CBT Analytics"** has no separate screen. The Dashboard stats
  (exam counts by type/status/premium, attempt count) already surface
  everything honestly derivable from existing data with one query each.
  Anything beyond that — trends over time, per-subject pass-rate
  breakdowns — isn't obtainable from the current architecture without
  new aggregation infrastructure this stage was not asked to build, and
  the brief explicitly says not to fake a statistic that can't be
  produced.
- **"Attempt Limits"** has no separate screen either — it's fully
  covered by `ExamEditorScreen`'s existing `attemptLimit` field (for
  per-exam limits) and `CbtSettingsScreen`'s new
  free/trial/premium-default fields (for the platform-wide fallback).
  A third screen would have duplicated one of the two.
- **"Questions"** opens the same `ExamManagerScreen`, unfiltered. There
  is no cross-exam question bank in this codebase —
  `QuestionManagerScreen` and `BulkQuestionUploadScreen` both require a
  specific `ExamModel` in their constructor (confirmed by reading them,
  not assumed) — so "pick an exam, then manage its questions" via that
  exam's existing popup menu *is* the real, only entry point. Nothing
  was invented to make this look more built than it is.

## 9. Admin capabilities added

- View real-time CBT statistics (exam counts by type/status/premium;
  bounded attempt count, explicitly labeled when capped).
- Navigate into Official/Practice/Mock exam management pre-filtered
  (same screen, same capabilities `ExamEditorScreen` already had:
  create, edit, publish/unpublish via `isActive`, schedule via
  `availableFrom`/`Until`, set duration/question-count/attempt-limit/
  premium/supported-modes/instructions/title/description/category).
- Reach question management/import per exam.
- View and delete individual exam attempts, filterable by mode.
- Configure platform-wide practice/mock availability, premium
  requirements, attempt-limit defaults, and a free-user practice
  question-limit default.

## 10. Audit events added

- `logSettingsChange` on every `CbtSettingsModel` save (`targetId:
  'cbt'`) — same call every other settings screen
  (branding/app-config/upload) already makes.
- `logDelete` on every attempt deletion, `module:
  AuditModules.academicStructure` (matching the module
  `ExamManagerScreen` already logs exam create/edit/delete under, so a
  given exam's full audit trail — exam changes and its attempts' —
  groups together in the Audit Log viewer).
- Exam create/edit/delete/publish/unpublish audit logging is
  **unchanged** — `ExamEditorScreen`/`ExamManagerScreen` already logged
  these before CBT-3; nothing needed adding there.

## 11. Verification performed

No Flutter/Dart toolchain available in this environment — static
verification only, stated plainly per the brief's own fallback
instruction:

- **Brace/paren balance** — checked programmatically across all 9
  touched/new files; all balanced.
- **Import resolution** — every relative import in the 3 new files
  checked against the real file tree; all resolve. One genuine bug was
  caught this way: an `AuditModules` import I'd removed as apparently-
  unused was actually needed (`AuditModules.academicStructure` is used
  in the same file `AuditActionType` lives in) — restored before
  delivery, not left broken.
- **Unused-import scan** — automated check of every imported symbol
  against its usage count across all new files; only false positives
  (symbols legitimately used once) were found.
- **Duplicate-class search** — grepped the whole `lib/` tree for a
  second `ExamModel`, `ExamRepository`, `QuestionRepository`,
  `ExamSessionRepository`, `ExamAttemptRepository`, `ExamListScreen`,
  `ExamRunnerScreen`, `ExamResultScreen`, or any of the three new CBT-3
  classes; exactly one definition of each found.
- **`ExamManagerScreen` call-site check** — confirmed the only 4 call
  sites of the newly-parameterized constructor are the 4 added in the
  new hub; no other file calls it, so nothing else could break from the
  added optional parameter.
- **RBAC path check** — confirmed every new screen is reachable only
  through `AdminDashboardScreen`, itself gated by `ProfileScreen`'s
  existing `isElevated` role check; no new or weakened gate.
- **Firestore rule check** — confirmed `match /settings/{id}` already
  covers `settings/cbt`, and `exam_attempts` already grants admin
  update/delete, both by reading the actual rules file.
- **Flutter timing bug caught and fixed** — an initial `late` field
  initializer referencing `widget` in `ExamManagerScreen`'s State class
  would have thrown at runtime (the framework hasn't attached `widget`
  to the State object yet at field-initializer time); moved into
  `initState()`, matching this codebase's own established pattern.
- **Emoji scan** — automated scan across every new/touched file; zero
  emoji introduced.
- **Light/dark theme** — every color reference in the 3 new files goes
  through `AppColors` or `Theme.of(context).textTheme`; no hardcoded
  hex values.
- **Not verified** (no toolchain): actual `flutter analyze`/compile,
  runtime layout on real device sizes, a live Firestore round-trip.
  These should be run before shipping, exactly as stated for CBT-1 and
  CBT-2.

## 12. Known limitations — stated plainly

- **No enforcement**, anywhere, of `isPremium`,
  `requirePremiumForPractice`/`ForMock`, or the free/trial/premium
  attempt-limit defaults. All of it is configuration for a future
  entitlement/payment system, exactly as the brief requires for this
  stage — and exactly the same status `ExamModel.isPremium` already had
  after CBT-2. Nothing in CBT-3 claims otherwise.
- **`offlinePracticeEnabled` controls nothing.** No sync/replay engine
  exists (confirmed again this stage — unchanged since CBT-1). The
  switch exists only so the admin's choice isn't lost once that engine
  is built.
- **Total attempt count is capped at 100**, labeled as such
  ("Attempts (100+)") rather than presented as a true platform-wide
  total, because no count/aggregation capability exists anywhere in
  this codebase and fetching an unbounded `exam_attempts` collection
  just to count it would be a new performance cost this stage wasn't
  asked to introduce.
- **No "Draft" status distinct from "Disabled."** `ExamModel` has no
  separate draft field — only `isActive` (true/false) plus the derived
  availability window. The Dashboard's status breakdown reflects this
  honestly (Active/Disabled/Upcoming/Expired) rather than inventing a
  Draft state the schema doesn't have.
- **Scanning Mode, proctoring, offline sync, and payment/subscription
  billing** remain exactly where CBT-1/CBT-2 left them — untouched,
  not started, per this stage's explicit scope.

## 13. Recommended next stage

The entitlement/subscription system is the natural next dependency —
`CbtSettingsModel` and `ExamModel.isPremium` now have a complete admin
configuration surface with nothing yet reading it at runtime. Building
that consumer (even a minimal one) would turn this stage's premium
controls from configuration into an actual access gate.

**Stopping here, as instructed, awaiting approval before CBT-4.**
