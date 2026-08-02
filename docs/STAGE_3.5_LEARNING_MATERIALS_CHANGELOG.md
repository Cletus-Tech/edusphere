# Stage 3.5 — Complete Learning Materials Module Implementation

Implements the full spec: data model, repository, storage integration,
student Learning Library, Admin CMS, audit integration, security rules,
and a controlled migration off the Stage 1 `learning_content` system —
with no two parallel content libraries left running.

## Files created

**Enums**
- `lib/core/enums/learning_material_type.dart` — `LearningMaterialType`
  (pdf/video/image/audio/document/presentation/archive/link/richText),
  each with `label`/`icon`/`color`/`extensions`/`fromExtension`.
- `lib/core/enums/material_publication_status.dart` —
  `MaterialPublicationStatus` (draft/published/scheduled/archived) and
  `MaterialVisibility` (everyone/institutionOnly/courseOnly).

**Model**
- `lib/models/learning_material_model.dart` — `LearningMaterialModel`.

**Repository**
- `lib/repositories/learning_material_repository.dart` —
  `LearningMaterialRepository`.

**Migration**
- `lib/services/migration/learning_content_migration_service.dart` —
  `LearningContentMigrationService`, `MigrationReport`.

**Student UI**
- `lib/features/learn/learning_materials/learning_library_screen.dart`
- `lib/features/learn/learning_materials/material_detail_screen.dart`
- `lib/features/learn/learning_materials/widgets/material_card.dart`

**Admin CMS**
- `lib/features/admin/learning_materials/admin_learning_materials_screen.dart`
  (already referenced by `admin_dashboard_screen.dart` — this stage
  supplies the missing file, not a new reference)
- `lib/features/admin/learning_materials/material_editor_screen.dart`

**Docs**
- `docs/STAGE_3.5_LEARNING_MATERIALS_CHANGELOG.md` (this file)

## Files modified

- `lib/core/constants/app_constants.dart` — `learningMaterialsCollection`
  doc comment updated; `learningContentCollection` now documented as
  deprecated (value unchanged).
- `lib/core/constants/storage_paths.dart` — added
  `learningMaterialFile`/`learningMaterialThumbnail`/`learningMaterialBanner`.
- `lib/models/learning_content_model.dart` — added a `DEPRECATED` doc
  comment; no field/behavior changes.
- `lib/repositories/learning_repository.dart` — added a `DEPRECATED`
  doc comment on `LearningContentRepository`; no field/behavior changes.
- `lib/features/learn/learn_screen.dart` — now renders
  `LearningLibraryScreen` instead of `FeaturePlaceholder`.
- `lib/main.dart` — added `UploadEngine.instance.start()` at launch
  (the method already existed; nothing called it before this stage).
- `pubspec.yaml` — added `file_picker: ^8.1.2` for the admin uploader.
- `firestore.rules` — added the `learning_materials` match block;
  `learning_content`'s block kept, now commented as deprecated.
- `storage.rules` — added `learning_materials/{allPaths=**}`;
  `learning_content/{allPaths=**}` kept, now commented as deprecated.
- `docs/ARCHITECTURE.md` — added a "Stage 3.5 — Learning Materials
  Module" section, resolving the "Learning Materials (Part 1) —
  re-pointing note" left by Stage 3.6.2's audit-integration work.

## Firestore changes

New collection `learning_materials/{materialId}` — see
`LearningMaterialModel.toMap()`/`.fromMap()` for the exact schema.
Composite indexes will be needed the first time each multi-`.where()`
query combination runs in `LearningMaterialRepository.watchMaterials`/
`watchAllForAdmin`/`filterMaterials` — Firestore surfaces a console
link to create them on first run, same as every other multi-filter
query already in this codebase (see `ARCHITECTURE.md`'s general note
on this).

`learning_content/{contentId}` documents gain one new field on
migration: `migratedTo` (the new `learning_materials` document id) —
nothing else about the legacy documents changes.

## Storage changes

