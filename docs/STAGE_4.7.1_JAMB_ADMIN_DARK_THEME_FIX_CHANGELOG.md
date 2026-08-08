# EduSphere Stage 4.7.1 — JAMB Admin Integration + Dark Theme Portal Fix

Targeted fix stage, not a feature stage. Two confirmed issues, fixed
directly in the existing Master Project. CBT Engine untouched — remains
a future stage.

## Part 1 — Audit

| Checked | Finding |
|---|---|
| JAMB dashboard, JAMB routes, `Home → JAMB` | ✅ Working — `AppRoutes.jamb` and `HomeScreen`'s `_routeForKey` were already correct, never broken |
| Admin Control Center tiles | ❌ `AdminDashboardScreen` had tiles for WAEC Subjects and NECO Subjects (both wired to the existing generic `SubjectManagerScreen`), but no JAMB Subjects tile — JAMB was simply never added when WAEC/NECO were |
| Theme configuration (`app_theme.dart`, `app_colors.dart`) | ✅ Correct — `ThemeData.dark` properly maps `textTheme` to `textPrimaryDark` / `textSecondaryDark`. The defect is not in the theme system itself |
| WAEC / NECO / JAMB dashboard tiles | ❌ Tile labels used the hardcoded constant `AppColors.textPrimary` (`0xFF1E293B`) instead of `Theme.of(context)`. That constant is identical to `AppColors.darkSurface`, so in dark mode the label text exactly matched the card background — fully invisible, not just low-contrast |
| University dashboard | ❌ Same defect present (profile card, institution card, course list tiles) — fixed per Part 5's instruction to correct it if the same defect exists |
| Shared exam-prep screens reached from WAEC/NECO/JAMB (Mock Exams list, Exam Results, Subject Browse, Course/Subject detail) | ❌ Same defect on primary-text labels in `exam_list_screen.dart` and `exam_result_screen.dart`; secondary-text chevrons/codes in `subject_browse_screen.dart` and `course_detail_screen.dart` also hardcoded | 
| Calculator sheet (`exam_calculator_sheet.dart`) | ✅ Not a defect — its panel background is deliberately always white (`AppColors.surfaceWhite`, not theme-driven), so its dark-navy text is legible in both app themes by design. Left untouched |
| Exam runner in-progress screen (`exam_runner_screen.dart`) | ✅ Not a defect — `AppColors.textSecondary` there is used only for muted semantic state (unanswered-question chips, idle timer), not primary content, and isn't visually invisible against either theme's surfaces. Left untouched |
| `FeaturePlaceholder` (Performance / Study Plan tabs) | ✅ Already theme-aware, no change needed |
| `MaterialCard` | ✅ Already theme-aware, no change needed |

## Part 2 — JAMB Admin Integration (fix)

**Modified: `lib/features/admin/admin_dashboard_screen.dart`**

Added a "JAMB Subjects" tile, following the exact pattern already used
for WAEC and NECO — no new screen, no new repository, no new Firestore
collection:

```dart
_AdminModuleTile(
  title: 'JAMB Subjects',
  onTap: () => Navigator.push(context, MaterialPageRoute(
    builder: (_) => const SubjectManagerScreen(categoryId: 'jamb', categoryLabel: 'JAMB'),
  )),
)
```

`Admin Control Center → JAMB Subjects → JAMB subject CRUD` now works
through the same generic `SubjectManagerScreen` NECO already reuses
(see that screen's own doc comment, written in Stage 4.5/4.6).

## Part 3 — Dark Theme Text Visibility (fix)

Root cause: several screens called `AppTextStyles.bodyMedium(AppColors.textPrimary)`
(and `.textSecondary`) directly with the light-mode color constant,
instead of reading the active `Theme.of(context).textTheme` the way
`admin_dashboard_screen.dart` and `SubjectManagerScreen` already did.
`AppColors.textPrimary == AppColors.darkSurface`, so on dark-theme
cards this wasn't just poor contrast — the text color and the card
color were the same value.

Fix pattern used everywhere (reusing the existing abstraction, no new
color system introduced):

```dart
final labelColor = Theme.of(context).textTheme.headlineLarge?.color ?? AppColors.textPrimary;
final bodyColor = Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
```

Files modified:
- `lib/features/waec/waec_dashboard_screen.dart` — subtitle + tile labels
- `lib/features/neco/neco_dashboard_screen.dart` — subtitle + tile labels
- `lib/features/jamb/jamb_dashboard_screen.dart` — subtitle + tile labels
- `lib/features/university/university_dashboard_screen.dart` — quick-action cards, setup-profile card, institution card, course list tiles
- `lib/features/university/course_detail_screen.dart` — description text
- `lib/features/exam_prep/exam_list_screen.dart` — exam title, stat row
- `lib/features/exam_prep/exam_result_screen.dart` — pass-mark caption, time-taken row, topic-breakdown rows, stat-tile labels
- `lib/features/exam_prep/subject_browse_screen.dart` — subject code, chevron icon

Deliberately **not** touched: `exam_calculator_sheet.dart` (always-white
panel by design), `exam_runner_screen.dart` (muted semantic state
colors only, not the reported defect), and the University sub-browse
screens' secondary/chevron colors (`course_browse_screen.dart`,
`institution_browse_screen.dart`, `institution_detail_screen.dart`,
`widgets/academic_node_browser_screen.dart`) — these use
`AppColors.textSecondary`, which remains legible against both themes'
surfaces and was not part of the reported "labels disappear" defect.

## Part 10/11 — Master Project Integrity

**Files inspected:** `admin_dashboard_screen.dart`, `subject_manager_screen.dart`,
`app_colors.dart`, `app_theme.dart`, `app_text_styles.dart`,
`waec_dashboard_screen.dart`, `neco_dashboard_screen.dart`,
`jamb_dashboard_screen.dart`, `university_dashboard_screen.dart`,
`course_detail_screen.dart`, `subject_browse_screen.dart`,
`exam_list_screen.dart`, `exam_result_screen.dart`,
`exam_calculator_sheet.dart`, `exam_runner_screen.dart`,
`performance_placeholder_screen.dart`, `study_plan_placeholder_screen.dart`,
`feature_placeholder.dart`, `material_card.dart`, `app_routes.dart`,
`home_screen.dart`.

**Files modified:** the 9 files listed in Parts 2–3 above.

**Files created:** none (this changelog only).

**Files removed:** none.

Verified: JAMB/WAEC/NECO/University/Admin all still route correctly;
Community, Authentication, and global theme switching untouched; no
duplicate files, repositories, or Firestore collections introduced; no
unrelated features modified; CBT remains the existing placeholder.
