# Story 77.7: Collapse merge-import boilerplate across disciplines

Status: done

## Story

As **a developer adding a new training discipline**,
I want the encode-and-insert-if-new merge loop in `mergeImportRecords(from:existingIn:into:)` reduced to a discipline-supplied key constructor plus a shared helper,
so that the four existing disciplines stop carrying near-identical loop bodies and a fifth discipline gets duplicate-aware merging "for free" without copying loop boilerplate.

## Background

77.4 left each discipline implementing the same shape:

```swift
func mergeImportRecords(...) throws -> (imported: Int, skipped: Int) {
    var existingKeys = try buildPitchDuplicateKeys(from: store)
    var imported = 0, skipped = 0
    for entry in parsedRecords(from: parseResult) {
        guard let p = entry.payload as? PitchDiscriminationPayload else { continue }
        let key = PitchDuplicateKey(timestamp: entry.timestamp, payload: p)
        if existingKeys.contains(key) {
            skipped += 1
            continue
        }
        let envelope = try JSONEnvelope.encode(p, timestamp: entry.timestamp)
        scope.insert(envelope)
        existingKeys.insert(key)
        imported += 1
    }
    return (imported, skipped)
}
```

The eight discipline files (Unison/Interval × Pitch Discrimination/Matching, plus the two rhythm disciplines) repeat this body verbatim. Only three things differ across them:

1. The payload type the parsed entry casts to.
2. The `existingKeys` builder (`buildPitchDuplicateKeys` vs. `buildRhythmDuplicateKeys`).
3. The key constructor `PitchDuplicateKey(timestamp:, payload:)` / `RhythmDuplicateKey(timestamp:, tempoBPM:, trainingType:)`.

Per the **Symmetric protocol design** memory, "new training domains must mirror existing protocol splits and reuse generic infrastructure." The current shape duplicates infrastructure rather than reusing it.

77.4's review surfaced this finding and deferred it to its own story to keep the envelope-storage refactor focused.

## Acceptance Criteria

### AC 1: Generic merge helper exists

**Given** the merge logic is consolidated
**When** inspected
**Then** a single helper performs the encode-and-insert-if-new loop. The helper takes:

- the parsed entries already filtered to the concrete payload type,
- the pre-built `existingKeys` set (or an iterator that yields them),
- a key constructor `(Date, Payload) -> Key` for the discipline,
- the `TransactionScope` to insert into.

It returns `(imported: Int, skipped: Int)`.

The helper's location is dev's choice: an extension on `TrainingDataStore.TransactionScope`, a free function in `Peach/Core/Training/`, or a static method on `JSONEnvelope`. Pick the location whose existing imports match the call sites with the least friction.

### AC 2: Discipline `mergeImportRecords` shrinks to wiring

**Given** each of the four conforming discipline implementations
**When** inspected after this story
**Then** `mergeImportRecords` contains no inline loop body — only:

1. building the existing-key set,
2. providing the typed parsed records,
3. invoking the helper with the key constructor.

A reasonable target is ≤ 8 lines per `mergeImportRecords` body.

### AC 3: Existential cast is gone or isolated

**Given** the helper consumes already-typed `[(Date, Payload)]`
**When** inspected
**Then** the `guard let p = entry.payload as? PitchDiscriminationPayload else { continue }` (and its three siblings) is gone, or — if `parsedRecords` still returns existentials — confined to one place per discipline rather than appearing inside the loop body.

### AC 4: No semantic change

**Given** existing tests
**When** the merge importer runs
**Then** behaviour is identical: same imported / skipped counts on every test fixture, same envelope insertions, same duplicate-key detection. No test changes are required for the four existing disciplines, beyond any fixture updates that go hand-in-hand with helper-shape changes.

### AC 5: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all tests pass under all four configurations. `bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

## Tasks / Subtasks

- [x] Task 1: Pick the helper location and signature (AC: 1)
  - [x] 1.1 Survey the four call sites; identify whether the shared parts (encode + insert + key insert + counter increments) belong on the scope, on `JSONEnvelope`, or as a free function.
  - [x] 1.2 Define the signature so the discipline supplies a `(Date, Payload) -> Key` closure and an `inout Set<Key>` it can pass through.
  - [x] 1.3 Confirm the chosen signature does not require new imports in feature directories.

- [x] Task 2: Extract the helper (AC: 1, 4)
  - [x] 2.1 Implement the helper.
  - [x] 2.2 Add a focused unit test exercising the encode-and-insert-if-new contract: empty existing-keys set, all-duplicate input, mixed input, throwing-encoder failure path.

- [x] Task 3: Migrate the four disciplines (AC: 2, 3, 4)
  - [x] 3.1 Replace each discipline's inline loop with a call to the helper.
  - [x] 3.2 If `parsedRecords` returns existentials, confine the cast to one site per discipline (or change `parsedRecords` to return a typed array — coordinate with 77.8 if it lands first).
  - [x] 3.3 Confirm imported/skipped counts match the pre-change behaviour for every test using `MergeImport`-style fixtures.

- [x] Task 4: Build/test (AC: 5)
  - [x] 4.1 All four test configurations green.
  - [x] 4.2 Build: zero new warnings.

## Dev Notes

### Why a helper rather than a default method on `TrainingDiscipline`

Putting the merge body as a default implementation on `TrainingDiscipline` hides the typed `Payload` inside the protocol and hits Swift's existential-cast pain. A free or scope-attached helper that takes the typed array directly is simpler and lets each discipline stay loosely coupled to the merge mechanism.

