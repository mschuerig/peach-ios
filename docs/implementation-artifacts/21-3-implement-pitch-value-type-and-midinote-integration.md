# Story 21.3: Implement Pitch Value Type and MIDINote Integration

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want a `Pitch` struct (MIDINote + Cents) that computes its frequency, with `MIDINote.pitch(at:in:)` composing Interval + TuningSystem into a Pitch, and `Frequency.concert440`,
So that interval frequency computation flows through domain types with 0.1-cent precision.

## Acceptance Criteria

1. **A4 frequency from Pitch** -- `Pitch(note: MIDINote(69), cents: Cents(0)).frequency(referencePitch: .concert440)` returns `Frequency(440.0)` (A4 in 12-TET).

2. **Middle C frequency precision** -- `Pitch(note: MIDINote(60), cents: Cents(0)).frequency(referencePitch: .concert440)` is accurate to within 0.1 cent of the theoretical value (~261.626 Hz).

3. **MIDINote.pitch with interval and tuning system** -- `MIDINote(60).pitch(at: .perfectFifth, in: .equalTemperament)` returns `Pitch(note: MIDINote(67), cents: Cents(0))` (G4 in 12-TET, cents = 0 because equal temperament intervals land exactly on MIDI notes).

4. **MIDINote.pitch default parameters (unison)** -- `MIDINote(60).pitch()` (defaults: `.prime`, `.equalTemperament`) returns `Pitch(note: MIDINote(60), cents: Cents(0))`.

5. **Frequency.concert440 static constant** -- `Frequency.concert440` is a static constant with value `Frequency(440.0)`.

6. **Pitch protocol conformances** -- `Pitch` conforms to `Hashable` and `Sendable`. Works as a dictionary key and can be passed across concurrency boundaries.

## Tasks / Subtasks

