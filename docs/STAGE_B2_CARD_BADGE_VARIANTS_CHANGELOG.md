# Stage B2 — Card & Badge Variants (Beautification, Part 2)

## Scope
Extends the two most-reused visual primitives (`CustomCard`, `AppChip`)
with opt-in params rather than creating parallel "featured card" /
"premium chip" classes. No screen was changed to *use* the new options
yet — that's B4+ (Home, per-module dashboards, learning materials).
This stage only makes the options exist and prove out on paper against
every existing call site.

## What's new

**`custom_card.dart`** — three new optional params, all default to "off":
- `accentColor` — 4px left-edge stripe for module/category identity
  (e.g. a JAMB card in violet). Ignored if `gradient` is set.
- `gradient` — background gradient (e.g. `AppColors.featuredGradient`/
  `premiumGradient` from B1) for hero/featured/premium cards. Replaces
  the flat card color; callers own text/icon coloring on top of it.
- `elevated` — swaps `AppShadows.soft` for `AppShadows.elevated` (from
  B1), light theme only, matching the existing shadow's light-only
  behavior.

**`app_chip.dart`** — one new optional param:
- `icon` — leading `IconData`, shown before the label. Powers premium/
  content-type badges without a separate chip-with-icon widget.

**`premium_badge.dart` (new file)** — `PremiumBadge`, a thin wrapper:
`AppChip(label: 'Premium', icon: workspace_premium_rounded, accent:
AppColors.premiumGold, selected: true)`. Exists so every premium
indicator across the app (exam cards, learning materials, course
content) renders identically instead of each screen picking its own
icon/gold shade — Section 27's "consistent visual language," enforced
by having exactly one widget rather than a convention to remember.

## Compatibility check
Every existing `CustomCard(...)` and `AppChip(...)` call site in the
app was checked (13 `AppChip` call sites across admin/learning-materials/
university/community) — all use named arguments, none positional, so
none are affected by the new optional params. No visual change to any
existing screen from this stage alone.

## What was deliberately NOT touched
`AppBadge` (the Stack-based icon/count badge — a different job from
`AppChip`, correctly left alone rather than merged). No dashboard,
CBT, admin, or feature screen was edited to adopt these yet.

## Merge
Applied directly to the same Master Project zip.
