# Stage 4.8C Part 1 — Submission & Scoring Engine

## Why this part came first
Auditing Stage 4.8C against the full spec found a blocker upstream of the
spec's own items: `ExamRunnerScreen` let a student answer and auto-save an
exam but had no timer, no Submit action, and no scoring/attempt-creation
path at all. Negative marking, calculator enforcement, and review policy
are all downstream of scoring existing, so this had to land before the
rest of Institution Controls could mean anything.

## What's new

**Scoring engine** (`exam_scoring.dart`, pure logic, no UI/Firestore
coupling): turns an answered `ExamSessionModel` into an `ExamScoringResult`
— correct/incorrect/unanswered counts, per-topic breakdown, and a score
percent that applies `ExamModel.negativeMarkingEnabled` /
`negativeMarkPercent` when set. Only the question types the runner
actually collects answers for (single/multiple-choice, true/false,
fill-in-the-blank, short-answer) are auto-scored; other types are excluded
from both the question count and the point total rather than silently
penalizing a student for a question type the runner shows as
"not supported" instead of an input.

**Submit flow** (`ExamRunnerScreen`): a Submit action in the app bar shows
an answered/unanswered confirmation, then scores the session, writes the
permanent `ExamAttemptModel` via `ExamAttemptRepository`, marks the
session `submitted`, and hands off to a new `ExamResultScreen`
(score, pass/fail, correct/incorrect/unanswered, time taken, topic
breakdown).

**Timer**: `ExamMode.official`/`ExamMode.mock` sessions now run a real
hard countdown from `ExamModel.durationMinutes`, persisted into
`ExamSessionModel.remainingSeconds` every 10 seconds so a killed app can't
be used to gain time, and auto-submit at zero. `ExamMode.practice` shows
an elapsed-time count-up instead, per the mode's existing documented
"student-controlled, nothing forces submission" behaviour. Session
creation is still hardcoded to `ExamMode.practice` (a mode picker is
separate, out-of-scope UI work), so the countdown path is exercised as
soon as that picker exists rather than being dead code today.

**Calculator**: `ExamModel.calculatorType` now actually gates something —
a calculator icon appears in the app bar only when it isn't `none`, opening
a bottom-sheet calculator. `basic` gets +, −, ×, ÷, %, sign-flip;
`scientific` adds sin/cos/tan, log, ln, √, x², and π.

**Option shuffling**: `ExamModel.shuffleOptions` (declared since Stage
4.8A, never applied) is now honored — a per-session, per-question display
order of option indices is computed once at session creation and stored
on `ExamSessionModel.optionOrder`, so shuffled order is stable across
resumes. Answers are still stored against the *original* option index, so
this is purely a display concern and never touches scoring.

## Data model changes
`ExamSessionModel` gains `optionOrder` (`Map<String, dynamic>`,
questionId -> list of original option indices). Additive and defaulted to
`{}`, decodes safely on every session document written before this part —
no migration needed.

## Deliberately still not here
Review policies (not yet modeled on `ExamModel` at all), premium gating,
offline engine, and proctoring — each is separate, larger build work
covered by their own parts of the Stage 4.8C audit.
