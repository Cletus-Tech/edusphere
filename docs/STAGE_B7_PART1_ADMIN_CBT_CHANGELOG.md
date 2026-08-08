# Stage B7 — Admin & CBT Surface Polish — Part 1

Scoped as Part 1 rather than covering all 23 admin/CBT files in one
pass — matching the CBT engine's own precedent of splitting large
stages (4.8A/4.8B/4.8C each shipped as "Part 1"). This part covers the
CBT runner (the actual exam-taking screen — the highest-stakes surface
in the whole app) plus the Admin Dashboard hub. The remaining 12 admin
CRUD/management screens (Users, Moderation, Audit Log, Academic
Structure, Learning Materials CMS, App Settings) are Part 2.

## Audit performed before implementation

- `cbt_screen.dart` is still the Stage 4.8A placeholder — real exam-
  taking happens in `exam_runner_screen.dart` (866 lines), reached via
  `exam_list_screen.dart`. Confirmed via its own doc comments this
  already went through Stage 4.8A Part 2 (navigator/answers/flag/
  bookmark/autosave) and Stage 4.8C Part 1 (timer, calculator,
  scoring, submit) in other sessions since this chat's Stage 4.8A
  Part 1 foundation work.
- `AppColors.warningAmber` (defined B1) and `AppColors.accentCyan`
  (defined B1) were both still completely unused anywhere in the
  codebase — confirmed by grep before claiming either for this stage.
- `AppAnimations` (defined B1) was still unused everywhere except
  B6's `post_card.dart` edits from this same session.
- `exam_result_screen.dart` — already at a high visual standard (hero
  pass/fail card, stat tiles, topic breakdown, all through
  `CustomCard`/`AppTextStyles`). No gap found worth changing.
- `exam_calculator_sheet.dart` — a real stateful accumulator
  (pending-operation calculator logic, not just UI). Left alone per
  the master rule against touching functional logic during a visual
  stage; its button grid didn't present an obvious visual gap either.
- `admin_dashboard_screen.dart` — found a real inconsistency: WAEC/
  NECO/JAMB "Subjects" management tiles used generic recycled colors
  (`accentGreen`, `highlightOrange`, `secondaryIndigo` — each also
  reused by an unrelated tile on the same screen), while B5 already
  gave those same three boards their own dashboard identity colors
  (`accentTeal`/`necoEmerald`/`accentViolet`) on the student-facing
  side. Fixing this is a "reuse existing tokens" change, not a new
  design decision.

## Changes

1. **`exam_runner_screen.dart`**
   - Countdown timer: was a binary normal/red split (red only under 60
     seconds). Added a `warningAmber` mid-tier under 5 minutes — still
     reading straight off the same `remainingSeconds` value the timer
     already ticks down; no new state, no change to when auto-submit
     actually fires. `warningAmber` was defined in B1, unused until now.
   - Bookmark AppBar icon: previously had zero color distinction
     between bookmarked/not (flag already got `highlightOrange` when
     active; bookmark got nothing). Now uses `accentCyan` when active
     — also unused until now — so the two "marked for review" signals
     sitting next to each other in the AppBar read as visually
     distinct.
   - Question navigator strip (`_QuestionNavigator`): plain `Container`
     → `AnimatedContainer` with the existing `AppAnimations.fast` +
     `.standard` constants, so jumping between questions or a question
     flipping to "answered" transitions smoothly instead of snapping.
     The current question now gets a 2px ring (not just a fill color),
     so it's identifiable even without relying on the fill color alone.

2. **`admin_dashboard_screen.dart`** — WAEC/NECO/JAMB Subjects tile
   accents changed to `accentTeal`/`necoEmerald`/`accentViolet`
   respectively, matching each board's own B5 dashboard color instead
   of a generic reused one.

## Left untouched (deliberately, this part)

- `exam_result_screen.dart`, `exam_calculator_sheet.dart` — see audit
  above.
- `cbt_screen.dart` — still a placeholder; nothing to polish until the
  Home-tab entry point actually does something.
- All 12 remaining admin screens (Users & Roles, Moderation, Audit
  Log, Academic Structure, Learning Materials CMS, App Settings) —
  Part 2. Not attempted here rather than rushed.
- Every piece of the runner's actual exam logic: timer countdown/
  auto-submit trigger, session autosave, answer scoring, shuffle,
  calculator's accumulator math, submit flow, navigation (`_goNext`/
  `_goPrevious`/`_jumpTo`) — all untouched. Only display color/
  transition of already-existing state changed.

## Theme check

- `warningAmber` (`0xFFF59E0B`) and `accentCyan` (`0xFF06B6D4`) — both
  B1-defined, full-opacity on both icon and text in the runner's
  AppBar, same treatment `error`/`textSecondary` already had in the
  same spots — no new contrast case.
- `AnimatedContainer`'s border/fill colors are the same
  `background`/`foreground` values the navigator already computed
  per-state before this stage; only the transition and the current-
  question ring are new, neither is color-dependent on theme beyond
  what was already there.
- Admin tile accents: same `.withOpacity(0.12)` icon-tile pattern
  every other `_AdminModuleTile` already uses — swapping which color
  feeds it doesn't change the pattern's theme behavior.

## Validation performed

- Brace/paren balance check on both edited files (passed).
- Confirmed `warningAmber`/`accentCyan` were genuinely unused before
  claiming them (grep, not assumption).
- No Flutter SDK available — static read-through and mechanical
  balance-check only, not a compiler guarantee.

## Next

B7 Part 2 — the remaining 12 admin screens. Not started automatically
per the continuation rule; report below and wait.

**B7 Part 1 complete — ready for B7 Part 2 or B8, whichever you'd like next.**
