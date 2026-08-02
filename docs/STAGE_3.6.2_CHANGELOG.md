# Stage 3.6.2 Changelog — Audit Integration

Wires the Stage 3.6.1 audit-trail infrastructure into the modules that
actually perform administrative actions today (Authentication,
Branding, Feature Flags, Learning Materials), adds Operation Tracking
(§7) to every log entry, and adds reusable-but-unwired hooks for the
two modules that don't have admin UI yet (User Management, Community
moderation). Everything below is additive on top of Stage 3.6.1 — no
existing screen, repository method, Firestore query, or document shape
was changed or removed. `AuditLogService` was extended, never
redesigned; every Stage 3.6.1 method signature still works unchanged.

## Known limitation, up front

This codebase snapshot doesn't contain a dedicated Stage 3 "Learning
Materials" module — `LearningMaterialRepository`, referenced in Stage
3.6.1's own repository doc comments, doesn't exist here. Part 1's
integration was done against `LearningContentRepository`
(`learning_content/{contentId}` — Stage 1's notes/assignments/
timetables model) instead, since it's this codebase's closest existing
analog and already had an `isPublished` flag to build on. If/when the
real Learning Materials module is added, apply the same pattern
directly to it — every hook already uses `AuditModules.learningMaterials`
and `AppConstants.learningMaterialsCollection`, both of which
anticipate that future module's name.

## Modified files

**`lib/models/audit_log_model.dart`**
- Added Operation Tracking fields (§7): `operationId`, `sessionId`,
  `appVersion`, `deviceType`, `deviceModel`, `durationMs` — all
  nullable, all defaulted to `null` on decode, so audit entries written
  before this stage still read back cleanly.

**`lib/core/enums/audit_action_type.dart`**
- New `AuditActionType` cases: `loginFailed`, `passwordResetRequested`,
  `passwordChanged`, `brandingChanged`, `featureFlagChanged` — each with
  a `label`/`icon`/`color`. `audit_log_filter_sheet.dart` needed no
  changes; its filter chips are generated from `AuditActionType.values`.
- New `AuditModules` ids: `branding`, `featureFlags`.

**`lib/services/audit/audit_log_service.dart`**
- `log()` and every existing `logX` convenience method gained optional
  `operationId`/`duration` parameters (§7), threaded through to
  `AuditLogModel`. Omit `operationId` and one is generated per call;
  pass the same id (from `newOperationId()`) across every `logX` call
  in one bulk action to group them.
- `_write()` now also resolves `sessionId`/`appVersion`/`deviceType`/
  `deviceModel` via the new `DeviceContext` helper — wrapped in its own
  try/catch so a plugin failure degrades to `null` fields, never a
  dropped log entry (§8).
- New convenience methods: `logFailedLogin`, `logPasswordResetRequested`,
  `logPasswordChanged` (Part 2); `logBrandingChange` (Part 3);
  `logFeatureFlagChange` (Part 4).
- New **reusable, unwired** hooks (Parts 5-6 — no call sites, no UI to
  call them from yet): `logUserCreated`, `logUserUpdated`,
  `logUserSuspended`, `logUserRestored`, `logUserDeleted`,
  `logRoleChanged`, `logPostDeleted`, `logCommentDeleted`,
  `logUserMuted`, `logUserBanned`, `logUserUnbanned`,
  `logCommunityCreated`.

**`lib/services/firebase/auth_service.dart`**
- `signInWithEmail` — logs `logLogin` on success, `logFailedLogin` on
  any failure (wrong password, unknown user, etc.).
- `signInWithGoogle` — logs `logLogin` on success.
- `sendPasswordResetEmail` — logs `logPasswordResetRequested` when some
  session happens to be signed in at request time (best-effort; the
  common "forgot password" flow is unauthenticated — see Known
  limitations below).
- `signOut` — captures `uid` before calling `FirebaseAuth.signOut()`
  (which clears it) and logs `logLogout` after.
