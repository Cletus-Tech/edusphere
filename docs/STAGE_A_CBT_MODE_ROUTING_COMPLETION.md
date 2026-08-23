# Stage A — CBT Mode Routing & Exam Catalog Integrity — Completion Report

## 1. Confirmed original problem

`BoardExamSelectionScreen` and `SubjectCombinationSelectionScreen` had
**no `mode` parameter at all**. Every call site — WAEC's "CBT" tile,
WAEC's "Mock Exams" tile, NECO's "CBT" tile, NECO's "Mock Exams" tile,
JAMB's "CBT" tile, JAMB's "Mock Exams" tile — constructed the screen
identically and handed off to `ExamListScreen` without a `mode`
argument, which defaults to `ExamMode.practice`
(`exam_list_screen.dart:70`).

**Worse than the audit's original description**: it wasn't just that
mode was *lost in transit* — for each board, the "CBT" tile and the
"Mock Exams" tile called the exact same screen with the exact same
parameters. Two differently-labeled entry points were, before this
fix, functionally identical: same screen, same exam type, same
(absent) mode. A student tapping "CBT" (intending an official exam)
and a student tapping "Mock Exams" landed in the identical selection
flow and, downstream, the identical `ExamMode.practice` session — no
hard timer, no auto-submit, regardless of which tile they chose or
what the admin configured on that specific exam's `supportedModes`.

Root cause confirmed by direct trace, not inference:
`exam_runner_screen.dart:157` (`remainingSeconds: mode ==
ExamMode.practice ? null : ...`) and `:389` (`isTimed = session.mode
!= ExamMode.practice`) — the runner genuinely behaves differently by
mode; the bug was entirely that board flows never told it anything
but the default.

## 2. Files modified

| File | Change | Why |
|---|---|---|
| `lib/features/exam_prep/board_exam_selection_screen.dart` | Added `required ExamMode mode` field; threaded to the existing `ExamListScreen(...)` call in `_viewExams()`. | The confirmed defect's source. Made `mode` required (not defaulted) so no future call site can silently repeat this bug — every caller must now state its intent. |
| `lib/features/exam_prep/subject_combination_selection_screen.dart` | Same fix, same reasoning — JAMB's sibling screen had the identical gap. |
| `lib/features/waec/waec_dashboard_screen.dart` | "Mock Exams" tile now passes `mode: ExamMode.mock`; "CBT" tile now passes `mode: ExamMode.official`. | These two tiles were the only two `BoardExamSelectionScreen` call sites for WAEC; each now states the intent its own label already promised. |
| `lib/features/neco/neco_dashboard_screen.dart` | Same two-tile fix as WAEC. |
| `lib/features/jamb/jamb_dashboard_screen.dart` | JAMB's "CBT" tile → `mode: ExamMode.official`; "Mock Exams" tile → `mode: ExamMode.mock` (both on `SubjectCombinationSelectionScreen`). JAMB's third exam-related tile, "Practice," was inspected and confirmed to route to `_openSubjects(section: CourseSection.practiceQuestions)` — content browsing, not the CBT engine — correctly left untouched. |

No other file needed modification. The CBT Center (`cbt_screen.dart`)
was inspected and confirmed already correct (see §5) — not touched.
The University/Post-UTME entry point was inspected and confirmed
already correct as-is (see §5) — not touched. `exam_review_screen.dart`'s
retry-incorrect flow was inspected and confirmed to intentionally omit
`mode` (defaults to practice, correct for a retry session) — not
touched.

## 3. Files created

**None.**

## 4. Existing systems reused

`ExamMode`, `ExamType` (`content_type.dart`) · `ExamModel.supportedModes`
(untouched, its existing guard in `exam_list_screen.dart`'s
`_startExam` was not modified — it now simply receives real intent
instead of always receiving the default) · `ExamListScreen`,
`ExamRunnerScreen` (both untouched — the fix is entirely in what's
*passed to* them, not in either screen) · `ExamRepository.watchByType`/
`watchByTypeWithFilters` · every existing selection-flow widget
(`AppChip`, `PrimaryButton`, `LoadingView`/`ErrorView`/`EmptyView`) —
zero new widgets, zero new colors, zero new icons.

## 5. Routing matrix (post-fix, confirmed by direct trace of every call site)

