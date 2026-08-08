# Stage 4.8B — Unified CBT Engine — Part 1: Question Palette & Navigation, and full spec audit

## Why this is scoped as "Part 1"

The uploaded spec ("Stage 4.8A + 4.8B — Full Production-Grade CBT
Engine") covers 25 major subsystems — question rendering for 24
question types, offline-first sync, admin exam configuration, premium
gating, proctoring-ready hooks, and more. That's multiple weeks of real
engineering, not one build pass. Per the spec's own "AUDIT FIRST" rule,
this part starts with a full gap audit against all 25 sections, then
implements the one contained, high-value gap that was both genuinely
missing and buildable without new dependencies: **Section 5 (Question
Navigation)**'s palette. Everything else is left as an honest, itemized
backlog below rather than attempted shallowly.

## Audit: spec sections 1–25 vs. what already exists

| # | Section | Status | Where |
|---|---|---|---|
| 1 | CBT Engine architecture (UI/domain/data separation) | ✅ Done | `exam_scoring.dart` (pure logic), `ExamSessionRepository`/`ExamAttemptRepository`, `ExamRunnerScreen` (UI) — already separated per Stage 4.8A |
| 2 | Exam types/modes | ⚠️ Partial | `ExamMode` enum (official/practice/mock) exists; session creation is hardcoded to `practice` — no mode picker UI yet |
| 3 | Question types (24 types) | ⚠️ Partial | `QuestionType` enum has all 14 from the original 4.8A/4.8B spec; only 5 have working answer-entry UI (single/multi-choice, true/false, fill-blank, short-answer). Matching, ordering, passage, diagram, table, math-notation, case-study, long-answer, novel-based decode via `typeData` but have no input UI or scorer |
| 4 | Question rendering (rich text/images/tables/media) | ❌ Missing | Questions render as plain text only; no image/table/passage rendering |
| 5 | Question navigation | ✅ **Done this part** | Palette (grid + strip), flag, jump, First/Last — see below |
| 6 | Timer system | ✅ Mostly done | Hard countdown + auto-submit for official/mock, elapsed count-up for practice (Stage 4.8C). Gap: countdown is client-persisted (`remainingSeconds` autosaved every 10s), not derived from an authoritative server timestamp — spec explicitly warns against relying solely on client countdown for official exams |
| 7 | Session control | ✅ Mostly done | Session id, resume, autosave, submission locking via `ExamSessionStatus`. Gap: no explicit "prevent duplicate submission" race-condition guard beyond status check |
| 8 | Answer auto-save | ✅ Done | Every answer/flag/bookmark/navigation change autosaves via `ExamSessionRepository.autoSave` |
| 9 | Offline-first support | ❌ Missing | `SyncStatus` field exists on both models (Stage 4.8A prepared the contract) but no local write queue, connectivity listener, or replay-on-reconnect engine exists |
| 10 | Calculator | ✅ Done | Basic + scientific, gated by `ExamModel.calculatorType` (Stage 4.8C) |
| 11 | Navigation rules (admin-configured back/skip/flag/review) | ❌ Missing | No `ExamModel` fields for these rules yet, no enforcement |
| 12 | Question randomization | ✅ Done | `shuffleQuestions`/`shuffleOptions`, computed once per session (Stage 4.8A/4.8C) |
| 13 | Marking system | ✅ Done | `exam_scoring.dart` — negative marking, per-question points, pass/fail |
| 14 | Results system | ✅ Mostly done | `ExamResultScreen` shows score/pass-fail/breakdown. Gap: no admin-controlled "hide results until released" — results always show immediately |
| 15 | Review system | ❌ Missing | No post-submission answer review screen (correct vs. student answer, explanation, retry) |
| 16 | Performance analytics | ❌ Missing | `ExamAttemptModel.topicBreakdown` captures the data (Stage 4.8A prepared it); no screen aggregates/displays it |
| 17 | Student exam history | ❌ Missing | `ExamAttemptRepository.watchHistoryForUser` exists; no history screen calls it |
| 18 | Admin exam configuration | ❌ Missing | No admin UI to create/edit an `ExamModel`'s settings at all — only `subject_manager_screen.dart` (manages Subjects, not Exams) exists under `lib/features/admin/exam_prep/` |
| 19 | Premium-ready architecture | ⚠️ Partial | `ExamModel.isPremium` field exists; nothing checks it before allowing a session to start |
| 20 | Access control | ✅ Reused | Existing `UserRole`/`AuthService` — nothing new needed, correctly not duplicated |
| 21 | Exam availability (draft/scheduled/active/paused/archived) | ❌ Missing | `ExamModel` has `isActive` (bool) and `availableFrom`/`availableUntil`, but no full status enum; a paused/archived/draft exam isn't distinguishable from an active one today |
| 22 | Interruption/recovery | ✅ Done | Session resume via `findResumableSession`, `PopScope` autosave-on-exit |
| 23 | Accessibility (theme contrast, touch targets) | ✅ Followed | All new palette UI reads colors from `Theme.of(context)`/`AppColors`, no hardcoded light-only colors |
| 24 | Proctoring-ready architecture | ⚠️ Partial | `ExamModel.proctoringEnabled` field exists (Stage 4.8A); no event-logging model/hooks reserved yet |
| 25 | Institutional remote exam ready | ❌ Missing | Depends on #18 (admin config) and #24 (proctoring hooks) existing first |

**Bottom line:** the engine's *foundation* (sections 1, 5–8, 10, 12, 13,
20, 22, 23) is solid. The *content breadth* (3, 4) and *admin/ops
surface* (2, 9, 11, 14 gating, 15–19, 21, 24, 25) are the real remaining
work — none of it is a quick add-on to this part.

