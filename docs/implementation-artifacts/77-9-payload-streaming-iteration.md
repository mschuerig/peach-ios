# Story 77.9: Streaming payload iteration on `TrainingDataStore`

Status: ready-for-dev

## Story

As **a developer maintaining hot read paths over the envelope store**,
I want a streaming/batched payload-iteration API on `TrainingDataStore` (e.g., `forEachPayload(_:body:)`) alongside the existing array-returning `fetchPayloads(_:)`,
so that callers iterating large payload sets — profile rebuild, duplicate-key building, CSV export — never have to materialise the full decoded array in memory at once, and the recurring "fetchAll pagination/streaming" concern is finally addressed at the right layer.

## Background

77.4 introduced the envelope storage path. Today every read goes through:

```swift
func fetchPayloads<P: TrainingDisciplinePayload>(_ type: P.Type) throws -> [(timestamp: Date, payload: P)]
```

which fetches every envelope for the discipline, decodes each into a `P`, and returns the full array. Callers that scan-and-aggregate — `feedAllRecords` (profile rebuild), `buildPitchDuplicateKeys` / `buildRhythmDuplicateKeys` (merge import), CSV export — only need one decoded payload at a time. They build aggregates incrementally and discard each decoded payload.

The recurring memory item **"Don't dismiss fetchAll pagination/streaming"** flags exactly this concern: the user has repeatedly asked for streaming/batched iteration over `fetchAll`-shaped APIs, and the request has been deferred each time. The envelope-by-envelope decode shape introduced in 77.4 makes streaming *cheaper* than before — each envelope is independent, decoding is local, and the iteration order is already sorted-by-timestamp.

77.4's review surfaced this finding and deferred it to its own story to keep the storage refactor focused on the envelope shape.

## Acceptance Criteria

### AC 1: Streaming API exists

