# EduSphere Backend Architecture — Stage 1.2

This document explains the backend/data layer added in Stage 1.2. It does
not change any screen, theme, or navigation flow from Stage 1 — it adds
the persistence, configuration, and access-control foundation those
screens will read from as each module (CBT, Marketplace, Scholarships,
Parents Portal, etc.) goes from "planned" to "built".

## Golden rule

> Nothing an administrator may reasonably want to change in the future
> should be hardcoded.

Feature availability, branding, dashboard layout, institutions, courses,
categories, AI settings, community settings, and notification templates
all live in Firestore under admin-writable collections, not in Dart
constants or `if` statements. The `settings`, `feature_flags`, and
`banners` collections exist specifically so a future "EduSphere Control
Center" admin panel can change any of this without an app store release.

## Layers

```
UI (screens/widgets)
   │  never talks to Firebase directly
   ▼
Repositories (lib/repositories/*)
   │  one per Firestore collection or config surface
   │  typed models in, typed models out, Result<T> for outcomes
   ▼
Services (lib/services/firebase/*, lib/services/config/*)
   │  thin Firebase wrappers + long-lived config caches
   ▼
Firebase (Auth, Firestore, Storage, FCM)
```

UI widgets should depend on a repository or config service, never on
`FirebaseFirestore.instance` / `FirebaseAuth.instance` / raw storage
paths. This was already true for auth in Stage 1 (`AuthService`); Stage
1.2 extends the same discipline to every other collection.

## Firestore collections

All collection names are centralized in `lib/core/constants/app_constants.dart`
— that file is the single source of truth; nothing should reference a raw
string literal.

| Domain | Collections |
|---|---|
| Identity & structure | `users`, `institutions`, `faculties`, `departments`, `levels`, `semesters` |
| Learning | `courses`, `subjects`, `categories`, `learning_content`, `exams`, `questions` |
| Community | `communities`, `posts`, `comments`, `reactions`, `bookmarks` |
| Engagement | `notifications`, `achievements`, `badges`, `leaderboard` |
| AI, moderation, insight | `ai_history`, `reports`, `analytics` |
| Remote configuration | `settings` (`branding`, `dashboard`, `app_config` docs), `banners`, `feature_flags` |

`faculties`/`departments`/`levels`/`semesters` share one shape
(`AcademicNodeModel`) linked by `parentId`, so the academic tree for a
university, polytechnic, college of education, or secondary school is
the same four collections — no per-institution-type schema fork.

`courses` and `subjects` likewise share `CourseModel`: tertiary courses
set `departmentId`/`levelId`/`semesterId`; secondary/exam-board subjects
set `categoryId` instead. One model, one query pattern, two collections
for independent security rules and indexes.

`questions` are never embedded inside an `exams` document — an exam can
have thousands of questions, and Firestore documents have a 1MB limit.
`QuestionRepository.fetchPageForExam` pages through them by `examId`.

## Roles (RBAC)

`lib/core/enums/user_role.dart` defines: `superAdmin`, `admin`,
`institutionAdmin`, `lecturer`, `teacher`, `student`, `parent`,
`contentCreator`, `moderator`, `guest`. `UserModel.roles` is a `Set`, so
a user can hold more than one (e.g. `student` + `contentCreator`).

Client-side role checks (`UserRole.isElevated`, `UserModel.hasRole`) are
**UI convenience only** — they control what's shown, not what's allowed.
The real boundary is `firestore.rules` / `storage.rules`, which re-derive
the same roles server-side from the caller's `users/{uid}` document (or,
for Storage, from a custom auth-token claim kept in sync by a Cloud
Function whenever a user's Firestore role changes).

## Feature flags

`feature_flags/{featureKey}` documents (canonical keys in
`FeatureKeys`) gate every module: AI Tutor, Community, Marketplace,
Scholarships, JAMB, WAEC, NECO, CBT, Parents Portal, Professional Exams.
A flag can be globally on/off, or scoped to specific
`enabledForInstitutionIds`. `FeatureFlagService` caches the latest
snapshot for synchronous `isEnabled()` checks and exposes a stream for
reactive UI. Missing flag docs default to **enabled** (fail-open) so a
newly-added module isn't accidentally hidden because nobody created its
flag document yet — disabling is always an explicit admin action.

## Dynamic branding & dashboard

`settings/branding` drives app title, tagline, logo, splash image, and
primary/secondary/accent colors. `settings/dashboard` drives the home
dashboard's cards (feature tiles, quick actions, recommended/trending
content), plus pinned and hidden module keys.
`DashboardConfigService.visibleCards()` combines dashboard config with
live feature flags so a card for a disabled module never renders, even
if an admin forgot to also hide it.