| Flow | Exam type | Mode passed | Confirmed at |
|---|---|---|---|
| WAEC → CBT | `waec` | `ExamMode.official` | `waec_dashboard_screen.dart` (this fix) |
| WAEC → Mock Exams | `waec` | `ExamMode.mock` | `waec_dashboard_screen.dart` (this fix) |
| NECO → CBT | `neco` | `ExamMode.official` | `neco_dashboard_screen.dart` (this fix) |
| NECO → Mock Exams | `neco` | `ExamMode.mock` | `neco_dashboard_screen.dart` (this fix) |
| JAMB → CBT | `jamb` | `ExamMode.official` | `jamb_dashboard_screen.dart` (this fix) |
| JAMB → Mock Exams | `jamb` | `ExamMode.mock` | `jamb_dashboard_screen.dart` (this fix) |
| Institutional/Post-UTME | `postUtme` | `ExamMode.practice` (default, unchanged) | `university_dashboard_screen.dart:64` — labeled "Post-UTME Practice" in its own title string; this is the *only* Post-UTME CBT entry point that exists. No official Post-UTME flow exists yet — genuine scope gap, not a routing defect (see §7). |
| CBT Center → Official Exams | `cbt` | `ExamMode.official` | `cbt_screen.dart:109` (pre-existing, verified not broken) |
| CBT Center → Practice | `practiceTest` | `ExamMode.practice` (default) | `cbt_screen.dart:122` (pre-existing, verified not broken) |
| CBT Center → Mock Exams | `mockExam` | `ExamMode.mock` | `cbt_screen.dart:140` (pre-existing, verified not broken) |