- **New method** `changePassword({currentPassword, newPassword})` —
  didn't exist before this stage. Re-authenticates via
  `EmailAuthProvider.credential`, calls `updatePassword`, then logs
  `logPasswordChanged`. Never logs either password string, only that a
  change happened.

**`lib/services/config/branding_service.dart`**
- `update()` now captures the live `_current` branding as "before",
  saves, then calls `logBrandingChange(previousValues, newValues)` with
  the full before/after `toMap()`s — covers logo, splash image, theme,
  contact info, social links, website, WhatsApp/email/phone in one
  diff since they're all fields on the same document.

**`lib/services/config/feature_flag_service.dart`**
- **New method** `updateFlag(FeatureFlagModel updated)` — there was no
  admin write path on this service before (only reads). Reads the
  previous value from the live cache, saves, then logs
  `logFeatureFlagChange(previousValues, newValues)`.

**`lib/models/learning_content_model.dart`**
- Added `isArchived`/`isDeleted` (`bool`, default `false`) so the
  repository below can offer real archive/restore/soft-delete
  operations. Backward compatible — existing documents without these
  fields decode as `false`.
- Added `copyWith()`.

**`lib/repositories/learning_repository.dart`** (Part 1)
- `LearningContentRepository` gained: `createContent`, `updateContent`,
  `publish`, `unpublish`, `archive`, `restore`, `duplicate`,
  `softDelete`, `uploadThumbnail`, `uploadFile`, `replaceFile` — every
  one logs through `AuditLogService` with `materialTitle`/`courseId`/
  best-effort `courseCode` context (`_courseCode` looks the course up
  via `CourseRepository`; failures there are swallowed, never block the
  write). `save`/`delete` inherited from `BaseRepository` are untouched
  and still usable directly for call sites that don't need the new
  named methods.
- `ExamRepository`/`QuestionRepository` in the same file are unchanged.

