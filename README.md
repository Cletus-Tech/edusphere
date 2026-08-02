# EduSphere

**Learn. Connect. Succeed.**

A premium educational ecosystem for university, polytechnic, and college
students — with JAMB/WAEC/NECO prep, CBT practice, AI tutoring, and a
student community, all under one roof.

This README covers setup and the high-level architecture. For what's
actually been built stage by stage, see `docs/ARCHITECTURE.md` (the
living source of truth) and the individual `docs/STAGE_*_CHANGELOG.md`
files — most recently `STAGE_3.5_LEARNING_MATERIALS_CHANGELOG.md`
(the real content library — replaces the flat Stage 1 placeholder
described lower in this file) and `STAGE_3.6.2_CHANGELOG.md` (admin
audit logging). The Learn tab, Admin Dashboard (reachable from Profile
for staff/admin accounts), and Firebase security rules are live, not
placeholders, as of Stage 3.5.

## Stage 1.1 — Foundation Audit
A cleanup pass over the Stage 1 foundation before any new features are
added. No screens, routes, or Firebase integration were redesigned —
only fixed and polished:
- Removed a malformed leftover directory chain under `lib/` and
  `assets/` (an artifact of the original scaffolding script), and
  created the real `assets/images/` and `assets/fonts/` folders the
  pubspec and README reference.
- Trimmed 7 unused dependencies (`flutter_svg`, `cached_network_image`,
  `shimmer`, `lottie`, `fl_chart`, `connectivity_plus`, `intl`) that
  were declared but never imported.
- Filled out the reusable component set the design system calls for:
  `SearchField`, `SectionHeader`, `AppAvatar`, `AppBadge`, `AppChip`,
  `AppDialog`, `AppBottomSheet` — and wired the real ones into Home
  and Profile in place of inline, one-off duplicates.
- Added missing accessibility tooltips on icon-only buttons.
- Removed leftover `debugPrint`/`print` calls from Firebase init and
  messaging setup.

## Getting started

```bash
flutter pub get

# Connect this project to your real Firebase project (overwrites the
# placeholder keys in lib/services/firebase/firebase_options.dart):
dart pub global activate flutterfire_cli
flutterfire configure

# Link the Firebase CLI itself (needed to deploy firestore.rules/
# storage.rules/firestore.indexes.json via `firebase deploy`):
firebase use --add

flutter run
```

Until `flutterfire configure` is run, the app still launches — Firebase
init failures are caught at startup (see `main.dart`) so the splash,
onboarding, theming, and navigation are testable without a live backend.
Auth, Firestore, Storage, and Messaging calls will fail gracefully with
the "no internet / please try again" style messages from
`core/utils/result.dart` until real keys are in place.

### Google Sign-In
`flutterfire configure` handles most of it, but Google Sign-In also needs:
- **Android**: SHA-1/SHA-256 fingerprints added in the Firebase console.
- **iOS**: the reversed client ID URL scheme added to `Info.plist`.

### Fonts
`google_fonts` fetches Poppins at runtime by default (fine for
development). For an offline/production build, download the Poppins
`.ttf` files into `assets/fonts/`, uncomment the `fonts:` block in
`pubspec.yaml`, and swap `GoogleFonts.poppins(...)` calls in
`theme/app_text_styles.dart` for `fontFamily: 'Poppins'`.

### Illustrations
The mockups' custom character illustrations (the student on the book
stack, etc.) aren't included as image assets — splash and onboarding
use icon-based compositions in the same brand colors as a stand-in.
Drop your exported illustration PNGs/SVGs into `assets/images/` and
swap them into `splash_screen.dart` / `onboarding/widgets/onboarding_page.dart`
when ready.

## Architecture

```
lib/
├── main.dart              # Firebase init + app bootstrap
├── app.dart                # MaterialApp, theming, route table
├── theme/                  # Colors, type scale, ThemeData, theme_provider
├── core/
│   ├── constants/          # App strings, Firestore collection names, spacing
│   ├── enums/                # UserRole, AuditActionType, LearningMaterialType, ...
│   ├── routes/              # Named route table
│   └── utils/                # Validators, Result<T> wrapper, error messages
├── models/                  # UserModel, LearningMaterialModel, CourseModel, ...
├── repositories/            # One per collection — BaseRepository<T> subclasses;
│                             # the only layer that talks to Firestore queries
├── services/
│   ├── firebase/            # AuthService, FirestoreService, StorageService,
│   │                         # MessagingService — every Firebase call goes
│   │                         # through here, never called directly from UI
│   ├── audit/                # AuditLogService — every admin action logs here
│   ├── upload/                # UploadEngine — the shared upload queue (progress/
│   │                         # retry/cancel/dedup) every feature uploads through
│   ├── config/                # BrandingService, FeatureFlagService, DashboardConfigService
│   └── migration/             # LearningContentMigrationService (Stage 3.5)
├── shared/widgets/          # PrimaryButton, AppTextField, CustomCard,
│                             # LoadingView/ErrorView/EmptyView, AppSnackbar
└── features/
    ├── splash/
    ├── onboarding/
    ├── auth/                 # login, register, forgot password
    ├── home/                 # home_shell (bottom nav) + home_screen
    ├── learn/                 # LearningLibraryScreen + Material detail/cards
    ├── community/             # placeholder — not built yet
    ├── ai_tutor/               # placeholder — not built yet
    ├── admin/                  # Admin Dashboard, Learning Materials CMS, Audit Log
    └── profile/                # includes the Admin Dashboard entry point (staff only)
```

**Why it's built this way:**
- **`Result<T>`** (`core/utils/result.dart`) — every service call returns
  success or a user-readable failure message. No silent failures, no
  raw exceptions reaching the UI.
- **Services own Firebase** — screens never touch `FirebaseAuth.instance`
  or `FirebaseFirestore.instance` directly, so swapping implementations
  or writing tests later doesn't touch UI code.
- **One feature = one folder** — Learn, Community, AI Tutor, and Profile
  are independent modules today. CBT, Marketplace, and Scholarships can
  be dropped in as new folders under `features/` without touching
  existing ones.
- **Centralized Firestore collection names** (`core/constants/app_constants.dart`)
  — including placeholders for `schools`, `exam_boards`, `cbt_questions`,
  `marketplace`, and `scholarships` — so future modules don't invent
  their own naming.

## Theming
Light, Dark, and Follow System are switchable at runtime from the
Profile tab (`ThemeProvider`, backed by `shared_preferences` so the
choice persists across restarts) — no rebuild required.

## What's next
CBT engine, JAMB/WAEC/NECO question banks (both can build directly on
`LearningMaterialModel`'s academic-structure fields), real Community
and AI Tutor functionality, Marketplace, Scholarships. See
`docs/STAGE_3.5_LEARNING_MATERIALS_CHANGELOG.md`'s "Next recommended
stage" for the current recommendation.
