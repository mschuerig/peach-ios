# Story 31.1: Create NoteRange Value Type

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want a validated `NoteRange` value type that encapsulates a lower and upper MIDI note bound,
so that note range constraints are expressed once and reused throughout the codebase.

## Acceptance Criteria

1. **Given** a new `NoteRange` struct in `Core/Audio/`, **when** it is created with `lowerBound: MIDINote` and `upperBound: MIDINote`, **then** it validates that `upperBound` is at least 12 semitones above `lowerBound`, **and** invalid ranges are rejected at construction time via `precondition` (consistent with `MIDINote` pattern)
2. **Given** a valid `NoteRange`, **when** `contains(_ note: MIDINote)` is called, **then** it returns `true` if the note is within `[lowerBound, upperBound]`, `false` otherwise
3. **Given** a valid `NoteRange`, **when** `clamped(_ note: MIDINote)` is called, **then** it returns the note clamped to `[lowerBound, upperBound]`
4. **Given** a valid `NoteRange`, **when** `semitoneSpan` is accessed, **then** it returns `upperBound.rawValue - lowerBound.rawValue`
5. **Given** `NoteRange`, **when** checked for protocol conformance, **then** it conforms to `Equatable`, `Sendable`, and `Hashable`
6. **Given** the `NoteRange` type, **when** unit tests are run, **then** all computed properties, validation, and edge cases are covered

## Tasks / Subtasks