Both services are started once in `main.dart` (`FeatureFlagService`,
`BrandingService`, `DashboardConfigService` `.start()` calls) right after
Firebase initializes, so their caches are warm before any screen needs
them — no new screens read from them yet in Stage 1.2, that's Stage 1's
UI layer catching up in a later stage.

## Storage layout

`lib/core/constants/storage_paths.dart` is the only place that builds a
Cloud Storage path (`users/`, `institutions/`, `notes/`, `videos/`,
`documents/`, `assignments/`, `images/`, `community/`, `avatars/`,
`banners/`, `certificates/`, `downloads/`, `marketplace/`).
`StorageRepository` wraps `StorageService` with these helpers so upload
call sites never hand-assemble a path string.

## Error handling

`lib/core/errors/app_exception.dart` adds `AppException`/`AppErrorType`
on top of Stage 1's `Result<T>` + `friendlyErrorMessage()` (kept as-is
for backward compatibility). `AppException.from(error)` maps
`FirebaseAuthException`, Firestore/Storage `FirebaseException` codes,
and network failures to one of: `network`, `authentication`,
`permission`, `notFound`, `storage`, `validation`, `unknown` — so
repositories return a `Result.failure` with a message that's both
categorized (for logic) and human-readable (for display) in one step
(`resultFailureFrom`).

## Offline & sync (prepared, not implemented)