New paths: `learning_materials/{materialId}/files/{fileName}`,
`learning_materials/{materialId}/thumbnail/{fileName}`,
`learning_materials/{materialId}/banner/{fileName}`. No existing
Storage objects moved or renamed — migrated materials keep pointing at
their original `learning_content/...` file URLs.

## Security changes

- `firestore.rules`: `learning_materials` — staff (`isStaff()`) full
  read/write; a signed-in, non-suspended student can read only where
  `status == 'published' && isDeleted != true`; hard `delete` requires
  `isAdmin()` (ordinary admin action is soft-delete via `update`,
  handled entirely client-side by `softDeleteMaterial`).
- `storage.rules`: `learning_materials/{allPaths=**}` — read requires
  sign-in, write requires the `isStaffClaim()` custom claim, matching
  every other staff-authored Storage path in this file.

## UI screens added

- **Learn tab** → `LearningLibraryScreen` (search, type filters, live
  grid) → `MaterialDetailScreen` (preview, download/open, records
  view/download analytics).
- **Admin Dashboard → Learning Materials** → `AdminLearningMaterialsScreen`
  (search, status filter, multi-select bulk archive, per-item action
  sheet, "migrate legacy content") → `MaterialEditorScreen`
  (create/edit, file/thumbnail/banner upload with live progress,
  scheduling, visibility).

## Audit integration

Every `LearningMaterialRepository` write path logs through the
existing `AuditLogService`, `module: AuditModules.learningMaterials`:
`createMaterial`→`logCreate`, `updateMaterial`→`logEdit`,
`publishMaterial`→`logPublish`, `unpublishMaterial`→`logUnpublish`,
`archiveMaterial`→`logArchive`, `restoreMaterial`→`logRestore`,
`duplicateMaterial`→`logDuplicate`, `softDeleteMaterial`→`logDelete`,
file/thumbnail/banner upload→`logUpload` (or `logEdit` for a
*replace*), download→`logDownload` (from `incrementDownload`).
Migration writes also log, tagged with one shared `operationId` per
run so a bulk migration groups in the Audit Log screen.

## Known limitations

- **No server-side scheduler.** `MaterialPublicationStatus.scheduled`
  items only flip to `published` when `publishDueScheduled()` runs
  client-side (called from both the Library and Admin list on open).
  A scheduled item won't go live at the exact scheduled minute if no
  one opens either screen — a Cloud Function on a timer is the correct
  fix once this project has Cloud Functions.
- **Course picker is a flat list.** `MaterialEditorScreen`'s "Browse
  courses" pulls up to 50 `CourseModel`s with no department/level
  pre-filter. Fine for the current catalog size; revisit if it grows.
- **No in-app file preview.** Downloading/opening a material hands off
  to the platform's default handler via `url_launcher`
  (`UrlLauncherAdapter`) rather than rendering a PDF/video/audio player
  in-app — matches what `MaterialDetailScreen`'s doc comment describes;
  an embedded viewer is a reasonable next-stage addition.
- **Composite indexes not pre-created.** As noted above, the first run
  of each filter combination needs a one-time index creation via the
  Firebase Console link Firestore returns.

## Verification performed

Every new/modified file was checked by hand against the existing
codebase's conventions (`Result<T>`, `BaseRepository<T>`,
`FirestoreModel`/`FirestoreConvert`, `UploadEngine`, `AuditLogService`,
the shared widget library, `AppColors`/`AppTextStyles`/`AppRadius`) —
symbol-by-symbol, including re-reading `base_repository.dart`,
`result.dart`, `audit_action_type.dart`, `course_model.dart`,
`content_type.dart`, and `learning_content_model.dart` to confirm
every field/method name and signature referenced from the new files.
**No emulator or `flutter analyze` run was possible in this
environment** (no Flutter SDK/network available) — treat this as
hand-verified, not compiler-verified. Run `flutter pub get && flutter
analyze` before merging.

## Next recommended stage

CBT Practice / Past Questions, building on `courseId`/academic
structure fields this stage already put in place on
`LearningMaterialModel` — per the original Stage 3.5 prompt's
instruction not to move to Community, AI, or CBT expansion until this
foundation was complete.
