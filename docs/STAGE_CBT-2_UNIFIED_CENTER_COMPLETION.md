# Stage CBT-2 — Unified CBT Center UI + Existing Engine Integration

Completion report. Per the stage brief: this is a UI-plus-wiring stage
only. No new exam engine, model, repository, or scoring logic was
created — everything below either reuses the CBT-1-audited engine as-is
or adds the single, additive parameter that engine's own code already
anticipated.

## 1. Files created

| File | Purpose |
|---|---|
| `lib/features/cbt/my_attempts_screen.dart` | Cross-board attempt history — "My Attempts" section. Reuses `ExamAttemptRepository.watchHistoryForUser` and the resolver's new `matchAll()` for data; no new attempt storage. |
| `docs/STAGE_CBT-2_UNIFIED_CENTER_COMPLETION.md` | This report. |

`lib/features/cbt/cbt_screen.dart` is a **full rewrite of an existing
file**, not a new file — its class name, filename, and the `/cbt` route
that points at it are all unchanged, so this required zero route-table
edits.

## 2. Files modified

| File | Change | Why |
|---|---|---|
| `lib/features/exam_prep/exam_runner_screen.dart` | Added optional `ExamMode mode` constructor param, default `ExamMode.practice`. Replaced the hardcoded `const mode = ExamMode.practice;` the class's own doc comment already called out as "mode picker is separate scope" with `final mode = widget.mode;`. Updated the class doc comment to match. | Official/Mock cards can't honestly claim to use `ExamMode.official`/`ExamMode.mock` (as the brief requires) unless something can tell the runner which mode to start in. This was the one real gap CBT-1 flagged. |
| `lib/features/exam_prep/exam_list_screen.dart` | Same additive `mode` param, passed through to `ExamRunnerScreen`. Added one new guard: if `exam.supportedModes` doesn't include the requested `mode`, the start is blocked with a clear dialog instead of silently proceeding. | The brief requires "if an exam is unavailable, do not allow the user to start it" — an exam authored as official-only shouldn't be startable from a practice entry point either. `ExamModel.supportedModes` already existed for exactly this; it just wasn't checked anywhere before. |
| `lib/features/exam_prep/exam_attempt_resolver.dart` | Added `matchAll()` — the unfiltered sibling of the existing `matchType()`. | "My Attempts" spans every board/mode; `matchType` (built for one board's `ExamHistoryScreen`) can't do that without a parallel join implementation, which would be a duplicate. `matchAll` is the same join, no filter. |
| `lib/features/home/home_screen.dart` | Two one-line additions: `'cbt'` added to `_fallbackQuickAccess`; a matching `'laptop_chromebook'` entry added to `_iconByName`. | `_routeForKey['cbt']` already resolved correctly before this stage — `'cbt'` just wasn't offered as a *default* tile (an admin had to hand-configure a Firestore dashboard card to reach it). This is the one line needed to make the existing configurable architecture actually surface it, not a Home redesign. |

## 3. Existing files reused, unmodified

`ExamModel`, `QuestionModel`, `ExamSessionModel`, `ExamAttemptModel`
(all in `exam_model.dart`/`exam_session_model.dart`) · `ExamRepository`,
`QuestionRepository`, `ExamSessionRepository`, `ExamAttemptRepository`
(`learning_repository.dart`) · `ExamMode`, `ExamType`
(`content_type.dart`) · `ExamListScreen`'s existing availability/
attempt-limit gating logic · `AuthService` · `FeatureKeys.cbt` /
`DashboardConfigService` (Home card visibility — untouched, still the
sole gate) · `CustomCard`, `AppChip`, `AppAvatar`, `SectionHeader`,
`FeaturePlaceholder`, `LoadingView`/`ErrorView`/`EmptyView`
(shared design system — no new widgets invented) · `AppColors`,
`AppTextStyles` (no new colors or type styles added).

## 4. Routes changed

**None.** `AppRoutes.cbt` already existed and already pointed at
`CbtScreen`; rewriting that class's body required no route-table edit.
No child routes were added — Official/Practice/Mock/My Attempts are all
reached via `Navigator.push`, the same pattern
WAEC/NECO/JAMB/University already use for their own sub-screens.

## 5. UI implemented

- **CBT Center header** — title, subtitle ("Your examination and
  practice hub"), avatar (reusing `AppAvatar`, no new avatar component).
- **Five feature cards** — Official Exams, Practice, Mock Exams,
  Scanning Mode (labeled "Coming soon" via a status chip — not
  disguised as functional), My Attempts. Each: icon, title, one-line
  description, tap target — no decorative excess, per the brief.
- **Live "Available Official Exams" preview** — up to 3 real exams from
  `ExamRepository.watchByType`, each showing question count, duration,
  premium badge (only `ExamModel` fields — no invented data), and a
  computed status chip (Available Now / Upcoming / Expired /
  Unavailable) using `AppChip`. Deliberately does **not** show a
  per-user "attempts remaining" count here — that number requires the
  live per-user query `ExamListScreen._startExam` already runs
  correctly at start-time; a second, possibly-stale copy of it in a
  preview card would risk being wrong, which the brief's honesty
  requirement rules out.
- **My Attempts screen** — list of every submitted attempt across every
  board/mode, with a mode chip (Official/Mock/Practice, color-coded to
  the same accent palette as the feature cards), date, duration, and a
  score/pass-fail readout; tapping opens the existing `ExamResultScreen`
  unchanged.
- **Scanning Mode** — its own route/screen (`_ScanningModeScreen`),
  rendering the existing `FeaturePlaceholder` component (same one every
  other unbuilt EduSphere module uses) rather than a fabricated scan UI.
- Icons throughout are Material's outlined/rounded professional set
  (`Icons.verified_outlined`, `Icons.timer_outlined`,
  `Icons.document_scanner_outlined`, etc.) — no emoji, confirmed by an
  automated scan of every touched file (one pre-existing emoji was
  found — a 👋 in Home's unrelated greeting text — and left untouched
  as it predates and is outside this stage).
- Light/dark theme: every color reference goes through `AppColors` or
  `Theme.of(context).textTheme` — no hardcoded hex values — so both
  themes are inherited automatically, matching every other screen's
  approach in this codebase.

## 6. Existing engine integrations

- **Official Exams** → `ExamListScreen(examTypeId: ExamType.cbt.id, mode: ExamMode.official)` → real `ExamRepository` query → real `ExamRunnerScreen` session in `ExamMode.official`.
- **Practice** → `ExamListScreen(examTypeId: ExamType.practiceTest.id)` (mode defaults to `practice`, unchanged from every existing call site's behavior).
- **Mock Exams** → `ExamListScreen(examTypeId: ExamType.mockExam.id, mode: ExamMode.mock)`.
- **My Attempts** → real `ExamAttemptRepository.watchHistoryForUser`, joined to real exams via the resolver, opening the real `ExamResultScreen`.
- All four go through the identical `ExamListScreen` → `_startExam` →
  `ExamRunnerScreen` path WAEC/NECO/JAMB/University already use — same
  availability check, same attempt-limit check, same sign-in check, plus
  the one new mode-support check described above.

## 7. Verification performed

No Flutter/Dart toolchain available in this environment — static
verification only, performed and reported honestly per the brief's own
fallback instruction:

- **Brace/paren balance** — checked programmatically across every
  touched/new file; all balanced.
- **Import resolution** — every relative import in the two new/rewritten
  CBT files resolved against the actual file tree; all exist.
- **API signature checks** — `ExamRepository.watchByType`,
  `ExamAttemptRepository.watchHistoryForUser`, `AppChip`, `CustomCard`,
  `AppAvatar`, `SectionHeader`, `FeaturePlaceholder`,
  `LoadingView`/`ErrorView`/`EmptyView`, `ExamResultScreen`'s
  constructor — each confirmed against its real source definition, not
  assumed.
- **Every call site of `ExamListScreen` outside the new CBT files**
  (WAEC, NECO, JAMB, University — 7 call sites) confirmed to pass only
  `examTypeId`/`title`, both still valid positional-optional-compatible
  named params; none of them break with the new optional `mode` param
  added.
- **Every call site of `ExamRunnerScreen` outside `exam_list_screen.dart`**
  — only `exam_review_screen.dart`'s "retry incorrect" flow — confirmed
  it doesn't pass `mode`, so it keeps defaulting to `ExamMode.practice`,
  correct for a retry flow and unchanged from before this stage.
- **Duplicate-symbol search** — grepped for a second `ExamModel`,
  `ExamListScreen`, `ExamRunnerScreen`, or attempt-repository anywhere
  in `lib/`; none found; none created.
- **Emoji scan** — automated scan across every touched file; zero
  emoji introduced by this stage (one pre-existing, unrelated instance
  found and left alone, reported above rather than silently fixed
  out-of-scope).
- **Not verified** (no toolchain): actual `flutter analyze`/compile,
  runtime widget layout on real device sizes, Firestore query behavior
  against a live project. These should be run before shipping.

## 8. Remaining limitations — stated plainly, not glossed over

- **Scanning Mode is a placeholder**, exactly as instructed — no scan
  engine exists.
- **Premium gating is display-only.** `ExamModel.isPremium` is shown as
  a badge on official-exam cards; nothing in this stage enforces it
  (no payment/entitlement check blocks a non-premium user from
  starting a premium exam). The brief explicitly excludes payment
  processing from CBT-2, but the *enforcement* gap (as opposed to
  billing) is worth flagging for whichever stage does own it.
- **No offline sync**, **no proctoring/monitoring**, **no admin CBT
  Control Center section** — all explicitly out of scope for this
  stage and not started.
- **"Practice by Subject/Topic" filtering** inside Practice isn't a
  separate CBT-2 UI — `ExamListScreen` already lists exams under the
  `practiceTest` type; if the existing system doesn't yet expose
  subject/topic filtering within that list, this stage didn't add it
  (the brief said to expose it "if the existing architecture already
  supports it" — it wasn't found to).
- **The live official-exams preview shows no per-user attempt count**,
  by design (see §5) — the authoritative number is only computed at
  start-time inside `ExamListScreen`.

## 9. Recommended next stage

A CBT Control Center section (per CBT-1's sketch: CBT Settings, Official
Exams, Practice Settings, Access Rules, Attempt Limits) is the next
logical piece — it would give the owner a UI for the
`isPremium`/`attemptLimit`/`availableFrom`/`availableUntil`/
`supportedModes` fields this stage now actively uses, without needing
Firestore console access. Camera/microphone monitoring and the offline
sync queue remain explicitly deferred, as instructed.

**Stopping here, as instructed, before CBT-3.**
