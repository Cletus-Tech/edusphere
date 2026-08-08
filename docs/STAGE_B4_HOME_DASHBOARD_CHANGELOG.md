# Stage B4 — Home Dashboard Polish

## Audit
- `home_screen.dart` (473 lines) is the only file this stage needed. Its
  data flow — `DashboardConfigService` for the hero/quick-access,
  `LearningMaterialRepository.watchRecentlyAdded` for the recent-materials
  list, `AuthService`/`NotificationRepository` for the header — was
  untouched; this stage only changed how each section is *drawn*.
- B1/B2 had already built the tokens this stage needed but left unused:
  `AppColors.featuredGradient` (comment: "reusable gradients for later
  stages' hero/featured/premium cards... deliberately not applied
  anywhere yet"), `CustomCard.accentColor`, and `AppAnimations`. B4 spends
  these rather than introducing new ones.
- `PremiumBadge` (B2) is still unused after this stage — showing it on
  Home would need the Firestore `UserModel` (for `isPremiumActive`),
  which Home doesn't currently fetch (only the cached Firebase Auth
  `displayName`). Adding that fetch is a data-layer change, out of scope
  for a visual-only stage — left for a future stage instead of smuggled
  in here.

## Changes (`lib/features/home/home_screen.dart` only)
1. **Hero banner** — `AppColors.splashGradient` → `AppColors.featuredGradient`
   (was unused; splash screen keeps its own gradient). Added a subtle
   decorative circle (8% white, positioned off-canvas top-right) for
   depth. Wrapped in a `TweenAnimationBuilder` fade + 12px slide-up on
   first build (`AppAnimations.medium` / `.standard`) — stateless, no
   controller to dispose, so no lifecycle risk.
2. **Quick-access tiles** — added a subtle 25%-opacity ring in the tile's
   own accent color and a soft drop shadow (light theme only, matching
   `CustomCard`'s existing light-only-shadow convention) instead of a
   flat opacity-fill square. Tap targets, sizes, and the
   `DashboardConfigService` fallback logic are unchanged.
3. **Recently Added cards** — passed `accentColor: materials[i].type.color`
   into the existing `CustomCard` (the param already existed, unused
   here before). Each row now gets a left-edge stripe in its content
   type's color, consistent with the icon it already showed.

## Left untouched (in scope, deliberately not touched)
- All data fetching, StreamBuilders, navigation callbacks (`_openTile`,
  `onNavigateToTab`), and the `Good morning, {name} 👋` greeting text.
- `SectionHeader`, `SearchField`, `AppAvatar`, `AppBadge` — shared
  widgets used elsewhere; not modified, since a Home-only stage
  shouldn't ripple into Learn/Community/etc.

## Theme check
- Featured gradient is a fixed two-color gradient (not theme-dependent),
  so white text/icon contrast on the hero banner is identical in light
  and dark. Quick-access ring/shadow and the recent-materials stripe use
  each item's own accent color at reduced opacity — readable against
  both `AppColors.surfaceWhite` and `AppColors.darkSurface` card
  backgrounds. Shadow is conditionally light-theme-only, matching
  `CustomCard`'s existing convention.

## Validation performed
- Manual brace/paren balance check and structural re-read of the
  modified `_HeroBanner`/`_QuickAccessRow`/`_RecentMaterials` widgets
  (no Flutter SDK available in this environment to run `flutter
  analyze`/`flutter build` — this is a static read-through, not a
  compiler guarantee; real verification happens on the next CI build).
- Cross-checked every new API call (`AppColors.featuredGradient`,
  `CustomCard.accentColor`, `AppAnimations.medium/.standard`) against
  where each was already defined, to confirm none of this stage's edits
  invented new tokens outside `AppColors`.

## Next stage
B5 — University / JAMB / WAEC / NECO.

**B4 complete — ready for B5.**