**`lib/core/constants/app_constants.dart`**
- Added `learningMaterialsCollection` and `auditLogsCollection` (merged
  in from the Stage 3.6.1 branch of this project; both already existed
  independently of Stage 3.6.2's own changes).

**`lib/core/constants/storage_paths.dart`**
- Added `learningContentFile`/`learningContentThumbnail` path builders,
  keyed by `contentId` rather than `courseId` (a material's file can be
  replaced independent of its course).

**`firestore.rules`**
- Added `audit_logs/{id}`: `read` for admins, `create` requires the
  signed-in uid to match the entry's own `userId`
  (`AuditLogService` always self-attributes), `update`/`delete` always
  `false` — a write-once trail.

**`storage.rules`**
- Added `learning_content/{allPaths=**}` alongside the existing
  `notes`/`videos`/`documents`/`assignments` rules.

## New files

- `lib/core/utils/device_context.dart` — `DeviceContext`, resolves
  `appVersion` (via `package_info_plus`), `deviceType`/`deviceModel`
  (via `device_info_plus`), and a per-launch `sessionId`
  (via `uuid`). Every plugin call is individually try/caught; a failure
  degrades to `null`, never an exception surfaced to `AuditLogService`.

## Dependencies added

`pubspec.yaml`: `uuid: ^4.4.0`, `package_info_plus: ^8.0.0`,
`device_info_plus: ^10.1.0` — all needed for Operation Tracking (§7).

## Firestore changes

- New collection `audit_logs` was already introduced in Stage 3.6.1;
  Stage 3.6.2 adds no new collections, only new optional fields on
  existing `audit_logs` documents (see Operation Tracking above) and
  two new fields on `learning_content` documents (`isArchived`,
  `isDeleted`).

## Storage changes

- New path prefix `learning_content/{contentId}/files/*` and
  `learning_content/{contentId}/thumbnail/*`.

## Security rules changes

- `firestore.rules`: `audit_logs/{id}` rule added (see above).
- `storage.rules`: `learning_content/{allPaths=**}` rule added (see
  above).

## Known limitations

- **Failed-login audit entries are best-effort by design, not a bug.**
  `firestore.rules`' `audit_logs` create rule requires
  `request.resource.data.userId == request.auth.uid` — a fully
  unauthenticated failed sign-in attempt has no `request.auth` at all,
  so that write is rejected by the rule and silently swallowed by
  `AuditLogService`'s own error-safety (§8). This was a deliberate
  trade-off: relaxing the rule to accept unauthenticated writes would
  let anyone spam the audit trail. A wrong-password attempt on a device
  where a *different* session is already signed in, or a reset request
  sent while signed in, is attributable and does get logged.
- **Learning Materials module gap** — see "Known limitation, up front".
- **Password reset requests are only attributable when some session is
  already signed in** — same root cause as failed logins above; the
  common "forgot password" flow (fully signed out) can't write an
  audit entry under the current rules.
- **`courseCode` lookup is best-effort** — `LearningContentRepository`
  fetches it live via `CourseRepository.getById` at log time rather
  than storing a denormalized copy on the content document; if the
  course lookup fails or times out, the audit entry is still written,
  just without `courseCode`.
- No `flutter analyze`/build was run — no Flutter SDK is available in
  this working environment. See "Static verification performed" below
  for what was checked instead.
- `AdminDashboardScreen`/`AuditLogScreen` have no navigation entry point
  in this codebase snapshot — the Stage 3.6.1 delta's own docs describe
  an `AdminAccess`-gated tile on `ProfileScreen`, but neither
  `AdminAccess` nor that wiring exist here. Left as-is rather than
  guessing at `app.dart`'s route table structure; every dependency the
  screens need (`CustomCard`, `SearchField`, `AppBottomSheet`, etc.) was
  individually verified present (see below), so the screens themselves
  are reachable via direct `Navigator.push` once a real entry point is
  added — they're just not linked from anywhere yet.

## Static verification performed

No Flutter SDK is available in this environment, so nothing here was
compiled. Verified by hand instead:
- Brace/parenthesis balance on every touched file (automated check).
- Every new/changed method call's target signature was located and
  read in its source file (`BaseRepository`, `StorageService`,
  `FirestoreConvert`, `UserModel`, `CourseModel`, `Result`/`Success`/
  `Failure`) to confirm parameter names, types, and return types match.
- Checked for and fixed a real bug introduced mid-edit: a local
  variable named `newId` shadowing `BaseRepository.newId()` inside
  `LearningContentRepository.duplicate()`.
- Confirmed `audit_log_filter_sheet.dart` iterates `AuditActionType
  .values` rather than a hardcoded list, so the five new action types
  need no widget changes to appear in the filter UI.
- Found and fixed a second pre-existing bug, in the Stage 3.6.1 delta
  itself (not introduced this stage): `audit_log_screen.dart`'s
  `build()` had a stray extra closing parenthesis after
  `body = RefreshIndicator(...)`, which would not compile. Removed the
  extra `)` and corrected the trailing `,` to `;` to properly terminate
  the assignment.
- Searched `lib/features/` for existing call sites of
  `LearningContentRepository`/`LearningContentModel(` — none exist yet,
  so the model/repository changes above have zero UI blast radius.

## Next recommended stage

Get the real Stage 3 Learning Materials module (or confirm
`LearningContentRepository` *is* that module going forward) so Part 1's
integration can be pointed at the actual production repository instead
of the Stage 1 stand-in. After that: build the User Management and
Community moderation admin UI so the Part 5/6 hooks added this stage
get their first real call sites.

## Final project status

Rough, self-assessed completion against the long-term EduSphere
roadmap as understood from this conversation (foundation → learning →
community → admin tooling → data integrity/audit): **foundation and
audit infrastructure are solid; the Learning/Community feature layers
this stage integrates into are themselves partially built** (Stage 1's
content model exists, Stage 3's dedicated module doesn't in this
snapshot; Community has no moderation UI yet). Treat any single
percentage figure here as a rough approximation, not a precise metric —
this assessment is based only on the files seen in this conversation,
not the full project.
