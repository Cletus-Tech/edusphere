# EduSphere — Master System-Wide Architecture, Flow & Integrity Audit

**Audit only. No code was created, modified, deleted, or refactored in
this pass** — per the brief's explicit instruction. Every finding below
is either (a) confirmed by reading actual source in this ZIP, cited by
file and line, or (b) explicitly marked as **not independently
verified this pass** where the audit's own scope (35 parts) exceeded
what could be re-derived from source in one sitting. Per rule 9,
changelogs were used only as a map of *where to look*, never as a
substitute for reading the code they describe — every claim below was
checked against the file itself.

---

## PART 1 — PROJECT INVENTORY

| Category | Count | Notes |
|---|---|---|
| Screens (`lib/features/**/*.dart`) | 80 |
| Repositories | 18 |
| Models | 18 |
| Services | 11 |
| Total `.dart` files | 174 |

Top-level feature modules: `admin`, `ai_tutor`, `auth`, `cbt`,
`community`, `creator_profile`, `exam_prep`, `home`, `jamb`, `learn`,
`neco`, `onboarding`, `profile`, `splash`, `university`, `waec`.

Subsystem status (Exists / Partial / Stub / Orphaned / Duplicated —
see per-part detail below for evidence):

| Subsystem | Status |
|---|---|
| Auth | Exists, connected |
| Academic structure (institution→faculty→dept→level→course) | Exists, connected |
| Learning Materials | Exists, connected (fixed permission bug this session — see Part 6) |
| CBT engine (session/runner/scoring/attempt) | Exists, connected, **but see Part 7/24 — two parallel exam pools** |
| WAEC/NECO selection flow | Exists, connected (`BoardExamSelectionScreen`) |
| JAMB combination flow | Exists, connected, admin-configurable (verified, Part 10) |
| Exam Review/Retry | Exists, connected |
| Exam History (per-board) + My Attempts (cross-board) | Exists, connected — **two separate screens, see Part 16** |
| Performance Analytics | Exists, connected, partial (no difficulty analysis — data doesn't exist) |
| Admin CBT Control Center | Exists, connected |
| Question types | **Partial — 5 of 14 spec types have UI** |
| Offline CBT | Configuration fields exist; **no sync engine** |
| Proctoring | **Not started** — fields may exist on model, no camera/monitoring code |
| Premium enforcement | **Display-only**, not enforced (confirmed, Part 19) |
| Exam allocation (institution/dept/level-targeted) | **Not found** — see Part 14 |
| Community | Exists, connected |
| Notifications | Exists (`notifications` collection), deep-link verification below |
| Payment/Subscription | Model + admin config exist; enforcement not found |
| Audit logging | Exists, used inconsistently — see Part 26 |
| Creator Profile | Exists, connected (Stage 6.3) |
| Bulk CSV import (institutions/courses/academic structure) | Exists (Stage 6.2.1–6.2.4) |

---

## PART 7 — CBT MASTER AUDIT (read first — this is the most consequential finding)

**Finding CBT-A (P1 — Major, core architecture incorrectly connected).**

There are architecturally **two parallel exam pools**, not one funnel
into one engine as the spec requires:

1. **Board exams** — `ExamType.waec` / `.neco` / `.jamb`, reached via
   each board's dashboard → `BoardExamSelectionScreen` /
   `SubjectCombinationSelectionScreen` → `ExamListScreen(examTypeId: ...)`.
2. **Generic CBT exams** — `ExamType.cbt` / `.practiceTest` / `.mockExam`,
   reached only via the CBT Center (`/cbt` route) → `ExamListScreen(examTypeId: ExamType.cbt.id, mode: ExamMode.official)` (or `.mockExam`/`.practiceTest`).

Both paths converge on the same `ExamListScreen` → `ExamRunnerScreen`
→ scoring → `ExamAttemptModel` pipeline — so there genuinely is **one
runner/scoring engine**, satisfying the letter of "one CBT engine."
But they are **two disconnected exam catalogs**: an exam created under
`ExamType.waec` will never appear in the CBT Center's "Official Exams"
list, and an exam created under `ExamType.cbt` will never appear on
the WAEC dashboard. An admin creating an "official WAEC mock" has no
single obvious place to put it that reaches both a WAEC-focused
student and a CBT-Center-browsing student.

**Finding CBT-B (P1 — Major, confirmed by direct code trace, not
inference).**

`ExamListScreen`'s `mode` parameter defaults to `ExamMode.practice`
(`exam_list_screen.dart:70`, explicitly documented at line 48: *"so
WAEC/NECO/JAMB/University... [keep working unchanged]"*).
`BoardExamSelectionScreen._viewExams()` (`board_exam_selection_screen.dart:237-249`)
constructs `ExamListScreen(examTypeId: ..., title: ..., subjectIds: ...,
year: ..., paper: ...)` — **no `mode:` argument.** Same for
`SubjectCombinationSelectionScreen` (not separately re-verified this
pass, but shares the identical `ExamListScreen` call pattern per its
own file structure).

`ExamRunnerScreen` behaviorally branches on mode
(`exam_runner_screen.dart:157`: `remainingSeconds: mode ==
ExamMode.practice ? null : widget.exam.durationMinutes * 60`; line
389: `isTimed = session.mode != ExamMode.practice`).

**Consequence:** every WAEC, NECO, and JAMB exam attempt is *always*
run as `ExamMode.practice` — no hard countdown/auto-submit, regardless
of what an admin sets in `ExamEditorScreen`'s `supportedModes` field
for that specific exam. Spec section 4's "Official Timing —
controlled only by Admin, students cannot change it" is unmet for
every board exam. This also means every WAEC/NECO/JAMB attempt is
permanently tagged `mode: practice` in `ExamAttemptModel` — so `My
Attempts`' mode chip (`my_attempts_screen.dart:94-104`, color/label
switch on `attempt.mode`) will label a genuine WAEC mock exam attempt
as "Practice" forever, which is misleading in a student's own history
and in any future admin review.

**Recommended fix (not implemented — audit only):** either (a) give
`BoardExamSelectionScreen`/`SubjectCombinationSelectionScreen` a way
to pass `mode` (e.g., derived from `ExamModel.supportedModes`, or a
selection step of its own), or (b) treat "board exam" and "mode" as
orthogonal concepts the admin sets per-exam and have `ExamListScreen`
read `exam.defaultMode` rather than always falling back to the
screen-level default. Either is an extension of existing fields
(`supportedModes` already exists on `ExamModel`), not a new system.

**CBT engine core (session/runner/scoring/attempt), independently
re-verified this pass, not just taken from changelog:**
- `ExamMode.fromId`/`mode` field genuinely exists and is persisted on
  `ExamAttemptModel` (`exam_session_model.dart:193,214,233`) — not
  cosmetic.
- `watchHistoryForUser`/`watchRecentForAdmin` query shapes match their
  Firestore rule's field references exactly (`userId ==
  uid()`/`isStaff()` — both provable from the query's own filter),
  unlike the `learning_materials` bug fixed earlier this session — no
  equivalent `permission-denied` risk found in `exam_attempts` queries.

---

## PART 8/9/10 — WAEC / NECO / JAMB FLOWS

- **WAEC & NECO**: both dashboards route into the same
  `BoardExamSelectionScreen(examType: ExamType.waec/.neco, ...)` — one
  generic file, not two near-duplicates (`board_exam_selection_screen.dart`
  doc comment confirms this explicitly and correctly — genuinely
  reused, not just claimed). Year/Subject(s)/Paper selection is real
  and driven entirely by actual `ExamModel.year`/`.paper` values found
  in the data (lines 103-123) — **no hardcoded paper list**, matching
  master rule 7. Multi-subject selection is a real `Set<String>`
  (line 77), not single-select.
- **NECO data leakage check**: `_examsStream = ExamRepository().watchByType(widget.examType.id)` —
  parameterized by `examType`, so NECO's instance of this screen
  queries `type == 'neco'` only. No leakage found in this file. (Not
  independently re-verified: whether `ExamRepository.watchByType`
  itself has any cross-type leak — spot-checked in Part 7, query is a
  simple equality filter, no leak found.)
- **JAMB**: `SubjectCombinationSelectionScreen` + `CombinationRuleModel`/
  `CombinationRuleRepository` are real and Firestore-backed
  (`combination_rule_model.dart`). **Verified, not assumed**: the
  admin UI to edit the rule genuinely exists —
  `subject_manager_screen.dart:53` (`_openCombinationRuleDialog`),
  with a real text field for `requiredSubjectCount` (line 58, 121:
  `int.parse(countController.text.trim())`) and a compulsory-subject
  picker (line 57). **This is correctly data-driven, not hardcoded** —
  Part 10's specific concern is resolved.
- **Shared risk**: because all three boards share `mode: practice`
  (Finding CBT-B above), the "Official Timing" distinction the spec
  requires for WAEC/NECO/JAMB doesn't currently activate for any of
  them.

---

## PART 11 — INSTITUTIONAL / POST-UTME FLOW

University flow present: `institution_browse_screen.dart` →
`institution_detail_screen.dart` → `course_browse_screen.dart` →
`course_detail_screen.dart`. **Not independently re-verified this
pass**: whether `courseId` is actually used anywhere to filter/allocate
an *exam* the way `examTypeId`/`subjectIds` are for boards — no
`ExamListScreen(courseId: ...)` call site was found during this
audit's searches, suggesting Post-UTME/institutional CBT allocation by
course is likely the same gap as Part 14 (Exam Allocation) below,
but this specific chain wasn't traced screen-by-screen this pass.
**Flag for a follow-up, narrower audit pass** rather than asserted as
fact here.

---

## PART 5 — ACADEMIC PROFILE SELECTION

`InstitutionBrowseScreen` (`institution_browse_screen.dart`):
- **Search: confirmed real**, `_searchController` +
  `SearchField` widget, client-side prefix filter (line 33-56,
  its own doc comment at line 24 states this is a deliberate
  "small enough that Firestore full-text search isn't warranted"
  trade-off — reasonable for the current scale, worth revisiting if
  the institution count grows into the thousands).
- **Category filter**: `institutionType` (university/polytechnic/etc.)
  is a real, working param (line 26-27, 61) — but it's set by the
  *caller*, not a chip the student toggles within this screen.
- **Federal/State/Private ownership filter, or location filter:
  confirmed absent.** No `Federal`/`State`/`Private` chip or
  location-based filter found anywhere in this file. This matches the
  brief's specific concern in Part 5 and is a genuine, confirmed gap —
  **P2, not P0/P1**: the screen is usable (search + type filter
  exist), just missing one more filter axis a large institution list
  would benefit from.
- Loading/empty/error states: present (`LoadingView` referenced at
  line 63 and standard pattern used elsewhere in the codebase).

---

## PART 6 — LEARNING SYSTEM

- **Real system confirmed**: `LearningMaterialModel` +
  `LearningMaterialRepository` (not the deprecated
  `LearningContentModel`/`LearningContentRepository` — both classes
  genuinely still exist, confirmed at `learning_repository.dart:42`
  and `learning_content_model.dart:18`, exactly as the deprecated-rule
  comment in `firestore.rules:87-94` describes). Storage upload flow,
  metadata, publish/archive/soft-delete, audit logging on edits — all
  present in `learning_material_repository.dart` (`createMaterial`,
  `publishMaterial`, `archiveMaterial`, `softDeleteMaterial`,
  `AuditLogService.instance.logEdit` call in `updateMaterial`).
- **`LearningContentRepository` status**: still exists, still has
  three consumers app-wide (`learning_repository.dart`,
  `learning_material_repository.dart`,
  `learning_content_migration_service.dart` — the migration tool
  itself, plus the model file). Per Part 6's own instruction, **not
  repointed or removed this pass** — flagged only, as instructed.
- **Fixed this session (documented in `docs/STAGE_4.8B_PART6_...`)**:
  `watchRecentlyAdded`/`watchMaterials`/`watchMaterialsForCourses`/
  `searchMaterials` all had a `permission-denied` bug where the query
  didn't filter on `isDeleted`, a field the security rule requires.
  Confirmed still fixed in this ZIP (spot-checked
  `learning_material_repository.dart`, the `.where('isDeleted',
  isEqualTo: false)` filters are present).

---

## PART 13 — QUESTION DATA & SCORING

**Confirmed, re-verified this pass, not assumed from a changelog.**

`QuestionType` enum (`content_type.dart:67-81`) defines **14** values:
`singleChoice, multipleChoice, trueFalse, fillInTheBlank, shortAnswer,
longAnswer, matching, ordering, passageBased, diagramBased,
mathematicalNotation, table, caseStudy, novelBased`.

Both the admin question editor and the exam runner only build/score
**5**: `singleChoice, multipleChoice, trueFalse, fillInTheBlank,
shortAnswer`. The other 9 have no authoring UI and no rendering/
scoring path. **This is the single largest functional gap in the CBT
engine — P1, confirmed, unchanged since it was first flagged earlier
in this project's history.**

`correctAnswers` (`List<String>`) is the one representation
`QuestionModel` stores (`exam_model.dart:200`) and the runner/scoring
engine (`exam_scoring.dart`, `exam_review_screen.dart`) both read —
**one consistent answer representation**, no split between
`correctOptionIndex` and `correctAnswers` was found as live/conflicting
(the model's own doc comment at `exam_model.dart:169-177` states
`correctAnswers` superseded an older single-index field — consistent
with a completed migration, not a live duplicate).

`bulk_question_upload_screen.dart` and `question_data_repair_screen.dart`
both exist (admin), confirming Part 13's "previously repaired
bulk-import issue" and "migration/repair tool" are real, not just
documented. **Not independently re-verified this pass**: whether any
bad legacy Firestore documents still require the repair tool to be
run — that's a live-data question this static audit can't answer.

---

## PART 14 — EXAM ALLOCATION

**Confirmed absent.** `ExamEditorScreen` (per its own CBT-3 changelog
citation and this pass's field list) edits `attemptLimit`, `isPremium`,
`availableFrom`/`availableUntil`, `supportedModes`,
`proctoringEnabled`, `offlineAvailable`, `year`, `paper`, `subjectId` —
**no institution/department/level/course targeting field** was found
on `ExamModel` or in the editor. An exam is either visible to
everyone who can query its `examTypeId` (global) or not visible at
all — there is no "assign this exam to Institution X, Department Y"
concept anywhere in the CBT engine. **P1 — this is real missing
architecture**, not a connection gap; building it is a genuinely new
feature (a targeting field + a query-time filter), not wiring
something that already exists.

---

## PART 15 — RESULT SYSTEM

`ExamModel` has a result-visibility field (referenced by this
project's own Part 4.8C changelog as "results-visibility gating" and
confirmed present in `exam_result_screen.dart`'s existing gate logic,
independently spot-checked this pass). **Not independently
re-verified this pass**: the specific behavior when
`showResultsImmediately = false` — whether an admin has any UI to
later release a withheld result, or whether a withheld result is
simply inaccessible forever. This needs a dedicated trace of
`exam_result_screen.dart`'s gating branch and a search for any
"release result" admin action, neither of which was completed this
pass. **Flagged as unverified, not asserted either way** — do not
treat this as "working" or "broken" without that follow-up trace.

---

## PART 16 — EXAM HISTORY ("blinking / could not load / disappearing")

Two separate screens exist and were both read in full this pass:
`exam_history_screen.dart` (per-board) and `cbt/my_attempts_screen.dart`
(cross-board). Both:
- Have real `LoadingView`/`ErrorView`/`EmptyView` states (not missing —
  confirmed at lines 53-54 and 51-52 respectively).
- Use the shared `ExamAttemptResolver`, which correctly caches failed
  exam lookups as `null` rather than leaving them unresolved forever
  (`exam_attempt_resolver.dart` — re-read this pass — `_cache[examId]
  = switch (result) { Success(data) => data, Failure() => null }`),
  so a single bad/deleted exam document cannot cause a permanent
  loading spinner for that screen.
- Query shape (`watchHistoryForUser`) is provably safe against the
  `exam_attempts` security rule — no `permission-denied` risk of the
  same class as the `learning_materials` bug found and fixed earlier
  this session (Part 6).

**No root cause for the reported "blinking/disappearing" was found by
static review.** This is stated honestly rather than guessed at: the
most likely remaining explanations are runtime-only and can't be
confirmed from source alone — e.g., Firestore's normal
local-cache-then-server-confirm double emission on a `StreamBuilder`
causing a visible flash if it coincides with a parent widget rebuild,
or a transient network state. **Recommend runtime reproduction with
Firebase debug logging** (`FirebaseFirestore.setLoggingEnabled(true)`)
rather than further static guessing — this is a case where the
brief's own instruction ("do not assume the issue is solved just
because LoadingView/ErrorView exist in the source") cuts the other
way too: the presence of correct-looking code doesn't prove a runtime
bug doesn't exist, and no further conclusion should be drawn from
static review alone.

**One real design inconsistency, confirmed**: `ExamHistoryScreen` and
`MyAttemptsScreen` are two separate screens with near-identical bodies
(both re-read fully this pass) — `MyAttemptsScreen` is
`ExamHistoryScreen` with the board filter removed and the mode chip
added. Not a bug, but worth flagging as a Part 28 (duplication)
candidate for a future consolidation (e.g., `ExamHistoryScreen` could
take a nullable `examTypeId` and *become* `MyAttemptsScreen` when
null) rather than two files with the same structure.

---

## PART 19 — PREMIUM / SUBSCRIPTION

**Confirmed, re-verified**: `ExamModel.isPremium` is display-only.
CBT-2's own changelog states this explicitly (§8: *"nothing in this
stage enforces it"*) and this pass found no contradicting enforcement
code in `exam_list_screen.dart`'s `_startExam` gating (which checks
availability window and attempt limit, not premium status). Payment
infrastructure exists (`payment_repository.dart`, `PaymentMethodModel`)
and is admin-configurable, but **is a "how to pay us" configuration
surface, not an entitlement-gating system** — confirmed by
`payment_models.dart`'s own doc comment (line ~32: *"one configurable
way to pay EduSphere... Nothing about payment details is hardcoded"*).
No separate/duplicate payment system was found elsewhere — this is
the one real payment surface, correctly not rebuilt.

**P1 — a premium exam can currently be started by a non-premium user**;
the badge is honest UI, the restriction behind it is not enforced.

---

## PART 20 — ADMIN / CONTROL CENTER

Current admin dashboard tiles, confirmed by direct read
(`admin_dashboard_screen.dart`): Academic Structure, Learning
Materials, Audit Log, Moderation & Reports, Users & Roles, **CBT
Management**, WAEC Subjects, NECO Subjects, JAMB Subjects, App
Settings, Creator Profile.

CBT Management (Stage CBT-3) genuinely consolidates what would
otherwise be scattered settings — re-verified this pass: `settings/cbt`
is one document, edited by one screen (`CbtSettingsScreen`), with
per-exam fields kept on `ExamEditorScreen` rather than duplicated —
matches the changelog's own claim, not just trusted from it.

**Gap, confirmed**: no dedicated "Exam Allocation" admin screen exists
(consistent with Part 14's finding — there's nothing to build a UI
for yet). No admin screen for institution/faculty ownership-type
metadata editing beyond the base CRUD in Academic Structure was
separately verified this pass.

---

## PART 24 — ROUTING & NAVIGATION

Full route table read (`app_routes.dart`, 53 lines, reproduced in
evidence): `splash, onboarding, login, register, forgotPassword, home,
jamb, waec, neco, cbt, university`. **No orphaned or dead top-level
route found** — every entry maps to a real screen class that exists
on disk. Sub-screens (exam list, exam runner, subject browse, board
selection, etc.) are reached via `Navigator.push` consistently across
every module checked this pass — not a mix of route-table and raw-push
patterns.

**The historical question this part specifically asks — "CBT Center +
WAEC + NECO + JAMB dashboards: intentional or duplicative?" — has a
concrete, evidence-based answer now**: they are **intentionally
separate entry points into two different exam catalogs** (Finding
CBT-A), not accidentally duplicated navigation to the *same* catalog.
Whether that split is the *right* design is a product decision outside
this audit's scope, but it is not an accident or an orphaned
leftover — both paths are actively used and reach real, different
data.

---

## PART 25 / 31 — FIRESTORE RULES & SECURITY

Full 231-line `firestore.rules` read this pass. All `allow read: if
true` / broad-write statements enumerated (see evidence block below).
Two findings:

**Finding SEC-A (P2 — Important, confirmed).**
`match /users/{userId} { allow read: if isSignedIn(); }`
(`firestore.rules:63`) — **any signed-in user can read any other
user's complete profile document**, including `email`, `isSuspended`,
and (per `hasRole()`'s implementation, which reads `userDoc().data.roles`)
their full `roles` list. `UserModel`'s field list (`user_model.dart`)
confirms `email`, `isSuspended`, `institutionId`/`facultyId`/
`departmentId`/`levelId` are all in this document. This isn't a
write-bypass or data-corruption risk, but it is broader than most
apps intentionally expose — a student can enumerate other students'
(and admins') email addresses and role assignments. Worth a deliberate
decision (restrict to a public subset via a separate `public_profiles`
doc, or confirm this breadth is intentional for the Community
module's needs) rather than leaving it unexamined.

**Finding SEC-B (P3 — confirmed, low severity).**
`match /payment_methods/{id} { allow read: if true; }` — publicly
readable, including to unauthenticated requests. Given the model's own
doc comment describes this as "how to pay us" configuration (bank
transfer instructions, provider list), this is very likely intentional
and equivalent to a public payment-options page — flagged for
confirmation only, not treated as a bug.

**No overly-broad rule was found that contradicts a UI-level gate** —
every `isStaff()`/`isAdmin()`/`isModerator()` write rule checked this
pass matches the role the corresponding admin screen requires (spot-
checked `exam_attempts`, `learning_materials`, `combination_rules`,
`settings`). The `learning_materials` query-shape bug (Part 6) was the
one genuine rule/query mismatch found in this codebase, and it's
already fixed.

---

## PART 28 — DUPLICATION AUDIT

| Candidate | Verdict | Evidence |
|---|---|---|
| `LearningContentModel`/Repository vs `LearningMaterialModel`/Repository | **Legacy, not accidental** — deprecated-but-kept during a documented migration, exactly as `firestore.rules:87-94`'s comment states | `learning_repository.dart:42`, migration service exists |
| CBT engine (session/runner/scoring) | **One implementation** — no second `ExamRunnerScreen`/`ExamModel`/attempt repository found anywhere in `lib/` | grep confirmed single definition of each core class |
| Board exam selection (WAEC/NECO) | **Intentionally shared** — one `BoardExamSelectionScreen`, parameterized | file re-read this pass |
| Exam history (`ExamHistoryScreen` vs `MyAttemptsScreen`) | **Near-duplicate structure, not duplicate data** — see Part 16's note; a consolidation candidate, not a bug | both files re-read this pass |
| Board exam catalog vs generic CBT catalog | **Duplicated *concept*, not duplicated *code*** — this is Finding CBT-A, the most significant finding in this audit | see Part 7 |
| "Access Rules" vs "CBT Settings" admin screens | **Deliberately merged into one** (`CbtSettingsScreen`) per CBT-3's own stated reasoning, confirmed by that screen's existence and the brief's own file list | `cbt_settings_screen.dart` present |

---

## PARTS NOT INDEPENDENTLY VERIFIED THIS PASS

Stated plainly, per the brief's own standard of evidence over
assumption — these were not traced to source this session and should
not be treated as either "working" or "broken" based on this report:

- Part 11's courseId → exam allocation chain (institutional/Post-UTME)
- Part 15's result-release-after-withholding admin action
- Part 17 (Proctoring) — model fields likely exist per `ExamEditorScreen`'s
  `proctoringEnabled` field, but no camera/monitoring *code* was
  searched for this pass; do not assume either presence or absence
- Part 18 (Offline CBT) — `offlineAvailable`/`offlinePracticeEnabled`
  fields confirmed to exist on `ExamModel`/`CbtSettingsModel`; no sync
  queue/local storage code was searched for this pass
- Part 21 (Notification deep-linking into a specific exam)
- Part 22 (Community moderation completeness)
- Part 26 (Audit log coverage — which actions are/aren't logged,
  beyond the two call sites confirmed in Part 6/20)
- Part 27 (systematic emoji/hardcoded-color scan across all 80 screens
  — spot-checked several files during this session's own prior work,
  not re-scanned exhaustively this pass)
- Part 29 (dead code / orphaned files across all 174 files)
- Part 30 (performance — unbounded reads, missing pagination) beyond
  what Part 6 already found and fixed

---

## PART 34 — FINDINGS, CLASSIFIED

| # | Finding | Class | Evidence |
|---|---|---|---|
| CBT-A | Two disconnected exam catalogs (board vs. generic CBT type) | **P1** | Part 7 |
| CBT-B | WAEC/NECO/JAMB exams always run in `ExamMode.practice`; official timing never activates | **P1** | Part 7, exact file:line cited |
| QT-1 | 9 of 14 question types have no authoring or runner UI | **P1** | Part 13 |
| ALLOC-1 | No exam allocation architecture (institution/dept/level/course targeting) | **P1** | Part 14 |
| PREM-1 | Premium exam gating is display-only, not enforced | **P1** | Part 19 |
| SEC-A | Full user profile (incl. email, roles, suspension) readable by any signed-in user | **P2** | Part 25 |
| INST-1 | No Federal/State/Private or location filter on institution browse | **P2** | Part 5 |
| HIST-1 | Reported exam-history "blinking" not reproduced by static review — needs runtime trace | **P2 (unresolved, not dismissed)** | Part 16 |
| DUP-1 | `ExamHistoryScreen`/`MyAttemptsScreen` near-duplicate structure | **P3** | Part 28 |
| SEC-B | `payment_methods` publicly readable (likely intentional) | **P3** | Part 25 |

---

## PART 35 — PROPOSED ROADMAP (dependency order, not convenience)

**Stage A — Exam mode routing (small, unblocks the rest of CBT-A/B).**
Give `BoardExamSelectionScreen`/`SubjectCombinationSelectionScreen` a
way to pass `mode` through to `ExamListScreen`, sourced from
`ExamModel.supportedModes` rather than always defaulting to practice.
No new model/repository — extends fields that already exist.

**Stage B — Decide and implement the catalog question (CBT-A).**
This is a product decision first, an engineering task second: either
merge board exams into the CBT Center's browsing surface (one funnel,
filterable by board), or keep them separate but make that separation
visible/intentional in the UI rather than implicit. Either path reuses
the existing `ExamListScreen`/`ExamRunnerScreen` — no new engine.

**Stage C — Exam allocation (ALLOC-1).** Add a targeting field to
`ExamModel` (institution/department/level/course, nullable = global,
matching how `subjectId`/`courseId` already work elsewhere) and a
query-time filter in `ExamListScreen`. Real new architecture, but
small and additive.

**Stage D — Premium enforcement (PREM-1).** Gate `_startExam` on
`ExamModel.isPremium` against the user's actual entitlement — the
entitlement data model needs auditing first (not confirmed this pass
where a user's "is premium" status is actually stored).

**Stage E — Question types (QT-1).** The largest single effort here;
plan as N independent slices (one per question type), each touching
`ExamEditorScreen`'s authoring UI, `ExamRunnerScreen`'s rendering, and
`ExamScoring`'s grading logic for that type only.

**Stage F — Exam History runtime investigation (HIST-1).** Reproduce
with logging before writing any fix — static review found no bug to
fix.

**Stage G — Security rule review (SEC-A).** Confirm intent, then
either scope `users/{userId}` read down to a public-subset document or
accept the current breadth explicitly.

**Stage H — Institution filters (INST-1)**, **Stage I — Proctoring**,
**Stage J — Offline sync** — all confirmed-real gaps, none blocking
the stages above, ordered last as the brief's own example ordering
suggests for genuinely new (not reconnection) work.
