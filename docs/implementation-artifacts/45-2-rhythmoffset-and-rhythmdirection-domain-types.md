# Story 45.2: RhythmOffset and RhythmDirection Domain Types

Status: ready-for-dev

## Story

As a **developer**,
I want `RhythmOffset` (signed duration) and `RhythmDirection` (early/late) types,
So that rhythm timing data uses domain types with direction derived from sign (FR99).

## Acceptance Criteria

1. **Given** `RhythmOffset` with a `Duration` value, **when** the duration is negative, **then** `direction` returns `.early`.

2. **Given** `RhythmOffset` with a positive or zero duration, **when** `direction` is accessed, **then** it returns `.late` (zero treated as on-the-beat, classified as late per architecture).

3. **Given** a `RhythmOffset` and a `TempoBPM`, **when** `percentageOfSixteenthNote(at:)` is called, **then** it returns `abs(duration / tempo.sixteenthNoteDuration) * 100` (FR87), **and** unit tests verify known values (e.g., 12.5ms offset at 120 BPM = 10% of 125ms sixteenth note).

4. **Given** `RhythmDirection` enum, **when** inspected, **then** it has cases `.early` and `.late` and conforms to `Hashable`, `Sendable`, `Codable`.

5. **Given** `RhythmOffset`, **when** `Comparable` is applied, **then** ordering is based on absolute magnitude (for difficulty comparison).

6. **Given** file location conventions, **when** files are created, **then** `RhythmOffset.swift` and `RhythmDirection.swift` are in `Core/Music/` with corresponding tests.

## Tasks / Subtasks

