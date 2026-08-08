# Stage B5 — University / JAMB / WAEC / NECO Polish

## Audit
- JAMB/WAEC/NECO dashboards are near-identical generic templates (WAEC's
  own doc comment: "Stage 4.6 (NECO) can copy this one file's shape...
  instead of rebuilding") — each an 8-11 tile `GridView` built from
  `_DashboardTile(icon, accent, label, onTap)`.
- Before this stage, all three modules mixed the exact same four generic
  colors (`primaryBlue`/`secondaryIndigo`/`accentGreen`/`highlightOrange`)
  across their tiles, in the same repeated order — zero visual
  distinction between JAMB, WAEC, and NECO at a glance, despite `app_colors.dart`
  already carrying a Stage B1 comment reserving "JAMB → violet, WAEC →
  teal, NECO → a green variant distinct from accentGreen's 'success'
  meaning" — written in B1, never applied until now.
- University Dashboard is structurally different (`_QuickActionsRow` +
  profile-driven sections, not a `_DashboardTile` grid) — its primary
  action already used `primaryBlue`, so it keeps that as its identity
  color rather than being forced into the same tile-grid treatment.
- `AppChip` (existing, already used by `PremiumBadge`) was reused as-is
  for the new module badges — no new badge widget created.

## Changes
1. **`app_colors.dart`** — added `necoEmerald` (`0xFF15803D`), the one
   token B1 planned but never defined. Nothing else changed; every
   existing constant is untouched.
2. **`jamb_dashboard_screen.dart`** — all 9 tile accents → `accentViolet`.
   Added an `AppChip(label: 'JAMB', accent: accentViolet, selected: true)`
   badge under the intro text.
3. **`waec_dashboard_screen.dart`** — all 9 tile accents → `accentTeal`.
   Same `AppChip` treatment, WAEC/teal.
4. **`neco_dashboard_screen.dart`** — all 11 tile accents → `necoEmerald`.
   Same `AppChip` treatment, NECO/emerald.
5. **`university_dashboard_screen.dart`** — added the same `AppChip`
   badge (primaryBlue) above `_QuickActionsRow`, for header consistency
   with the other three modules. Existing per-card icon colors inside
   `_QuickActionsRow`/`_SetupProfileCard` untouched.

## Left untouched (deliberately)
- `exam_prep/subject_browse_screen.dart`, `exam_prep/exam_list_screen.dart`,
  `university/course_detail_screen.dart` — these are shared,
  category-agnostic screens reached from all four modules (per their own
  doc comments). Recoloring them to one module's accent would be wrong;
  they stay neutral by design, not oversight.
- Every tile's icon, label, and `onTap` — all identical to before this
  stage. Only the `accent` `Color` value changed; no navigation, no data
  fetching, no route touched.

## Theme check
`AppChip` with `selected: true` renders white text/icon on the full
(non-transparent) accent color — verified this is unconditional in
`app_chip.dart` (`contentColor = selected ? Colors.white : bodyColor`),
so all four new accents (`accentViolet`, `accentTeal`, `necoEmerald`,
`primaryBlue`) hold sufficient contrast in both light and dark theme
without any additional per-theme handling needed. Tile accents were
already used the same way pre-B5 (via `.withOpacity(0.12)` fills, theme-
proven since Stage 4.5-4.7); swapping which named color feeds that same
existing pattern doesn't change its theme behavior.

## Validation performed
- Brace/paren balance check on all 5 edited files (passed).
- Confirmed exact tile counts before/after the bulk accent recolor
  (JAMB 9, WAEC 9, NECO 11 — matched pre- and post-edit) so no tile was
  silently skipped or double-matched by the bulk replace.
- No Flutter SDK available in this environment — this is a static
  read-through and mechanical count-check, not a compiler guarantee.

## Next stage
B6 — Learning Materials / Community / Profile.

**B5 complete — ready for B6.**
