# Story 22.1: Migrate FrequencyCalculation to Domain Types

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want the standalone `FrequencyCalculation.swift` utility replaced by `Pitch.frequency(referencePitch:)` and `MIDINote.frequency(referencePitch:)` domain methods,
So that frequency computation lives on the domain types that own the data, and the redundant utility is deleted.

## Acceptance Criteria

1. **Forward conversion migrated** -- All call sites of `FrequencyCalculation.frequency(midiNote:cents:referencePitch:)` are migrated to `Pitch.frequency(referencePitch:)` or `MIDINote.frequency(referencePitch:)`.

2. **Inverse conversion migrated** -- All call sites of `FrequencyCalculation.midiNoteAndCents(frequency:referencePitch:)` are migrated to a new `Pitch.init(frequency:referencePitch:)` initializer (or equivalent domain method).

3. **FrequencyCalculation deleted** -- `FrequencyCalculation.swift` is deleted and no file imports or references `FrequencyCalculation`.

4. **Precision preserved** -- NFR3 (0.1-cent frequency precision) is preserved. Existing frequency precision tests pass against the new domain methods.

5. **Full test suite passes** -- All tests pass with no behavioral changes.

## Tasks / Subtasks

- [x] Task 1: Add `Pitch.init(frequency:referencePitch:)` inverse initializer with tests (AC: #2, #4)
  - [x] Write failing tests in `PitchTests.swift`: round-trip (frequency→Pitch→frequency), known values (440 Hz → MIDINote(69)/Cents(0)), half-semitone offsets, boundary MIDI notes, non-440 reference pitch
  - [x] Implement `Pitch.init(frequency:referencePitch:)` in `Pitch.swift` — inverse of `frequency()`: compute exact MIDI from `69 + 12 * log2(freq / ref)`, round to nearest integer for `note`, remainder as `cents` (clamped to -50...+50)
  - [x] Verify 0.1-cent precision on round-trip tests

- [x] Task 2: Make `MIDINote.frequency()` self-contained (AC: #1, #4)
  - [x] Update `MIDINote.frequency(referencePitch:)` to compute frequency directly using `Pitch(note: self, cents: Cents(0)).frequency(referencePitch: Frequency(referencePitch))` instead of delegating to `FrequencyCalculation`
  - [x] Remove `throws` from `MIDINote.frequency()` — the `Pitch.frequency()` method is pure math, no validation needed (MIDINote already validates range 0-127 at init)
  - [x] Update all call sites that `try` `MIDINote.frequency()` to remove `try`
  - [x] Update `MIDINoteTests.swift` to verify frequency values unchanged

- [x] Task 3: Migrate `Comparison.swift` forward conversion call sites (AC: #1)
  - [x] Replace `note1Frequency()` to use `Pitch(note: note1, cents: Cents(0)).frequency(referencePitch: ...)` or `note1.frequency(referencePitch:)`
  - [x] Replace `note2Frequency()` to use `Pitch(note: note2, cents: centDifference).frequency(referencePitch: ...)`
  - [x] Remove `throws` from both methods (pure math, no validation)
  - [x] Update all callers of `note1Frequency()`/`note2Frequency()` to remove `try`

- [x] Task 4: Migrate `PitchMatchingSession.swift` forward conversion call sites (AC: #1)
  - [x] Replace line ~185 `FrequencyCalculation.frequency(midiNote:referencePitch:)` with `Pitch(note: challenge.referenceNote, cents: Cents(0)).frequency(referencePitch: ...)`
  - [x] Replace line ~201 `FrequencyCalculation.frequency(midiNote:cents:referencePitch:)` with `Pitch(note: challenge.referenceNote, cents: Cents(challenge.initialCentOffset)).frequency(referencePitch: ...)`
  - [x] Remove `try` if methods are now non-throwing

- [x] Task 5: Migrate `SoundFontNotePlayer.swift` inverse conversion call site (AC: #2)
  - [x] Replace `FrequencyCalculation.midiNoteAndCents(frequency:referencePitch:)` with `Pitch(frequency: freq, referencePitch: .concert440)` then use `.note.rawValue` and `.cents`
  - [x] Verify pitch bend calculation unchanged

- [x] Task 6: Migrate `SoundFontPlaybackHandle.swift` inverse conversion call site (AC: #2)
  - [x] Replace `FrequencyCalculation.midiNoteAndCents(frequency:referencePitch:)` with `Pitch(frequency: freq, referencePitch: .concert440)` then compute from `.note` and `.cents`
  - [x] Verify cent difference calculation unchanged

- [x] Task 7: Migrate FrequencyCalculation tests to domain type tests (AC: #4, #5)
  - [x] Move forward-conversion tests to `PitchTests.swift` and `MIDINoteTests.swift`
  - [x] Move inverse-conversion tests to `PitchTests.swift` (testing `Pitch.init(frequency:referencePitch:)`)
  - [x] Move round-trip tests to `PitchTests.swift`
  - [x] Move reference pitch validation tests — decide: keep validation in `Pitch.init(frequency:)` or drop it (architecture says `Pitch.frequency()` is pure math, no throws)
  - [x] Delete `FrequencyCalculationTests.swift`

- [x] Task 8: Delete `FrequencyCalculation.swift` and verify (AC: #3, #5)
  - [x] Delete `Peach/Core/Audio/FrequencyCalculation.swift`
  - [x] Delete `PeachTests/Core/Audio/FrequencyCalculationTests.swift` (if not already deleted in Task 7)
  - [x] Grep entire project for `FrequencyCalculation` — zero results
  - [x] Run `tools/check-dependencies.sh`
  - [x] Run full test suite: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`

## Dev Notes

### Critical Design Decisions

- **`Pitch.init(frequency:referencePitch:)` is the inverse conversion** -- Replaces `FrequencyCalculation.midiNoteAndCents()`. Computes `exactMidi = 69 + 12 * log2(frequency / referencePitch)`, rounds to nearest integer for `note`, remainder in cents clamped to -50...+50. This keeps the inverse on the same type that owns the forward conversion. [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, lines 1066-1075]
- **`MIDINote.frequency()` becomes non-throwing** -- Currently `throws` because `FrequencyCalculation` validates reference pitch range (380-500 Hz). After migration, `MIDINote.frequency()` delegates to `Pitch.frequency()` which is pure math with no validation. Reference pitch validation was a defensive check that's unnecessary — callers already provide sensible values (440.0 default, or user-configured). Removing `throws` simplifies all call sites. [Source: Peach/Core/Audio/FrequencyCalculation.swift]
- **Reference pitch validation decision** -- `FrequencyCalculation` validates `referencePitch` is in 380-500 Hz range. This validation is NOT replicated in domain types. The architecture specifies `Pitch.frequency()` as "pure math, no throws". The app's `SettingsScreen` already constrains the slider to valid range. Drop the validation; don't gold-plate. [Source: docs/planning-artifacts/architecture.md -- line 1001]
- **Pure refactoring — no functional changes** -- All stories in Epic 22 are explicitly "pure refactoring with no functional changes" per the epic description. Every frequency value must be bit-identical before and after migration.
- **Test migration strategy** -- FrequencyCalculationTests (35 tests) covers forward conversion, inverse conversion, round-trips, and edge cases. These tests are valuable and must be preserved as domain type tests, not deleted without replacement. Restructure into PitchTests and MIDINoteTests organized by behavior.

### Architecture Specification (Canonical Implementation)

**New: `Pitch.init(frequency:referencePitch:)`**
```swift
extension Pitch {
    init(frequency: Frequency, referencePitch: Frequency = .concert440) {
        let exactMidi = 69.0 + 12.0 * log2(frequency.rawValue / referencePitch.rawValue)
        let roundedMidi = Int(exactMidi.rounded())
        let centsRemainder = (exactMidi - Double(roundedMidi)) * 100.0
        self.init(
            note: MIDINote(roundedMidi.clamped(to: MIDINote.validRange)),
            cents: Cents(centsRemainder)
        )
    }
}
```
[Source: docs/planning-artifacts/architecture.md -- lines 1066-1075, FrequencyCalculation migration table]

**Updated: `MIDINote.frequency()` (non-throwing)**
```swift
extension MIDINote {
    func frequency(referencePitch: Double = 440.0) -> Frequency {
        Pitch(note: self, cents: Cents(0)).frequency(referencePitch: Frequency(referencePitch))
    }
}
```
[Source: Peach/Core/Audio/MIDINote.swift -- current implementation delegates to FrequencyCalculation]

### Call Site Migration Map

| File | Current Call | Migration Target | Throws Change |
|------|-------------|-----------------|---------------|
| `MIDINote.swift:23` | `FrequencyCalculation.frequency(midiNote:referencePitch:)` | `Pitch(note: self, cents: Cents(0)).frequency(referencePitch:)` | `throws` → non-throwing |
| `Comparison.swift:13` | `FrequencyCalculation.frequency(midiNote: note1.rawValue, referencePitch:)` | `Pitch(note: note1, cents: Cents(0)).frequency(referencePitch:)` | `throws` → non-throwing |
| `Comparison.swift:17` | `FrequencyCalculation.frequency(midiNote: note2.rawValue, cents: centDifference.rawValue, referencePitch:)` | `Pitch(note: note2, cents: centDifference).frequency(referencePitch:)` | `throws` → non-throwing |
| `PitchMatchingSession.swift:185` | `FrequencyCalculation.frequency(midiNote: ..., referencePitch:)` | `Pitch(note: challenge.referenceNote, cents: Cents(0)).frequency(referencePitch:)` | Remove `try` |
| `PitchMatchingSession.swift:201` | `FrequencyCalculation.frequency(midiNote: ..., cents: ..., referencePitch:)` | `Pitch(note: challenge.referenceNote, cents: Cents(...)).frequency(referencePitch:)` | Remove `try` |
| `SoundFontNotePlayer.swift:141` | `FrequencyCalculation.midiNoteAndCents(frequency:referencePitch:)` | `Pitch(frequency: freq, referencePitch: .concert440)` → `.note`, `.cents` | No change |
| `SoundFontPlaybackHandle.swift:50` | `FrequencyCalculation.midiNoteAndCents(frequency:referencePitch:)` | `Pitch(frequency: freq, referencePitch: .concert440)` → `.note`, `.cents` | No change |

### File Placement

**Modified files:**
- `Peach/Core/Audio/Pitch.swift` — Add `init(frequency:referencePitch:)` inverse initializer
- `Peach/Core/Audio/MIDINote.swift` — Rewrite `frequency()` to delegate to Pitch, remove `throws`
- `Peach/Core/Audio/Comparison.swift` — Migrate `note1Frequency()`/`note2Frequency()` to Pitch, remove `throws`
- `Peach/Core/Audio/SoundFontNotePlayer.swift` — Migrate inverse conversion to `Pitch.init(frequency:)`
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — Migrate inverse conversion to `Pitch.init(frequency:)`
- `Peach/PitchMatching/PitchMatchingSession.swift` — Migrate forward conversion to Pitch

**Deleted files:**
- `Peach/Core/Audio/FrequencyCalculation.swift`
- `PeachTests/Core/Audio/FrequencyCalculationTests.swift`

**Modified test files:**
- `PeachTests/Core/Audio/PitchTests.swift` — Add inverse conversion tests, round-trip tests, migrated edge case tests
- `PeachTests/Core/Audio/MIDINoteTests.swift` — Update frequency tests (remove `try`, verify values)

**Callers that need `try` removal (ripple effect):**
- Any file calling `MIDINote.frequency()` with `try` — grep for `try.*\.frequency\(` after making it non-throwing
- Any file calling `Comparison.note1Frequency()` or `note2Frequency()` with `try`
- Corresponding test files

### Project Structure Notes

- All modified files remain in their current locations — no file moves
- `Pitch.swift` extension stays in the same file (inverse initializer alongside forward method)
- No new directories needed
- No `PeachApp.swift` wiring changes (no new services or environment keys)
- No localization changes
- Run `tools/check-dependencies.sh` to verify no forbidden imports after changes

### Previous Story Intelligence (Story 21.3)

**What worked:**
- TDD approach: write failing tests first, then implement
- Clean code review found: test values should independently verify, not mirror production formula
- `Pitch.frequency()` already implements the combined-exponent formula (one `pow` call) with better precision than FrequencyCalculation's two-`pow` approach
- Pattern: `import Foundation` → type definition → extensions

**Code review findings from 21.3:**
- (M1) Sendable test should actually cross isolation boundary (use `Task.detached`)
- (M2) Test edge cases: negative cents offset, non-standard reference pitch
- (M3) Test values must be independently computed, not mirror production formula

**Patterns to follow:**
- File structure: `import Foundation` → struct/enum → extensions
- Test structure: `import Testing` → `import Foundation` → `@testable import Peach` → `@Suite` struct
- Hardcode expected values in tests (don't recompute with formula)
- Run full test suite, not individual files

### Git Intelligence

Recent commits (most recent first):
- `3ea155e` Fix code review findings for story 21.3 and mark done
- `48086de` Implement story 21.3: Pitch Value Type and MIDINote Integration
- `6cdd6d4` Add story 21.3: Implement Pitch Value Type and MIDINote Integration

**Patterns observed:**
- Commit message format: `Implement story {id}: {description}`
- Story file committed first (`Add story ...`), then implementation, then code review fixes
- Clean separation per story

### Existing Types This Story Depends On

- **`Pitch` struct** (Story 21.3, done) -- `Peach/Core/Audio/Pitch.swift`. `note: MIDINote`, `cents: Cents`. Has `frequency(referencePitch:) -> Frequency`. The inverse initializer will be added here.
- **`MIDINote` struct** -- `Peach/Core/Audio/MIDINote.swift`. `rawValue: Int` (0-127). Currently has `frequency(referencePitch:) throws -> Frequency` that delegates to FrequencyCalculation. Will be rewritten.
- **`Frequency` struct** -- `Peach/Core/Audio/Frequency.swift`. `rawValue: Double`, `static let concert440`. Arithmetic already supported.
- **`Cents` struct** -- `Peach/Core/Audio/Cents.swift`. `rawValue: Double`. Used for cent offsets.
- **`Comparison` struct** -- `Peach/Core/Audio/Comparison.swift` (or `Core/Training/`). Has `note1Frequency()` and `note2Frequency()` that use FrequencyCalculation.
- **`FrequencyCalculation` enum** -- `Peach/Core/Audio/FrequencyCalculation.swift`. The target for deletion. 2 static methods, 35 tests.

### Concurrency & Swift 6.2

- All new code (Pitch initializer) is pure computation on value types — automatically `Sendable`
- Default MainActor isolation active — do NOT add explicit `@MainActor`
- Removing `throws` from `MIDINote.frequency()` and `Comparison` methods simplifies call sites (no `try`)
- No async work introduced

### Dependency Rules

- All modified files are in `Core/Audio/` or `Core/Training/` — must remain framework-free
- Allowed imports: `Foundation` (for `pow`, `log2`, `Double`), Swift standard library
- Forbidden imports: `SwiftUI`, `UIKit`, `SwiftData`, `Combine`
- Run `tools/check-dependencies.sh` after all changes
- [Source: docs/project-context.md -- Dependency Direction Rules]

### Risk Assessment

- **Medium risk: Removing `throws`** -- Changing `MIDINote.frequency()` and `Comparison.note1Frequency()`/`note2Frequency()` from throwing to non-throwing will cause compiler errors at all call sites that use `try`. This is intentional and the compiler will find every site. Fix by removing `try`/`try?`/`try!`.
- **Low risk: Precision** -- `Pitch.frequency()` uses the same mathematical formula as `FrequencyCalculation.frequency()` (combined exponent is actually more precise). Round-trip tests will verify.
- **Low risk: Inverse conversion edge cases** -- `Pitch.init(frequency:)` must handle boundary MIDI notes (0, 127) and clamp correctly. FrequencyCalculation already handles this; replicate the clamping.

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 22: Clean Slate, Story 22.1]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, FrequencyCalculation migration (lines 1066-1075)]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, Pitch definition (lines 990-1001)]
- [Source: docs/planning-artifacts/architecture.md -- v0.3 Amendment, NotePlayer takes Pitch (lines 1034-1058)]
- [Source: docs/project-context.md -- TDD workflow, testing standards, dependency rules]
- [Source: Peach/Core/Audio/FrequencyCalculation.swift -- Current utility (7 call sites)]
- [Source: Peach/Core/Audio/Pitch.swift -- Pitch struct with forward frequency method]
- [Source: Peach/Core/Audio/MIDINote.swift -- MIDINote.frequency() delegates to FrequencyCalculation]
- [Source: Peach/Core/Audio/Comparison.swift -- note1Frequency/note2Frequency use FrequencyCalculation]
- [Source: Peach/PitchMatching/PitchMatchingSession.swift -- 2 FrequencyCalculation calls]
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift -- Inverse conversion call site]
- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift -- Inverse conversion call site]
- [Source: PeachTests/Core/Audio/FrequencyCalculationTests.swift -- 35 tests to migrate]
- [Source: docs/implementation-artifacts/21-3-implement-pitch-value-type-and-midinote-integration.md -- Previous story intelligence]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

No debug issues encountered.

### Completion Notes List

- Task 1: Added `Pitch.init(frequency:referencePitch:)` inverse initializer in an extension to preserve the memberwise init. 17 new tests added to PitchTests covering inverse conversion, round-trips, boundary cases, clamping, and precision.
- Task 2: Made `MIDINote.frequency()` non-throwing by delegating to `Pitch.frequency()` instead of `FrequencyCalculation`. Updated MIDINoteTests to remove `try`.
- Task 3: Migrated `Comparison.note1Frequency()` and `note2Frequency()` to use `Pitch.frequency()`. Removed `throws`. Updated `ComparisonSession` and `ComparisonTests` to remove `try`.
- Task 4: Migrated `PitchMatchingSession.playNextChallenge()` to use `Pitch.frequency()` instead of `FrequencyCalculation.frequency()`.
- Task 5: Migrated `SoundFontNotePlayer` inverse conversion from `FrequencyCalculation.midiNoteAndCents()` to `Pitch(frequency:referencePitch:)`.
- Task 6: Migrated `SoundFontPlaybackHandle.adjustFrequency()` inverse conversion from `FrequencyCalculation.midiNoteAndCents()` to `Pitch(frequency:referencePitch:)`.
- Task 7: Migrated all FrequencyCalculation tests to PitchTests (forward conversion edge cases, sub-cent precision, cents range validation, multiple reference pitches) and MIDINoteTests (boundary frequencies). Updated PitchMatchingSessionTests and SoundFontNotePlayerTests to remove FrequencyCalculation references. Deleted FrequencyCalculationTests.swift. Reference pitch validation tests dropped per architecture (pure math, no throws).
- Task 8: Deleted `FrequencyCalculation.swift`. Verified zero references in production code. All dependency checks pass. Full test suite passes.

### Change Log

- 2026-02-28: Implemented story 22.1 — migrated all FrequencyCalculation usage to Pitch and MIDINote domain types, deleted FrequencyCalculation.swift and FrequencyCalculationTests.swift

### File List

**New:**
(none)

**Modified:**
- `Peach/Core/Audio/Pitch.swift` — Added `init(frequency:referencePitch:)` inverse initializer extension
- `Peach/Core/Audio/MIDINote.swift` — Rewrote `frequency()` to delegate to Pitch, removed `throws`
- `Peach/Core/Training/Comparison.swift` — Migrated `note1Frequency()`/`note2Frequency()` to Pitch, removed `throws`
- `Peach/PitchMatching/PitchMatchingSession.swift` — Migrated forward conversion to Pitch
- `Peach/Core/Audio/SoundFontNotePlayer.swift` — Migrated inverse conversion to `Pitch(frequency:)`
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — Migrated inverse conversion to `Pitch(frequency:)`
- `Peach/Comparison/ComparisonSession.swift` — Removed `try` from note frequency calls
- `PeachTests/Core/Audio/PitchTests.swift` — Added 28 tests (inverse, round-trip, migrated forward conversion edge cases)
- `PeachTests/Core/Audio/MIDINoteTests.swift` — Updated frequency tests (removed `try`), added boundary tests
- `PeachTests/Core/Training/ComparisonTests.swift` — Removed `throws`/`try` from frequency tests
- `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` — Migrated FrequencyCalculation references to Pitch
- `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` — Migrated FrequencyCalculation reference to Pitch

**Deleted:**
- `Peach/Core/Audio/FrequencyCalculation.swift`
- `PeachTests/Core/Audio/FrequencyCalculationTests.swift`