Repositories go through `FirestoreService`/`BaseRepository`, which is
the seam where offline persistence (`Settings(persistenceEnabled: true)`)
and conflict handling will be added later without touching call sites.
Not enabled in Stage 1.2 per the brief ("prepare... do not fully
implement sync yet").

## Analytics (prepared, not implemented)

`analytics/{docId}` snapshots (`AnalyticsSnapshotModel`) are read-only
from the app's side — `AnalyticsRepository` has no write path. They're
meant to be written by trusted backend jobs (Cloud Functions) aggregating
daily users, course usage, downloads/uploads, community activity, AI
usage, exam statistics, and storage usage. `firestore.rules` denies
client writes to this collection outright.

## Adding a future module

1. Add its collection name(s) to `AppConstants`.
2. Add a model implementing `FirestoreModel`.
3. Add a repository extending `BaseRepository<YourModel>`.
4. Add its key to `FeatureKeys` and create a `feature_flags/{key}` doc.
5. Add match blocks to `firestore.rules` (and `storage.rules` if it
   uploads files).
6. Build the screen against the repository — never against
   `FirebaseFirestore.instance` directly.

No existing collection, model, or repository needs to change for this —
that's the scalability guarantee this stage was built for.

## Stage 1.3 — Foundation Finalization & Production Readiness

Stage 1.3 hardens the Stage 1.2 foundation for production and adds a
handful of cross-cutting services every future module will reuse. No
user-facing Learning module work happens here.

**Audit fix.** `core/utils/result.dart`'s `Result.success`/
`Result.failure` factories are called with `const` throughout the
codebase (`auth_service.dart`, `storage_service.dart`, ...) but weren't
declared `const factory`, which does not compile. Fixed by adding
`const` to both factory declarations.

**Firebase production hardening.** `FirestoreService` now wraps every
one-shot read/write in `_withRetry`: a 12s timeout plus up to 3 attempts
with backoff for transient errors (`unavailable`, `deadline-exceeded`,
`aborted`). Permission/validation errors are never retried. Streams are
left as-is — Firestore's own offline cache already keeps `snapshots()`
alive and replays on reconnect. `core/utils/network_monitor.dart`
(`NetworkMonitor.instance`, backed by `connectivity_plus`) gives the UI
a synchronous `isOnline` flag and an `onStatusChange` stream so screens
can show an offline state instead of a raw exception.

**Logging.** `core/utils/app_logger.dart` (`AppLogger`) is the single
logging entry point — `debug`/`info`/`warning`/`error`/`firebase`/
`analytics`. Debug/info logs are silenced in release builds
(`kReleaseMode`); errors always log. `avoid_print` stays enabled in
`analysis_options.yaml` — nothing should call `print()`/`debugPrint()`
directly.

**Smart Links Engine.** `core/utils/smart_links_service.dart`
(`SmartLinksService.instance`) recognizes phone, WhatsApp, email, SMS,
Facebook, Instagram, YouTube, TikTok, X/Twitter, LinkedIn, Telegram,
Google Maps, and generic website links from a raw backend-supplied
string, validates them, and opens them via `url_launcher` — preferring
an installed native app (App Links/Universal Links) and falling back to
the browser/system chooser. `core/utils/url_launcher_adapter.dart` is
the seam over the third-party plugin. No link is ever hardcoded in the
app; every value passed to `SmartLinksService.open()` comes from a
`ContactItemModel`, `PaymentMethodModel`, or `BrandingSettingsModel`.

**Contact Center.** `contacts/{contactId}` (`ContactItemModel`,
`ContactRepository`) — one reachable contact point per document, tagged
with a `ContactCategory` (owner, company, support, marketing,
admissions, payments, emergency) and a `ContactAction` that maps onto
`SmartLinkType`. Supports icon, title, value, visibility, and sort
order, exactly as specified.

**Payment Center.** `payment_methods/{paymentMethodId}`
(`PaymentMethodModel`, `PaymentRepository`) — unlimited payment methods
across `PaymentProvider` (bank transfer, Paystack, Flutterwave, Stripe,
PayPal, mobile money, other/future), each with name, logo, description,
currency, status, and provider-specific fields (account name/number/
bank/QR for bank transfer; public key/gateway link for card gateways).

**Firestore rules.** `contacts/{id}` and `payment_methods/{id}` are
public-read (so support/admissions/payment info is reachable before
login) and admin-write only.

**Still pending for a later Stage 1.3 pass** (not yet built): Feature
Flag Engine UI surface (the `FeatureFlagService` backend already existed
from Stage 1.2), icon system standardization audit, secure-storage
wrapper around `flutter_secure_storage` (dependency added, service not
yet written), and a full `flutter analyze` pass (not runnable in this
environment — no Flutter SDK available; the fixes above came from a
manual code read plus static heuristics).

### Upload Engine (§9)

`services/upload/upload_engine.dart` (`UploadEngine.instance`) is now
the single queue every feature should upload through, built specifically
to avoid repeating the upload bugs from FUTALearn:

- **Validation first** — `core/utils/file_validator.dart` checks size
  and extension against `settings/uploads` (`UploadSettingsModel`,
  `AppSettingsRepository.watchUploadSettings/saveUploadSettings`)
  before anything touches the network.
- **Duplicate detection** — SHA-256 content hash. In-session duplicates
  (same file queued twice) return the existing task instead of
  re-uploading; cross-session duplicates are caught via
  `UploadHistoryRepository.findByHash` against `upload_history/*`.
- **Queue with concurrency limit** — `maxConcurrentUploads` (from
  settings, default 2) governs how many uploads run at once; the rest
  wait as `UploadStatus.queued`.
- **Pause/resume/cancel/retry** — wraps `firebase_storage`'s
  `UploadTask` controls directly; retry re-queues without re-reading
  the file from disk.
- **Live progress** — `UploadEngine.watchTasks()` is a broadcast stream
  of `List<UploadTaskModel>`, each with a 0.0–1.0 `progress`.
- **History** — every terminal task (success/failed/cancelled) is
  persisted to `upload_history/{taskId}`, queryable by uid via
  `UploadHistoryRepository.watchForUser`.

It sits on top of `firebase_storage` directly (not `StorageService`) so
it can hold onto the underlying `UploadTask` object for pause/resume/
cancel — `StorageService`/`StorageRepository` remain for simple
fire-and-forget writes (e.g. the profile avatar) that don't need queue
control. No upload logic is duplicated between them; `StorageRepository`
methods and `UploadEngine.enqueue` both ultimately call
`ref.putFile(...)`.

Preview generation (thumbnails) and background-upload (continuing after
the app is closed) are flagged in `UploadSettingsModel` /
`fileName`/`mimeType` metadata but not implemented — thumbnailing needs
an image-processing package and background uploads need
platform-specific work (WorkManager/BGTaskScheduler) that's out of scope
for a foundation stage.

## Stage 3 — Learning Content System, Phase 1 (Learning Content Viewer)

Adds the data layer, Firestore/Storage integration, and Learning-tab UI
for course study materials. Scoped to Phase 1 of the 7-phase Learning
Content System spec: models, repository, list UI, search/filter, and
state handling — no PDF/video/audio viewer packages, no offline
download manager, no progress tracking, and no admin CMS yet. Those are
architected for (see "Extension points" below) but intentionally not
built in this pass, since each is a substantial feature in its own
right and this stage was scoped to ship a solid, verifiable foundation
rather than a large surface of unverified code.

### Why a new collection instead of extending `learning_content`

`LearningContentModel`/`LearningContentRepository` (Stage 1,
`learning_content` collection) already cover a different shape — notes,
assignments, timetables, flashcards — and `CourseDetailScreen` was their
only call site. Rather than overload that enum/model with the Phase 1
spec's fields (lecturer, file size, duration/page count, publish
scheduling, targeting), Phase 1 introduces a parallel, purpose-built
collection:

- **Model**: `models/learning_material_model.dart` — `LearningMaterialModel`
  (`learning_materials/{materialId}`)
- **Type enum**: `core/enums/learning_material_type.dart` —
  `LearningMaterialType` (pdf, video, audio, image, presentation,
  document, externalLink, archive), carrying its own icon/label per case
