# Story 21.2: Implement TuningSystem Enum

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want a `TuningSystem` enum that computes the cent offset for any interval,
So that interval frequencies are derived from a pluggable tuning system with 0.1-cent precision (NFR14).

## Acceptance Criteria

1. **Equal temperament cent offset for perfect fifth** -- `TuningSystem.equalTemperament.centOffset(for: .perfectFifth)` returns `700.0` (exactly 7 x 100).

2. **Equal temperament cent offset for prime** -- `TuningSystem.equalTemperament.centOffset(for: .prime)` returns `0.0`.

3. **Equal temperament cent offset for octave** -- `TuningSystem.equalTemperament.centOffset(for: .octave)` returns `1200.0`.

4. **Protocol conformances** -- `TuningSystem` conforms to `Hashable`, `Sendable`, `CaseIterable`, `Codable`. Encoding and decoding a `TuningSystem` value round-trips correctly.

5. **Extensibility guarantee** -- Adding a hypothetical new case to `TuningSystem` requires only implementing its `centOffset(for:)` switch case. No changes to `Interval`, training logic, or any other file.

## Tasks / Subtasks

- [x] Task 1: Write TuningSystemTests.swift with failing tests (AC: #1, #2, #3, #4)
  - [x] Test `centOffset(for: .perfectFifth)` returns 700.0
  - [x] Test `centOffset(for: .prime)` returns 0.0
  - [x] Test `centOffset(for: .octave)` returns 1200.0
  - [x] Test all 13 intervals have correct cent values (each interval.semitones * 100.0)
  - [x] Test `CaseIterable` gives 1 case (only equalTemperament for now)
  - [x] Test `Codable` round-trip preserves value
  - [x] Test `Hashable` (use as Set element / Dictionary key)
- [x] Task 2: Implement TuningSystem enum (AC: #1, #2, #3, #5)
  - [x] Create `Peach/Core/Audio/TuningSystem.swift`
  - [x] Single case `.equalTemperament`
  - [x] `func centOffset(for interval: Interval) -> Double` with switch
  - [x] Conformances: `Hashable`, `Sendable`, `CaseIterable`, `Codable`
- [x] Task 3: Run full test suite (all ACs)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] Zero regressions

## Dev Notes

### Critical Design Decisions

- **`enum TuningSystem` (not a protocol)** -- Architecture explicitly states: "TuningSystem is an enum (not a protocol) to support a future Settings picker." An enum supports `CaseIterable` for UI pickers and `Codable` for persistence. Protocol would be overengineered for the bounded set of tuning systems. [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, lines 971-988]
- **`func centOffset(for interval: Interval) -> Double`** -- Returns `Double` (not `Cents`) because the architecture spec uses `Double` in its signature. The cent offset is a raw numeric value used in later computation (`Pitch.frequency()`). The `Cents` type is used for user-facing cent deviations, not for tuning system computations. [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, lines 979-984]
- **Equal temperament formula: `Double(interval.semitones) * 100.0`** -- In 12-TET, each semitone is exactly 100 cents. This is not an approximation — it is the definition of equal temperament. The formula is trivially correct for all 13 intervals (0 through 1200 cents). [Source: FR54]
- **Extensibility via switch statement (FR55)** -- Adding a new tuning system (e.g., `.justIntonation`) requires adding a new enum case and a new `case .justIntonation:` in the `centOffset(for:)` switch. No other files change. The switch ensures exhaustive handling at compile time. [Source: docs/planning-artifacts/prd.md -- FR55]
- **No `import Foundation` needed** -- The enum uses only `Double` arithmetic and `Interval` (from `Core/Audio/`). `Codable` synthesis works without Foundation import if the raw type supports it. However, since `Codable` requires `Foundation` for `JSONEncoder`/`JSONDecoder`, include `import Foundation` for consistency with other Core/Audio types. [Source: Peach/Core/Audio/Interval.swift pattern]

### Architecture Specification (Canonical Implementation)

```swift
enum TuningSystem: Hashable, Sendable, CaseIterable, Codable {
    case equalTemperament
    // Future: case justIntonation, case pythagorean

    func centOffset(for interval: Interval) -> Double {
        switch self {
        case .equalTemperament:
            return Double(interval.semitones) * 100.0
        }
    }
}
```

[Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, lines 974-985]

### File Placement

**New file:** `Peach/Core/Audio/TuningSystem.swift`
- `TuningSystem` enum definition
- `func centOffset(for interval: Interval) -> Double`

**New test file:** `PeachTests/Core/Audio/TuningSystemTests.swift`
- All TuningSystem tests

**No modified files** -- This story is purely additive. No existing files need changes.

### Existing Types This Story Depends On

- **`Interval` enum** (Story 21.1, done) -- `Interval.semitones: Int` provides the input for cent computation. Located at `Peach/Core/Audio/Interval.swift`. [Source: Story 21.1 implementation]
- **`Cents` type** -- `struct Cents: Hashable, Comparable, Sendable` at `Peach/Core/Audio/Cents.swift`. NOT used in `centOffset` return type (architecture uses `Double`), but worth knowing exists for future stories.
- **`Frequency` type** -- `struct Frequency: Hashable, Comparable, Sendable` at `Peach/Core/Audio/Frequency.swift`. Will be used by `Pitch` in Story 21.3.

### Testing Framework & Patterns

```swift
import Testing
import Foundation
@testable import Peach

@Suite("TuningSystem Tests")
struct TuningSystemTests {
    @Test("equalTemperament centOffset for perfectFifth returns 700.0")
    func perfectFifthCentOffset() async {
        #expect(TuningSystem.equalTemperament.centOffset(for: .perfectFifth) == 700.0)
    }

    @Test("Codable round-trip preserves value")
    func codableRoundTrip() async throws {
        let original = TuningSystem.equalTemperament
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TuningSystem.self, from: data)
        #expect(decoded == original)
    }
}
```

- Swift Testing only (`@Test`, `@Suite`, `#expect`) -- never XCTest
- All test functions `async`
- `@Test("behavioral description")` -- no `test` prefix
- Mirror source structure: test file at `PeachTests/Core/Audio/TuningSystemTests.swift`
- [Source: docs/project-context.md -- Testing Standards]

### Concurrency & Swift 6.2

- `TuningSystem` as `enum` is automatically `Sendable`
- Default MainActor isolation is active -- do NOT add explicit `@MainActor`
- `nonisolated` only if compiler requires it for protocol conformance
- [Source: docs/project-context.md -- Concurrency Rules]

### Dependency Rules

- `TuningSystem.swift` goes in `Core/Audio/` -- must be framework-free
- Allowed imports: `Foundation` (for Codable), Swift standard library
- Forbidden imports: `SwiftUI`, `UIKit`, `SwiftData`, `Combine`
- Run `tools/check-dependencies.sh` to verify
- [Source: docs/project-context.md -- Dependency Direction Rules]

### Previous Story Intelligence (Story 21.1)

**What worked:**
- TDD approach: write failing tests first, then implement
- Single new file in `Core/Audio/` with clean conformances
- `import Foundation` at top for consistency
- `Comparable` conformance added during code review -- architecture expects it for sorting intervals
- Test count: be precise in completion notes (was corrected in code review)

**Code review findings applied to 21.1:**
- (M1) Parameter names matter: `between(a:, b:)` renamed to `between(reference:, target:)` per architecture
- (M2) Test count accuracy in completion notes
- (M3) `Comparable` conformance added per architecture expectations

**Patterns to follow:**
- File structure: `import Foundation` → enum definition → extensions
- Test structure: `import Testing` → `import Foundation` → `@testable import Peach` → `@Suite` struct
- Code review did NOT find issues with the core implementation pattern

### Git Intelligence

Recent commits (relevant to this story):
- `a06adb8` Fix code review findings for story 21.1 and mark done
- `78e627b` Implement story 21.1: Interval Enum and MIDINote Transposition
- `531fe13` Add story 21.1: Implement Interval Enum and MIDINote Transposition

**Patterns observed:**
- Commit message format: `Implement story {id}: {description}`
- Story file created first, then implementation, then code review fixes
- Clean separation: story 21.1 added one new source file + one new test file + one small modification

### Future Context (Epic 21-24 Roadmap)

This story is the second building block:
- **Story 21.1** (done): `Interval` enum with 13 cases, `MIDINote.transposed(by:)`, `Interval.between(_:_:)`
- **Story 21.2** (this story): `TuningSystem` enum with `centOffset(for:)` -- bridges intervals to cent values
- **Story 21.3** (next): `Pitch` value type composing `MIDINote + Cents`, using `Interval + TuningSystem` to compute
- **Epic 22**: Prerequisite refactorings to unify naming (reference/target) and make NotePlayer take Pitch
- **Epic 23**: Generalize ComparisonSession and PitchMatchingSession to accept intervals
- **Epic 24**: Interval training UI

### Project Structure Notes

- `TuningSystem.swift` belongs in `Core/Audio/` alongside `Interval.swift`, `MIDINote.swift`, `Frequency.swift`, `Cents.swift` -- it's an audio domain value type
- No new directories needed
- No `PeachApp.swift` wiring needed (value type, not an injectable service)
- No environment key needed
- No localization needed (display names come in later UI stories)

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 21: Speak the Language, Story 21.2]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, TuningSystem definition (lines 971-988)]
- [Source: docs/planning-artifacts/prd.md -- FR54: Tuning System computation, FR55: Multiple tuning systems]
- [Source: docs/planning-artifacts/prd.md -- NFR14: Tuning system precision (0.1 cent)]
- [Source: docs/project-context.md -- TDD workflow, testing standards, dependency rules]
- [Source: Peach/Core/Audio/Interval.swift -- Interval enum (dependency for this story)]
- [Source: docs/implementation-artifacts/21-1-implement-interval-enum-and-midinote-transposition.md -- Previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

None — clean implementation, no debugging required.

### Completion Notes List

- Implemented `TuningSystem` enum in `Peach/Core/Audio/TuningSystem.swift` with single case `.equalTemperament`
- `centOffset(for:)` method computes cent offset using `Double(interval.semitones) * 100.0` (12-TET definition)
- Conformances: `Hashable`, `Sendable`, `CaseIterable`, `Codable` — all compiler-synthesized
- Wrote 8 tests in `PeachTests/Core/Audio/TuningSystemTests.swift`: 3 specific AC tests (perfectFifth=700.0, prime=0.0, octave=1200.0), 1 exhaustive all-13-intervals test, 1 CaseIterable count test, 1 Codable round-trip test, 2 Hashable tests (Set element + Dictionary key)
- TDD workflow: tests written first and confirmed failing, then implementation, then full suite pass
- Full test suite passes with zero regressions
- Dependency check (`tools/check-dependencies.sh`) passes — no forbidden imports
- Extensibility: adding a new tuning system requires only a new enum case and switch branch in `centOffset(for:)` — no other files affected (AC #5)

### File List

- `Peach/Core/Audio/TuningSystem.swift` (new)
- `PeachTests/Core/Audio/TuningSystemTests.swift` (new)
- `docs/implementation-artifacts/21-2-implement-tuningsystem-enum.md` (modified — tasks, status, dev agent record)
- `docs/implementation-artifacts/sprint-status.yaml` (modified — status update)

### Change Log

- 2026-02-28: Implemented TuningSystem enum with equalTemperament case and centOffset(for:) method. Added 8 tests covering all acceptance criteria. Story complete.
