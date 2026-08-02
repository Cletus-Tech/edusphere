# Stage 3.5.2 — Final Foundation Audit & Production Readiness

An audit pass, not a feature stage — no new modules, no new screens
beyond what fixing genuine issues required. Everything below is either
a corrective fix or a confirmation that a category is healthy.

## Files created

- `firebase.json` — was completely missing. Without it, the Firebase
  CLI has no project config, so `firebase deploy --only
  firestore:rules,storage` (suggested at the end of Stage 3.5) had
  nothing to deploy from.
- `firestore.indexes.json` — empty (`indexes: []`), matching this
  project's documented convention of creating composite indexes
  on-demand via the console link Firestore returns on first query,
  rather than guessing at index definitions up front.
- `docs/STAGE_3.5.2_AUDIT_CHANGELOG.md` (this file).

## Files modified

- `lib/repositories/learning_material_repository.dart` — orphaned-file
  fix on file replace; new `archiveManyMaterials` batched bulk-write.
- `lib/features/admin/learning_materials/admin_learning_materials_screen.dart`
  — cached Firestore stream (was being recreated on every unrelated
  `setState`); bulk archive now uses the batched method.
- `lib/features/learn/learning_materials/learning_library_screen.dart`
  — same stream-caching fix; pull-to-refresh no longer tears down a
  live stream for no reason.
- `lib/features/admin/learning_materials/material_editor_screen.dart`
  — closed a race condition in the file-upload progress listener.
