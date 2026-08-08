# Stage B1 — Global Design Tokens (Beautification, Part 1)

## Scope
Per the staged plan from the beautification audit: foundation tokens
only, zero screens touched. Everything here is additive — every
existing `AppColors`/`AppTheme` constant and every call site that reads
them is untouched.

## What's new

**`app_colors.dart`**
- Four new accents: `accentViolet`, `accentPurple`, `accentCyan`,
  `accentTeal` — gives later per-module stages (JAMB/WAEC/NECO/
  University) a real palette to draw from instead of reusing
  `primaryBlue` everywhere.
- `warningAmber`, split out from `highlightOrange` so "generic
  highlight" and "caution/warning" stop sharing one token as the app
  gets more status-aware.
- `premiumGold`/`premiumGoldDark` — Section 27's dedicated premium
  accent, deliberately not reused from any existing color.
- `featuredGradient`/`premiumGradient` — reusable gradient tokens for
  hero/featured/premium cards (Sections 5, 7). Not applied anywhere
  yet; later stages opt in per screen.

**`app_theme.dart`**
- `AppShadows.elevated` — a second, stronger shadow tier alongside the
  existing `.soft`, for featured/elevated cards (Section 8's "cards
  should not all look identical").
- `AppSpacing` — a named scale (`xs`..`xxl`) matching the gap values
  already used ad hoc throughout the app. A naming convention for
  future edits, not a re-layout of anything existing.
- `pageTransitionsTheme` added to both `AppTheme.light` and `.dark`
  (`CupertinoPageTransitionsBuilder` on both platforms) — the one
  global lever for Section 25's page-transition ask. This is the only
  change in this stage with an app-wide visible effect: every existing
  `Navigator.push`/named route now animates with a consistent
  slide instead of each OS's default (Android zoom/fade vs. iOS
  slide).

**`app_animations.dart` (new file)**
- `AppAnimations.fast/medium/slow` durations + `standard`/`emphasized`
  curves — a shared vocabulary so later card-entrance/micro-interaction
  work doesn't hand-roll per-widget magic numbers. Not wired into
  anything yet.

## What was deliberately NOT touched
No screen, no widget's visual output changes in this stage except the
one app-wide transition swap. `CustomCard`, `AppChip`, `AppBadge`,
`state_views.dart`, every dashboard, CBT, admin — all untouched.
Firestore rules, models, repositories — untouched.

## Merge
Applied directly to the same Master Project zip. No new project, no
separate beautification branch.
