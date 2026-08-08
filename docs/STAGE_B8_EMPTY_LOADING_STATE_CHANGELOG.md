# Stage B8 — Empty / Loading State Upgrade

## Audit performed before implementation

- `state_views.dart` (`LoadingView`/`ErrorView`/`EmptyView`/
  `AppSnackbar`) is used across **29 files** — the single highest-
  leverage file in the whole beautification workstream: one correct
  change here reaches nearly every screen with a `StreamBuilder`/
  `FutureBuilder`, without touching those 29 files individually.
- `home_screen.dart` (B4/B1) already established a fade + slight-
  upward-slide entrance pattern — `TweenAnimationBuilder<double>` with
  `AppAnimations.medium` + `.standard`, `Opacity` +
  `Transform.translate`. Reused that exact shape here rather than
  inventing a second entrance animation pattern for state views.
- Confirmed every existing call site (`community_screen.dart`,
  `admin_users_screen.dart`, `subject_manager_screen.dart`, and 26
  others) constructs `EmptyView`/`ErrorView` with only `message`/
  `icon`/`onRetry` — no call site reaches into internals, so an
  internal-only rendering change is safe everywhere without touching
  those files.
- Several call sites use `const EmptyView(...)`/`const ErrorView(...)`.
  Verified this stays valid: `const` applies to the constructor call
  being compile-time-constant, not to what `build()` does at runtime
  — a `const`-constructed widget can still build a `TweenAnimationBuilder`
  (itself a `StatefulWidget`) inside, exactly like plenty of other
  `const` widgets in Flutter do.

## Changes

**`state_views.dart`** — `EmptyView` and `ErrorView` only.

1. Both now render their icon inside a new private `_TintedStateIcon`
   — a soft `color.withOpacity(0.12)` circle behind a full-strength
   icon, instead of `EmptyView`'s previous bare icon at a fixed 0.4
   opacity or `ErrorView`'s bare icon with no backdrop at all. Reuses
   the exact tint ratio `MaterialCard`'s search-result tiles and (from
   this same session's B6) `ProfileScreen`'s `_ProfileTile` already
   established, rather than inventing a new opacity value.
2. Both now wrap their content in a new private `_StateReveal` — the
   `home_screen.dart` fade+slide-in shape, `AppAnimations.medium` +
   `.standard`. Every empty/error state across the app now has the
   same short, subtle "settling in" reveal instead of popping in
   instantly.
3. `ErrorView`'s previous 48px bare icon → part of the shared 72px
   tinted circle (32px icon) both views now use, for visual parity
   between the two states.

**`LoadingView`, `AppSnackbar`** — untouched. See below.

## Left untouched (deliberately)

- **`LoadingView`** — deliberately did *not* get the same
  `_StateReveal` fade-in. A loading spinner's entire job is to appear
  the instant something starts loading; a 300ms fade delay on the one
  state that most needs to read as "immediate" would work against the
  brief's own "should improve perceived quality... not slow down the
  app" animation rule, not support it.
- **`AppSnackbar`** — already consistent, already uses
  `SnackBarBehavior.floating` with its own built-in Material motion;
  nothing here needed the tinted-icon or reveal treatment (a snackbar
  is transient feedback, not a persisted state view).
- Every one of the 29 consuming files — no call site changed, no
  `message`/`icon`/`onRetry` argument changed anywhere.

## Theme check

- `_TintedStateIcon`'s backdrop is `color.withOpacity(0.12)` where
  `color` is either `AppColors.error` (`ErrorView`) or the current
  theme's `bodyMedium` text color (`EmptyView`, same source it already
  read from before this stage) — both already correct per-theme
  values, just reused at a fixed opacity rather than introducing a new
  color.
- `_StateReveal`'s `Opacity`/`Transform.translate` don't touch color
  at all — no new theme interaction beyond what `_TintedStateIcon`
  above already covers.

## Validation performed

- Brace/paren balance check on `state_views.dart` (passed).
- Grepped every `EmptyView(`/`ErrorView(` call site across the app to
  confirm none pass anything beyond the existing three named params,
  and that `const` call sites remain valid per the reasoning above.
- No Flutter SDK available — static read-through and mechanical
  balance-check only, not a compiler guarantee.

## Next stage

That completes the originally planned B1–B8 beautification workstream
list (B7 Part 2 — the remaining 12 admin screens — is still open from
last stage, flagged there as deferred, not part of this list).

**B8 complete.**
