# Stage CBT-Refactor Phase 5 — JAMB Selection & Subject-Combination Flow

## Part 1 — Audit findings

- **`ExamModel.subjectId`** is singular (`String?`), not a list — each
  exam targets one subject. **`ExamRepository.watchByTypeWithFilters`**
  already accepts a `subjectIds` **list** parameter (confirmed from the
  Phase 4 changelog, not assumed) — a real server-side `whereIn` query,
  already exactly what a multi-subject combination needs to filter
  exams by. No second subject-to-exam relationship was created.
- **`BoardExamSelectionScreen`** (Year → Subject(s) → Paper) is
  WAEC/NECO-shaped: JAMB has no "paper" concept and needs a
  compulsory-subject-lock + exact-count validation, which is a
  genuinely different UX/logic shape, not a filter variation on the
  same shape. Extending it with mode-branches would fork nearly the
  entire widget body. Built a sibling screen instead — same reuse
  philosophy as Phase 3/4 (generic over category, built once,
  anticipating reuse), not a JAMB-only screen.
- **`SubjectRepository.watchByCategory('jamb')`** already returns real
  JAMB subject data (`CourseModel`) — the same subjects
  `SubjectBrowseScreen`/`SubjectManagerScreen` already use. No new
  subject data path.
- **No existing concept of a "valid subject combination" anywhere** —
  confirmed via grep for `combination`/`categoryId`-adjacent config
  before writing anything. `CourseModel` has no compulsory flag; no
  config document held a required count. Per Part 5's explicit
  permission, one new small abstraction was designed rather than
  embedding the logic in a screen (see `CombinationRuleModel` below).
- **`jamb_dashboard_screen.dart`**'s "CBT" and "Mock Exams" tiles
  pushed `ExamListScreen` directly — the exact pre-Phase-4 pattern
  WAEC/NECO had before their own selection screens were wired in.
  These were the two entry points redirected.