- `lib/features/profile/profile_screen.dart` — added a role-gated
  "Admin Dashboard" entry point (see Issues Fixed #1).
- `README.md` — was frozen at Stage 1.1; updated title, setup steps,
  and folder tree to match the current codebase.

## Files removed

None. Every fix this stage was additive or corrective in place —
nothing was deleted.

## Firestore changes

None beyond what Stage 3.5 already introduced. `archiveManyMaterials`
uses a `WriteBatch` against the existing `learning_materials`
collection — no schema change.

## Storage changes

None. The orphaned-file fix (Issues Fixed #4) deletes objects at
paths `StoragePaths` already defines; no new paths added.

## Security rule changes

None. Verified `learning_materials`/`learning_content` rules in both
`firestore.rules` and `storage.rules` correctly reflect what Stage 3.5
implemented — no drift found.

## Architecture updates

None beyond the fixes listed above — the Repository → Service → UI
layering, `Result<T>` convention, and constructor-based dependency
access (see "Project Health Report" → Dependency Injection, below)
were all found consistent with the rest of the codebase.

## Documentation updates

`README.md` (see Files modified). `docs/ARCHITECTURE.md` was checked
against the implementation and found already accurate — no changes
needed there this stage.

---

## Project Health Report

| Category | Rating | Notes |
|---|---|---|
| Bootstrap | ✅ Healthy | `main.dart` initializes Firebase, catches init failures gracefully, starts all four remote-config/engine services (`FeatureFlagService`, `BrandingService`, `DashboardConfigService`, and now `UploadEngine` — see Issues Fixed). No duplicate init found. |
| Routing | ⚠️ → ✅ Needs Attention → Fixed | `AdminDashboardScreen` was completely unreachable (Issue #1). Fixed this stage. Every other registered route resolves; no orphans or duplicates remain. |
| Dependency Injection | ✅ Healthy (with a note) | No DI *container* (get_it, etc.) exists in this project — repositories are constructed at point of use, services are accessed via `.instance` singletons. That's a legitimate, consistent pattern for this codebase's size, not a defect. No duplicate registrations or circular dependencies found because there's no registration step to duplicate. |
| Firebase | ✅ Healthy | Auth, Firestore, Storage, Messaging all initialize correctly and are only ever accessed through their respective services, never directly from UI. `firebase_options.dart`'s placeholder keys are intentional and documented (README, main.dart's try/catch). Remote Config is not used anywhere in this codebase — not a gap, just not part of the architecture. |
| UI | ✅ Healthy | Dark-mode support, loading/empty/error states, and icon tooltips are consistent across every screen this audit touched. No emoji or default clipart icons found. `Community`/`AI Tutor`/three Admin Dashboard tiles are still `FeaturePlaceholder` — expected (unbuilt modules), not a defect. |
| Learning Materials | ✅ Healthy (after fixes) | Repository, model, student library, detail screen, admin CMS, upload/download flow, search, filters, publish/archive workflow, and migration service are all correctly wired end to end. Two real bugs found and fixed this stage (stream recreation, upload race condition) — see Issues Fixed. |
| Audit System | ✅ Healthy | Every `LearningMaterialRepository` write path logs exactly once, with correct `operationId` grouping (including the new batched bulk-archive) and complete metadata (module/target/title). No duplicate or missing logs found. |
| Storage | ⚠️ Needs Attention | Upload engine (progress/retry/cancel/dedup) is solid. Orphaned-file leak on main-file replace fixed this stage; the same leak still exists for thumbnail/banner replacement in both the new and legacy modules (see Remaining Limitations) and for the legacy `learning_content` module's `replaceFile`, which was the original source of the pattern. |
| Firestore | ✅ Healthy | Collection names centralized and consistent; queries follow the existing "console creates the index on first run" convention; the one real gap (bulk writes not batched) is fixed this stage. |
| Performance | ✅ Healthy (after fixes) | Two genuine `StreamBuilder` re-subscription bugs found and fixed (both new screens). No other rebuild/memory-leak issues found in this stage's scope. |
| Architecture | ✅ Healthy | Repository pattern, naming, and folder organization are consistent project-wide. No duplicate modules found — confirmed the legacy `learning_content` system had zero UI consumers ever, validating Stage 3.5's decision to migrate rather than maintain two libraries. |
| Documentation | ✅ Healthy (after fixes) | `ARCHITECTURE.md` was already accurate. `README.md` was stale (frozen at Stage 1.1) and is fixed this stage. |

## Issues Fixed

1. **`AdminDashboardScreen` was unreachable.** It shipped in Stage 3.5
   with real functionality (Learning Materials CMS, Audit Log) but no
   route, button, or link anywhere in the app pointed to it.
   `UserRole.isElevated` existed specifically for this kind of gating
   but had never been called. Fixed by adding a role-gated "Admin
   Dashboard" tile to `ProfileScreen`.
2. **Missing `firebase.json`/`firestore.indexes.json`.** The project
   had `firestore.rules`/`storage.rules` but no CLI config connecting
   them to a deploy command. Added both.
3. **`StreamBuilder` re-subscription on unrelated state changes**, in
   both `LearningLibraryScreen` and `AdminLearningMaterialsScreen`.
   The stream was being constructed inline in `build()`, so any
   `setState` — including a bulk-select checkbox tap that has nothing
   to do with the query — handed `StreamBuilder` a new `Stream`
   instance, tearing down and resubscribing the Firestore listener and
   flashing the whole list back to a loading spinner. Fixed by caching
   the stream and only recomputing it when a filter that actually
   changes the query fires. `RefreshIndicator`'s pull-to-refresh had
   the same problem for no benefit (the stream is already live) —
   fixed to call `publishDueScheduled()` instead, which is actually
   useful.
4. **Orphaned Storage files on file replace.** Replacing a material's
   main content file saved the new download URL but left the old
   Storage object behind forever. Fixed by reconstructing the old
   path via `StoragePaths` (using the previously-tracked filename) and
   best-effort deleting it after a successful replace.
5. **Bulk archive was N sequential round-trips.** The multi-select
   "Archive selected" action awaited `archiveMaterial` in a loop.
   Replaced with a single `WriteBatch` (`archiveManyMaterials`), reads
   parallelized via `Future.wait`, audit entries kept one-per-item but
   grouped under one `operationId`.
6. **Race condition in the upload progress listener.**
   `UploadEngine`'s task stream is `StreamController.broadcast()` with
   no event replay. A small/fast file could finish uploading in the
   window between `enqueue()` returning and the listener attaching,
   silently dropping the completion event and leaving the file never
   attached to the material. Fixed by also checking
   `UploadEngine.instance.tasks`'s synchronous snapshot immediately
   after subscribing, with a guard against double-attaching if both
   paths observe the same terminal state.
7. **`README.md` frozen at Stage 1.1.** Still described the app as
   placeholder-only with a stale folder tree. Updated to point at
   `ARCHITECTURE.md`/the changelogs as the living source of truth and
   corrected the folder tree and setup steps.

## Remaining Limitations

*(Only confirmed, verified limitations — not speculative.)*

- **No server-side scheduler.** Scheduled-publish materials only go
  live when `publishDueScheduled()` runs client-side (on Library/Admin
  open). Documented since Stage 3.5; still true, no Cloud Functions in
  this project to fix it with.
- **Thumbnail/banner replacement still orphans the old Storage
  object.** Fixed for the main content file this stage (a filename is
  tracked for it); thumbnails/banners have no filename field to
  reconstruct the old path from. Same gap exists in the legacy
  `learning_content` module's `replaceFile`. A real fix needs a schema
  addition (`thumbnailFileName`/`bannerFileName`), deliberately not
  made in an audit-only stage.
- **Course picker in `MaterialEditorScreen` is a flat 50-item list**,
  no department/level pre-filter. Documented in Stage 3.5; unchanged.
- **No in-app file preview/player.** Download/open hands off to the
  platform's default handler via `url_launcher`. Documented in Stage
  3.5; unchanged.
- **Several Profile/Admin Dashboard tiles remain intentional
  placeholders** (My Downloads, My Notes, My Certificates, Help &
  Support, Settings icon, Moderation & Reports, Users & Roles, App
  Settings) — out of scope for both Stage 3.5 and this audit, which
  covers Learning Materials specifically.
- **No automated test suite exists in this project** — every
  verification in Stage 3.5 and this audit was manual/hand-checked
  against the codebase's own conventions, not compiler- or
  test-verified (no Flutter SDK available in the environment these
  stages were built in). Run `flutter pub get && flutter analyze &&
  flutter test` before considering either stage complete.

## Production Readiness

**Production Foundation Ready** — for the Learning Materials module
specifically, conditional on the one step no environment here could
perform: **running `flutter analyze`/`flutter test` against a real
Flutter SDK before shipping.** Every fix in this stage and Stage 3.5
was verified by hand, symbol-by-symbol, against the existing
codebase's actual method signatures and conventions — but that's a
substitute for compiling, not equivalent to it.

Reasoning:
- Architecture, security rules, audit logging, and the Learning
  Materials module are internally consistent and correctly wired
  end-to-end (confirmed by this audit).
- The genuine defects found (unreachable admin screen, stream
  re-subscription bug, orphaned files, un-batched bulk writes, upload
  race condition, missing Firebase CLI config, stale README) are all
  now fixed.
- What keeps this from being unconditionally "Production Ready"
  rather than "Production Foundation Ready": no compiler/test
  verification has occurred, `firebase_options.dart` still has
  placeholder keys (expected — the developer runs `flutterfire
  configure` before shipping), and the confirmed remaining limitations
  above (scheduler, thumbnail/banner orphan cleanup, course picker)
  are real if minor gaps a production launch should know about going
  in, not surprises to discover after.

## Next Recommended Stage

CBT Practice / Past Questions — per Stage 3.5's own recommendation,
now unblocked since the Learning Materials foundation this audit
verified is what it builds on (`courseId` and the rest of
`LearningMaterialModel`'s academic-structure fields).

## Overall EduSphere Roadmap Progress

Roughly **35–40%** toward the vision described in the README (Learn,
Community, AI Tutor, CBT, Marketplace, Scholarships, all built out).
Solid: foundation/design system, auth, RBAC data model, branding/
feature-flag/upload infrastructure, admin audit logging, and now a
real Learning Materials module. Not started: CBT engine, Community,
AI Tutor, Marketplace, Scholarships, and any user-facing role
management UI beyond the audit log itself.