- [x] Task 1: Create `NoteRange` struct (AC: #1, #5)
  - [x] 1.1 Write failing test: valid construction with exactly 12 semitone gap
  - [x] 1.2 Write failing test: valid construction with large gap (e.g., 48 semitones)
  - [x] 1.3 Write failing test: verify `Equatable` conformance (two equal ranges, two different ranges)
  - [x] 1.4 Write failing test: verify `Hashable` conformance (can be used as dictionary key / in Set)
  - [x] 1.5 Implement `NoteRange` struct with `precondition` validation
  - [x] 1.6 Verify tests pass
- [x] Task 2: Implement `contains(_:)` (AC: #2)
  - [x] 2.1 Write failing test: note at lowerBound returns `true`
  - [x] 2.2 Write failing test: note at upperBound returns `true`
  - [x] 2.3 Write failing test: note in middle returns `true`
  - [x] 2.4 Write failing test: note below lowerBound returns `false`
  - [x] 2.5 Write failing test: note above upperBound returns `false`
  - [x] 2.6 Implement `contains(_:)`
  - [x] 2.7 Verify tests pass
- [x] Task 3: Implement `clamped(_:)` (AC: #3)
  - [x] 3.1 Write failing test: note below range returns `lowerBound`
  - [x] 3.2 Write failing test: note above range returns `upperBound`
  - [x] 3.3 Write failing test: note within range returns same note
  - [x] 3.4 Write failing test: note at boundaries returns same note
  - [x] 3.5 Implement `clamped(_:)`
  - [x] 3.6 Verify tests pass
- [x] Task 4: Implement `semitoneSpan` (AC: #4)
  - [x] 4.1 Write failing test: span of exactly 12 returns 12
  - [x] 4.2 Write failing test: span of 48 (C2–C6) returns 48
  - [x] 4.3 Implement `semitoneSpan` computed property
  - [x] 4.4 Verify tests pass
- [x] Task 5: Run full test suite (AC: #6)
  - [x] 5.1 Run `bin/test.sh` — all tests must pass (814 passed, 0 failed)
  - [x] 5.2 Run `bin/build.sh` — no warnings or errors (build succeeded)
  - [x] 5.3 Run `bin/check-dependencies.sh` — no dependency violations (all rules passed)

## Dev Notes

### Technical Requirements

**What this story IS:**
- Create a single new file `Peach/Core/Audio/NoteRange.swift` with a validated value type
- Create a single new test file `PeachTests/Core/Audio/NoteRangeTests.swift`
- Pure value type with no dependencies beyond `MIDINote`
- ~30 lines of production code, ~80 lines of test code

**What this story is NOT:**
- No changes to `UserSettings`, `AppUserSettings`, `SettingsKeys`, or `SettingsScreen` (that's story 31.2)
- No changes to `TrainingSettings`, `ComparisonSession`, `PitchMatchingSession`, or `KazezNoteStrategy` (that's story 31.3)
- No changes to `PerceptualProfile` or `PianoKeyboardView` (that's story 31.4)
- No changes to `PeachApp.swift` or `EnvironmentKeys.swift`
- No changes to any existing files — this story only creates 2 new files
- No localization changes
- No UI changes

### Architecture Compliance

**File placement:** `Peach/Core/Audio/NoteRange.swift` — alongside `MIDINote.swift`, `Cents.swift`, `Frequency.swift`, and other audio domain value types. This is the correct location per project structure rules: "Audio domain value types → Core/Audio/".

**No framework imports in Core/:** `NoteRange` only needs `import Foundation` (same as `MIDINote`). No SwiftUI, no UIKit, no SwiftData.

**Value type by default:** `struct` for data carrier — consistent with all other domain types (`MIDINote`, `Cents`, `Frequency`, `DetunedMIDINote`, `DirectedInterval`).

**Protocol-first is NOT needed here:** `NoteRange` is a value type, not a service. No protocol needed — consistent with `MIDINote`, `Cents`, `Frequency`, etc.

### Library & Framework Requirements

**No new dependencies.** This story uses only:
- `Foundation` — standard library
- `MIDINote` — existing domain type in `Core/Audio/`

### File Structure Requirements

**2 files created, 0 files modified:**

| File | Action | What It Contains |
|------|--------|-----------------|
| `Peach/Core/Audio/NoteRange.swift` | Create | `NoteRange` struct with validation, `contains`, `clamped`, `semitoneSpan` |
| `PeachTests/Core/Audio/NoteRangeTests.swift` | Create | Comprehensive tests for all properties and edge cases |

**Do not touch these files:**
- `Peach/Core/Audio/MIDINote.swift` — no changes needed
- `Peach/Settings/SettingsKeys.swift` — constants stay as-is (story 31.2 will use them)
- `Peach/Settings/UserSettings.swift` — protocol changes are story 31.2
- `Peach/Settings/AppUserSettings.swift` — implementation changes are story 31.2
- `Peach/Core/Algorithm/NextComparisonStrategy.swift` — `TrainingSettings` changes are story 31.3
- Any view files — adoption is stories 31.2–31.4

### Testing Requirements

**Framework:** Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`) — never XCTest.

**All `@Test` functions must be `async`.** No `test` prefix on function names.

**Test file:** `PeachTests/Core/Audio/NoteRangeTests.swift`

**Test structure pattern (follow existing conventions):**

```swift
import Testing
@testable import Peach

@Suite("NoteRange")
struct NoteRangeTests {

    // MARK: - Construction & Validation

    @Test("creates valid range with minimum 12-semitone gap")
    func validMinimumGap() async {
        let range = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        #expect(range.lowerBound == MIDINote(60))
        #expect(range.upperBound == MIDINote(72))
    }

    @Test("creates valid range with large gap")
    func validLargeGap() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.lowerBound == MIDINote(36))
        #expect(range.upperBound == MIDINote(84))
    }

    // MARK: - Equatable & Hashable

    @Test("equal ranges are equal")
    func equalRanges() async {
        let a = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        let b = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(a == b)
    }

    @Test("different ranges are not equal")
    func differentRanges() async {
        let a = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        let b = NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(84))
        #expect(a != b)
    }

    @Test("can be used in a Set")
    func hashable() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        let set: Set<NoteRange> = [range, range]
        #expect(set.count == 1)
    }

    // MARK: - contains

    @Test("contains note at lowerBound")
    func containsLowerBound() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.contains(MIDINote(36)))
    }

    @Test("contains note at upperBound")
    func containsUpperBound() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.contains(MIDINote(84)))
    }

    @Test("contains note in middle")
    func containsMiddle() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.contains(MIDINote(60)))
    }

    @Test("does not contain note below lowerBound")
    func doesNotContainBelow() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(!range.contains(MIDINote(35)))
    }

    @Test("does not contain note above upperBound")
    func doesNotContainAbove() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(!range.contains(MIDINote(85)))
    }

    // MARK: - clamped

    @Test("clamps note below range to lowerBound")
    func clampsBelowToLower() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(20)) == MIDINote(36))
    }

    @Test("clamps note above range to upperBound")
    func clampsAboveToUpper() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(100)) == MIDINote(84))
    }

    @Test("clamped returns same note when within range")
    func clampedWithinRange() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(60)) == MIDINote(60))
    }

    @Test("clamped returns same note at boundaries")
    func clampedAtBoundaries() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.clamped(MIDINote(36)) == MIDINote(36))
        #expect(range.clamped(MIDINote(84)) == MIDINote(84))
    }

    // MARK: - semitoneSpan

    @Test("semitoneSpan returns difference between bounds")
    func semitoneSpanMinimum() async {
        let range = NoteRange(lowerBound: MIDINote(60), upperBound: MIDINote(72))
        #expect(range.semitoneSpan == 12)
    }

    @Test("semitoneSpan for default range C2-C6 is 48")
    func semitoneSpanDefault() async {
        let range = NoteRange(lowerBound: MIDINote(36), upperBound: MIDINote(84))
        #expect(range.semitoneSpan == 48)
    }
}
```

**Precondition testing note:** Testing that `precondition` fires for invalid ranges (gap < 12) is not possible with Swift Testing's `#expect` — preconditions terminate the process. The developer should NOT write tests for invalid construction. The precondition is a programmer error guard, consistent with `MIDINote`.

