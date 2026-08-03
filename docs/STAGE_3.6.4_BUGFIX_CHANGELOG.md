# Stage 3.6.4 — SecondaryButton Overflow Fix

## Bug
`SecondaryButton` (lib/shared/widgets/secondary_button.dart) laid out its
icon+label as a `Row(mainAxisSize: MainAxisSize.min)` with a bare `Text`.
When the button is squeezed into a constrained width (e.g. two
`SecondaryButton`s side-by-side in an `Expanded` row, as on the
Material Editor's "Add Thumbnail" / "Add Banner" row), longer labels
like "Replace Thumbnail" could not shrink and triggered a
`RenderFlex overflow` ("RIGHT OVERFLOWED BY n PIXELS").

This is a shared widget, so the bug affected every screen using
`SecondaryButton` with a long label in a constrained-width context, not
just the Material Editor screen where it was reported.

## Fix
- Removed `mainAxisSize: MainAxisSize.min` (let the Row use the space its
  parent already constrains, e.g. via `Expanded`).
- Wrapped the label `Text` in `Flexible` with `overflow: TextOverflow.ellipsis`
  and `maxLines: 1`, so long labels truncate gracefully instead of
  overflowing the render box.

## Not in scope / separate issues
Two other errors reported alongside this (via screenshots) are **not**
code bugs and are not touched by this change:

- `cloud_firestore/failed-precondition` (missing index) on Home/Learn —
  code-side indexes were already added in Stage 3.6.3; this means the
  `firebase deploy --only firestore:indexes` either hasn't been run yet
  or the indexes are still building server-side after deploy.
- `firebase_storage/object-not-found` on Learning Materials — a data
  issue, not code: some `learning_materials` documents reference Storage
  paths that were never actually written, most likely because they were
  created before Firebase Storage was provisioned on the project. Fixing
  this requires either re-uploading those specific files or clearing the
  stale `fileUrl`/`thumbnailUrl` fields on the affected documents.
