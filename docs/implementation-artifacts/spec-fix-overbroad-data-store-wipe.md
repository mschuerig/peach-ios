---
title: 'Fix overbroad data-store wipe in setupDataStore'
type: 'bugfix'
created: '2026-06-16'
status: 'done'
baseline_commit: 'f123ab5ca4408d0486c59c92a1d5c9a1f6f59640'
context:
  - '{project-root}/docs/project-context.md'
  - '{project-root}/Peach/Core/Data/PeachSchema.swift'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `PeachApp.setupDataStore` catches **every** error from `ModelContainer.init` and unconditionally wipes the on-disk store. Recoverable conditions — disk-full, file-permission, encrypted-store / keychain-unlock failure, corrupted `.shm`/`.wal` — all hit this path and destroy the user's training history even though the data on disk is intact and the cause is transient.

**Approach:** Match only the error cases that genuinely indicate schema incompatibility (the documented wipe-and-retry path). Let everything else propagate so the app fails loudly instead of silently destroying records. Extract the classification into a testable helper so the contract is unit-tested rather than relying on a manual review of a `catch` block.

## Boundaries & Constraints

**Always:**
- Wipe the store **only** when the caught error matches one of these schema-incompatibility cases:
  - `SwiftDataError.loadIssueModelContainer`
  - `SwiftDataError.backwardMigration`
  - `SwiftDataError.unknownSchema`
  - `CocoaError(.persistentStoreIncompatibleVersionHash)` (passthrough from Core Data)
- Log the caught error's type and localized description at `.error` level on both the wipe path and the rethrow path so production diagnostics distinguish the two.
- Preserve the existing "wipe → retry once → rethrow on second failure" structure on the schema path.

**Ask First:**
- (none — execution is mechanical given the catch list above)

**Never:**
- Catch `Error` without filtering and then wipe.
- Wipe on `CocoaError(.fileWriteOutOfSpace)`, `CocoaError(.fileWriteNoPermission)`, `CocoaError(.fileReadNoPermission)`, `CocoaError(.persistentStoreOpen)`, `CocoaError(.sqlite)`, or any non-schema `CocoaError`.
- Add an in-app alert UI for the rethrow path — out of scope; rethrow surfaces as an `init` failure and the app crashes with the original error.
- Touch `wipeDefaultStoreFiles()` itself — it's a leaf and correct.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|--------------|-------------------|----------------|
| Fresh install | No store on disk | Succeeds first try; no catch path | N/A |
| Schema mismatch (SwiftDataError) | Pre-77.4 store on disk | Wipe + retry succeeds | Second wipe-or-init failure rethrows |
| Schema mismatch (CocoaError hash) | Store flagged with `persistentStoreIncompatibleVersionHash` | Wipe + retry succeeds | Same as above |
| Disk full | `CocoaError(.fileWriteOutOfSpace)` from first init | Rethrow; no wipe | Caller sees the original error |
| Permission denied | `CocoaError(.fileWriteNoPermission)` | Rethrow; no wipe | Same |
| Corrupt shm/wal | `CocoaError(.persistentStoreOpen)` / `.sqlite` | Rethrow; no wipe | Same — user can recover via offline tooling |
| Unrecognized SwiftDataError case | A `SwiftDataError` not in the wipe list | Rethrow; no wipe | Same |
| Arbitrary `Error` | Any other type | Rethrow; no wipe | Same |

</frozen-after-approval>

## Code Map

- `Peach/App/PeachApp.swift:302-319` — `setupDataStore`; narrow the catch and extract the classification.
- `Peach/Core/Data/PeachSchema.swift` — defines `SchemaV1` + `PeachSchemaMigrationPlan` (the wipe-and-retry remains tied to these).
- `Peach/App/PeachApp.swift:321-333` — `wipeDefaultStoreFiles` (unchanged; still invoked only on schema cases).
- `PeachTests/App/PeachAppDataStoreClassifierTests.swift` — **new** test file covering the classifier helper.

## Tasks & Acceptance