- **Repository**: `repositories/learning_material_repository.dart` —
  `LearningMaterialRepository extends BaseRepository<LearningMaterialModel>`,
  `watchByCourse` (published, newest-first) and `watchAllByCourseForAdmin`
  (Phase 6 hook, unused today)
- **Storage paths**: `StoragePaths.learningMaterialFile` /
  `.learningMaterialThumbnail`, both under `learning_materials/{courseId}/{materialId}/...`
- **Security rules**: `firestore.rules` (`learning_materials` collection,
  same read/write shape as `learning_content`) and `storage.rules`
  (`learning_materials/**`, same shape as `notes`/`videos`/`documents`)

`LearningContentModel`, `LearningContentRepository`, the
`learning_content` collection, and its Firestore/Storage rules are all
untouched.

### UI

`CourseDetailScreen` is now a two-tab screen (`DefaultTabController`):
**Overview** (unchanged course metadata, extracted into `_OverviewTab`)
and **Learning** (`features/learn/learning_tab_view.dart`). The Learning
tab streams `watchByCourse`, applies a client-side search/type filter
(the same pattern `LearnScreen`/`CourseListScreen` already use, since
Firestore has no partial-text search), and renders `LoadingView` /
`ErrorView` / `EmptyView` for every state per the existing convention.

Each item renders as a `MaterialTile`
(`features/learn/widgets/material_tile.dart`) showing everything the
Phase 1 spec calls for: thumbnail-or-icon (`ContentTypeBadge`), title,
description, lecturer, relative upload date, file size, content-type
tag, a download-status icon, and duration/page count where applicable —
all formatted via the new dependency-free `core/utils/format_utils.dart`
(`FormatUtils`; the project deliberately doesn't carry `intl`, see the
Stage 1.1 changelog above, so this is hand-rolled rather than
reintroducing it for one feature).

### Extension points for later phases

- **Phase 2 (viewers)**: `features/learn/utils/material_open_handler.dart`
  defines `MaterialOpenHandler`, the single seam `LearningTabView` calls
  on tap. Today it resolves to `defaultMaterialOpenHandler` (an
  acknowledgement snackbar); a real per-type viewer router is a new
  implementation of that typedef, passed into `LearningTabView`'s
  `onOpenMaterial` — no change needed to the tab, tile, repository, or
  model.
- **Phase 3 (downloads)**: `core/enums/material_download_status.dart`
  (`MaterialDownloadStatus`) and `MaterialTile.downloadStatus` exist now
  so the tile already has a real, typed indicator. `LearningTabView`
  currently passes the default (`notDownloaded`) for every item; a
  download manager only needs to supply a per-`materialId` lookup at
  that one call site.
- **Phase 4 (progress)**: `LearningMaterialType.hasProgressPosition`
  flags which types will carry a resume position once a `progress`
  Firestore doc (mirroring the existing `progressCollection` constant)
  is wired up — not built in Phase 1.
- **Phase 6 (admin)**: `LearningMaterialModel` already carries
  `institutionId`/`departmentId`/`levelId`/`semesterId`/`publishAt`, and
  `LearningMaterialRepository.watchAllByCourseForAdmin` exists, so the
  future admin CMS needs new screens and an uploader, not a data-model
  migration.

### Known limitations (Phase 1 scope)

- No PDF/video/audio/document rendering yet — tapping a material shows
  an acknowledgement, not a preview.
- No offline download manager; the download-status icon always reads
  "not downloaded."
- No learning-progress tracking, bookmarks/favorites, or "Continue
  Learning" surface yet.
- No admin upload/edit/publish UI; `learning_materials` documents must
  be created directly in Firestore/Storage (or via the Console) until
  Phase 6.
- Composite index required in a live Firebase project for
  `watchByCourse`'s `(courseId, isPublished, createdAt)` query —
  Firestore will surface a console link to create it on first run, same
  as every other compound query in this codebase.

---

## Stage 3.5 — Admin Learning Material Management

Delivers the Phase 6 hook called out above: a full admin CMS for
`learning_materials/{materialId}`, built entirely additively on top of
Stage 3/Phase 1's model, repository, and storage layout. No existing
screen, query, or document shape changed — see each section below for
exactly why.

### Data model

`LearningMaterialModel` gains `topic`, `week`, `tags`, `bannerUrl`,
`displayOrder`, `status` (`MaterialPublicationStatus`: draft/published/
scheduled/archived), `unpublishAt`, `originalFileName`, and
`lastEditedByUid` — all nullable/defaulted. `isPublished`/`publishAt`
keep their Phase 1 shape unchanged; `LearningMaterialModel
.computeIsPublished(status, publishAt)` is the single place that derives
the boolean from the richer status so `watchByCourse`'s existing query
never has to change. Documents written before this stage have no
`status` field; `fromMap` derives a default from their existing
`isPublished` value, so no backfill migration is needed.

