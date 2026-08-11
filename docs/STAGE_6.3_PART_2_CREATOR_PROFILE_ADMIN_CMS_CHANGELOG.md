# Stage 6.3 Part 2 — Creator Profile Admin CMS

Continuation of the single EduSphere master project. Extends the Creator
Profile system Part 1 built; nothing was rebuilt or replaced.

## Audit findings (before coding)

Reviewed the existing Part 1 implementation first:

| Piece | Status | Decision |
|---|---|---|
| `CreatorProfileModel`, `CreatorSkillModel`, `CreatorAchievementModel`, `CreatorDocumentModel`, `CreatorProjectModel` | Existed, read-only fields | Extend additively — see "Data architecture" |
| `CreatorProfileRepository` | Existed — `watch`/`fetch`/`save` on the singleton doc only, no per-item CRUD for the four list collections | Extend with CRUD/publish/reorder/upload methods, all audited |
| `firestore.rules` / `storage.rules` | Already had public-read / admin-only-write rules for every `creator_*` collection and `creator_profile/**` storage path | **No security changes required** |
| `StoragePaths` | Already had `creatorProfileImage`, `creatorCoverImage`, `creatorDocument`, `creatorProjectImage` builders | Reused as-is |
| `StorageService` | Had `uploadFile`/`deleteFile` (by path); no delete-by-URL | Added one method, `deleteByUrl` — see below |
| `AuditLogService` / `AuditModules.creatorProfile` | Module constant already existed, unused | Wired every mutation through `logCreate`/`logEdit`/`logDelete`/`logPublish`/`logUnpublish`/`logUpload` |
| Admin Dashboard | Existing grid-of-modules shell (Stage 3.5) | Added one tile — no second dashboard |
| Public `creator_profile_screen.dart` | Rendered every skill/achievement/project/document unconditionally | Added client-side `isPublished` filtering per section (see below) |
| `firestore.indexes.json` | Composite indexes exist for other equality+orderBy queries | **Not touched** — deliberately avoided a schema/index change (see below) |

No duplicate models, repositories, Firebase collections, storage systems, or
audit systems were created.

## Data architecture

Each of the four list models gained one additive field:

```
isPublished: bool (default true)
```

Default `true` means every item Part 1 already wrote reads as published
without a migration. This single field serves both "enable/disable" (§3)
and "publish/unpublish" (§4, §5, §6) — the spec uses both terms for the
same concept per collection, so one field covers it rather than two
redundant booleans.

**Filtering approach:** rather than adding a `.where('isPublished', '==',
true)` clause to each repository's public-facing query (which would need
a new Firestore composite index per collection — `isPublished` + `sortOrder`
— since equality-then-orderBy on different fields requires one), the
public `CreatorProfileScreen` reads the same `watchAll()` stream the Admin
manager uses and filters `isPublished` client-side. These lists are small
(a handful of skills/achievements/projects/documents), so this is the
smaller, lower-risk change — no `firestore.indexes.json` edit, no deploy
step, one repository method serves both the public page and the admin
manager.

`CreatorProfileModel.isPublished` (the master switch, already defined by
Part 1, default `false`) is unchanged in shape — Part 2 just adds the UI
to flip it (`CreatorProfileRepository.setPublished`) and surfaces it as a
"Publishing" card at the bottom of the CMS hub.

## Files created

- `lib/features/admin/creator_profile/creator_profile_management_screen.dart` — CMS hub (7 section tiles + Publishing card)
- `lib/features/admin/creator_profile/creator_profile_info_editor_screen.dart` — name/title/introduction + profile picture/cover image upload-replace-remove
- `lib/features/admin/creator_profile/creator_biography_editor_screen.dart` — about/mission/vision/journey
- `lib/features/admin/creator_profile/creator_contact_editor_screen.dart` — email/website + dynamic social links list
- `lib/features/admin/creator_profile/creator_skills_manager_screen.dart` — add/edit/delete/reorder/enable-disable
- `lib/features/admin/creator_profile/creator_achievements_manager_screen.dart` — same, plus category/date
- `lib/features/admin/creator_profile/creator_projects_manager_screen.dart` — list + reorder/publish/delete
- `lib/features/admin/creator_profile/creator_project_editor_screen.dart` — full-screen editor (image upload, technologies, links) for one project
- `lib/features/admin/creator_profile/creator_documents_manager_screen.dart` — upload flow (select → upload → progress → save metadata → publish), replace file, delete, reorder
- `docs/STAGE_6.3_PART_2_CREATOR_PROFILE_ADMIN_CMS_CHANGELOG.md` — this file

