# Stage 3.6.3 Changelog — Storage Rules & Missing Indexes Bugfix

Fixes two real bugs found during a live-device audit session, both of
which were silently failing with no useful error surfaced to the user.
Purely additive/corrective — no schema change, no repository method
signature changed, no screen touched.

## Bug 1 — every staff/admin Storage upload was silently denied

**File:** `storage.rules`

`isStaffClaim()` gated writes to `institutions/`, `notes/`, `videos/`,
`documents/`, `assignments/`, `learning_content/`, `learning_materials/`,
`banners/`, `certificates/`, and `marketplace/` behind
`request.auth.token.role` — a Firebase Auth **custom claim**. Nothing
in this project (no Cloud Function) ever calls `setCustomUserClaims`,
so that claim was always unset and the check evaluated `false` for
every user, including `superAdmin`. Result: "Could not upload the
banner image" and equivalent failures for any staff-gated path, with
no indication in the UI of why.

**Fix:** replaced `isStaffClaim()` with `isStaffFirestore()`, which
reads the same `users/{uid}.roles` array `firestore.rules`' `hasRole()`
already checks, via the `firestore.get()` cross-service Rules function
(GA since Sept 2022 — no Cloud Function needed). Every call site
(`isStaffClaim()` → `isStaffFirestore()`) was updated; no match block's
allow logic otherwise changed. Storage Rules cap cross-service reads at
2 unique Firestore documents per evaluation — every call here reads
the same `users/{request.auth.uid}` doc, which is cached across calls
within one request, so this stays well under that limit regardless of
how many staff-gated paths a single request touches.

## Bug 2 — "Could not load materials" / "Could not load reports" / Scheduled tab failure

**File:** `firestore.indexes.json`

Was `{"indexes": [], "fieldOverrides": []}` — genuinely empty. Every
`.where(...).orderBy(...)` query on a different field needs a deployed
composite index; without one, Firestore rejects the query outright.
Added the four indexes matching the query shapes actually used in
`LearningMaterialRepository` and `ReportRepository`:

| Collection | Fields | Backs |
|---|---|---|
| `learning_materials` | `status` ASC, `createdAt` DESC | `watchRecentlyAdded()` |
| `learning_materials` | `status` ASC, `updatedAt` DESC | `watchAllForAdmin()` / `filterMaterials()` when filtered by status only |
| `learning_materials` | `status` ASC, `scheduledFor` ASC | `publishDueScheduled()` — the Scheduled tab |
| `reports` | `status` ASC, `createdAt` DESC | `watchPending()` |

**Not covered:** `filterMaterials()` and `watchAllForAdmin()` accept
several optional filters (`courseId`, `institutionId`, `type`) that can
combine with `status` in ways not listed above. Firestore only needs an
index for combinations actually queried at runtime — if the Admin CMS
filter UI is used with a courseId+status combo (for example) that
isn't in the table, Firestore's error message includes a direct link
that auto-fills the Console's "create index" form for that exact
combination. Add indexes on-demand from that link rather than
pre-building every possible filter permutation speculatively.

## Deploy

Neither fix is live until deployed:

```
firebase deploy --only storage,firestore:indexes
```