- **`subjects` collection**'s Firestore rule (`read: true`, `write:
  isStaff()`) was mirrored exactly for the new collection rather than
  inventing a different access policy.
- **`AuditModules.examPrep`** already covers WAEC/NECO/JAMB subject
  administration (used in `subject_manager_screen.dart` before this
  phase) — reused as-is; no new audit module added.

## Part 2/3/4 — Selection flow & UX

**`lib/features/exam_prep/subject_combination_selection_screen.dart`**
(new) — `SubjectCombinationSelectionScreen`, generic over
`ExamType`/`categoryId` (not JAMB-only, matching
`BoardExamSelectionScreen`'s own precedent):
- Compulsory subject (from `CombinationRuleModel`) shown locked and
  pre-selected, exactly per the brief ("English is automatically
  selected and locked").
- "Selected: X / N" counter, live, including the locked subject in the
  count.
- Further selection disabled once at the required count (`Opacity` +
  `onTap: null` on remaining chips) — prevents over-selection at the
  UI layer, in addition to (not instead of) the independent validator.
- New `_SearchableSubjectGrid` widget — search field + selected-subject
  summary chips with one-tap removal + the filtered chip grid. Built
  new because audit found no existing searchable-multiselect-with-
  summary component (`BoardExamSelectionScreen`'s subject step is a
  bare `Wrap`, adequate for WAEC/NECO's shorter lists but explicitly
  insufficient for JAMB's "There may be many JAMB subjects").
- Handles empty subjects, loading, and error states via the existing
  `LoadingView`/`ErrorView`/`EmptyView` — no new state-view components.

## Part 5 — Validation

**`lib/core/utils/subject_combination_validator.dart`** (new) —
`SubjectCombinationValidator.validate()`, a pure static method, plus
`SubjectCombinationStatus` (`incomplete`/`valid`/`invalid`). Not a bare
count check: `invalid` also covers a rule with a compulsory subject
missing from the selection (defensive — the UI should never let this
happen, but the check doesn't rely on the UI being correct). Not
embedded in the screen, callable/testable independently, per the
brief's explicit instruction.

**Explicitly not done**: real UTME combination-eligibility rules (e.g.
Science-track requiring Physics/Chemistry/Biology). Audit found no such
data anywhere, and the brief explicitly warns "Do not invent fake JAMB
combinations." This phase validates count + compulsory-subject
presence only — a future phase would need real admin-supplied
combination-eligibility data before this could go further, and that
data doesn't exist yet.

## Part 6 — Exam resource allocation

No new relationship introduced. `_viewExams()` passes the full
selected subject-id set (compulsory + chosen) straight into the
existing `ExamListScreen(subjectIds: ...)`, which already resolves
through `ExamRepository.watchByTypeWithFilters` — unchanged from how
`BoardExamSelectionScreen` already hands off to the same screen.

## Part 7 — Admin control

**`lib/models/combination_rule_model.dart`** (new) —
`CombinationRuleModel`: `categoryId` (doc id, same string
`SubjectRepository.watchByCategory` uses), `compulsorySubjectId`
(nullable), `requiredSubjectCount` (defaults to 4 — the real UTME
standard, as an *admin-overridable starting point*, not hardcoded
logic in a screen).

**`lib/repositories/combination_rule_repository.dart`** (new) —
`CombinationRuleRepository extends BaseRepository<CombinationRuleModel>`
(doc id = categoryId, so every category shares the same CRUD shape
every other collection here uses). `watchForCategory()` never returns
null — an unconfigured category gets the model's own default rather
than every caller special-casing "no rule yet." `setCompulsorySubject()`
is audit-logged via the existing `AuditLogService.log()`
(`AuditModules.examPrep`, reused).

**`lib/features/admin/exam_prep/subject_manager_screen.dart`**
(modified) — added a "Combination Rule" control directly in the
existing subject-management screen (not a disconnected new admin
system, per the brief): a summary line ("Compulsory: X · Required: N")
plus a dialog to set both, and a "Compulsory" badge on the relevant
subject's card in the list. Reuses this screen because it's exactly
where a category's subjects already live — the same place an admin
would naturally look to configure which of those subjects is
compulsory.

**Mid-build correction**: a large edit to this file initially left a
duplicated trailing code fragment (leftover lines from the
pre-edit version of the widget tree) and referenced a `_findTitle`
helper that hadn't actually been added yet. Caught both via a full
top-to-bottom re-view of the file rather than trusting the edit had
landed cleanly — removed the duplicate, added the missing helper,
re-verified brace/paren balance and re-read the whole file before
treating it as done.

## Part 8/9 — Existing engine & back navigation

Zero changes to `ExamRunnerScreen`, `ExamResultScreen`,
`ExamHistoryScreen`, `PerformanceAnalyticsScreen`, scoring, timer,
autosave, or attempt tracking — `SubjectCombinationSelectionScreen`
only decides what `ExamListScreen` is asked to show, exactly like
`BoardExamSelectionScreen` already does for WAEC/NECO. Back navigation
uses plain `Navigator.push`/back, same as every other screen in this
flow — no custom stack manipulation, so a student backing out of
`ExamListScreen` returns to the selection screen with `_selectedSubjectIds`
still intact (it's `State` on the still-alive widget below), and
backing out further returns to the JAMB dashboard with no special
handling needed.

## Part 10 — Error/empty states

- No subjects configured → `EmptyView`.
- Search returns nothing → inline "No subjects match your search."
  text (not a full-screen empty state, since the compulsory chip and
  selected-summary above the search box should stay visible).
- Incomplete combination → button disabled + "Select N more
  subject(s) to continue" hint.
- Rule/subject stream failure → `ErrorView`.
- The brief's remaining listed cases (network failure, unauthenticated,
  exam unavailable/expired, attempt limits, premium exams) are all
  already handled inside `ExamListScreen`/`ExamRunnerScreen`, which
  this phase hands off to unchanged — not re-implemented here.

## Part 12 — Verification performed

- Brace/paren balance check on every new/modified file (all passed).
- Full diff against the original Phase 4 upload: exactly 4 files
  modified (`firestore.rules`, `app_constants.dart`,
  `subject_manager_screen.dart`, `jamb_dashboard_screen.dart`), 4 files
  created, nothing else touched anywhere in the project.
- Grepped `waec_dashboard_screen.dart`/`neco_dashboard_screen.dart` —
  confirmed present and, per the diff above, byte-for-byte unchanged.
- Emoji scan (Python unicode-range scan across every new/modified
  file) — none found.
- Hardcoded-color scan (`Color(0x...)`) across new files — none;
  colors are threaded through as `accent`/`AppColors.*` params.
- Confirmed `ExamListScreen`'s `subjectIds`/`year`/`paper` are all
  optional (defaults null) before relying on the 2-arg call this phase
  makes.
- Confirmed `AppChip`, `PrimaryButton`, `AppTextField` (`keyboardType`,
  `validator`), and `DropdownButtonFormField`'s param name (`value:`,
  not `initialValue:` — checked an existing call site rather than
  assuming Flutter SDK version) all match this exact branch's actual
  source before using them.
- Caught and fixed one real mistake before it shipped: used
  `.firstOrNull` initially, which a prior stage's own comment in this
  codebase (`bulk_question_upload_screen.dart`) confirms isn't
  available (no `collection` package dependency) — replaced with a
  manual loop lookup in both places it was used.
- No Flutter SDK available in this environment — everything above is
  static/source verification, not an executed run.

## Known limitations / future phases

- Real combination-eligibility data (which subject sets are valid
  together beyond "compulsory + count") doesn't exist and wasn't
  invented — count + compulsory-presence validation only.
- `ExamEditorScreen` still sets `subjectId` as free text (same
  limitation Phase 3/4 already documented) — an admin still can't pick
  a JAMB exam's subject from a list.
- No UI indicates to a student *why* an exam didn't appear (e.g. "no
  Physics exam exists yet") beyond `ExamListScreen`'s own empty state.

## STOP

Per the phase brief: stopping after Phase 5. Not starting Institutional
CBT, result-policy refactoring, role-permission architecture, admin
search/filter improvements, proctoring, offline sync, or subscription
enforcement.