Every `ExamListScreen(...)` call site in the project (8 total) and
every `ExamRunnerScreen(...)` call site (3 total, including the
class's own constructor) was individually enumerated and accounted
for above — none were missed, none left ambiguous.

## 6. Regression checks performed

- **Brace/paren balance**: 0 imbalanced files, whole project.
- **Import resolution**: 0 unresolved local imports, whole project.
- **Duplicate class search**: only private (`_`-prefixed), file-scoped
  classes repeat (`_DashboardTile`, `_RecentActivity`, etc.) — expected
  Dart behavior, not a collision; no duplicate `ExamListScreen`,
  `ExamRunnerScreen`, `ExamModel`, or CBT repository found anywhere.
- **`supportedModes` regression check**: confirmed both the
  constructor default and the Firestore-read fallback
  (`exam_model.dart:106,139-141`) default to *all three* modes — every
  pre-existing exam document (created before this field existed, or
  with the field empty) continues to work exactly as before. Only an
  exam an admin has *explicitly* restricted will now correctly enforce
  that restriction — this fix cannot newly block any exam that wasn't
  already configured to be restricted.
- **Emoji scan**: zero emoji in any of the 5 touched files (automated
  scan, not eyeballed).
- **Hardcoded-color scan**: the only lines added to any touched file
  are `mode: ExamMode.official`/`.mock` — no color, no icon, no string
  literal beyond the enum reference.
- **Question scoring regression (Part 10)**: not touched by this
  stage — `exam_scoring.dart` was not modified, and this fix only
  affects which `ExamMode` a session is *created* with, not how
  answers are graded once submitted. No scoring-path code was edited.
- **History/result chain (Part 11)**: not touched — `ExamAttemptModel`,
  `ExamResultScreen`, `ExamHistoryScreen`, `MyAttemptsScreen` were not
  modified. One *consequence* worth flagging, not a regression this
  stage caused: WAEC/NECO/JAMB attempts taken from today onward will
  now correctly carry `mode: official` or `mode: mock` in their stored
  `ExamAttemptModel`, whereas every attempt taken before this fix was
  shipped is permanently stored as `mode: practice` — `My Attempts`'
  mode chip will accurately reflect intent going forward, but will not
  retroactively relabel historical attempts. No data migration was
  performed or requested by this stage's scope.

## 7. Remaining issues — deferred, not solved here

- **Two disconnected exam catalogs** (`ExamType.waec/neco/jamb` vs.
  `ExamType.cbt/practiceTest/mockExam`) — explicitly out of scope per
  this stage's Part 9 instruction ("do NOT merge them during this
  stage"). Documented, not touched.
- **No official Post-UTME/Institutional entry point exists at all** —
  confirmed during this stage's routing trace (§5), not previously
  documented this precisely. The one Post-UTME entry point that exists
  is correctly practice-mode already; there's simply no second,
  official-mode entry point to fix. This is new-feature scope
  (building an entry point that doesn't exist), not a routing defect
  within this stage's mandate.
- **Exam allocation** (institution/department/level targeting) — no
  architecture found, per the original audit; unchanged by this stage.
- **Premium enforcement** — still display-only; unchanged by this
  stage.
- **9 of 14 question types still have no authoring/runner UI** —
  unchanged, out of scope.
- **Historical `mode: practice` attempts won't retroactively relabel**
  — noted in §6, no migration performed (out of this stage's scope;
  Part 15 of the original audit brief covers result/history changes,
  not this one).

## 8. Next recommended stage

Per the original audit's roadmap, **Stage B — the catalog-unification
product decision** (Finding CBT-A) is next in dependency order — it's
a decision, not just engineering, so it may be worth resolving before
further CBT engineering compounds on top of two catalogs. Alternatively,
if catalog unification is deferred further, **building the missing
official Post-UTME entry point** (confirmed absent in §5/§7) is a
small, self-contained slice that doesn't depend on resolving the
catalog question first.

**Not proceeding to Stage B or any other stage automatically, per the
brief's stop condition. Waiting for approval.**

---

## Runtime verification note (per Part 15's instruction)

No Flutter/Dart toolchain is available in this environment. **Static
verification only was performed and is reported above as such — this
report does not and cannot claim `flutter analyze`, `flutter test`, or
a successful build.** Runtime Flutter compilation and on-device
verification remain required before this fix ships.

---

## Addendum — 2 pre-existing bugs caught by real CI, missed by static review

Runtime verification (§ above) explicitly flagged that this report's
static checks could not substitute for an actual compiler. That
caveat turned out to matter: GitHub Actions' `flutter build apk
--release` failed on push, and correctly caught **two pre-existing
bugs** neither this report's checks nor the earlier system-wide audit
found — both were in files this stage touched, but neither was
introduced by this stage's edit (confirmed by checking that this
stage's diff only added `mode:` arguments, never touched the affected
lines/imports).

1. **`AppColors.accentTeal` — never defined.** Used twice in
   `waec_dashboard_screen.dart` (`BoardExamSelectionScreen`'s
   `accent:` argument, both WAEC's Mock Exams and CBT tiles). The
   actual palette (`app_colors.dart`) only defines `primaryBlue`,
   `secondaryIndigo`, `accentGreen`, `highlightOrange`. Fixed by using
   `AppColors.accentGreen` — WAEC's own established first-tile accent
   in this same file, not a new color.

2. **Missing import in `subject_combination_selection_screen.dart`.**
   `SubjectRepository` is defined in `course_repository.dart`, but
   this file only imported `learning_repository.dart`. Its sibling
   `board_exam_selection_screen.dart` correctly imports both. Fixed by
   adding the missing import line.

**Why static review missed both**: this environment has no Flutter/
Dart SDK, so "static verification" here meant regex-based checks
(brace/paren balance, import-path-exists, duplicate-class-name scan)
— none of which can catch "this identifier isn't actually defined" or
"this symbol was used without being imported," since both require
real symbol resolution, not text pattern matching.

**What was done about it**: built two new targeted heuristic scripts
after seeing the real compiler's output, specifically shaped to catch
these two exact bug classes project-wide (not just in the two flagged
files):
- A "class used but not imported" scanner (maps every top-level class
  to its defining file, then checks every file's usages against what
  its own imports actually make available) — **0 further instances**
  found project-wide.
- An "undefined static member" scanner for `AppColors`/`AppTextStyles`/
  `AppConstants`/etc. (first pass had a regex bug that missed
  arrow-function-style static methods, producing 326 false positives;
  corrected and re-run) — **0 further instances** found project-wide.

Both scanners are heuristic, not a real compiler — they reduce the
odds of this exact failure mode recurring but don't replace `flutter
analyze`/`flutter build`. That distinction is stated here plainly
rather than implied away.

## Files modified (revised)

Adding to the original files-modified table:

| File | Change | Why |
|---|---|---|
| `lib/features/waec/waec_dashboard_screen.dart` | `AppColors.accentTeal` → `AppColors.accentGreen` (2 occurrences) | Pre-existing undefined member, caught by CI |
| `lib/features/exam_prep/subject_combination_selection_screen.dart` | Added missing `import '../../repositories/course_repository.dart';` | Pre-existing missing import, caught by CI |