**Run full suite:** `bin/test.sh` — all existing + new tests must pass before committing.

### Implementation Guidance

**`NoteRange.swift` — follow the `MIDINote` pattern exactly:**

```swift
import Foundation

/// A validated range of MIDI notes with a minimum span of 12 semitones (one octave).
///
/// NoteRange encapsulates a lower and upper MIDI note bound, validating
/// that the span is at least 12 semitones at construction time. Used throughout
/// the codebase to express note range constraints consistently.
struct NoteRange: Hashable, Sendable {
    static let minimumSpan = 12

    let lowerBound: MIDINote
    let upperBound: MIDINote

    init(lowerBound: MIDINote, upperBound: MIDINote) {
        precondition(
            upperBound.rawValue - lowerBound.rawValue >= Self.minimumSpan,
            "NoteRange requires at least \(Self.minimumSpan) semitones, got \(upperBound.rawValue - lowerBound.rawValue)"
        )
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    func contains(_ note: MIDINote) -> Bool {
        note >= lowerBound && note <= upperBound
    }

    func clamped(_ note: MIDINote) -> MIDINote {
        if note < lowerBound { return lowerBound }
        if note > upperBound { return upperBound }
        return note
    }

    var semitoneSpan: Int {
        upperBound.rawValue - lowerBound.rawValue
    }
}
```

**Key design decisions:**
- `precondition` (not `fatalError`, not throwing) — consistent with `MIDINote` init pattern
- `minimumSpan = 12` matches `SettingsKeys.minimumNoteGap` — but defined independently on the type (no dependency on SettingsKeys)
- `Hashable` implies `Equatable` — both satisfied by struct auto-synthesis since `MIDINote` is `Hashable`
- `Sendable` — satisfied automatically as a struct with `Sendable` stored properties
- `Comparable` is NOT needed on `NoteRange` itself — ranges are not naturally ordered
- No `ExpressibleByIntegerLiteral` — ranges need two bounds, no sensible literal syntax

### Previous Story Intelligence

**Story 30.3 (most recent completed story):**
- 793 tests passing at completion
- No changes to note range functionality
- Established pattern: access session properties from views via `@Environment`-injected `@Observable`

**Story 19.2 (Value Objects for Domain Primitives):**
- Established the domain value type pattern: `Cents`, `Frequency`, `AmplitudeDB`, `MIDIVelocity`
- All use `precondition` for validation, all are `struct`, all conform to `Hashable`, `Sendable`
- `NoteRange` follows this exact established pattern

**Story 22.3 (Introduce DetunedMIDINote):**
- Created `DetunedMIDINote` value type combining `MIDINote` + `Cents`
- Demonstrates the pattern of composing domain types from other domain types
- `NoteRange` similarly composes from `MIDINote`