**Given** `Peach/Core/Data/TrainingDataStore.swift`
**When** inspected after this story
**Then** the store exposes a streaming/batched payload-iteration method that decodes envelopes one at a time without holding the full array. Suggested shape (dev's call on the exact signature):

```swift
func forEachPayload<P: TrainingDisciplinePayload>(
    _ type: P.Type,
    body: (Date, P) throws -> Void
) throws
```

The implementation fetches envelopes (sorted), decodes one envelope at a time, hands the timestamp + payload to `body`, and lets the previous payload be deallocated before the next decode.

### AC 2: At least one read path migrated

**Given** the three primary scan-and-aggregate callers (profile rebuild, duplicate-key builders, CSV export)
**When** inspected after this story
**Then** at least one of them is migrated to the streaming API as a worked example. The remaining call sites may stay on `fetchPayloads` if the array shape suits them; the goal is not to migrate every caller in this story but to land the API and demonstrate it on a real scan-and-aggregate path. Document the migrated caller in Completion Notes.

### AC 3: `fetchPayloads(_:)` is preserved or thinned

**Given** existing callers of `fetchPayloads(_:)`
**When** inspected
**Then** either `fetchPayloads(_:)` is kept as a thin convenience that internally calls the streaming API and accumulates into an array, or it is preserved verbatim alongside the streaming API. Either is acceptable; the goal is no behavioural change at unmigrated call sites.

### AC 4: Tests cover the streaming contract

**Given** the new streaming method
**When** tested
**Then** tests cover at minimum:

- iteration order matches `fetchPayloads` ordering on the same data (timestamp-ascending),
- `body` receives every payload exactly once,
- a `body` that throws aborts iteration and propagates the error without partial state leakage,
- empty store yields zero `body` invocations.

### AC 5: All four configurations green

**Given** `bin/test.sh && bin/test.sh -p mac && bin/test.sh --research && bin/test.sh -p mac --research`
**When** run after the changes
**Then** all tests pass under all four configurations. `bin/build.sh && bin/build.sh -p mac` produces zero new warnings.

## Tasks / Subtasks

- [ ] Task 1: Land the streaming API (AC: 1)
  - [ ] 1.1 Add `forEachPayload(_:body:)` (or chosen-equivalent shape) to `TrainingDataStore`.
  - [ ] 1.2 Implement it so that decoding happens per envelope inside the iteration, not eagerly. The intermediate `TrainingRecord` array is allowed (SwiftData's `FetchDescriptor` is array-shaped today); the *decoded payload* is what must not be materialised in bulk.
  - [ ] 1.3 If/when SwiftData exposes a true streaming fetch, migrate the implementation; out of scope for this story.

- [ ] Task 2: Migrate a scan-and-aggregate caller (AC: 2)
  - [ ] 2.1 Pick one of: profile rebuild (`feedAllRecords` → `feedRecords` per discipline), duplicate-key builders (`buildPitchDuplicateKeys` / `buildRhythmDuplicateKeys`), or CSV export's per-discipline collection.
  - [ ] 2.2 Migrate the chosen caller to `forEachPayload`; ensure aggregate output is identical.
  - [ ] 2.3 Document the migrated caller and the rationale in Completion Notes.

- [ ] Task 3: Preserve or thin `fetchPayloads(_:)` (AC: 3)
  - [ ] 3.1 Decide whether to keep `fetchPayloads` verbatim or rewrite it on top of `forEachPayload`. Either is acceptable.
  - [ ] 3.2 Confirm no caller's behaviour changes.

- [ ] Task 4: Test coverage (AC: 4)
  - [ ] 4.1 Add focused tests in `PeachTests/Core/Data/` for the streaming contract.
  - [ ] 4.2 Confirm the tests fail meaningfully if the implementation accumulates into an array internally before invoking `body`.

- [ ] Task 5: Build/test (AC: 5)
  - [ ] 5.1 All four test configurations green.
  - [ ] 5.2 Build: zero new warnings.

- [ ] Task 6 (opportunistic): `RhythmDuplicateKey` naming on the timing-category caller
  - [ ] 6.1 If you migrate `buildRhythmDuplicateKeys(timingOffsetDetectionsIn:trainingType:)` (one of the two rhythm-key builders) to `forEachPayload`, take the opportunity to either rename `RhythmDuplicateKey` to a name that fits both rhythm-category disciplines without ambiguity (e.g. `TempoDuplicateKey`), or split it into two structurally-identical types whose names match each consuming discipline. Decide which is cleaner once the streaming migration shape is in front of you. Skip if you migrate a different caller.

## Dev Notes

### Why the request keeps coming back

The user has asked for streaming/batching on fetchAll-style APIs more than once and has flagged dismissals of the request as a problem. 77.4 made the underlying shape friendlier (envelope-by-envelope decode is independent), so this is the right moment.

The streaming API is not a premature optimisation — it is a load-bearing primitive that profile rebuild, merge import, and CSV export all want. The current array-shaped path forces every one of those callers to hold N decoded payloads in memory regardless of whether N is small or large.

### Why not a `Sequence`-shaped API

A `Sequence` or `AsyncSequence`-shaped API would be cleaner stylistically but introduces lifetime questions (the SwiftData `ModelContext` must outlive iteration; lazy decoding interacts with `throws`). The closure-based `forEachPayload` keeps lifetime obvious and matches the existing `withinTransaction` pattern. If a future story finds the closure shape limiting, redesign then.

### What this story is NOT

- Not a SwiftData migration to a different fetch primitive. SwiftData's `fetch(_:)` returns an array; that is acceptable so long as the *decoded payload* is streamed.
- Not a wholesale migration of every existing call site. One worked example demonstrates the API; subsequent stories or opportunistic migration handle the rest.
- Not a `replaceAllRecords` or `withinTransaction` redesign. Those stay as-is.

### References

- `Peach/Core/Data/TrainingDataStore.swift` — `fetchPayloads(_:)` is the array-shaped API to complement.
- `Peach/Core/Training/Discipline/TrainingDisciplineRegistry.swift` — `feedAllRecords` is one candidate scan-and-aggregate caller.
- `Peach/Core/Training/DuplicateKey.swift` — `buildPitchDuplicateKeys` / `buildRhythmDuplicateKeys` are other candidates.
- `Peach/Core/Data/TrainingDataExporter.swift` (or its CSV equivalent) — per-discipline payload collection during export.
- Memory: `feedback_fetchall_streaming` — recurring user request to take streaming seriously rather than dismiss.
- Story 77.4 — review surfaced this finding and deferred it.

## Change Log

- 2026-04-28: Drafted as a deferred 77.4 review finding, taking up the recurring `fetchAll` streaming request now that the envelope shape makes it cheap. Status → ready-for-dev.
- 2026-04-29: Added Task 6 (opportunistic) — `RhythmDuplicateKey` naming on the timing-category caller, deferred from 77.8 review (D3). Boy-Scout rename to consider only if the migration touches `buildRhythmDuplicateKeys(timingOffsetDetectionsIn:...)`.