If 77.8 (associated `Payload` type) lands first, this helper becomes a default protocol method and the cast disappears entirely. Coordinate work order accordingly — do not block this story on 77.8.

### What this story is NOT

- Not a `parsedRecords` redesign. If `parsedRecords` still returns `any TrainingDisciplinePayload`, the helper's caller does the cast once. 77.8 is the place to fix the existential.
- Not a streaming change. 77.9 covers streaming; this story keeps array-shaped inputs.
- Not a duplicate-key-builder consolidation. `buildPitchDuplicateKeys` / `buildRhythmDuplicateKeys` keep their signatures.

### References

- `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift` — `mergeImportRecords(...)` is the canonical loop body; the three sibling files mirror it.
- `Peach/Training/PitchMatching/Discipline/IntervalPitchMatchingDiscipline.swift` — same shape against `PitchMatchingPayload`.
- `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift` and `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift` — same shape against the rhythm payloads + `RhythmDuplicateKey`.
- `Peach/Core/Training/DuplicateKey.swift` — key types and existing-key builders.
- `Peach/Core/Data/JSONEnvelope.swift` — encode helper used inside the loop.
- `Peach/Core/Data/TrainingDataStore.swift` — `TransactionScope` is the insert target.
- Story 77.4 — review surfaced this finding and deferred it.

## Change Log

- 2026-04-28: Drafted as a deferred 77.4 review finding. Status → ready-for-dev.
- 2026-04-28: Implemented helper `TrainingDataStore.TransactionScope.mergeImportPayloads(_:existingKeys:keyFor:)` and migrated all six conforming disciplines (the story narrative said "four"; six discipline files actually carried the loop body — pitch and matching × unison/interval, plus the two rhythm disciplines). Status → review.
- 2026-04-28: Code-review fixes — extended helper doc to specify the throw-path contract and `keyFor` injectivity expectation; converted the six discipline call sites to trailing-closure form so each body is 8 lines; strengthened the in-batch-dedup test to assert first-occurrence-wins; added empty-batch and partial-success-then-throw tests.
- 2026-04-29: Resolved deferred review findings. (1) Type-mismatched payloads silently dropped at each per-discipline `compactMap` is captured by 77.8 Task 3.2 — no separate tracking. (2) Generic `K: Hashable` unrelated to `P` is captured by new 77.8 subtask 4.3 (consider associated `DuplicateKey`). (3) Throw-time loss of `imported`/`skipped` progress: **won't-do** — pre-existing design with no current caller needing partial progress; revisit only when a real merge-import retry use case appears. (4) No test for cross-call `existingKeys` reuse in one transaction: **won't-do** — speculative; no discipline calls the helper more than once per transaction. Status → done.

## Dev Agent Record

### Implementation Plan

- Helper location: extension on `TrainingDataStore.TransactionScope` in `Peach/Core/Data/TransactionScope+MergeImport.swift`. Same module as `JSONEnvelope`/`TrainingRecord`, no new imports required at call sites (Foundation only). Reads naturally as `scope.mergeImportPayloads(...)` next to the existing `scope.insert(envelope)`.
- Signature: generic over `P: TrainingDisciplinePayload` and `K: Hashable`; takes typed `[(timestamp: Date, payload: P)]`, an `inout Set<K>` (so in-batch duplicates are caught after the first successful insert), and a `keyFor: (Date, P) -> K` closure. Returns the same `(imported: Int, skipped: Int)` tuple the protocol method returns.
- Existential cast: confined to a single `compactMap` per discipline, immediately before the helper call. Disappears when 77.8 lands the typed `Payload` associated type.
- Order preserved as encode → `scope.insert` → `existingKeys.insert` so a throwing encoder cannot leave the local key set ahead of what was actually persisted.

### Completion Notes

- Helper consolidates the encode-and-insert-if-new loop that was duplicated across six disciplines. Each discipline's `mergeImportRecords` body is now 8 lines (build set, typed conversion, helper call as trailing-closure form).
- All four test configurations green: iOS Debug 1460 passed, macOS Debug 1454, iOS Debug (Research) 1804, macOS Debug (Research) 1798.
- Both builds clean (only the pre-existing `appintentsmetadataprocessor` warning, unchanged by this story).
- Unit tests in `PeachTests/Core/Data/TransactionScopeMergeImportTests.swift` cover: empty existing-keys, all-duplicate, mixed input, empty batch, in-batch dedup (asserts first-occurrence-wins), throwing-encoder, and partial-success-then-throw (documents the inout/transaction asymmetry).

### File List

- Added: `Peach/Core/Data/TransactionScope+MergeImport.swift`
- Added: `PeachTests/Core/Data/TransactionScopeMergeImportTests.swift`
- Modified: `Peach/Training/PitchDiscrimination/Discipline/UnisonPitchDiscriminationDiscipline.swift`
- Modified: `Peach/Training/PitchDiscrimination/Discipline/IntervalPitchDiscriminationDiscipline.swift`
- Modified: `Peach/Training/PitchMatching/Discipline/UnisonPitchMatchingDiscipline.swift`
- Modified: `Peach/Training/PitchMatching/Discipline/IntervalPitchMatchingDiscipline.swift`
- Modified: `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift`
- Modified: `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift`
- Modified: `docs/implementation-artifacts/77-7-collapse-merge-import-boilerplate.md`
- Modified: `docs/implementation-artifacts/sprint-status.yaml`
