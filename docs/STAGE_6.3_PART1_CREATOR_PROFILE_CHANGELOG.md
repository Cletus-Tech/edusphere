# Stage 6.3 — Creator Profile / About Owner Module — Part 1

Part 1 = data model, repositories, security rules, and the public
read-only page. Part 2 (not started, per the brief's own "stop after
Part 1 unless told otherwise" spirit and the earlier audit's proposed
split) = the admin management screens for full CRUD on all 7 sections.

## Audit performed before coding (this is what the previous message's
"Go ahead" was confirming)

- No existing creator/about/owner/founder/portfolio concept anywhere
  in the codebase — confirmed via grep before naming anything, so this
  is genuinely new, not a rename/reuse situation.
- `AppSettingsRepository` already has the exact pattern needed for the
  profile singleton doc (fixed-id doc, `watch`/`save`, not a
  `BaseRepository<T>`) — reused that shape instead of inventing one.
- **Found a real naming collision risk and avoided it**:
  `AppConstants.achievementsCollection` ('achievements') already
  exists for student gamification (`AchievementModel` /
  `AchievementRepository` in `engagement_repository.dart`). Named this
  module's collection `creator_achievements` instead of reusing
  `achievements` — reusing it would have silently mixed two unrelated
  document shapes in one collection.
- `AdminAppSettingsScreen`'s 3-tab structure (Feature Flags / Banners
  / Uploads & App) is too lightweight for 7 CRUD sections — Part 2
  should follow `admin_dashboard_screen.dart`'s tile-to-own-screen
  pattern instead (same as Academic Structure, Users, Moderation),
  not get crammed into that tab bar.
- `profile_screen.dart` already had the right entry-point pattern
  (`_ProfileTile` + `onTap` + `MaterialPageRoute`, exactly how
  "Academic Profile" is wired) — reused it verbatim rather than adding
  a named route.
- **Mid-build correction**: this zip is a different branch than the
  one a separate session's B6/B7/B8 visual-beautification work was
  built on — it never received those stages' color tokens or
  `CustomCard`'s `accentColor` param. Caught this by re-verifying every
  widget/API against *this actual codebase* rather than assuming
  parity with the other branch, and fixed two mistakes before they
  shipped: `AppColors.premiumGold` (doesn't exist here — swapped to
  the existing `highlightOrange`) and `CustomCard(accentColor: ...)`
  (this branch's `CustomCard` has no such param — removed, achievement
  cards use a plain `CustomCard` with just the trophy icon tinted).

## What this part adds

**`lib/models/creator_profile_model.dart`** (new)
- `CreatorProfileModel` — singleton doc (name, title, images, intro,
  biography, mission, vision, journey, email, website, socialLinks,
  `isPublished`). Every field defaults to empty, never placeholder
  copy, per "nothing hardcoded." `hasContent` getter (published +
  has a name/intro) is what the public screen uses to decide between
  the real page and a genuine empty state.
- `CreatorSkillModel`, `CreatorAchievementModel`,
  `CreatorDocumentModel`, `CreatorProjectModel` — one collection each,
  each with a `sortOrder` for admin reordering (Part 2).

**`lib/repositories/creator_profile_repository.dart`** (new)
- `CreatorProfileRepository` — `watch()`/`fetch()`/`save()` on the
  singleton doc, audit-logged via the existing generic
  `AuditLogService.log()` (action `edit`, module `creatorProfile`).
- `CreatorSkillRepository`/`CreatorAchievementRepository`/
  `CreatorDocumentRepository`/`CreatorProjectRepository` — each a real
  `BaseRepository<T>`, `watchAll()` ordered by `sortOrder`.

**`lib/core/constants/app_constants.dart`** — 5 new collection/doc
constants (see naming-collision note above).

**`lib/core/constants/storage_paths.dart`** — `creatorProfileImage`,
`creatorCoverImage`, `creatorDocument`, `creatorProjectImage` helpers,
following the file's existing one-named-function-per-upload-type
convention.

**`lib/core/enums/audit_action_type.dart`** —
`AuditModules.creatorProfile` added to the module list.

**`firestore.rules`** — `creator_profile`/`creator_skills`/
`creator_achievements`/`creator_documents`/`creator_projects`: public
read (`if true` — this is a public About page, same as `communities`),
admin-only write (`isAdmin()`).

**`storage.rules`** — new `isAdminFirestore()` helper: stricter than
the existing `isStaffFirestore()` (superAdmin/admin only, not the full
staff list), because the owner's personal CMS shouldn't be editable by
every lecturer/contentCreator role the way course content is. Mirrors
`firestore.rules`' own `isAdmin()` exactly, same cross-service
`firestore.get()` approach and same cached-document budget
`isStaffFirestore()` already uses. `creator_profile/**` path: public
read, `isAdminFirestore()` write.

**`lib/features/creator_profile/creator_profile_screen.dart`** (new)
— the public page. Hero (cover/avatar/name/title/intro), Story
(biography/mission/vision/journey), Skills (chips), Achievements
(cards), Projects (cards with tech-tag chips), Documents (tappable
list, opens `downloadUrl` via the existing `UrlLauncherAdapter`),
Contact (email/website/social action chips). Every section is
conditionally rendered — a section with no data renders nothing rather
than an empty header. Whole screen shows `LoadingView`/`EmptyView` via
the existing `state_views.dart` while data loads or before a profile
is published — no hardcoded fallback text anywhere.

**`lib/features/profile/profile_screen.dart`** — one new tile ("About
EduSphere") between Help & Support and Logout, wired exactly like the
Academic Profile tile already was.

## What this part does NOT include (Part 2)

- Any admin UI — no way to actually edit the profile/skills/
  achievements/documents/projects yet. Every repository method needed
  to build that (`save`, `BaseRepository`'s inherited create/update/
  delete) already exists; only the screens are missing.
- Image/document upload flow wiring (the `StoragePaths` helpers exist;
  no screen calls `StorageService.uploadFile` with them yet).
- Drag-to-reorder for skills/achievements/projects (`sortOrder` field
  exists; nothing writes to it yet).
- `admin_dashboard_screen.dart` — no new tile added yet; deferred
  until Part 2's management screen actually exists to link to (an
  admin tile pointing at nothing would be worse than no tile).

## Validation performed

- Brace/paren balance check on every new/edited Dart file, plus
  `firestore.rules`/`storage.rules` (all passed).
- `firestore.indexes.json` re-validated as unchanged/valid JSON — no
  composite indexes needed since every new query is a single-field
  `orderBy('sortOrder')`, which Firestore auto-indexes.
- Every widget/method call in the new screen cross-checked against
  this branch's actual source (not assumed from another session's
  branch) — see the mid-build correction above.
- No Flutter SDK available — static read-through and mechanical
  balance-check only, not a compiler guarantee.

## Next

Part 2 — Admin Creator Profile Management (tile on
`admin_dashboard_screen.dart` + its own screen with full CRUD for all
7 sections, upload wiring, reordering).