- [ ] Task 1: Create `RhythmDirection` enum (AC: #4, #6)
  - [ ] Create `Peach/Core/Music/RhythmDirection.swift`
  - [ ] `enum RhythmDirection: Hashable, Sendable, Codable` with cases `.early`, `.late`
  - [ ] No `import SwiftUI` — Core/ is framework-free
- [ ] Task 2: Create `RhythmOffset` value type (AC: #1, #2, #5, #6)
  - [ ] Create `Peach/Core/Music/RhythmOffset.swift`
  - [ ] `struct RhythmOffset` with `let duration: Duration`
  - [ ] Conform to `Hashable`, `Sendable`, `Codable`, `Comparable`
  - [ ] `nonisolated init(_ duration: Duration)` — matches `Cents`/`TempoBPM` pattern
  - [ ] Computed `var direction: RhythmDirection` — negative → `.early`, positive or zero → `.late`
  - [ ] `Comparable` via absolute magnitude: `abs(lhs) < abs(rhs)`, NOT raw duration order
- [ ] Task 3: Add `percentageOfSixteenthNote(at:)` method (AC: #3)
  - [ ] `func percentageOfSixteenthNote(at tempo: TempoBPM) -> Double`
  - [ ] Formula: `abs(duration / tempo.sixteenthNoteDuration) * 100`
  - [ ] Uses `Duration / Duration` which returns `Double` natively in Swift
- [ ] Task 4: Write `RhythmDirection` tests (AC: #4, #6)
  - [ ] Create `PeachTests/Core/Music/RhythmDirectionTests.swift`
  - [ ] `@Suite("RhythmDirection")` struct with `@Test` functions (all `async`)
  - [ ] Test `Codable` — round-trip encode/decode for both cases
  - [ ] Test `Hashable` — set deduplication
- [ ] Task 5: Write `RhythmOffset` tests (AC: #1, #2, #3, #5, #6)
  - [ ] Create `PeachTests/Core/Music/RhythmOffsetTests.swift`
  - [ ] `@Suite("RhythmOffset")` struct with `@Test` functions (all `async`)
  - [ ] Test `direction` — negative duration → `.early`
  - [ ] Test `direction` — positive duration → `.late`
  - [ ] Test `direction` — zero duration → `.late`
  - [ ] Test `percentageOfSixteenthNote` — 12.5ms offset at 120 BPM = 10% (12.5 / 125 × 100)
  - [ ] Test `percentageOfSixteenthNote` — 125ms offset at 120 BPM = 100%
  - [ ] Test `percentageOfSixteenthNote` — negative offset uses absolute value
  - [ ] Test `Comparable` — smaller magnitude < larger magnitude regardless of sign
  - [ ] Test `Comparable` — equal magnitude offsets (early vs late) are equal in ordering
  - [ ] Test `Codable` — round-trip encode/decode preserves duration
  - [ ] Test `Hashable` — equal values hash equally
- [ ] Task 6: Build verification
  - [ ] Run `bin/build.sh` — zero errors, zero warnings
  - [ ] Run `bin/test.sh` — full suite passes, zero regressions

## Dev Notes

### Pattern to follow: `TempoBPM.swift` and `Cents.swift`

Both `RhythmDirection` and `RhythmOffset` follow the same lightweight domain type pattern as other `Core/Music/` types. Key similarities:
- `nonisolated init` (required because default MainActor isolation applies)
- `Comparable` with explicit `<` operator
- Single stored property wrapper

Reference files:
- `Peach/Core/Music/TempoBPM.swift` — closest structural match for `RhythmOffset`
- `Peach/Core/Music/Cents.swift` — `magnitude` property and `Comparable` pattern

### Architecture specification

From architecture.md (v0.4 amendment):

**RhythmDirection (lines 1713–1724):**
```swift
enum RhythmDirection: Hashable, Sendable, Codable {
    case early
    case late
}
```

**RhythmOffset (lines 1688–1711):**
```swift
struct RhythmOffset: Hashable, Sendable, Codable, Comparable {
    /// Signed duration — negative means early, positive means late.
    let duration: Duration

    var direction: RhythmDirection {
        if duration < .zero { return .early }
        if duration > .zero { return .late }
        return .late // zero offset treated as "on the beat"
    }

    /// Offset as percentage of one sixteenth note at the given tempo (FR87).
    func percentageOfSixteenthNote(at tempo: TempoBPM) -> Double
}
```

- `Duration` (Swift native) as underlying representation — sub-millisecond precision without floating-point ambiguity
- Sign encodes direction (FR99) — no separate early/late field needed
- `Comparable` based on absolute magnitude for difficulty comparison
- File locations: `Core/Music/RhythmOffset.swift`, `Core/Music/RhythmDirection.swift`

### Critical: `Comparable` is by absolute magnitude, NOT raw value

Unlike `TempoBPM` and `Cents` where `Comparable` uses the raw value, `RhythmOffset.Comparable` must use **absolute magnitude**. The architecture specifies this for difficulty comparison — a 50ms-early offset and 50ms-late offset are equally difficult. Implementation:

```swift
static func < (lhs: RhythmOffset, rhs: RhythmOffset) -> Bool {
    abs(lhs.duration) < abs(rhs.duration)
}
```

Where `abs` for `Duration` is: `duration < .zero ? -duration : duration` (no built-in `abs` for `Duration`, but `Duration` supports unary negation).

**Consequence:** Two offsets with equal magnitude but opposite signs (e.g., -50ms and +50ms) are `==` under `Comparable` (neither is less than the other). This is intentional — they represent equal difficulty.

### `Duration` division for percentage calculation

Swift `Duration / Duration` returns `Double` natively. The `percentageOfSixteenthNote(at:)` implementation:

```swift
func percentageOfSixteenthNote(at tempo: TempoBPM) -> Double {
    let absDuration = duration < .zero ? -duration : duration
    return (absDuration / tempo.sixteenthNoteDuration) * 100.0
}
```

Test values at 120 BPM (sixteenth note = 125ms):
- 12.5ms offset → 10%
- 125ms offset → 100%
- -12.5ms offset → 10% (absolute value)

### `Codable` for `Duration`

`Duration` conforms to `Codable` natively (Swift 5.9+/iOS 17+). With `let duration: Duration` as the sole stored property, Swift auto-synthesizes `Codable` for `RhythmOffset`. Same pattern as `TempoBPM`'s auto-synthesized `Codable`.

### Future conformance: `WelfordMeasurement`

Story 44.4 established `WelfordMeasurement` in `Core/Profile/WelfordAccumulator.swift` to bridge domain types to `Double` for statistical operations. `RhythmOffset` will need this conformance when `RhythmProfile` (story 45.4) uses `WelfordAccumulator<RhythmOffset>`. However, `WelfordMeasurement` conformance is NOT an AC for this story — it belongs in story 45.4 where the accumulator is actually used. The `statisticalValue` mapping will be: `duration` in seconds as `Double` (via `Duration` components).

### Anti-patterns to avoid

- **Do NOT add validation/clamping in the initializer** — offset range is a session concern, not a type concern
- **Do NOT make `Comparable` use raw `duration` order** — must be absolute magnitude per architecture (for difficulty comparison)
- **Do NOT store direction separately** — direction is derived from sign (FR99); no redundant field
- **Do NOT use `TimeInterval`** — use `Duration` everywhere; `TimeInterval` only at platform API boundaries
- **Do NOT use XCTest** — Swift Testing only (`@Test`, `@Suite`, `#expect`)
- **Do NOT add explicit `@MainActor`** — redundant with default isolation; use `nonisolated` on init
- **Do NOT add `import SwiftUI`** — Core/ files are framework-free
- **Do NOT add `WelfordMeasurement` conformance yet** — belongs in story 45.4
- **Do NOT skip `nonisolated` on init** — required for `Codable` deserialization from any context

### Project Structure Notes

New files only — no modifications to existing files:
- `Peach/Core/Music/RhythmDirection.swift` — new enum
- `Peach/Core/Music/RhythmOffset.swift` — new value type (imports `RhythmDirection` from same module)
- `PeachTests/Core/Music/RhythmDirectionTests.swift` — new tests
- `PeachTests/Core/Music/RhythmOffsetTests.swift` — new tests

Aligns with existing Core/Music/ directory containing: `Cents.swift`, `Frequency.swift`, `MIDINote.swift`, `MIDIVelocity.swift`, `AmplitudeDB.swift`, `Interval.swift`, `Direction.swift`, `DirectedInterval.swift`, `DetunedMIDINote.swift`, `NoteDuration.swift`, `NoteRange.swift`, `TuningSystem.swift`, `SoundSourceID.swift`, `TempoBPM.swift`.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 45, Story 45.2]
- [Source: docs/planning-artifacts/architecture.md#v0.4 Amendment, lines 1688–1724 — RhythmOffset and RhythmDirection specification]
- [Source: docs/planning-artifacts/architecture.md#v0.4 Amendment, lines 1667–1686 — TempoBPM (dependency)]
- [Source: docs/project-context.md#Type Design — domain types everywhere, Duration for time intervals]
- [Source: docs/project-context.md#Language-Specific Rules — nonisolated, Sendable, no explicit @MainActor]
- [Source: docs/project-context.md#Testing Rules — Swift Testing, struct-based suites, async test functions]
- [Source: Peach/Core/Music/TempoBPM.swift — reference pattern for value type implementation]
- [Source: Peach/Core/Music/Cents.swift — reference pattern for magnitude and Comparable]
- [Source: docs/implementation-artifacts/45-1-tempobpm-domain-type.md — previous story learnings]
- [Source: docs/implementation-artifacts/44-4-typed-metrics-generic-accumulator-incremental-profile-init.md — WelfordMeasurement future context]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
