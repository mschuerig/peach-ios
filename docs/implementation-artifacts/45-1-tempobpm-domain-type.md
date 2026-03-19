# Story 45.1: TempoBPM Domain Type

Status: review

## Story

As a **developer**,
I want a `TempoBPM` value type representing tempo in beats per minute,
So that all rhythm APIs use a domain type instead of raw `Int` values.

## Acceptance Criteria

1. **Given** `TempoBPM` with an `Int` value, **when** it is used across the codebase, **then** it conforms to `Hashable`, `Sendable`, `Codable`, `Comparable`.

2. **Given** a `TempoBPM` value, **when** `sixteenthNoteDuration` is computed, **then** it returns `Duration.seconds(60.0 / (Double(value) * 4.0))`, **and** unit tests verify known values (e.g., 120 BPM -> 125ms sixteenth note).

3. **Given** file location conventions, **when** the file is created, **then** it is placed at `Core/Music/TempoBPM.swift` with tests at `PeachTests/Core/Music/TempoBPMTests.swift`.

## Tasks / Subtasks

- [x] Task 1: Create `TempoBPM` value type (AC: #1, #3)
  - [x] Create `Peach/Core/Music/TempoBPM.swift`
  - [x] `struct TempoBPM` with `let value: Int`
  - [x] Conform to `Hashable`, `Sendable`, `Codable`, `Comparable`
  - [x] `Comparable` via `value` — `lhs.value < rhs.value`
  - [x] `nonisolated init(_ value: Int)` — matches `Cents` pattern
  - [x] Add `ExpressibleByIntegerLiteral` conformance for ergonomic construction
- [x] Task 2: Add `sixteenthNoteDuration` computed property (AC: #2)
  - [x] Compute `Duration.seconds(60.0 / (Double(value) * 4.0))`
  - [x] Formula: one beat = 60/BPM seconds, one sixteenth = beat / 4
- [x] Task 3: Write tests (AC: #2, #3)
  - [x] Create `PeachTests/Core/Music/TempoBPMTests.swift`
  - [x] `@Suite("TempoBPM")` struct with `@Test` functions (all `async`)
  - [x] Test `sixteenthNoteDuration` at 120 BPM -> `.milliseconds(125)`
  - [x] Test `sixteenthNoteDuration` at 60 BPM -> `.milliseconds(250)`
  - [x] Test `sixteenthNoteDuration` at 240 BPM -> `.milliseconds(62.5)` (use approximate comparison)
  - [x] Test `Comparable` — 60 BPM < 120 BPM
  - [x] Test `Hashable` — equal values hash equally
  - [x] Test `Codable` — round-trip encode/decode
  - [x] Test `ExpressibleByIntegerLiteral` — `let tempo: TempoBPM = 120`
  - [x] Run `bin/test.sh` — all tests pass
- [x] Task 4: Build verification (AC: #1)
  - [x] Run `bin/build.sh` — zero errors, zero warnings
  - [x] Run `bin/test.sh` — full suite passes

## Dev Notes

### Pattern to follow: `Cents.swift`

`TempoBPM` follows the same lightweight value type pattern as `Cents`, `Frequency`, `MIDINote`, `MIDIVelocity`, and `AmplitudeDB` in `Core/Music/`. Key similarities:
- Wraps a single primitive (`Int` for TempoBPM, `Double` for Cents)
- `nonisolated init` (required because default MainActor isolation applies)
- `Comparable` with explicit `<` operator
- `ExpressibleByIntegerLiteral` for ergonomic construction

Reference: `Peach/Core/Music/Cents.swift` — follow this exact file structure.

### Architecture specification

From architecture.md (v0.4 amendment, line 1667):
```swift
struct TempoBPM: Hashable, Sendable, Codable, Comparable {
    let value: Int
    var sixteenthNoteDuration: Duration {
        .seconds(60.0 / (Double(value) * 4.0))
    }
}
```

- `Int` storage — tempos are always whole BPM per the PRD
- `Comparable` for profile ordering and range validation
- Minimum floor ~60 BPM enforced at settings/session level, NOT in the type (FR85)
- `sixteenthNoteDuration` used by future sessions for pattern building and by display logic for offset-to-percentage conversion (FR87)

### Future conformance: `WelfordMeasurement`

Story 44.4 established the `WelfordMeasurement` protocol in `Core/Profile/WelfordAccumulator.swift` to bridge domain types to `Double` for statistical operations. `Cents` already conforms. `RhythmOffset` (story 45.2) will also need conformance — but `TempoBPM` itself does NOT need `WelfordMeasurement` conformance. `TempoBPM` is a grouping key (like `TrainingMode`), not a measured value.

### `Duration` comparison in tests

Swift `Duration` supports exact equality comparison. For 120 BPM: `Duration.seconds(60.0 / (120.0 * 4.0))` equals `.milliseconds(125)` exactly. For 240 BPM, `Duration.seconds(60.0 / (240.0 * 4.0))` = `.seconds(0.0625)` which is `.milliseconds(62.5)` — use `Duration.milliseconds(62.5)` (Duration supports fractional milliseconds via `.seconds(0.0625)`).

### `Codable` conformance

With `let value: Int` as the sole stored property, Swift compiler auto-synthesizes `Codable`. No manual implementation needed. The `nonisolated` requirement for `Codable` conformance (`init(from:)` and `encode(to:)`) is handled automatically since they're compiler-synthesized — no need for explicit `nonisolated` on synthesized conformances.

### Anti-patterns to avoid

- **Do NOT add validation/clamping in the initializer** — min tempo is a settings concern, not a type concern (architecture: "Minimum floor ~60 BPM enforced at the settings/session level, not in the type")
- **Do NOT make it a class** — value type, same as all other Music domain types
- **Do NOT add explicit `@MainActor`** — redundant with default isolation; use `nonisolated` on init
- **Do NOT use XCTest** — Swift Testing only (`@Test`, `@Suite`, `#expect`)
- **Do NOT add rhythm-specific logic** — this is purely a domain value type; rhythm session logic comes in later epics
- **Do NOT add `import SwiftUI`** — Core/ files are framework-free
- **Do NOT skip `nonisolated` on init** — required because default MainActor isolation applies to all code; init must be callable from any context for Codable deserialization

### Project Structure Notes

New files only — no modifications to existing files:
- `Peach/Core/Music/TempoBPM.swift` — new domain type
- `PeachTests/Core/Music/TempoBPMTests.swift` — new tests

Aligns with existing Core/Music/ directory containing: `Cents.swift`, `Frequency.swift`, `MIDINote.swift`, `MIDIVelocity.swift`, `AmplitudeDB.swift`, `Interval.swift`, `Direction.swift`, `DirectedInterval.swift`, `DetunedMIDINote.swift`, `NoteDuration.swift`, `NoteRange.swift`, `TuningSystem.swift`.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 45, Story 45.1]
- [Source: docs/planning-artifacts/architecture.md#v0.4 Amendment, lines 1667–1686 — TempoBPM specification]
- [Source: docs/project-context.md#Type Design — domain types everywhere]
- [Source: docs/project-context.md#Language-Specific Rules — nonisolated, Sendable, no explicit @MainActor]
- [Source: docs/project-context.md#Testing Rules — Swift Testing, struct-based suites, async test functions]
- [Source: Peach/Core/Music/Cents.swift — reference pattern for value type implementation]
- [Source: docs/implementation-artifacts/44-4-typed-metrics-generic-accumulator-incremental-profile-init.md — WelfordMeasurement context]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Implemented `TempoBPM` value type following the `Cents.swift` pattern exactly
- Conforms to `Hashable`, `Sendable`, `Codable`, `Comparable`, `ExpressibleByIntegerLiteral`
- `sixteenthNoteDuration` computed property returns `Duration.seconds(60.0 / (Double(value) * 4.0))`
- No validation/clamping in init — min tempo enforced at settings/session level per architecture spec
- 7 tests covering all ACs: Comparable, Hashable, Codable, ExpressibleByIntegerLiteral, sixteenthNoteDuration at 60/120/240 BPM
- Full suite: 1097 tests pass, zero regressions

### Change Log

- 2026-03-19: Implemented story 45.1 — TempoBPM domain type with all conformances and tests

### File List

- `Peach/Core/Music/TempoBPM.swift` (new)
- `PeachTests/Core/Music/TempoBPMTests.swift` (new)
