# Story 77.7: Collapse merge-import boilerplate across disciplines

Status: ready-for-dev

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

- [ ] Task 1: Pick the helper location and signature (AC: 1)
  - [ ] 1.1 Survey the four call sites; identify whether the shared parts (encode + insert + key insert + counter increments) belong on the scope, on `JSONEnvelope`, or as a free function.
  - [ ] 1.2 Define the signature so the discipline supplies a `(Date, Payload) -> Key` closure and an `inout Set<Key>` it can pass through.
  - [ ] 1.3 Confirm the chosen signature does not require new imports in feature directories.

- [ ] Task 2: Extract the helper (AC: 1, 4)
  - [ ] 2.1 Implement the helper.
  - [ ] 2.2 Add a focused unit test exercising the encode-and-insert-if-new contract: empty existing-keys set, all-duplicate input, mixed input, throwing-encoder failure path.

- [ ] Task 3: Migrate the four disciplines (AC: 2, 3, 4)
  - [ ] 3.1 Replace each discipline's inline loop with a call to the helper.
  - [ ] 3.2 If `parsedRecords` returns existentials, confine the cast to one site per discipline (or change `parsedRecords` to return a typed array — coordinate with 77.8 if it lands first).
  - [ ] 3.3 Confirm imported/skipped counts match the pre-change behaviour for every test using `MergeImport`-style fixtures.

- [ ] Task 4: Build/test (AC: 5)
  - [ ] 4.1 All four test configurations green.
  - [ ] 4.2 Build: zero new warnings.

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