### Repository additions

`LearningMaterialRepository`: `watchAllForAdmin` (cross-course stream
for the dashboard), `createMaterial`/`updateMaterial`,
`duplicateMaterial`, `archiveMaterial`/`restoreMaterial`,
`publishNow`/`unpublishNow`, `schedulePublish`/`scheduleUnpublish`,
`setVisibility`, `deleteMaterial`, `countByCourse`. `CourseRepository`
gains `watchAll()` for the admin course filter/picker (no Phase 1/Stage 2
screen needs an unscoped course list; Phase 1's `watchByDepartmentAndLevel`
is untouched).

### Storage

The material file itself is queued through the existing `UploadEngine`
(progress/pause/resume/retry for free); thumbnails and banners upload
fire-and-forget via two new `StorageRepository` methods, same pattern as
the existing avatar/course-note/banner uploads. `StoragePaths` gains
`learningMaterialBanner`, alongside the existing
`learningMaterialFile`/`learningMaterialThumbnail`. `StorageService`
gains `deleteFileAtUrl` (delete-by-download-URL, `object-not-found`
treated as success) since the model only stores URLs, not raw paths.

### Validation

`core/utils/learning_material_validator.dart` (`LearningMaterialValidator`)
is deliberately separate from `FileValidator` (which checks a picked
file against the remote `UploadSettingsModel` size/type limits):
`LearningMaterialValidator` checks required fields, that the picked
file's extension actually matches the spec's per-type allow-list (PDF /
DOCX / PPT-PPTX / MP4 / MP3 / images / ZIP), duplicate filenames within
the same course, well-formed http(s) URLs, and a course actually being
assigned — everything the admin form needs before the Upload Engine is
ever invoked.

### Admin UI (`features/admin/`)

- `AdminDashboardScreen` — new shell entry point (nothing built one
  before this stage); a grid of modules, only "Learning Materials" fully
  wired, the other three (Moderation & Reports, Users & Roles, App
  Settings) as `FeaturePlaceholder` screens — a real extension point
  rather than a single-purpose screen, matching the spec's "Future
  Compatibility" ask.
- `AdminLearningMaterialsScreen` — stats (totals, published/draft/
  scheduled/archived, storage usage, by-type, by-course, recent uploads),
  search, the filter/sort bottom sheet, a paginated ("load more") action
  list, pull-to-refresh, and a FAB into the form. Stats and filtering are
  computed client-side over `watchAllForAdmin`'s stream — the same
  "Firestore has no partial-text search / arbitrary filter combos need a
  combinatorial number of composite indexes" reasoning `LearningTabView`
  already established; documented as needing a Cloud-Function-aggregated
  `analytics/*` snapshot instead, if the catalog ever reaches tens of
  thousands of materials.
- `AdminMaterialFormScreen` — create/edit for every field the spec lists,
  a cascading `AcademicScopePicker` (Institution → Department → Level →
  Semester → Course, built entirely on the existing Stage 1.2 tree
  repositories), a chip-based `TagInputField`, file/thumbnail/banner
  pickers with live upload progress, and the publication workflow
  (draft/published/scheduled/archived, schedule pickers).
- `AdminAccess` gates the dashboard's *visibility* only — real
  enforcement is `firestore.rules`/`storage.rules`, which already cover
  `learning_materials`/`learning_materials/**` with staff-write/
  admin-delete and student-read (see below); no rules changes were
  needed for this stage.

The Admin Dashboard entry point itself lives in `ProfileScreen`, visible
only when `AdminAccess.watchIsAdmin()` emits true for the signed-in
user's roles (`superAdmin`/`admin`/`institutionAdmin`).

### Scheduled publish/unpublish — a documented limitation

There is no Cloud Function/cron in this stage. A material scheduled to
publish or unpublish only actually flips (`status`/`isPublished`) when
some admin's `AdminLearningMaterialsScreen` is open to notice the time
has passed — `MaterialWorkflow.dueForAutoPublish`/`dueForAutoUnpublish`
run client-side against every stream emission, best-effort. This is
called out explicitly in `LearningMaterialModel.computeIsPublished`'s
doc comment and should move to a scheduled Cloud Function once the
project has a backend deployment target.

### Security rules

No `firestore.rules`/`storage.rules` changes were needed — Stage 3's
rules already gate `learning_materials` writes to `isStaff()`/deletes to
`isAdmin()`, and `learning_materials/**` storage writes to
`isStaffClaim()`, exactly matching this stage's "only administrators may
upload/edit/delete/publish" requirement. One pre-existing, carried-over
limitation worth noting: Firestore read rules allow any non-suspended
signed-in user to read the `learning_materials` collection outright
(`notSuspended()`, no `isPublished` check in the rule itself) — draft/
unpublished visibility is enforced by `watchByCourse`'s query shape on
the client, exactly as it already was before this stage, not by the
rules. Hardening that would be a rules change beyond this stage's
additive scope, so it's flagged here rather than silently left implicit.

