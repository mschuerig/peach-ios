# Story 21.1: Implement Interval Enum and MIDINote Transposition

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want an `Interval` enum representing musical intervals from Prime through Octave, with a `MIDINote.transposed(by:)` extension and an `Interval.between(_:_:)` factory,
So that intervals are first-class domain concepts with compile-time safety and the system can compute transposed notes.

## Acceptance Criteria

1. **Interval enum with 13 cases and correct semitone values** -- `Interval` is an `enum Interval: Int` with cases `prime` (0) through `octave` (12). `Interval.perfectFifth.semitones` returns `7`. All 13 cases have correct semitone values (0-12).

2. **MIDINote transposition** -- `MIDINote(60).transposed(by: .perfectFifth)` returns `MIDINote(67)`. Transposition that would exceed MIDI range 0-127 crashes via precondition (matches existing `MIDINote.init` pattern).

3. **Interval.between factory** -- `Interval.between(MIDINote(60), MIDINote(67))` returns `.perfectFifth`. Computes the absolute semitone distance between two notes, regardless of order.

4. **Interval.between throws for out-of-range distance** -- `Interval.between(_:_:)` throws when the absolute semitone distance exceeds 12 (outside Prime-Octave range).

5. **Protocol conformances** -- `Interval` conforms to `Hashable`, `Sendable`, `CaseIterable`, `Codable`. Encoding and decoding an `Interval` value round-trips correctly.

## Tasks / Subtasks