## What this part adds

**`lib/models/exam_session_model.dart`**
- `ExamSessionModel.visitedQuestionIds` (`List<String>`, additive,
  defaults to `[]`) — every question index opened at least once,
  independent of whether it was answered. Powers the palette's
  "visited but unanswered" state, which the spec's navigation section
  calls out as distinct from "never opened." Decodes safely on every
  session written before this part.

**`lib/features/exam_prep/exam_runner_screen.dart`**
- `_markVisited` — called on session load and every `_jumpTo`, so
  visited state tracks accurately through resume too.
- New palette icon in the app bar opens `_QuestionPaletteSheet` — a
  full grid (not just a horizontal strip) with a legend
  (Current/Answered/Flagged/Visited/Unvisited), First/Last jump
  buttons, and an answered-count header. Built specifically because the
  existing horizontal strip doesn't scan well for a 60–250 question
  JAMB/WAEC-length exam — the spec's "professional CBT navigation"
  requirement needs something a student can scan at a glance.
- `_QuestionNavigator` (the horizontal strip) also now reads
  `visitedQuestionIds` for a 4th distinguishable state, rather than the
  grid and strip disagreeing about what "visited" means.
- All new colors come from `AppColors`/`Theme.of(context)` — verified
  against both Light and Dark theme, per the spec's explicit contrast
  requirement.

## Also fixed this pass

**`.gitignore`** — was missing from the project entirely (confirmed
absent in every snapshot audited across this whole engagement, not
introduced this part). Added the standard Flutter set — `.dart_tool/`,
`build/`, `android/local.properties`, `android/key.properties`,
`ios/Pods/`, `ios/Flutter/Generated.xcconfig`, platform `ephemeral/`
folders, etc. — so a first `git add .` doesn't commit machine-specific
or regeneratable files. This was a blocker for a clean GitHub push,
independent of the CBT engine work.

## Deliberately still not here (see audit table for the full picture)

The nine question types without input UI, the offline sync engine,
admin exam configuration screens, results-visibility gating, the
review/retry screen, performance analytics/history screens, exam
availability states beyond `isActive`, and proctoring event logging are
all real, separate slices of work — attempting any of them shallowly in
this part would produce something that looks done in a file listing but
doesn't actually work end-to-end. Recommended order for the next parts,
given what each depends on:

1. **Admin exam configuration UI** (#18) — nothing else in the "ops"
   half of the spec is testable without a way to create an `ExamModel`
   through the app instead of hand-writing Firestore documents.
2. **Review/retry screen** (#15) + **results visibility gating** (#14)
   — small, self-contained, high student-facing value, builds directly
   on data `ExamAttemptModel` already has.
3. **Remaining question-type UI** (#3/#4) — biggest single chunk of
   work; can be done type-by-type without touching the runner's
   navigation/timer/scoring shell built so far.
4. **Offline sync engine** (#9) — the `SyncStatus` contract is ready;
   this is genuinely new infrastructure (local queue, connectivity
   listener) rather than an extension of existing files.
5. **Proctoring event hooks** (#24) and **institutional remote exam**
   (#25) — explicitly spec'd as reserve-the-architecture-only for now;
   lowest priority until an actual proctoring requirement exists.