### Static audit fixes (pre-existing, found while auditing this stage)

`CourseRepository` and (before this stage's own addition)
`LearningMaterialRepository` called `resultFailureFrom` (defined in
`core/errors/app_exception.dart`) without importing that file —
`CourseRepository.countByDepartment` predates this stage and had this
bug already; `LearningMaterialRepository.countByCourse` is new and
inherited the same oversight before the fix. Both now import
`app_exception.dart` directly. No behavior changes, just a missing
import that would have failed to compile.

### Known limitations (Stage 3.5 scope)

- No server-side scheduled publish/unpublish (see above) — client-side,
  best-effort only.
- Stats/filtering/pagination are computed client-side over a bounded
  (`limit: 500`) admin stream, not server-side aggregation — fine at
  this app's expected scale, flagged for a future Cloud Function if the
  catalog grows far beyond that.
- `file_picker` is added as a new dependency for the admin form's file/
  image selection; it feeds a plain `dart:io File` into the existing
  `UploadEngine`/`StorageRepository` paths unchanged, so this stage adds
  exactly one new package rather than a parallel upload pipeline.
- The Admin Dashboard's other three module tiles (Moderation & Reports,
  Users & Roles, App Settings) are intentionally left as
  `FeaturePlaceholder` screens — out of this stage's scope, wired only
  as navigation so the dashboard reads as a real hub.

## Stage 3.6.1 — Admin Productivity Pack: Audit Logging Infrastructure

Ships the reusable audit-trail infrastructure the Stage 3.6 spec calls
for as its first piece, so every later Stage 3.6.x feature (bulk ops,
drag-and-drop ordering, version history, storage dashboard, ...) — and
every future module beyond Learning Materials — can log through the
same service instead of inventing its own.

### What's new

- **`AuditActionType`** (`core/enums/audit_action_type.dart`) — the 13
  action kinds the spec lists (create/edit/publish/unpublish/archive/
  restore/duplicate/delete/login/logout/upload/download/settings-changed),
  each with a label/icon/color, plus an `other` decode fallback. Also
  hosts `AuditModules`, a small set of `String` constants (not an enum,
  deliberately — a new module should be able to log against its own id
  without an enum edit here) for the "filter by module" axis.
- **`AuditLogModel`** (`models/audit_log_model.dart`) — one
  `audit_logs/{logId}` document: who (`userId`/`userName`/`userRole`),
  what (`actionType`/`module`), on what (`targetCollection`/`targetId`/
  `targetTitle`), detail (`summary`/`previousValues`/`newValues`), and
  context (`platform`/`ipAddress`/`createdAt`).
- **`AuditLogRepository`** (`repositories/audit_log_repository.dart`) —
  extends `BaseRepository<AuditLogModel>` but, unlike every other
  repository in this codebase, does real `startAfterDocument` cursor
  pagination (`fetchPage`) instead of the "grow the limit" convention
  `LearningMaterialRepository.watchAllForAdmin` documents — an audit
  trail grows unbounded, so the grow-the-limit approach doesn't hold up
  here the way it does for a per-course materials catalog. Also exposes
  `fetchRecentActors` (a bounded scan for the filter sheet's "User"
  dropdown, not a full `users` directory read). Combining more than one
  `.where()` filter with the `createdAt` ordering needs a composite
  index — Firestore will surface a console link the first time an
  unindexed combination runs, exactly like every other multi-filter
  query already in this codebase.
- **`AuditLogService`** (`services/audit/audit_log_service.dart`) — the
  singleton every module logs through. `log()` and its `logX`
  convenience wrappers (`logCreate`, `logEdit`, `logPublish`, `logLogin`,
  ...) are synchronous and fire-and-forget: the Firestore write happens
  on an un-awaited `Future`, and every exception in that path is caught
  and swallowed (debug-logged only) so a logging hiccup can never fail
  or roll back the action it's describing. Attribution is self-reported
  from `AuthService.currentUser` (or an explicit `actingUid`/`uid` for
  `logLogin`/`logLogout`, since `currentUser` isn't reliably available
  around a sign-out) plus a `UserRepository` lookup for role/display
  name — never trusted from the caller, matching the
  `request.resource.data.userId == uid()` check in `firestore.rules`.