**Execution:**
- [x] `Peach/App/PeachApp.swift` — extract `static func shouldWipeStore(after error: Error) -> Bool` matching the four cases listed in **Always**; rewrite `setupDataStore` to call it instead of catching unconditionally. Log the chosen path explicitly.
- [x] `PeachTests/App/PeachAppDataStoreClassifierTests.swift` — add a `@Suite("setupDataStore error classifier")` with one `@Test` per row of the I/O matrix above (schema cases → true; disk-full / permission / sqlite / unknown SwiftDataError / arbitrary `NSError` → false).

**Acceptance Criteria:**
- Given the on-disk store is a pre-77.4 SwiftData store, when `setupDataStore` runs, then the store is wiped exactly once and a fresh `ModelContainer` is returned.
- Given a non-schema error fires (any `CocoaError` from the **Never** list, or any non-listed `SwiftDataError` case), when `setupDataStore` runs, then `wipeDefaultStoreFiles` is **not** called and the error rethrows unchanged.
- Given `shouldWipeStore(after:)` is called with each row in the I/O matrix, when the result is compared to the matrix's column, then they match.

## Spec Change Log

## Design Notes

**Why a classifier helper rather than inline `catch` arms?** A `private static func shouldWipeStore(after:) -> Bool` accepts synthetic errors in tests; an inline `catch` arm cannot be driven without a SwiftData mock layer (which doesn't exist and isn't worth building for this fix). The helper's signature also documents the contract: one boolean, one input.

**Calibrated uncertainty (research finding):** Apple's docs group `loadIssueModelContainer` under "Container errors" and `backwardMigration` / `unknownSchema` under "Migration errors" (https://docs.developer.apple.com/tutorials/data/documentation/swiftdata/swiftdataerror.md), but **no Apple-authored prose literally states "schema mismatch ⇒ `loadIssueModelContainer`"**. The classifier is calibrated to that uncertainty: it covers the three SwiftDataError grouping members plus the underlying Core Data `persistentStoreIncompatibleVersionHash` code, and lets everything else propagate. False-positive risk (wiping on a transient corrupt-`.shm`/`.wal` that SwiftData happens to surface as `loadIssueModelContainer`) is acknowledged but strictly smaller than the current "wipe on any error" surface; false-negative risk (a future schema case outside the four matched names) leaves the user with a re-thrown error on next launch — recoverable, not destructive.

## Verification

**Commands:**
- `bin/test.sh -s "PeachTests/PeachAppDataStoreClassifierTests"` — expected: classifier suite passes.
- `bin/test.sh` — expected: full iOS suite passes (no regression in the existing PeachApp lifecycle paths).
- `bin/test.sh -p mac` — expected: full macOS suite passes.
- `bin/build.sh && bin/build.sh -p mac` — expected: both platforms build clean.

## Suggested Review Order

**Narrowing the catch**

- The narrowed `catch` arm: classifier guard → schema log → wipe (now wrapped to preserve original error) → second init.
  [`PeachApp.swift:314`](../../Peach/App/PeachApp.swift#L314)

- The classifier itself — both the SwiftDataError switch arms and the explicit NSError fallback for raw Core Data domain+code 134140 (verified by `bridgedNSErrorHashMismatchWipes`).
  [`PeachApp.swift:351`](../../Peach/App/PeachApp.swift#L351)

**Test coverage of the I/O matrix**

- Wipe-true rows: four `SwiftDataError`/`CocoaError` schema cases plus the raw-NSError bridge.
  [`PeachAppDataStoreClassifierTests.swift:9`](../../PeachTests/App/PeachAppDataStoreClassifierTests.swift#L9)

- Wipe-false rows: disk-full, write-perm, read-perm, `persistentStoreOpen`, `fileReadCorruptFile`, unrelated `SwiftDataError`, arbitrary `NSError`.
  [`PeachAppDataStoreClassifierTests.swift:35`](../../PeachTests/App/PeachAppDataStoreClassifierTests.swift#L35)

**Deferred follow-ups (catalog)**

- PF-071 (no integration test for the wipe-then-retry orchestration), PF-072 (`.public`-privacy convention), PF-073 (telemetry on the destructive path).
  [`deferred-work.md` PF-071..073](../implementation-artifacts/deferred-work.md)