## Files modified

- `lib/models/creator_profile_model.dart` — added `isPublished` + `copyWith` to the four list models; added `copyWith` to `CreatorProfileModel`
- `lib/repositories/creator_profile_repository.dart` — added full CRUD, publish/unpublish, reorder, and image/document upload methods to all five repository classes, every mutation audited
- `lib/repositories/base_repository.dart` — added one generic `reorderSortOrder()` batch-write method, reusable by any collection with a `sortOrder` field
- `lib/services/firebase/storage_service.dart` — added `deleteByUrl()` (translates a stored download URL to a deletable Storage ref) for best-effort cleanup on replace/remove
- `lib/features/creator_profile/creator_profile_screen.dart` — filters `isPublished` client-side in each section (skills/achievements/projects/documents)
- `lib/features/admin/admin_dashboard_screen.dart` — added the "Creator Profile" tile

## Admin features delivered

- Profile info: name, title, introduction — text fields; profile picture and cover image — upload / replace / remove, saved immediately, old file cleaned up from Storage on replace/remove
- Biography: about me, mission, vision, journey — free-form multiline, no length cap
- Skills: add / edit / delete / drag-to-reorder / enable-disable
- Achievements: same, plus category and optional date
- Projects: add / edit / delete / drag-to-reorder / publish-unpublish, with image upload, comma-separated technologies, and website/repository links
- Documents: upload (select → upload with progress → save metadata) / replace file / edit title & description / delete / drag-to-reorder / publish-unpublish
- Contact & Social Links: email, website, and an arbitrary label→URL list of social links
- Publishing: master switch on the CMS hub controlling whether the public page renders at all (existing `hasContent` gate on the public screen), plus a per-item switch on every skill/achievement/project/document

## Security

No `firestore.rules` or `storage.rules` changes — Part 1's public-read /
admin-only-write rules already cover every collection and path this stage
writes to. Verified the admin screens go through
`CreatorProfileRepository`/`CreatorSkillRepository`/etc. exclusively — no
direct Firestore or Storage calls from any screen.

## Audit logging

Every create, edit, delete, publish/unpublish, and upload — across the
singleton profile doc and all four list collections — logs through
`AuditLogService.instance`, using the existing `create`/`edit`/`delete`/
`publish`/`unpublish`/`upload` action types and the existing
`AuditModules.creatorProfile` module constant. Reordering logs a single
`edit` entry per operation ("Reordered skills", etc.) rather than one
entry per item, since it's one user action.

## Theme & responsiveness

All new screens use `AppColors`/`AppTextStyles`/`CustomCard`/`AppTextField`/
`PrimaryButton`/`SecondaryButton`/`AppSnackbar`/`AppDialog`/`LoadingView`/
`EmptyView` — the existing design system — with no hardcoded colors, so
light/dark/system theme is inherited automatically. Layout uses
`ListView`/`ReorderableListView` with standard padding, matching the
existing admin screens (e.g. `AdminLearningMaterialsScreen`,
`MaterialEditorScreen`) for touch-friendly, scroll-safe mobile UX.

## Verification

Checked against the project's actual source (no Flutter toolchain
available in this environment, so this is a manual code-level review, not
a compiled/run test):

- Confirmed every constant, path builder, and method signature referenced
  by the new screens (`AppConstants.creator*`, `StoragePaths.creator*`,
  `AuditLogService.log*`, `StorageService.uploadFile`, `Result`/`Success`/
  `Failure`, `AppTextField`/`PrimaryButton`/`SecondaryButton`/`AppDialog`/
  `AppSnackbar`/`LoadingView`/`EmptyView` constructors) exists with the
  exact name and parameters used, by reading the real source files rather
  than assuming.
- Confirmed no duplicate model, repository, Firebase collection, admin
  dashboard, or audit system was introduced.
- Confirmed the public page's existing empty-state behavior (`hasContent`,
  per-section `if (items.isEmpty) return const SizedBox.shrink()`) is
  unchanged — unpublished items now simply don't reach that check.
- Did not verify: a live Firebase project (upload success, security rule
  evaluation, Firestore data) and a Flutter build/run, since neither
  toolchain nor network access is available here. This should be smoke-
  tested against a real project before shipping.

## Deferred (intentionally, per the stage boundary)

Marketplace, Scholarship system, Question Bank redesign, CBT
modifications, and bulk learning materials — none of these were touched
or started. Stage 6.3 Part 2 is complete and self-contained.