- **`AuditLogScreen`** (`features/admin/audit_log/`) — a new, fully
  wired Admin Dashboard tile. Cursor-paginated list (`Load more`, not
  grow-the-limit), a filter sheet (user/action/module/target ID/date
  range), a detail bottom sheet (full entry incl. previous/new value
  diffs), loading/error/empty states, and pull-to-refresh — all built
  from existing shared widgets (`CustomCard`, `SearchField`,
  `AppBottomSheet`, `LoadingView`/`ErrorView`/`EmptyView`), no new
  design-system surface introduced. Search is client-side over the
  currently loaded page only, same documented "Firestore has no
  partial-text search" limitation `AdminLearningMaterialsScreen`
  already carries — the indexed filters are the precise way to narrow
  results; search is a quick scan on top of what's loaded.

### Deliberately not done this stage

This stage ships the *infrastructure* the spec asked for first — it
does **not** go back and add `AuditLogService.logX(...)` calls inside
`AdminLearningMaterialsScreen`, `AuthService`, or any other existing
module, to keep the change additive and scoped (no unrelated module was
modified). Practical effect: the Audit Log screen will show an empty
state until a later stage wires real call sites in. Wiring a call site
is one line at the point of action, e.g.:

```dart
await _materialRepository.publishNow(material);
AuditLogService.instance.logPublish(
  module: AuditModules.learningMaterials,
  targetCollection: AppConstants.learningMaterialsCollection,
  targetId: material.materialId,
  targetTitle: material.title,
);
```

### Security rules

`audit_logs` is append-only: any signed-in user may `create` an entry
attributed to themselves (`request.resource.data.userId == uid()`),
`read` is admin-only, and `update`/`delete` are denied outright — an
editable/deletable audit trail isn't one. See `firestore.rules`.

### Known limitations (Stage 3.6.1 scope)

- No Cloud Function captures `ipAddress` yet — the field exists on the
  model/schema so a future trusted-backend writer can populate it, but
  every client-written entry leaves it `null`, exactly as the spec's
  "if supported by the backend" phrasing anticipates.
- Search is client-side over the loaded page, not full-text server-side
  search, same limitation the rest of the admin surface already has.
- No existing action in the app calls `AuditLogService` yet (see
  "Deliberately not done this stage" above).

## Stage 3.6.2 — Audit Integration

Wires `AuditLogService` into the modules that perform administrative
actions today. Full detail in `docs/STAGE_3.6.2_CHANGELOG.md`; summary
here.

**Operation Tracking (§7)** — `AuditLogModel` gained `operationId`/
`sessionId`/`appVersion`/`deviceType`/`deviceModel`/`durationMs`, all
nullable so pre-3.6.2 entries still decode. `core/utils/device_context.dart`
(`DeviceContext`) resolves the device/app fields lazily via
`package_info_plus`/`device_info_plus`, each call wrapped so a plugin
failure degrades to `null` rather than breaking a log write.
`AuditLogService.newOperationId()` generates an id; pass the same one
to every `logX` call in one bulk action to group them later.

**Authentication (Part 2)** — `AuthService` now logs login (success +
failure), logout, password reset requests, and password changes. Added
a `changePassword()` method that didn't exist before. Failed-login and
signed-out password-reset entries are best-effort: `firestore.rules`
requires `request.resource.data.userId == request.auth.uid`, so a
fully unauthenticated attempt can't write an entry — documented as a
deliberate trade-off in the changelog, not a bug.

**Branding (Part 3)** / **Feature Flags (Part 4)** — `BrandingService
.update()` and a new `FeatureFlagService.updateFlag()` (there was no
admin write path on that service before) both log full before/after
diffs.

