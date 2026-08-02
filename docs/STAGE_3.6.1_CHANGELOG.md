# Stage 3.6.1 Changelog — Audit Logging Infrastructure

First slice of Stage 3.6 (Admin Productivity Pack & Data Integrity):
the reusable audit-trail infrastructure every later Stage 3.6.x feature
(bulk ops, drag-and-drop ordering, version history, storage dashboard,
file health checker, upload experience, dashboard enhancements) and
every future module can log through. Everything below is additive on
top of Stage 3.5. No existing screen, repository method, Firestore
query, or document shape was changed or removed.

## New files

**Enums / constants**
- `lib/core/enums/audit_action_type.dart` — `AuditActionType`
  (create/edit/publish/unpublish/archive/restore/duplicate/delete/
  login/logout/upload/download/settingsChanged/other) with label/icon/
  color; `AuditModules`, `String`-constant module ids + display labels.

**Model**
- `lib/models/audit_log_model.dart` — `AuditLogModel`
  (`audit_logs/{logId}`): who/what/on-what/detail/context fields per
  the spec.

**Repository**
- `lib/repositories/audit_log_repository.dart` — `AuditLogRepository`
  (`fetchPage` cursor pagination, `fetchRecentActors`, `record`),
  `AuditLogPage`, `AuditActor`.

**Service**
- `lib/services/audit/audit_log_service.dart` — `AuditLogService`
  singleton: fire-and-forget `log()` + `logCreate`/`logEdit`/
  `logPublish`/`logUnpublish`/`logArchive`/`logRestore`/`logDuplicate`/
  `logDelete`/`logLogin`/`logLogout`/`logUpload`/`logDownload`/
  `logSettingsChange` convenience wrappers. Never throws, never blocks
  the caller, never fails the primary action it's logging.

**Admin feature module (`lib/features/admin/audit_log/`)**
- `audit_log_screen.dart` — cursor-paginated, searchable, filterable
  Audit Log screen.
- `widgets/audit_log_filter_sheet.dart` — `AuditLogFilters` value
  object + user/action/module/target/date-range filter bottom sheet.
- `widgets/audit_log_list_tile.dart` — list row.
- `widgets/audit_log_detail_sheet.dart` — full-entry detail bottom
  sheet, including previous/new value diffs.

**Docs**
- `docs/STAGE_3.6.1_CHANGELOG.md` — this file.

## Edited files

- `lib/core/constants/app_constants.dart` — added
  `auditLogsCollection = 'audit_logs'`.
- `lib/core/utils/format_utils.dart` — added `dateTime()` (date +
  time-of-day; `date()` itself is unchanged and still used everywhere
  it already was).
- `lib/features/admin/admin_dashboard_screen.dart` — added a fully
  wired "Audit Log" module tile, alongside the existing "Learning
  Materials" tile; the other placeholder tiles are unchanged.
- `firestore.rules` — added an `audit_logs` block: admin-only `read`,
  self-attributed `create` only, `update`/`delete` denied outright.
- `docs/ARCHITECTURE.md` — appended the "Stage 3.6.1" section.

## Not done this stage (intentional)

No existing action anywhere in the app (materials publish/delete/etc.,
auth sign-in/out, settings saves, ...) calls `AuditLogService` yet.
Wiring those call sites touches modules outside this stage's scope by
definition, so it's left for the stage(s) that build/extend each of
those features next. `docs/ARCHITECTURE.md`'s Stage 3.6.1 section has
a one-line example of what a call site looks like.

## Static audit findings

None — no pre-existing issues encountered while building this stage
(no missing imports, no brace/paren imbalance, no duplicate class/enum
names introduced).

## Firestore indexes to create before this ships

`AuditLogRepository.fetchPage`/`_filtered` combines up to four
equality filters (`userId`, `actionType`, `module`, `targetId`) plus a
`createdAt` range with `orderBy('createdAt', descending: true)`.
Firestore will prompt with a console link to create the exact
composite index needed the first time a given filter combination
actually runs against a live project — same as every other
multi-`.where()` query already in this codebase (see
`LearningMaterialRepository.watchByCourse`'s doc comment). No index
was pre-created as part of this stage; do this once real usage
patterns (which filter combinations admins actually use) are known,
rather than guessing every permutation up front.