- [x] Task 1: Write PitchTests.swift with failing tests (AC: #1, #2, #3, #4, #6)
  - [x] Test A4 pitch frequency returns 440.0
  - [x] Test middle C pitch frequency within 0.1-cent precision
  - [x] Test pitch at various intervals (all 13 cases for completeness)
  - [x] Test pitch with cents offset computes correct frequency
  - [x] Test Hashable: use Pitch as Set element and Dictionary key
  - [x] Test Sendable: Pitch is value type (automatic)
  - [x] Test MIDINote.pitch(at:in:) with .perfectFifth returns correct Pitch
  - [x] Test MIDINote.pitch() defaults to prime/equalTemperament
  - [x] Test MIDINote.pitch for all 13 intervals in equalTemperament (cents always 0)
- [x] Task 2: Write Frequency.concert440 test (AC: #5)
  - [x] Test in existing FrequencyTests or new section: `Frequency.concert440.rawValue == 440.0`
- [x] Task 3: Implement Pitch struct (AC: #1, #2, #6)
  - [x] Create `Peach/Core/Audio/Pitch.swift`
  - [x] `struct Pitch: Hashable, Sendable` with `let note: MIDINote` and `let cents: Cents`
  - [x] `func frequency(referencePitch: Frequency = .concert440) -> Frequency` using formula: `referencePitch.rawValue * pow(2.0, (Double(note.rawValue - 69) + cents.rawValue / 100.0) / 12.0)`
- [x] Task 4: Add MIDINote.pitch(at:in:) extension (AC: #3, #4)
  - [x] Add to `Peach/Core/Audio/Interval.swift` where `MIDINote.transposed(by:)` already lives
  - [x] `func pitch(at interval: Interval = .prime, in tuningSystem: TuningSystem = .equalTemperament) -> Pitch`
  - [x] Implementation: transpose note by interval, compute cents from tuningSystem centOffset minus exact semitone cents
- [x] Task 5: Add Frequency.concert440 static constant (AC: #5)
  - [x] Add `static let concert440 = Frequency(440.0)` to `Peach/Core/Audio/Frequency.swift`
- [x] Task 6: Run full test suite (all ACs)
  - [x] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] Zero regressions

## Dev Notes

### Critical Design Decisions

- **`struct Pitch: Hashable, Sendable` (value type)** -- Pitch represents a resolved point in pitch space. Once created, the tuning system computation has already been applied and the cent offset is baked in. This is a data carrier, not a service. [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, lines 990-1001]
- **`let note: MIDINote` + `let cents: Cents`** -- The `note` is the nearest MIDI note number, `cents` is the deviation from that exact MIDI note frequency. For 12-TET intervals, `cents` is always `Cents(0)` because equal temperament intervals land exactly on MIDI notes. For future tuning systems (just intonation), `cents` will capture the micro-deviation. [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, MIDINote.pitch description]
- **`func frequency(referencePitch: Frequency = .concert440) -> Frequency`** -- Pure math, no throws. Formula: `referencePitch.rawValue * pow(2.0, (Double(note.rawValue - 69) + cents.rawValue / 100.0) / 12.0)`. This is equivalent to the existing `FrequencyCalculation.frequency()` formula but operates on domain types. The combined exponent `(note - 69 + cents/100) / 12` is more precise than multiplying two separate `pow(2, ...)` terms. [Source: docs/planning-artifacts/architecture.md -- line 1001]
- **Default parameter `referencePitch: Frequency = .concert440`** -- Callers don't need to specify the reference pitch for standard tuning. The existing codebase uses 440.0 everywhere as default.
- **`MIDINote.pitch(at:in:)` lives alongside `MIDINote.transposed(by:)`** -- Both are interval-related MIDINote extensions. The `pitch(at:in:)` method transposes the note AND computes the cent offset from the tuning system. For 12-TET: `cents = centOffset - Double(interval.semitones) * 100.0 = 0` (always). Place in `Interval.swift` where `transposed(by:)` already lives. [Source: docs/planning-artifacts/architecture.md -- lines 1003-1026]

### Architecture Specification (Canonical Implementation)

```swift
struct Pitch: Hashable, Sendable {
    let note: MIDINote
    let cents: Cents

    func frequency(referencePitch: Frequency = .concert440) -> Frequency {
        let semitones = Double(note.rawValue - 69) + cents.rawValue / 100.0
        return Frequency(referencePitch.rawValue * pow(2.0, semitones / 12.0))
    }
}
```
[Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, lines 990-1001]

```swift
extension MIDINote {
    func pitch(
        at interval: Interval = .prime,
        in tuningSystem: TuningSystem = .equalTemperament
    ) -> Pitch {
        let transposedNote = transposed(by: interval)
        let centOffset = tuningSystem.centOffset(for: interval)
        let exactSemitones = Double(interval.semitones) * 100.0
        let centsDeviation = centOffset - exactSemitones
        return Pitch(note: transposedNote, cents: Cents(centsDeviation))
    }
}
```
[Source: docs/planning-artifacts/architecture.md -- lines 1003-1026]

```swift
extension Frequency {
    static let concert440 = Frequency(440.0)
}
```
[Source: docs/planning-artifacts/architecture.md -- lines 1023-1025]

### File Placement

**New file:** `Peach/Core/Audio/Pitch.swift`
- `Pitch` struct definition
- `func frequency(referencePitch:) -> Frequency`

**Modified file:** `Peach/Core/Audio/Interval.swift`
- Add `MIDINote.pitch(at:in:)` extension (alongside existing `MIDINote.transposed(by:)`)

**Modified file:** `Peach/Core/Audio/Frequency.swift`
- Add `static let concert440 = Frequency(440.0)`

**New test file:** `PeachTests/Core/Audio/PitchTests.swift`
- All Pitch tests and MIDINote.pitch(at:in:) tests and Frequency.concert440 test

### Existing Types This Story Depends On

- **`MIDINote` struct** -- `Peach/Core/Audio/MIDINote.swift`. Has `rawValue: Int` (0-127), `transposed(by:)` extension in `Interval.swift`. The `pitch(at:in:)` extension builds on `transposed(by:)`.
- **`Interval` enum** (Story 21.1, done) -- `Peach/Core/Audio/Interval.swift`. `Int` raw value, `.semitones: Int` property. All 13 cases (prime=0 through octave=12).
- **`TuningSystem` enum** (Story 21.2, done) -- `Peach/Core/Audio/TuningSystem.swift`. `centOffset(for: Interval) -> Double`. For `.equalTemperament`: returns `Double(interval.semitones) * 100.0`.
- **`Cents` struct** -- `Peach/Core/Audio/Cents.swift`. `rawValue: Double`, conforms to `Hashable, Comparable, Sendable`, supports `ExpressibleByFloatLiteral` and `ExpressibleByIntegerLiteral`.
- **`Frequency` struct** -- `Peach/Core/Audio/Frequency.swift`. `rawValue: Double` (must be > 0), conforms to `Hashable, Comparable, Sendable`, supports `ExpressibleByFloatLiteral` and `ExpressibleByIntegerLiteral`.
- **`FrequencyCalculation` enum** -- `Peach/Core/Audio/FrequencyCalculation.swift`. Contains the reference formula `frequency(midiNote:cents:referencePitch:) -> Double`. The `Pitch.frequency()` method replicates this formula using domain types. (Will be deleted in Story 22.1.)

### Frequency Formula Verification

The existing `FrequencyCalculation.frequency()` uses:
```
referencePitch * pow(2.0, (midiNote - 69) / 12.0) * pow(2.0, cents / 1200.0)
```

The `Pitch.frequency()` combines into a single exponent:
```
referencePitch * pow(2.0, (Double(note - 69) + cents / 100.0) / 12.0)
```

These are mathematically equivalent:
- `(midiNote - 69) / 12 + cents / 1200 = ((midiNote - 69) * 100 + cents) / 1200 = (midiNote - 69 + cents/100) / 12`

The combined form has slightly better floating-point precision (one `pow` call instead of two).

### Testing Framework & Patterns

```swift
import Testing
import Foundation
@testable import Peach

@Suite("Pitch Tests")
struct PitchTests {
    @Test("A4 pitch frequency returns 440.0 Hz")
    func a4Frequency() async {
        let pitch = Pitch(note: MIDINote(69), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: .concert440)
        #expect(freq.rawValue == 440.0)
    }

    @Test("middle C frequency within 0.1-cent precision")
    func middleCFrequency() async {
        let pitch = Pitch(note: MIDINote(60), cents: Cents(0))
        let freq = pitch.frequency(referencePitch: .concert440)
        // Theoretical: 440 * 2^(-9/12) ≈ 261.6255653...
        #expect(abs(freq.rawValue - 261.6255653) < 0.01)
    }

    @Test("MIDINote.pitch defaults to prime/equalTemperament")
    func pitchDefaults() async {
        let pitch = MIDINote(60).pitch()
        #expect(pitch.note == MIDINote(60))
        #expect(pitch.cents == Cents(0))
    }
}
```

- Swift Testing only (`@Test`, `@Suite`, `#expect`) -- never XCTest
- All test functions `async`
- `@Test("behavioral description")` -- no `test` prefix
- Mirror source structure: `PeachTests/Core/Audio/PitchTests.swift`
- [Source: docs/project-context.md -- Testing Standards]

### Precision Testing Strategy

To verify 0.1-cent precision (AC #2), compare against known theoretical values:
- A4 (MIDI 69, 0 cents): exactly 440.0 Hz
- Middle C (MIDI 60, 0 cents): 261.6255653005986 Hz (440 * 2^(-9/12))
- C5 (MIDI 72, 0 cents): 523.2511306011972 Hz (440 * 2^(3/12))
- A4 + 50 cents (MIDI 69, 50 cents): 440 * 2^(50/1200) ≈ 452.893 Hz

The tolerance for 0.1-cent precision at 440 Hz: `440 * (2^(0.1/1200) - 1) ≈ 0.0254 Hz`. Use conservative tolerance of 0.01 Hz for test assertions.

### Equal Temperament Cents Invariant

For `MIDINote.pitch(at:in: .equalTemperament)`, the `cents` component is ALWAYS `Cents(0)` for ALL intervals. This is because:
- `TuningSystem.equalTemperament.centOffset(for: interval)` = `interval.semitones * 100.0`
- `exactSemitones` = `interval.semitones * 100.0`
- `centsDeviation` = `centOffset - exactSemitones` = `0.0`

This invariant should be tested exhaustively for all 13 intervals to ensure the formula is correct. When future tuning systems are added (just intonation), the cents will be non-zero.

### Concurrency & Swift 6.2

- `Pitch` as `struct` with `Hashable, Sendable` conformance -- value type is automatically `Sendable`
- Default MainActor isolation is active -- do NOT add explicit `@MainActor`
- `nonisolated` only if compiler requires it for protocol conformance
- [Source: docs/project-context.md -- Concurrency Rules]

### Dependency Rules

- `Pitch.swift` goes in `Core/Audio/` -- must be framework-free
- Allowed imports: `Foundation` (for `pow`, `Double`), Swift standard library
- Forbidden imports: `SwiftUI`, `UIKit`, `SwiftData`, `Combine`
- Run `tools/check-dependencies.sh` to verify
- [Source: docs/project-context.md -- Dependency Direction Rules]

### Previous Story Intelligence (Stories 21.1 & 21.2)

**What worked:**
- TDD approach: write failing tests first, then implement
- Single new file in `Core/Audio/` with clean conformances
- `import Foundation` at top for consistency
- Code review found: test values should independently verify, not mirror production formula
- `Comparable` conformance was added to `Interval` during code review -- consider if `Pitch` needs it (architecture says `Hashable, Sendable` only -- do NOT add `Comparable` unless architecture specifies it)

**Code review findings from 21.1:**
- (M1) Parameter names: use `reference`/`target` not `a`/`b`
- (M3) Add `Comparable` if architecture expects it -- for `Pitch`, architecture says `Hashable, Sendable` only

**Code review findings from 21.2:**
- (M1) Test values must be independently computed, not mirror production formula (e.g., use hardcoded expected Hz values, not recompute from formula)

**Patterns to follow:**
- File structure: `import Foundation` -> struct/enum definition -> extensions
- Test structure: `import Testing` -> `import Foundation` -> `@testable import Peach` -> `@Suite` struct
- Hardcode expected values in tests (don't recompute)

### Git Intelligence

Recent commits (most recent first):
- `7d5dbf6` Fix code review findings for story 21.2 and mark done
- `2733136` Implement story 21.2: TuningSystem Enum
- `1bd5000` Add story 21.2: Implement TuningSystem Enum
- `a06adb8` Fix code review findings for story 21.1 and mark done
- `78e627b` Implement story 21.1: Interval Enum and MIDINote Transposition

**Patterns observed:**
- Commit message format: `Implement story {id}: {description}`
- Story file committed first, then implementation, then code review fixes
- Clean separation: each story adds new source file(s) + test file(s) with minimal modifications to existing files

### Future Context (Epic 21-24 Roadmap)

This story is the **final building block of Epic 21**:
- **Story 21.1** (done): `Interval` enum, `MIDINote.transposed(by:)`, `Interval.between(_:_:)`
- **Story 21.2** (done): `TuningSystem` enum with `centOffset(for:)`
- **Story 21.3** (this story): `Pitch` value type, `MIDINote.pitch(at:in:)`, `Frequency.concert440`
- **Epic 22** (next): Prerequisite refactorings -- migrate `FrequencyCalculation` to `Pitch.frequency()` (Story 22.1), rename note1/note2 to reference/target (22.2), `NotePlayer` takes `Pitch` (22.3), extract `SoundSourceProvider` (22.4)
- **Epic 23**: Generalize sessions for intervals
- **Epic 24**: Interval training UI

After this story, all interval domain foundation types exist. Epic 22.1 will delete `FrequencyCalculation.swift` and migrate callers to `Pitch.frequency()` and `MIDINote.frequency()`.

### Project Structure Notes

- `Pitch.swift` belongs in `Core/Audio/` alongside `MIDINote.swift`, `Frequency.swift`, `Cents.swift`, `Interval.swift`, `TuningSystem.swift` -- it's an audio domain value type
- `MIDINote.pitch(at:in:)` extension added to `Interval.swift` where `MIDINote.transposed(by:)` already lives (keeps interval-related MIDINote extensions together)
- `Frequency.concert440` added directly to `Frequency.swift`
- No new directories needed
- No `PeachApp.swift` wiring needed (value type, not an injectable service)
- No environment key needed
- No localization needed (display names come in later UI stories)

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 21: Speak the Language, Story 21.3]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, Pitch definition (lines 990-1001)]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, MIDINote extensions (lines 1003-1026)]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, Frequency.concert440 (lines 1023-1025)]
- [Source: docs/planning-artifacts/prd.md -- FR53: Interval value object, FR54: Target frequency computation, FR55: Extensible tuning systems]
- [Source: docs/planning-artifacts/prd.md -- NFR14: Tuning system precision (0.1 cent)]
- [Source: docs/project-context.md -- TDD workflow, testing standards, dependency rules]
- [Source: Peach/Core/Audio/FrequencyCalculation.swift -- Reference formula for frequency computation]
- [Source: Peach/Core/Audio/MIDINote.swift -- MIDINote struct (dependency)]
- [Source: Peach/Core/Audio/Cents.swift -- Cents struct (dependency)]
- [Source: Peach/Core/Audio/Frequency.swift -- Frequency struct (dependency)]
- [Source: Peach/Core/Audio/Interval.swift -- Interval enum and MIDINote.transposed(by:) (dependency)]
- [Source: Peach/Core/Audio/TuningSystem.swift -- TuningSystem enum (dependency)]
- [Source: docs/implementation-artifacts/21-1-implement-interval-enum-and-midinote-transposition.md -- Story 21.1 learnings]
- [Source: docs/implementation-artifacts/21-2-implement-tuningsystem-enum.md -- Story 21.2 learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no debugging required.

### Completion Notes List

- Implemented `Pitch` struct in `Peach/Core/Audio/Pitch.swift` with `note: MIDINote` and `cents: Cents` properties, plus `frequency(referencePitch:)` method using combined-exponent formula
- Added `MIDINote.pitch(at:in:)` extension in `Interval.swift` alongside existing `transposed(by:)` — computes transposed note and cent deviation from tuning system
- Added `Frequency.concert440` static constant in `Frequency.swift`
- Created 16 tests in `PitchTests.swift` covering all 6 ACs: frequency precision (A4, middle C, C5, positive/negative cents offset, non-standard reference pitch), MIDINote.pitch for all 13 intervals, default parameters, Hashable/Sendable conformance, and Frequency.concert440
- All tests follow TDD (red-green-refactor): tests written first (compilation failure confirmed), then implementation, then verification
- Full test suite passes with zero regressions
- Dependency check passes — no forbidden imports in Core/

### Senior Developer Review (AI)

**Reviewer:** Claude Opus 4.6 | **Date:** 2026-02-28 | **Outcome:** Approved with fixes applied

**Issues found:** 0 High, 3 Medium, 2 Low

**Fixed (3 Medium):**
- (M1) Replaced no-op Sendable test with real cross-isolation boundary test using `Task.detached`
- (M2) Added missing test for negative cents offset (`Cents(-50)` → ~427.474 Hz)
- (M3) Added missing test for non-standard reference pitch (`Frequency(442.0)`)

**Noted but not fixed (2 Low):**
- (L1) `pitchAtMinorSecond` and `pitchAtOctave` are redundant with parametric `allIntervalsEqualTemperamentCentsZero` — harmless, kept for readability
- (L2) Precision tolerance `0.01` is a magic number in frequency tests — acceptable given clear comments with theoretical values

**Verification:** All ACs implemented, all tasks complete, 16 tests pass, zero regressions, dependency check clean.

### Change Log

- 2026-02-28: Implemented story 21.3 — Pitch value type, MIDINote.pitch(at:in:), Frequency.concert440
- 2026-02-28: Code review fixes — replaced no-op Sendable test, added negative cents and non-standard reference pitch tests (14→16 tests)

### File List

- `Peach/Core/Audio/Pitch.swift` (new) — Pitch struct with frequency computation
- `Peach/Core/Audio/Interval.swift` (modified) — Added MIDINote.pitch(at:in:) extension
- `Peach/Core/Audio/Frequency.swift` (modified) — Added static let concert440
- `PeachTests/Core/Audio/PitchTests.swift` (new) — 16 tests covering all ACs
- `docs/implementation-artifacts/sprint-status.yaml` (modified) — Status: in-progress → review
- `docs/implementation-artifacts/21-3-implement-pitch-value-type-and-midinote-integration.md` (modified) — Task checkboxes, Dev Agent Record, File List, Change Log, Status
