# Stage 4.1 — Home Dashboard Integration & Navigation

## Audit (before changes)

The Home Dashboard (`lib/features/home/home_screen.dart`, shell in
`home_shell.dart`) has five interactive regions:

| Component | Behavior found | Verdict |
|---|---|---|
| Notification bell | Pushes `NotificationsScreen`, real unread badge via `NotificationRepository.watchByUser` | OK |
| Avatar | Static, no tap handler | OK (not a button in this design) |
| Search field | Present, not yet wired to a results screen | Pre-existing scope gap, not a Home routing bug — left untouched per "don't regenerate existing architecture" |
| Hero banner "Learn More" | Switches to Learn tab | OK |
| "Explore" → See All | Switches to Learn tab | OK |
| Quick-access tiles: University | Switches to Learn tab (Learning Library) | **Correct** — Learning Library is documented as the University coursework browser |
| Quick-access tiles: JAMB | Switches to Learn tab (Learning Library) | **Bug** — dead-ends at the same University content library with nothing JAMB-specific |
| Quick-access tiles: WAEC | Switches to Learn tab (Learning Library) | **Bug** — same as JAMB |
| Quick-access tiles: NECO | Switches to Learn tab (Learning Library) | **Bug** — same as JAMB |
| Quick-access tiles: AI Tutor | Switches to AI Tutor tab (real `FeaturePlaceholder` screen) | OK |
| "Recently Added" → See All | Switches to Learn tab | OK |
| Recently Added material cards | Push `MaterialDetailScreen` | OK |
| Quick-access tap target | `GestureDetector`, no ripple/press feedback | **UX gap** |
| Recently-added empty state | Plain `CustomCard` + text, inconsistent with the app's `EmptyView` used elsewhere | **UX gap** |
| Admin-configured `cbt` dashboard card (`FeatureKeys.cbt` already exists in Control Center) | No route/tab resolves `key == 'cbt'` → falls to "not available yet" snackbar | **Gap** — flag exists but nothing to land on |

CBT/Marketplace/Scholarships/Parents Portal/Professional Exams tiles are
not part of the current Home UI at all (no card renders for them today);
only CBT was addressed here per the Part 6 requirement, since it already
has a toggleable feature flag in the Control Center.

## Root cause (Part 3)

`HomeScreen._tabForKey` aliased `'jamb'`, `'waec'`, and `'neco'` to the
same tab index as `'university'` (`_tabLearn`), so every one of those
quick-access tiles opened the identical `LearningLibraryScreen`.

## Fix

**New files** (placeholder screens, following the existing
`FeaturePlaceholder` pattern already used by `AiTutorScreen`):
- `lib/features/jamb/jamb_screen.dart`
- `lib/features/waec/waec_screen.dart`
- `lib/features/neco/neco_screen.dart`
- `lib/features/cbt/cbt_screen.dart`

**Modified files:**
- `lib/core/routes/app_routes.dart` — registered `/jamb`, `/waec`,
  `/neco`, `/cbt` as real named routes.
- `lib/features/home/home_screen.dart`
  - Removed the JAMB/WAEC/NECO → `_tabLearn` aliases from `_tabForKey`.
  - Added `_routeForKey`, resolved after `_tabForKey` in `_openTile`, so
    JAMB/WAEC/NECO/CBT push their own placeholder route instead of
    falling through to Learn or the "not available yet" snackbar.
  - Quick-access tiles now wrap in `Material` + `InkWell` for a real
    ripple instead of a bare `GestureDetector`.
  - Recently Added's empty state now uses the shared `EmptyView` widget
    instead of a plain text card.

**Reused, not duplicated:** `FeaturePlaceholder`, `AppColors`,
`AppRoutes` table, `EmptyView`, `FeatureKeys.cbt` (existing Control
Center flag), the existing `_openTile`/`deepLink` resolution order.

## Navigation table after this stage

| Key | Destination |
|---|---|
| `university` | Learn tab (Learning Library) |
| `learn` | Learn tab |
| `community` | Community tab |
| `ai_tutor` | AI Tutor tab (placeholder) |
| `profile` | Profile tab |
| `jamb` | `/jamb` (placeholder) |
| `waec` | `/waec` (placeholder) |
| `neco` | `/neco` (placeholder) |
| `cbt` | `/cbt` (placeholder) |
| anything else (marketplace, scholarships, parents_portal, professional_exams, unknown keys) | "This module isn't available yet." snackbar |

## Compatibility notes

- Firebase, auth, Firestore, Storage, audit logging, repositories,
  theme, Community, Learning Materials, and Admin modules are untouched.
- `DashboardConfigService`-driven cards (`settings/dashboard.cards`)
  keep working exactly as before: an explicit `deepLink` still wins
  first; a bare `key` now additionally resolves against the new
  `_routeForKey` map, so existing/future Control-Center-configured
  cards with `key: 'jamb' | 'waec' | 'neco' | 'cbt'` land correctly
  without any Firestore data changes required.

## Remaining modules for future stages

University (real content beyond the shared library), WAEC, NECO, JAMB,
and the Unified CBT Engine all still need their actual screens/logic —
this stage only gives each an honest, on-brand landing spot instead of
a wrong or dead one.

## Standard Completion Checklist
- ✅ Home Dashboard audited
- ✅ Navigation corrected
- ✅ Dead buttons removed (quick-access tiles now have ripple feedback)
- ✅ Incorrect routes fixed (JAMB/WAEC/NECO no longer alias to Learning Library)
- ✅ Existing modules reused (FeaturePlaceholder, AppRoutes, EmptyView, FeatureKeys.cbt)
- ✅ No duplicate code
- ✅ Master project preserved
- ✅ Ready for Stage 4.2 — Community Completion
