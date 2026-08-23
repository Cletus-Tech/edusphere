# Stage CBT-Refactor Phase 4 — NECO Examination Selection Flow

## What changed
`NecoDashboardScreen`'s two direct entry points (`Mock Exams`, `CBT` tiles) —
previously `Navigator.push(... ExamListScreen(examTypeId: ExamType.neco.id, ...))`
— now push `BoardExamSelectionScreen(examType: ExamType.neco, title: 'NECO',
accent: AppColors.accentGreen)` instead: the exact same Year → Subject(s) → Paper
→ Available Exams flow WAEC already uses.

`accent: AppColors.accentGreen` reuses this same file's own existing "Mock Exams"
tile accent, rather than inventing a new NECO identity color.

## Files modified
- `lib/features/neco/neco_dashboard_screen.dart` — swapped import
  (`exam_list_screen.dart` → `board_exam_selection_screen.dart`, since after the
  swap `ExamListScreen` is no longer referenced anywhere in this file) and both
  call sites, per above.

## Files created
None. Per the phase's own rule 6 ("Do NOT create a second
`BoardExamSelectionScreen`") and rule 3 ("Do NOT copy the WAEC selector") —
this phase is a wiring change only.

## Files reused (unmodified)
`BoardExamSelectionScreen`, `ExamRepository.watchByTypeWithFilters`,
`ExamListScreen`, `ExamRunnerScreen`, `ExamResultScreen`, `SubjectRepository`,
`ExamModel.year`/`.paper`/`.subjectId`.

## Repository/query behavior (verified, not assumed)
`BoardExamSelectionScreen` calls `SubjectRepository().watchByCategory(widget.examType.id)`.
Confirmed `ExamType.id => name`, so `ExamType.neco.id == 'neco'` — the exact
`categoryId` value `SubjectBrowseScreen` already uses for NECO subjects (Stage
4.6's own doc comment: `categoryId: 'neco'`). Same subject documents, no new
data path.

Exam list filtering goes through `ExamRepository.watchByTypeWithFilters(typeId:
'neco', year:, paper:, subjectIds:)` — real server-side Firestore `.where()`
clauses (`type`, `isActive`, and conditionally `year`/`paper`/`subjectId
whereIn`), not a client-side filter over every exam. Because the first filter is
always `type == 'neco'`, a WAEC exam (`type == 'waec'`) cannot appear in NECO's
result set regardless of year/subject/paper overlap — the type filter alone
rules out cross-board leakage before the optional filters are even applied.

## Data-flow trace (static, matching the required scenario)
NECO Dashboard → `BoardExamSelectionScreen(examType: neco)` → year chips (from
real `ExamModel.year` values where `type == neco`) → subject chips (from
`categoryId: 'neco'` subjects) → paper chips (from matching exams' `.paper`
values) → `ExamListScreen(examTypeId: 'neco', subjectIds:, year:, paper:)` →
`ExamRepository.watchByTypeWithFilters` → selected exam → existing
`ExamRunnerScreen` (session/timer/scoring untouched) → existing
`ExamResultScreen`.

## Missing-metadata behavior (documented, not invented)
`BoardExamSelectionScreen`'s year list is derived from `allExams.map((e) =>
e.year).whereType<int>()` — a NECO exam with no `year` set is simply excluded
from every year bucket (it was never counted, so nothing was "removed"). This
is pre-existing `BoardExamSelectionScreen` behavior from Phase 3, unchanged by
this phase — flagging per the phase's instruction not to invent undocumented
fallback logic. Practically: an admin-created NECO exam without a year/paper
configured won't surface through this selection flow at all; it remains
reachable only if some other entry point queries it directly (none currently
does for NECO, now that both dashboard tiles route through the selector).

## WAEC regression check
`grep` confirmed both `WaecDashboardScreen` call sites still read
`examType: ExamType.waec` unchanged — zero lines in that file were touched.

## Security considerations
Firestore rules were not touched. The `type` field is still the first clause in
every exam query (`watchByType` and `watchByTypeWithFilters` both start with
`.where('type', isEqualTo: typeId)`), so this phase doesn't introduce a new way
for one board's exams to leak into another's list.

## Static verification performed
- Brace/paren balance check on the modified file (matched).
- Grep for leftover `ExamListScreen` references in the file (none).
- Grep for `BoardExamSelectionScreen` call sites app-wide (4 total: 2 WAEC
  unchanged, 2 NECO new).
- Emoji scan (Python unicode-range scan — none).
- Hardcoded-color scan (`Color(0x...)` — none; `AppColors.accentGreen` reused).
- Confirmed `ExamType.neco.id` resolves to `'neco'`, matching the subject
  `categoryId` convention already in use.

## Not runtime-tested
No Flutter toolchain available in this environment — everything above is
static/source verification, not an executed run.

## Known limitations
Same as Phase 3's own documented limitation, unchanged: `ExamEditorScreen`
still sets `subjectId`/`year`/`paper` as free-text fields, so an admin must
type the exact subject ID rather than pick from a list — Phase 9 (Admin
Allocation) work, not part of this phase.
