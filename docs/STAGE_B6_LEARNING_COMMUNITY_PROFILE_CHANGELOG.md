# Stage B6 — Learning Materials / Community / Profile Polish

## Audit performed before implementation

- Confirmed B1–B5 state from their own changelogs: `AppColors` already
  reserves `accentCyan`/`accentPurple` (defined in B1, never applied by
  any later stage), `AppAnimations` already defines `fast`/`medium`/
  `slow` + `standard`/`emphasized` curves (defined in B1, not yet used
  anywhere), `CustomCard.accentColor` (B2) is only used on Home's
  "Recently Added" rows so far, `AppChip`/`AppBadge` unchanged since
  B2.
- `LearningMaterialType` already carries its own `.color` per type
  (pdf/video/image/etc.) — Learning Materials already has real
  per-type visual identity from Stage 3.5, wired into
  `MaterialCard`/`material_detail_screen.dart`/the library's filter
  chips. This means Learning Materials does **not** need a single
  module accent the way JAMB/WAEC/NECO did in B5 — it already has a
  richer, per-item scheme; forcing one flat color over it would be a
  regression, not an improvement.
- Community has no existing accent — `community_screen.dart`'s FAB
  used plain `secondaryIndigo` (the generic brand color used all over
  the app, not anything Community-specific).
- `profile_screen.dart`'s `_ProfileTile` rendered every icon as flat,
  untinted `Icon` widgets — the one screen in this stage's scope with
  no tinting at all, unlike the search-result tiles in the Learning
  Library which already use a `.withOpacity(0.12)` tinted-circle
  pattern.

## Changes

1. **`material_card.dart`** — added `accentColor: type.color` to the
   existing `CustomCard` call (the param already existed from B2,
   unused here). Brings the Library grid in line with the same
   left-edge-stripe treatment Home's "Recently Added" rows already use
   for the same `LearningMaterialType.color`. Verified `CustomCard`
   auto-insets its child by the border width (Flutter's `Container`
   merges `padding` with `decoration.padding` from the border), so the
   stripe doesn't get covered by the card's zero-padding thumbnail.

2. **`post_card.dart`**
   - Like button: wrapped the heart icon in `AnimatedScale` (1.0 →
     1.15 on `liked` flipping true, `AppAnimations.fast` +
     `.emphasized` — both existing B1 constants, no new duration
     introduced). `AnimatedScale` only re-animates when its `scale`
     input changes, so a `StreamBuilder` rebuild that doesn't flip
     `liked` doesn't retrigger it.
   - Bookmark button: same `AnimatedScale` treatment; active color
     changed from `primaryBlue` to `accentPurple` (Community's new
     module accent — see below).

3. **`community_screen.dart`** — FAB `backgroundColor`:
   `secondaryIndigo` → `accentPurple`. Establishes Community's module
   identity the same way B5 gave JAMB violet / WAEC teal / NECO
   emerald. Didn't add a header `AppChip` badge like B5's dashboards:
   this screen's body starts directly with the feed `ListView`, no
   intro-text header section to anchor a chip under — forcing one in
   would mean restructuring the body layout for a stage whose brief is
   "smallest correct change," not adding new structure.

4. **`post_detail_screen.dart`** — comment send button color:
   `primaryBlue` → `accentPurple`, matching the same new Community
   identity.

5. **`profile_screen.dart`** — `_ProfileTile`: icon changed from a
   flat `Icon` to a `CircleAvatar` with a `.withOpacity(0.12)` tint
   behind it, reusing the exact pattern already established in the
   Learning Library's search-result tiles rather than inventing a new
   one. Tint defaults to `primaryBlue`; a tile's existing `color`
   param (e.g. Logout's `error`) still overrides it exactly as before
   — no tile's actual color meaning changed, only how it's rendered.

## Left untouched (deliberately)

- **`material_detail_screen.dart`** — already uses `type.color` for
  its hero banner fallback, chip, and icon; already has a `_Stat` row
  and a `PrimaryButton`. Already at the same visual standard the rest
  of this stage's changes are bringing other files up to — no gap
  found worth changing.
- **`academic_profile_screen.dart`** — audited but not touched. This
  screen is six near-identical cascading-dropdown blocks where each
  `onChanged` clears multiple pieces of downstream state
  (institution → faculty → department → level → semester). Any visual
  wrapper touching all six blocks carries real regression risk for a
  purely-visual stage's minimal-diff principle, for a screen that
  reads perfectly clearly as plain form fields today. Flagging as a
  candidate for a future, narrowly-scoped stage rather than folding it
  into B6's remaining files.
- All data fetching, `StreamBuilder`s, repository calls, `onTap`/
  `onChanged` callbacks, route definitions, and `AuthService` calls —
  identical to before this stage in every file touched.
- `AppChip`, `AppBadge`, `CustomCard`'s internal implementation,
  `AppAnimations`, `AppColors` — read from, not modified.

## Theme check

- `accentPurple` (`0xFF9333EA`) — same B1-defined constant already
  used at full opacity elsewhere (chips render white-on-accent per B5's
  own verified `AppChip` contrast note); FAB icon/label default to
  white via `FloatingActionButton`'s own foreground-color-on-background
  contrast logic, unaffected by this change. Comment send icon is a
  bare `Icon` in `accentPurple` at full opacity — readable against both
  `AppColors.surfaceWhite` and `AppColors.darkSurface`, same contrast
  margin `primaryBlue` had in the exact same spot before.
- `_ProfileTile`'s `.withOpacity(0.12)` tint circle is the identical
  pattern the Library's search-result tiles already use in both
  themes — no new contrast case introduced.
- `AnimatedScale` changes size, not color — no theme interaction.

## Validation performed

- Brace/paren balance check on all 5 edited files (passed).
- Confirmed `CustomCard`'s border/padding interaction in
  `custom_card.dart` directly before relying on it in `material_card.dart`.
- No Flutter SDK available in this environment — static read-through
  and mechanical balance-check only, not a compiler guarantee, per the
  brief's requirement to state this limitation clearly.

## Next stage

B7 — Admin & CBT Surface Polish.

**B6 complete — ready for B7.**