### Git Intelligence

**Recent commits (most relevant):**
```
79553b0 Fix epic numbering: insert Epics 25–30, renumber 25–32 → 31–38
74fb0fe Add epics 25–32: NoteRange refactoring, settings reorg, data export/import...
7ed9617 Fix TuningSystem frequency bridge to respect tuning system
```

**Commit format:** `{Verb} story {id}: {Description}` — e.g., `Implement story 31.1: Create NoteRange Value Type`

**Current test count:** 793 tests passing (as of story 30.3 completion).

### Project Structure Notes

- `NoteRange.swift` placement in `Peach/Core/Audio/` is alongside: `MIDINote.swift`, `Cents.swift`, `Frequency.swift`, `DetunedMIDINote.swift`, `Interval.swift`, `DirectedInterval.swift`, `Direction.swift`, `AmplitudeDB.swift`, `MIDIVelocity.swift`, `NoteDuration.swift`
- Test file `NoteRangeTests.swift` placement in `PeachTests/Core/Audio/` mirrors the source structure
- No conflicts with project structure detected
- No existing `NoteRange` type in the codebase — this is a net-new addition

### Cross-Story Context (Epic 31 Roadmap)

This is story 1 of 4 in Epic 31. The subsequent stories will adopt `NoteRange`:
- **31.2:** Replace `noteRangeMin`/`noteRangeMax` in `UserSettings` protocol and `AppUserSettings` with `noteRange: NoteRange`; update `SettingsScreen` validation
- **31.3:** Replace separate min/max in `TrainingSettings`, `ComparisonSession`, `PitchMatchingSession`, `KazezNoteStrategy`
- **31.4:** Adopt in `PerceptualProfile` and `PianoKeyboardView`

**Important for this story:** Do NOT attempt to adopt `NoteRange` anywhere — just create the type and its tests. The adoption stories will handle integration one layer at a time.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 31] — Epic definition, all 4 stories, acceptance criteria
- [Source: Peach/Core/Audio/MIDINote.swift] — Pattern to follow: `precondition`, `Hashable`, `Comparable`, `Sendable`, `struct`
- [Source: Peach/Settings/SettingsKeys.swift] — `minimumNoteGap = 12`, `defaultNoteRangeMin = 36` (C2), `defaultNoteRangeMax = 84` (C6)
- [Source: Peach/Core/Algorithm/NextComparisonStrategy.swift] — `TrainingSettings.isInRange()` method (will be replaced in story 31.3)
- [Source: docs/project-context.md] — Swift 6.2, precondition pattern, value types, testing rules, file placement rules
- [Source: docs/implementation-artifacts/30-3-add-tuning-system-indicator-to-interval-training-screens.md] — Most recent story, 793 tests passing

## Change Log

- 2026-03-04: Implemented NoteRange value type with full test coverage (16 tests). TDD workflow: wrote all tests first (RED — build failed with "Cannot find 'NoteRange' in scope"), then implemented the struct (GREEN — all tests pass). No refactoring needed.
- 2026-03-04: Code review — added 6 MIDI boundary edge case tests (construction, contains, clamped at MIDI 0 and 127). Total: 22 NoteRange tests, 820 tests passing.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No issues encountered.

### Completion Notes List

- Created `NoteRange` struct following established domain value type pattern (MIDINote, Cents, Frequency)
- Precondition validates minimum 12-semitone span at construction time
- 22 tests covering: construction/validation (including MIDI boundary edges), Equatable, Hashable, contains, clamped, semitoneSpan
- All 820 tests pass, build clean, dependency rules pass
- Only 2 new files created, 0 existing files modified — exactly per story scope

### File List

- `Peach/Core/Audio/NoteRange.swift` (created)
- `PeachTests/Core/Audio/NoteRangeTests.swift` (created, updated in review — added 6 boundary tests)
- `docs/implementation-artifacts/31-1-create-noterange-value-type.md` (updated — tasks, status, dev record)
- `docs/implementation-artifacts/sprint-status.yaml` (updated — story status)
