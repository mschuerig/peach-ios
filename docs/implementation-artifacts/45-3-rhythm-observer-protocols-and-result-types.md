# Story 45.3: Rhythm Observer Protocols and Result Types

Status: review

## Story

As a **developer**,
I want `RhythmComparisonObserver` and `RhythmMatchingObserver` protocols with their completed-result value types,
So that rhythm sessions can notify observers using the same pattern as pitch training.

## Acceptance Criteria

1. **Given** `RhythmComparisonObserver` protocol, **when** inspected, **then** it declares `rhythmComparisonCompleted(_ result: CompletedRhythmComparison)`.

2. **Given** `CompletedRhythmComparison` value type, **when** inspected, **then** it contains `tempo: TempoBPM`, `offset: RhythmOffset`, `isCorrect: Bool`, `timestamp: Date` **and** conforms to `Sendable`.

3. **Given** `RhythmMatchingObserver` protocol, **when** inspected, **then** it declares `rhythmMatchingCompleted(_ result: CompletedRhythmMatching)`.

4. **Given** `CompletedRhythmMatching` value type, **when** inspected, **then** it contains `tempo: TempoBPM`, `expectedOffset: RhythmOffset`, `userOffset: RhythmOffset`, `timestamp: Date` **and** conforms to `Sendable`.

5. **Given** file locations, **when** files are created, **then** observer protocols are in `Core/Training/` and value types in `Core/Training/` with corresponding tests.

## Tasks / Subtasks