- [x] Task 1: Write IntervalTests.swift with failing tests (AC: #1, #5)
  - [x] Test all 13 cases have correct semitone values
  - [x] Test `CaseIterable` gives 13 cases
  - [x] Test `Codable` round-trip
  - [x] Test `Hashable` (use as Set element / Dictionary key)
- [x] Task 2: Implement Interval enum (AC: #1, #5)
  - [x] Create `Peach/Core/Audio/Interval.swift`
  - [x] 13 cases with `Int` raw values 0-12
  - [x] `var semitones: Int { rawValue }` computed property
- [x] Task 3: Write MIDINote transposition tests (AC: #2)
  - [x] Add transposition tests to `PeachTests/Core/Audio/MIDINoteTests.swift`
  - [x] Test basic transposition (C4 + P5 = G4)
  - [x] Test identity transposition (`.prime` returns same note)
  - [x] Test boundary: transposition at top of MIDI range
- [x] Task 4: Implement MIDINote.transposed(by:) (AC: #2)
  - [x] Add extension in `Interval.swift` (keeps Interval-related logic together)
  - [x] `func transposed(by interval: Interval) -> MIDINote`
  - [x] Precondition on result within `MIDINote.validRange`
- [x] Task 5: Write Interval.between tests (AC: #3, #4)
  - [x] Test known interval derivation (60, 67 -> perfectFifth)
  - [x] Test distance-independent order (67, 60 also returns perfectFifth)
  - [x] Test prime (same note returns .prime)
  - [x] Test octave (12 semitones returns .octave)
  - [x] Test throws for distance > 12 semitones
- [x] Task 6: Implement Interval.between (AC: #3, #4)
  - [x] `static func between(_ a: MIDINote, _ b: MIDINote) throws -> Interval`
  - [x] Compute absolute semitone distance
  - [x] Initialize from raw value or throw error
- [x] Task 7: Run full test suite (all ACs)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] Zero regressions

## Dev Notes

### Critical Design Decisions

- **`enum Interval: Int` (not struct)** -- The domain is well-bounded: exactly 13 musical intervals from unison to octave. Each has a fixed semitone value. `Int` raw value gives free `Codable`, `Comparable`, sorting. `CaseIterable` supports iterating all intervals. This matches the architecture specification exactly. [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment]
- **`var semitones: Int { rawValue }`** -- Semantic alias for the raw value. Keeps the API readable (`interval.semitones`) while leveraging the raw value for init/codable.
- **Precondition on `transposed(by:)`, throw on `between(_:_:)`** -- `transposed(by:)` uses precondition because passing a valid Interval to a valid MIDINote and getting an out-of-range result is a programmer error (the caller should constrain). `between(_:_:)` throws because it validates external input (two arbitrary notes). This matches the existing MIDINote pattern where `init` uses precondition. [Source: Peach/Core/Audio/MIDINote.swift]
- **`between(_:_:)` uses absolute distance** -- Musical intervals are always positive (distance, not direction). `between(MIDINote(67), MIDINote(60))` and `between(MIDINote(60), MIDINote(67))` both return `.perfectFifth`.

### Interval Enum Cases (Canonical Names)

```swift
enum Interval: Int, Hashable, Sendable, CaseIterable, Codable {
    case prime = 0          // Unison
    case minorSecond = 1
    case majorSecond = 2
    case minorThird = 3
    case majorThird = 4
    case perfectFourth = 5
    case tritone = 6        // NOT augmentedFourth
    case perfectFifth = 7
    case minorSixth = 8
    case majorSixth = 9
    case minorSeventh = 10
    case majorSeventh = 11
    case octave = 12
}
```

Case names are from the architecture document. Use `tritone` (not `augmentedFourth`). [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment]

### Error Handling for Interval.between

Add a new case to the existing `AudioError` enum in `NotePlayer.swift`:

```swift
case invalidInterval(String)
```

Usage: `throw AudioError.invalidInterval("Semitone distance \(distance) exceeds octave range (0-12)")`

Existing `AudioError` cases for reference: `engineStartFailed`, `invalidFrequency`, `invalidDuration`, `invalidPreset`, `contextUnavailable`. [Source: Peach/Core/Audio/NotePlayer.swift:3-9]

### Architecture & Integration

**New file:** `Peach/Core/Audio/Interval.swift`
- `Interval` enum definition
- `var semitones: Int` computed property
- `static func between(_:_:) throws -> Interval`
- `MIDINote.transposed(by:)` extension (co-located with Interval since it's Interval-related API)

**Modified file:** `Peach/Core/Audio/NotePlayer.swift`
- Add `case invalidInterval(String)` to `AudioError` enum

**New test file:** `PeachTests/Core/Audio/IntervalTests.swift`
- All Interval tests and MIDINote.transposed tests

**Modified test file:** `PeachTests/Core/Audio/MIDINoteTests.swift`
- Add transposition boundary tests if preferred (or keep all in IntervalTests)

### Existing MIDINote Type (Must Understand)

```swift
// Peach/Core/Audio/MIDINote.swift
struct MIDINote: Hashable, Comparable, Codable, Sendable {
    static let validRange = 0...127
    let rawValue: Int

    init(_ rawValue: Int) {
        precondition(Self.validRange.contains(rawValue), "MIDI note must be 0-127")
        self.rawValue = rawValue
    }
}
```

Key: `MIDINote.init` uses `precondition` for range validation. Follow the same pattern in `transposed(by:)`. The `rawValue` is `Int`, so arithmetic is straightforward. [Source: Peach/Core/Audio/MIDINote.swift]

### Existing Value Type Patterns (Follow These)

Reference these files for consistent style:
- `Peach/Core/Audio/Frequency.swift` -- `struct Frequency: Hashable, Comparable, Sendable` with `rawValue: Double`, `ExpressibleByFloatLiteral`
- `Peach/Core/Audio/Cents.swift` -- Similar pattern with `rawValue: Double`, `magnitude` property
- `Peach/Core/Audio/MIDIVelocity.swift` -- `UInt8`-based value type

### Testing Framework & Patterns

```swift
import Testing

@Suite("Interval Tests")
struct IntervalTests {
    @Test("perfectFifth has 7 semitones")
    func perfectFifthSemitones() async {
        #expect(Interval.perfectFifth.semitones == 7)
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() async throws {
        let original = Interval.perfectFifth
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Interval.self, from: data)
        #expect(decoded == original)
    }

    @Test("between throws for distance exceeding octave")
    func betweenThrowsForLargeDistance() async {
        #expect(throws: AudioError.self) {
            try Interval.between(MIDINote(60), MIDINote(80))
        }
    }
}
```

- Swift Testing only (`@Test`, `@Suite`, `#expect`) -- never XCTest
- All test functions `async`
- `@Test("behavioral description")` -- no `test` prefix
- Mirror source structure: test file at `PeachTests/Core/Audio/IntervalTests.swift`
- [Source: docs/project-context.md -- Testing Standards]

### Concurrency & Swift 6.2

- `Interval` as `enum` with `Int` raw value is automatically `Sendable`
- Default MainActor isolation is active -- do NOT add explicit `@MainActor`
- Use `nonisolated` only if compiler requires it for protocol conformance
- [Source: docs/project-context.md -- Concurrency Rules]

### Dependency Rules

- `Interval.swift` goes in `Core/Audio/` -- must be framework-free
- Allowed imports: `Foundation` (if needed), Swift standard library
- Forbidden imports: `SwiftUI`, `UIKit`, `SwiftData`, `Combine`
- Run `tools/check-dependencies.sh` to verify
- [Source: docs/project-context.md -- Dependency Direction Rules]

### Future Context (Epic 21-24 Roadmap)

This story is the foundation for all interval training features:
- **Story 21.2** adds `TuningSystem` enum using `Interval` for cent offsets
- **Story 21.3** adds `Pitch` value type composing `MIDINote + Cents` using `Interval + TuningSystem`
- **Epic 22** refactors existing code to use these new types (reference/target naming, NotePlayer takes Pitch)
- **Epic 23** generalizes ComparisonSession and PitchMatchingSession to accept intervals
- **Epic 24** builds the interval training UI

Design for extensibility: `Interval` will be used as `Set<Interval>` in session parameters, as dictionary keys in profiles, and in `Codable` records. The conformances are not optional.

### Project Structure Notes

- `Interval.swift` belongs in `Core/Audio/` alongside `MIDINote.swift`, `Frequency.swift`, `Cents.swift` -- it's an audio domain value type
- No new directories needed
- No `PeachApp.swift` wiring needed (value type, not an injectable service)
- No environment key needed
- No localization needed for Story 21.1 (display names come in later UI stories)

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 21: Speak the Language, Story 21.1]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, Interval domain types]
- [Source: docs/planning-artifacts/prd.md -- FR53: Interval Domain Model, FR54: Target frequency computation, FR55: Extensible tuning systems]
- [Source: docs/project-context.md -- TDD workflow, testing standards, dependency rules]
- [Source: Peach/Core/Audio/MIDINote.swift -- Existing MIDINote type definition]
- [Source: Peach/Core/Audio/NotePlayer.swift -- AudioError enum definition]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered during implementation.

### Completion Notes List

- Implemented `Interval` enum with 13 cases (prime through octave) as `enum Interval: Int` with `Hashable`, `Sendable`, `CaseIterable`, `Codable` conformances (AC #1, #5)
- Added `var semitones: Int { rawValue }` computed property for readable API
- Implemented `MIDINote.transposed(by:)` extension in `Interval.swift` using precondition for MIDI range validation, matching existing `MIDINote.init` pattern (AC #2)
- Implemented `Interval.between(_:_:)` static factory computing absolute semitone distance, throwing `AudioError.invalidInterval` for distances > 12 (AC #3, #4)
- Added `case invalidInterval(String)` to `AudioError` enum
- 26 new tests: 23 IntervalTests (13 semitone values, CaseIterable, 2 Codable round-trip, 2 Hashable, 5 between factory) + 3 MIDINote transposition tests
- Full test suite passes with zero regressions
- Dependency check passes — no forbidden imports in Core/

### File List

- `Peach/Core/Audio/Interval.swift` (new) — Interval enum, semitones property, Interval.between factory, MIDINote.transposed extension
- `Peach/Core/Audio/NotePlayer.swift` (modified) — Added `case invalidInterval(String)` to AudioError
- `PeachTests/Core/Audio/IntervalTests.swift` (new) — 22 tests for Interval enum, conformances, and between factory
- `PeachTests/Core/Audio/MIDINoteTests.swift` (modified) — Added 3 transposition tests
- `docs/implementation-artifacts/sprint-status.yaml` (modified) — Story status updated
- `docs/implementation-artifacts/21-1-implement-interval-enum-and-midinote-transposition.md` (modified) — Tasks marked complete, dev record updated

## Change Log

- 2026-02-28: Implemented Interval enum with 13 cases, MIDINote.transposed(by:) extension, Interval.between(_:_:) factory, and AudioError.invalidInterval case. Added 26 new tests across IntervalTests.swift and MIDINoteTests.swift. All tests pass, zero regressions.
- 2026-02-28: Code review fixes — (M1) Renamed `between()` parameter names from `a, b` to `reference, target` per architecture spec; (M2) Corrected test count from 22/25 to actual 26; (M3) Added `Comparable` conformance to Interval enum per architecture expectations.