**Learning Materials (Part 1) — re-pointing note.** This codebase
snapshot doesn't contain `learning_material_model.dart`/
`learning_material_repository.dart`, even though the Stage 3/3.5
sections above (merged in from the Stage 3.6.1 delta's own docs)
describe them in detail. Part 1 was integrated against
`LearningContentRepository` (Stage 1's model) as the closest available
stand-in — see the changelog's "Known limitation, up front". When the
real `LearningMaterialRepository` is added to this project, wire it the
same way, method-for-method:

| `LearningMaterialRepository` method | Audit call |
|---|---|
| `createMaterial` | `logCreate` |
| `updateMaterial` | `logEdit` (previous/new `toMap()`) |
| `publishNow` | `logPublish` |
| `unpublishNow` | `logUnpublish` |
| `schedulePublish` / `scheduleUnpublish` | `logEdit` (summary noting the scheduled time) or a new `logSchedule` convenience if this becomes common |
| `archiveMaterial` | `logArchive` |
| `restoreMaterial` | `logRestore` |
| `duplicateMaterial` | `logDuplicate` (`newTargetId` = the new material's id) |
| `deleteMaterial` | `logDelete` |
| thumbnail/banner/file upload (`StorageRepository` methods) | `logUpload` (or `logEdit` with previous/new URL for a *replace*, matching this stage's `LearningContentRepository.replaceFile` pattern) |

Every call should use `module: AuditModules.learningMaterials`,
`targetCollection: AppConstants.learningMaterialsCollection`,
`targetId: material.materialId`, `targetTitle: material.title` — both
constants already exist in `app_constants.dart` anticipating this.

**User Management (Part 5) / Community (Part 6)** — reusable hooks only
(`AuditLogService.logUserX`/`logPostDeleted`/etc.), no call sites yet;
no admin UI exists for either in this snapshot.

## Stage 3.5 — Learning Materials Module

Resolves the "Learning Materials (Part 1) — re-pointing note" above:
`learning_material_model.dart` and `learning_material_repository.dart`
now exist, and every method in that table is wired exactly as
described (`publishMaterial` here, not `publishNow` — same behavior,
the name just matches this stage's own naming). Full detail in
`docs/STAGE_3.5_LEARNING_MATERIALS_CHANGELOG.md`; summary here.

**Model (Part 1)** — `LearningMaterialModel` (`learning_materials/{id}`)
replaces the flat Stage 1 `LearningContentModel` as the **official**
content system. Adds: full academic structure (institution/department/
level/semester/course/topic/week + tags), nine `LearningMaterialType`
cases (pdf/video/image/audio/document/presentation/archive/link/
richText, each with its own icon/color/typical extensions),
`MaterialPublicationStatus` (draft/published/scheduled/archived) +
`MaterialVisibility`, and analytics counters (views/downloads/
bookmarks/shares). `titleLower` is precomputed for prefix search —
Firestore has no full-text search.

**Repository (Part 2)** — `LearningMaterialRepository` extends
`BaseRepository<LearningMaterialModel>`. Beyond CRUD: full lifecycle
(`publishMaterial`/`unpublishMaterial`/`scheduleMaterial`/
`archiveMaterial`/`restoreMaterial`/`softDeleteMaterial`/
`duplicateMaterial`), `searchMaterials` (titleLower prefix range
query), `filterMaterials`, a student-facing `watchMaterials` stream
(published + non-deleted only) and an admin `watchAllForAdmin` stream
(every status, bounded `limit` rather than cursor pagination — see the
method's own doc comment for why that's an intentional, documented
choice at this scale). `publishDueScheduled()` flips a due `scheduled`
item to `published`; called from both the Learning Library and Admin
list's init since there's no Cloud Functions scheduler in this
codebase — a known limitation, not silently swallowed.

**Storage (Part 3)** — the main content file queues through the
existing `UploadEngine` (`queueFileUpload` → `attachFile` once the
task succeeds), which is what actually supplies progress/pause/resume/
cancel/retry/dedup — this module adds no second upload pipeline.
Thumbnail/banner go straight through `StorageService.uploadFile`
(small, immediate, same pattern the legacy module used).
`StoragePaths.learningMaterialFile/Thumbnail/Banner` centralize the
three paths. `UploadEngine.instance.start()` is now called from
`main.dart` — it existed before this stage but nothing invoked it.

**Student UI (Part 4)** — `LearningLibraryScreen` (search + type-chip
filters over a live `watchMaterials` stream, grid of `MaterialCard`)
is now the Learn tab's real content, replacing the Stage 1
`FeaturePlaceholder`. `MaterialDetailScreen` records a view on open and
a download on the download/open action.

**Admin CMS (Part 5)** — `AdminLearningMaterialsScreen` (search,
status-chip filter, multi-select bulk archive, per-item action sheet,
a "migrate legacy content" action) and `MaterialEditorScreen`
(create/edit form; the draft document is created as soon as a title is
entered — Storage paths are keyed by `materialId`, so a doc has to
exist before a file/thumbnail/banner can attach to it).

**Security (Part 7)** — `firestore.rules`/`storage.rules`: staff
(`isStaff()`) can read/write everything; a signed-in, non-suspended
student can only read a `learning_materials` doc where
`status == 'published' && isDeleted != true`. `learning_content`
rules are kept as-is (read-only from new code, not removed).

**Migration** — `LearningContentMigrationService.migrateAll()` copies
every not-yet-migrated `learning_content` doc into `learning_materials`
under the *same id* (existing links/deep-links keep resolving), maps
`LearningContentType` → `LearningMaterialType`, and preserves
`fileUrl`/`thumbnailUrl`/`courseId`/`uploadedBy`/`downloadCount`/
publish state. The legacy doc is flagged `migratedTo` rather than
deleted — idempotent, safe to run more than once, and
`LearningContentModel`/`LearningContentRepository` stay in the
codebase (marked `DEPRECATED` in their own doc comments) until
production data is verified migrated, per the spec's "remove old code
only after verification" rule.