- [x] Task 1: Create `CompletedRhythmComparison` value type (AC: #2, #5)
  - [x] Create `Peach/Core/Training/CompletedRhythmComparison.swift`
  - [x] `struct CompletedRhythmComparison: Sendable` with `let tempo: TempoBPM`, `let offset: RhythmOffset`, `let isCorrect: Bool`, `let timestamp: Date`
  - [x] `nonisolated init` with `timestamp: Date = Date()` default
- [x] Task 2: Create `RhythmComparisonObserver` protocol (AC: #1, #5)
  - [x] Create `Peach/Core/Training/RhythmComparisonObserver.swift`
  - [x] `protocol RhythmComparisonObserver` with `func rhythmComparisonCompleted(_ result: CompletedRhythmComparison)`
- [x] Task 3: Create `CompletedRhythmMatching` value type (AC: #4, #5)
  - [x] Create `Peach/Core/Training/CompletedRhythmMatching.swift`
  - [x] `struct CompletedRhythmMatching: Sendable` with `let tempo: TempoBPM`, `let expectedOffset: RhythmOffset`, `let userOffset: RhythmOffset`, `let timestamp: Date`
  - [x] `nonisolated init` with `timestamp: Date = Date()` default
- [x] Task 4: Create `RhythmMatchingObserver` protocol (AC: #3, #5)
  - [x] Create `Peach/Core/Training/RhythmMatchingObserver.swift`
  - [x] `protocol RhythmMatchingObserver` with `func rhythmMatchingCompleted(_ result: CompletedRhythmMatching)`
- [x] Task 5: Write `CompletedRhythmComparison` tests (AC: #2)
  - [x] Create `PeachTests/Core/Training/CompletedRhythmComparisonTests.swift`
  - [x] `@Suite("CompletedRhythmComparison")` struct with `@Test` functions (all `async`)
  - [x] Test stored properties are accessible and correct
  - [x] Test default timestamp is populated
  - [x] Test `Sendable` conformance (compiles with `nonisolated(unsafe)` not needed)
- [x] Task 6: Write `CompletedRhythmMatching` tests (AC: #4)
  - [x] Create `PeachTests/Core/Training/CompletedRhythmMatchingTests.swift`
  - [x] `@Suite("CompletedRhythmMatching")` struct with `@Test` functions (all `async`)
  - [x] Test stored properties are accessible and correct
  - [x] Test `expectedOffset` and `userOffset` are independent values
  - [x] Test default timestamp is populated
- [x] Task 7: Build verification
  - [x] Run `bin/build.sh` — zero errors, zero warnings
  - [x] Run `bin/test.sh` — full suite passes, zero regressions

## Dev Notes

### Pattern to follow: existing pitch observer protocols

The rhythm observer types mirror the pitch observer types exactly. Follow these reference files:

| Rhythm (new)                         | Pitch (existing pattern)                          |
|--------------------------------------|---------------------------------------------------|
| `RhythmComparisonObserver.swift`     | `Core/Training/PitchComparisonObserver.swift`     |
| `RhythmMatchingObserver.swift`       | `Core/Training/PitchMatchingObserver.swift`       |
| `CompletedRhythmComparison.swift`    | `Core/Training/PitchComparison.swift` (contains `CompletedPitchComparison`) |
| `CompletedRhythmMatching.swift`      | `Core/Training/CompletedPitchMatching.swift`      |

Key differences from pitch patterns:
- **Separate files for result types** — unlike pitch where `CompletedPitchComparison` shares a file with `PitchComparison`, the rhythm result types each get their own file (there is no `RhythmComparison` companion type yet)
- **Simpler data** — rhythm results carry `TempoBPM` + `RhythmOffset` instead of `MIDINote` + `Cents` + `TuningSystem`
- **Explicit `Sendable`** — architecture specifies `Sendable` conformance on result types; pitch types get it implicitly (all stored properties are value types), but rhythm types should declare it explicitly per the AC

### Architecture specification

From architecture.md (Observer Protocols section):

```swift
protocol RhythmComparisonObserver {
    func rhythmComparisonCompleted(_ result: CompletedRhythmComparison)
}

protocol RhythmMatchingObserver {
    func rhythmMatchingCompleted(_ result: CompletedRhythmMatching)
}
```

```swift
struct CompletedRhythmComparison {
    let tempo: TempoBPM
    let offset: RhythmOffset        // the offset that was presented
    let isCorrect: Bool
    let timestamp: Date
}

struct CompletedRhythmMatching {
    let tempo: TempoBPM
    let expectedOffset: RhythmOffset  // always zero (the correct beat position)
    let userOffset: RhythmOffset      // signed timing error
    let timestamp: Date
}
```

File locations per architecture:
- `Core/Training/RhythmComparisonObserver.swift`
- `Core/Training/RhythmMatchingObserver.swift`
- `Core/Training/CompletedRhythmComparison.swift`
- `Core/Training/CompletedRhythmMatching.swift`

### `nonisolated init` pattern

All value types in this project use `nonisolated init` because default MainActor isolation applies project-wide. Without `nonisolated`, the init would be `@MainActor`-isolated, preventing construction from non-isolated contexts (e.g., `Codable` deserialization, test factories). Follow the same pattern as `TempoBPM`, `RhythmOffset`, and `CompletedPitchMatching`.

### `import Foundation` only

These files only need `import Foundation` (for `Date`). The domain types `TempoBPM` and `RhythmOffset` are in the same module (`Core/Music/`). No SwiftUI, no UIKit — Core/ is framework-free.

### Future conforming types (NOT in scope for this story)

The architecture lists these future observers — do NOT implement any conformances:
- `TrainingDataStore` — will persist `RhythmComparisonRecord` / `RhythmMatchingRecord`
- `PerceptualProfile` — will update rhythm statistics via `RhythmProfile`
- `ProgressTimeline` — will track rhythm training modes
- `HapticFeedbackManager` — will provide haptic on incorrect rhythm comparison answers

### Anti-patterns to avoid

- **Do NOT implement observer conformances** — this story creates only the protocols and value types; conformances belong in later stories
- **Do NOT create `RhythmChallenge`** — that type belongs in `RhythmComparison/` (a feature directory), not `Core/Training/`
- **Do NOT add doc comments listing future conforming types** — the pitch observer has detailed doc comments listing conforming types, but those were added after the conformances existed; adding them now would be speculative
- **Do NOT use XCTest** — Swift Testing only (`@Test`, `@Suite`, `#expect`)
- **Do NOT add explicit `@MainActor`** — redundant with default isolation; use `nonisolated` on init
- **Do NOT add `import SwiftUI`** — Core/ files are framework-free
- **Do NOT add `Codable` or `Hashable`** — not specified in the AC; these are transient event types, not persisted or compared

### Previous story learnings (from 45.2)

- `Duration` does not support unary `-` operator; use `.zero - duration` pattern instead
- Code review removed `Comparable` from `RhythmOffset` because magnitude-based ordering conflicts with identity-based `Equatable` — don't assume types have conformances not listed in their AC
- `precondition(value > 0)` was added to `TempoBPM.init` — safe to use `TempoBPM` in tests without worrying about zero-division

### Project Structure Notes

New files only — no modifications to existing files:
- `Peach/Core/Training/CompletedRhythmComparison.swift` — new value type
- `Peach/Core/Training/CompletedRhythmMatching.swift` — new value type
- `Peach/Core/Training/RhythmComparisonObserver.swift` — new protocol
- `Peach/Core/Training/RhythmMatchingObserver.swift` — new protocol
- `PeachTests/Core/Training/CompletedRhythmComparisonTests.swift` — new tests
- `PeachTests/Core/Training/CompletedRhythmMatchingTests.swift` — new tests

Existing Core/Training/ directory contains: `PitchComparisonObserver.swift`, `PitchMatchingObserver.swift`, `PitchComparison.swift`, `CompletedPitchMatching.swift`, `Resettable.swift`, `PitchComparisonTrainingSettings.swift`, `PitchMatchingTrainingSettings.swift`.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 45, Story 45.3]
- [Source: docs/planning-artifacts/architecture.md#Observer Protocols — RhythmComparisonObserver, RhythmMatchingObserver, CompletedRhythmComparison, CompletedRhythmMatching]
- [Source: docs/project-context.md#Type Design — domain types everywhere, nonisolated init]
- [Source: docs/project-context.md#Language-Specific Rules — nonisolated, Sendable, no explicit @MainActor]
- [Source: docs/project-context.md#Testing Rules — Swift Testing, struct-based suites, async test functions]
- [Source: Peach/Core/Training/PitchComparisonObserver.swift — reference pattern for observer protocol]
- [Source: Peach/Core/Training/PitchMatchingObserver.swift — reference pattern for observer protocol]
- [Source: Peach/Core/Training/CompletedPitchMatching.swift — reference pattern for result value type]
- [Source: docs/implementation-artifacts/45-2-rhythmoffset-and-rhythmdirection-domain-types.md — previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- All 4 source files created in `Core/Training/` following pitch observer patterns
- Both value types declare explicit `Sendable` conformance per AC
- `nonisolated init` with `timestamp: Date = Date()` default on both value types
- Protocols are minimal — single method each, no doc comments listing future conforming types (per anti-patterns)
- 8 tests across 2 test suites: stored property access, default timestamp, Sendable conformance, independent offsets
- Build succeeds (zero errors), full test suite passes (1116 tests, zero regressions)

### Change Log

- 2026-03-20: Implemented story 45.3 — created 4 source files and 2 test files

### File List

- `Peach/Core/Training/CompletedRhythmComparison.swift` — new
- `Peach/Core/Training/CompletedRhythmMatching.swift` — new
- `Peach/Core/Training/RhythmComparisonObserver.swift` — new
- `Peach/Core/Training/RhythmMatchingObserver.swift` — new
- `PeachTests/Core/Training/CompletedRhythmComparisonTests.swift` — new
- `PeachTests/Core/Training/CompletedRhythmMatchingTests.swift` — new
