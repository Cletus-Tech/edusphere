# Stage B3 — Navigation Active-State Indicator (Beautification, Part 3)

## Scope
`home_shell.dart` only, per the staged plan. Pure presentation swap —
`_currentIndex`, `_goToTab`, `_pages`, and the tab list are untouched.

## What changed
Replaced the stock `BottomNavigationBar` (active tab shown only by
icon/label color change — flagged in the audit as the exact pattern
the brief asks to move away from) with a custom `_AppBottomNavBar`:
the active tab gets a real indicator, a soft rounded pill
(`selectedColor.withOpacity(0.12)`) behind its icon, plus a bolder
label weight, both animating in over `AppAnimations.fast` (from B1).

Every color — background, selected, unselected — is read from
`Theme.of(context).bottomNavigationBarTheme`, which `app_theme.dart`
already fully defines for both light and dark. Nothing here is
hardcoded, so this works correctly in both themes with zero
theme-specific code in the new widget, and any future theme edit to
`bottomNavigationBarTheme` continues to apply automatically.

## What was deliberately NOT touched
Tab switching logic, the five pages, the `IndexedStack`, item
icons/labels themselves — all identical to before. No other screen
touched.

## Merge
Applied directly to the same Master Project zip.
