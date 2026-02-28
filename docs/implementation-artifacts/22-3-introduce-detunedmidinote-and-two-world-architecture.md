# Story 22.3: Introduce DetunedMIDINote and Two-World Architecture

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer building interval training**,
I want a `DetunedMIDINote(note:offset:)` value type representing a MIDI note with a cent offset in the logical world, `TuningSystem.frequency(for:referencePitch:)` bridge methods for converting to the physical world, and the `Pitch` struct dissolved,
So that the codebase has a clear two-world architecture: logical (MIDINote, DetunedMIDINote, Interval, Cents) and physical (Frequency), bridged explicitly by TuningSystem + ReferencePitch.

## Acceptance Criteria

1. **DetunedMIDINote struct** -- `DetunedMIDINote(note: MIDINote, offset: Cents)` conforms to `Hashable` and `Sendable`. Represents a MIDI note with a microtonal offset, with no frequency or tuning knowledge.

2. **DetunedMIDINote convenience init** -- `DetunedMIDINote(note)` creates a `DetunedMIDINote` with `offset: Cents(0)` for plain MIDINote conversion.

3. **TuningSystem.frequency(for: DetunedMIDINote)** -- `TuningSystem.frequency(for: DetunedMIDINote, referencePitch: Frequency) -> Frequency` returns the correct frequency for that note+offset combination. NFR3 (0.1-cent frequency precision) preserved.

4. **TuningSystem.frequency(for: MIDINote)** -- Convenience overload delegates to the `DetunedMIDINote` overload with zero offset.

5. **No default values on bridge methods** -- Every call site must explicitly pass both `tuningSystem` and `referencePitch`.

6. **Pitch struct dissolved** -- All 5 production call sites migrated to `DetunedMIDINote` + `TuningSystem.frequency(for:referencePitch:)`. `Pitch.swift` deleted. No file references `Pitch` as a type.

7. **MIDINote.pitch(at:in:) removed** -- Zero production callers; method removed from `Interval.swift`. No file references `pitch(at:` or `pitch(in:`.

8. **SoundFont inverse conversion privatized** -- `Pitch(frequency:referencePitch:)` logic moved to a private helper within the SoundFont layer. No code outside the SoundFont layer performs Hz->MIDINote decomposition.

9. **project-context.md updated** -- Documents the two-world model: logical world (MIDINote, DetunedMIDINote, Interval, Cents) and physical world (Frequency), bridged by `TuningSystem.frequency(for:referencePitch:)`.

10. **Full test suite passes** -- All tests pass with no behavioral changes.

## Tasks / Subtasks

- [x] Task 1: Create `DetunedMIDINote` struct (AC: #1, #2)
  - [x] 1.1 Create `Peach/Core/Audio/DetunedMIDINote.swift` with `note: MIDINote`, `offset: Cents`, `Hashable`, `Sendable`
  - [x] 1.2 Add convenience `init(_ note: MIDINote)` that sets `offset: Cents(0)`
  - [x] 1.3 Add `///` doc comment explaining role in the two-world architecture
  - [x] 1.4 Write `DetunedMIDINoteTests.swift` — construction, hashable, sendable, convenience init

- [x] Task 2: Add `TuningSystem.frequency(for:referencePitch:)` bridge methods (AC: #3, #4, #5)
  - [x] 2.1 Add `func frequency(for note: DetunedMIDINote, referencePitch: Frequency) -> Frequency` to `TuningSystem`
  - [x] 2.2 Move forward-conversion math from `Pitch.frequency(referencePitch:)` into the new method
  - [x] 2.3 Add `func frequency(for note: MIDINote, referencePitch: Frequency) -> Frequency` convenience that delegates to DetunedMIDINote overload with zero offset
  - [x] 2.4 No default values on any parameter
  - [x] 2.5 Write tests for both overloads in `TuningSystemTests.swift` — mirror all forward-conversion tests from `PitchTests.swift`

- [x] Task 3: Migrate 5 production call sites from `Pitch` to `DetunedMIDINote` + `TuningSystem.frequency()` (AC: #6)
  - [x] 3.1 Migrate `Comparison.note1Frequency(referencePitch:)` — add `tuningSystem` parameter, use `tuningSystem.frequency(for: MIDINote, referencePitch:)`
  - [x] 3.2 Migrate `Comparison.note2Frequency(referencePitch:)` — add `tuningSystem` parameter, use `tuningSystem.frequency(for: DetunedMIDINote(note: note2, offset: centDifference), referencePitch:)`
  - [x] 3.3 Migrate `PitchMatchingSession` reference frequency (line ~185) — use `tuningSystem.frequency(for: challenge.referenceNote, referencePitch:)`
  - [x] 3.4 Migrate `PitchMatchingSession` tunable frequency (line ~199) — use `tuningSystem.frequency(for: DetunedMIDINote(note: challenge.referenceNote, offset: Cents(challenge.initialCentOffset)), referencePitch:)`
  - [x] 3.5 Remove `Pitch(note:, cents:)` construction from `MIDINote.pitch(at:in:)` in `Interval.swift` (method is being removed entirely in Task 4)
  - [x] 3.6 Update `ComparisonSession` callers of `note1Frequency`/`note2Frequency` to pass `tuningSystem` parameter
  - [x] 3.7 Update all test callers to pass explicit `tuningSystem` parameter

- [x] Task 4: Remove `MIDINote.pitch(at:in:)` (AC: #7)
  - [x] 4.1 Delete `pitch(at:in:)` method from the `extension MIDINote` block in `Interval.swift`
  - [x] 4.2 Delete test cases in `PitchTests.swift` that test `pitch(at:in:)` (5 tests: pitchAtPerfectFifth, pitchDefaults, allIntervalsEqualTemperamentCentsZero, pitchAtMinorSecond, pitchAtOctave)
  - [x] 4.3 Verify no file references `pitch(at:` or `pitch(in:`

- [x] Task 5: Privatize inverse conversion to SoundFont layer (AC: #8)
  - [x] 5.1 Create a `private` struct or helper function inside `SoundFontNotePlayer.swift` that replicates `Pitch.init(frequency:referencePitch:)` logic — decompose Hz into nearest MIDI note + cent remainder
  - [x] 5.2 Update `SoundFontNotePlayer.play()` (line ~141) to use the private helper instead of `Pitch(frequency:referencePitch:)`
  - [x] 5.3 Update `SoundFontPlaybackHandle.adjustFrequency()` (line ~50) to use the same private helper
  - [x] 5.4 Migrate inverse-conversion tests from `PitchTests.swift` into `SoundFontNotePlayerTests.swift` (test the private helper through the public `play()` interface, or make the helper `nonisolated static` within the SoundFont layer for direct testing)

- [x] Task 6: Delete `Pitch.swift` (AC: #6)
  - [x] 6.1 Delete `Peach/Core/Audio/Pitch.swift`
  - [x] 6.2 Delete or fully migrate `PeachTests/Core/Audio/PitchTests.swift`
  - [x] 6.3 Verify no file references `Pitch` as a type (grep for `Pitch` in Swift files)

- [x] Task 7: Update `project-context.md` (AC: #9)
  - [x] 7.1 Replace MIDI-to-Hz conversion guidance (line ~81) with two-world model documentation
  - [x] 7.2 Document: logical world (MIDINote, DetunedMIDINote, Interval, Cents) and physical world (Frequency), bridged by `TuningSystem.frequency(for:referencePitch:)`
  - [x] 7.3 Update "Never Do This" section to mention `Pitch` as a deleted type

- [x] Task 8: Run full test suite and verify (AC: #10)
  - [x] 8.1 `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [x] 8.2 Verify zero behavioral changes — same frequency values, same precision

## Dev Notes

### Two-World Architecture Concept

This story establishes the foundational separation:

- **Logical world**: `MIDINote`, `DetunedMIDINote`, `Interval`, `Cents` — discrete pitch identities and relationships, no knowledge of Hz
- **Physical world**: `Frequency` — Hz values that `NotePlayer` consumes
- **Bridge**: `TuningSystem.frequency(for:referencePitch:)` — the ONLY path from logical to physical; always requires explicit `tuningSystem` and `referencePitch` parameters

The current `Pitch` struct conflates both worlds — it holds a note+cents (logical) and converts to Hz (physical) in one type. Dissolving it forces every frequency computation to go through the explicit bridge.

### Current Pitch.swift Forward Conversion Math (to preserve exactly)

```swift
// From Pitch.frequency(referencePitch:) — move this into TuningSystem.frequency(for:referencePitch:)
private static let referenceMIDINote = 69
private static let semitonesPerOctave = 12.0
private static let centsPerSemitone = 100.0
private static let octaveRatio = 2.0

func frequency(referencePitch: Frequency) -> Frequency {
    let semitones = Double(note.rawValue - Self.referenceMIDINote)
        + cents.rawValue / Self.centsPerSemitone
    return Frequency(referencePitch.rawValue * pow(Self.octaveRatio, semitones / Self.semitonesPerOctave))
}
```

### Current Pitch.swift Inverse Conversion Math (to privatize in SoundFont layer)

```swift
// From Pitch.init(frequency:referencePitch:) — move into SoundFont private helper
init(frequency: Frequency, referencePitch: Frequency) {
    let exactMidi = Double(Self.referenceMIDINote)
        + Self.semitonesPerOctave * log2(frequency.rawValue / referencePitch.rawValue)
    let roundedMidi = Int(exactMidi.rounded())
    let centsRemainder = (exactMidi - Double(roundedMidi)) * Self.centsPerSemitone
    self.init(
        note: MIDINote(roundedMidi.clamped(to: MIDINote.validRange)),
        cents: Cents(centsRemainder)
    )
}
```

### Exact Production Call Sites to Migrate

**Forward conversion (Pitch → Hz) — 5 sites, migrate to TuningSystem.frequency():**

| # | File | Current Code | New Code |
|---|------|-------------|----------|
| 1 | `Peach/Core/Training/Comparison.swift:13` | `Pitch(note: note1, cents: Cents(0)).frequency(referencePitch: referencePitch)` | `tuningSystem.frequency(for: note1, referencePitch: referencePitch)` |
| 2 | `Peach/Core/Training/Comparison.swift:17` | `Pitch(note: note2, cents: centDifference).frequency(referencePitch: referencePitch)` | `tuningSystem.frequency(for: DetunedMIDINote(note: note2, offset: centDifference), referencePitch: referencePitch)` |
| 3 | `Peach/PitchMatching/PitchMatchingSession.swift:~185` | `Pitch(note: challenge.referenceNote, cents: Cents(0)).frequency(referencePitch: settings.referencePitch)` | `tuningSystem.frequency(for: challenge.referenceNote, referencePitch: settings.referencePitch)` |
| 4 | `Peach/PitchMatching/PitchMatchingSession.swift:~199` | `Pitch(note: challenge.referenceNote, cents: Cents(challenge.initialCentOffset)).frequency(referencePitch: settings.referencePitch)` | `tuningSystem.frequency(for: DetunedMIDINote(note: challenge.referenceNote, offset: Cents(challenge.initialCentOffset)), referencePitch: settings.referencePitch)` |
| 5 | `Peach/Core/Audio/Interval.swift:54` | `Pitch(note: transposedNote, cents: Cents(centsDeviation))` | Method being deleted (Task 4) — no migration needed |

**Inverse conversion (Hz → Pitch) — 2 sites, privatize in SoundFont:**

| # | File | Current Code | New Code |
|---|------|-------------|----------|
| 1 | `Peach/Core/Audio/SoundFontNotePlayer.swift:~141` | `Pitch(frequency: frequency, referencePitch: .concert440)` | Private helper: `Self.decompose(frequency: frequency)` or similar |
| 2 | `Peach/Core/Audio/SoundFontPlaybackHandle.swift:~50` | `Pitch(frequency: frequency, referencePitch: .concert440)` | Same private helper (shared between NotePlayer and PlaybackHandle) |

### Comparison.swift Signature Changes

The `Comparison` struct's frequency methods currently take only `referencePitch`:
```swift
func note1Frequency(referencePitch: Frequency) -> Frequency
func note2Frequency(referencePitch: Frequency) -> Frequency
```

After migration, they must also take `tuningSystem`:
```swift
func note1Frequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency
func note2Frequency(tuningSystem: TuningSystem, referencePitch: Frequency) -> Frequency
```

**Callers to update:** `ComparisonSession.swift` calls both methods — it reads `tuningSystem` from its settings. Search for `note1Frequency` and `note2Frequency` to find all call sites.

### PitchMatchingSession.swift Changes

`PitchMatchingSession` currently reads `settings.referencePitch` but has no `tuningSystem` parameter. It will need to:
1. Receive or read a `tuningSystem` value (from settings or hardcoded `.equalTemperament` for now — check how `ComparisonSession` handles it)
2. Pass it to `TuningSystem.frequency(for:referencePitch:)` calls

### SoundFont Private Helper Design

The inverse conversion is always 12-TET (hardcoded `referencePitch: .concert440`). Design options:

**Recommended: `nonisolated static` method on `SoundFontNotePlayer`**
```swift
/// Decomposes a frequency into its nearest MIDI note and cent remainder.
/// Always uses 12-TET at concert pitch (A4=440Hz) — this is a MIDI
/// implementation detail, not a musical tuning choice.
nonisolated static func decompose(frequency: Frequency) -> (note: UInt8, cents: Cents) {
    // ... math from Pitch.init(frequency:referencePitch:) ...
}
```

This keeps it testable via `SoundFontNotePlayer.decompose(frequency:)` without exposing it as a domain concept. `SoundFontPlaybackHandle` can call `SoundFontNotePlayer.decompose(frequency:)`.

### MIDINote.pitch(at:in:) Removal

Located in `Peach/Core/Audio/Interval.swift` lines 46-55 as an `extension MIDINote` block. Zero production callers. Five test callers in `PitchTests.swift` (lines ~67-106). Safe to delete the method and its tests.

**Keep `MIDINote.transposed(by:)` — it IS used and stays.** Only remove `pitch(at:in:)`.

### Test Migration Plan

| Current Test File | Action | Destination |
|---|---|---|
| `PitchTests.swift` — forward conversion tests (~lines 1-60, 107-230) | Rewrite to test `TuningSystem.frequency(for:referencePitch:)` | `TuningSystemTests.swift` (new or extend existing) |
| `PitchTests.swift` — `pitch(at:in:)` tests (lines ~63-106) | Delete | N/A |
| `PitchTests.swift` — inverse conversion tests (lines ~232-370) | Migrate to test the SoundFont private helper | `SoundFontNotePlayerTests.swift` |
| `PitchTests.swift` — Hashable/Sendable tests | Migrate to `DetunedMIDINoteTests.swift` for the new type | `DetunedMIDINoteTests.swift` |
| `MIDINoteTests.swift` — lines using `Pitch(note:cents:).frequency()` | Rewrite to use `TuningSystem.frequency(for:referencePitch:)` | Same file |
| `ComparisonTests.swift` — `note1Frequency`, `note2Frequency` tests | Add `tuningSystem` parameter | Same file |

### Project Structure Notes

- `DetunedMIDINote.swift` → `Peach/Core/Audio/DetunedMIDINote.swift` (alongside `MIDINote.swift`, `Cents.swift`, etc.)
- `DetunedMIDINoteTests.swift` → `PeachTests/Core/Audio/DetunedMIDINoteTests.swift`
- `TuningSystem.frequency()` methods → add to existing `Peach/Core/Audio/TuningSystem.swift`
- Forward-conversion tests → extend existing `PeachTests/Core/Audio/TuningSystemTests.swift` (check if it exists, create if not)
- SoundFont inverse helper → stays inside `Peach/Core/Audio/SoundFontNotePlayer.swift`
- No new directories needed — all files fit existing structure

### Architecture Compliance

- `DetunedMIDINote` is a value type (`struct`) — satisfies `Sendable` naturally
- No `import SwiftUI` in `Core/Audio/` — `DetunedMIDINote` is framework-free
- Bridge methods on `TuningSystem` keep the tuning-system-aware conversion explicit
- `NotePlayer` protocol boundary preserved — it still only knows `Frequency`
- SoundFont inverse conversion remains a 12-TET MIDI implementation detail behind the protocol

### Library/Framework Requirements

- No new dependencies. Pure Swift value types and existing `AVAudioEngine` APIs
- `pitchBendValue(forCents:)` static method on `SoundFontNotePlayer` — already exists, no changes needed

### References

- [Source: docs/planning-artifacts/epics.md#Story 22.3] — acceptance criteria and story definition
- [Source: Peach/Core/Audio/Pitch.swift] — forward and inverse conversion math to migrate
- [Source: Peach/Core/Audio/TuningSystem.swift] — bridge target for frequency methods
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift:~141] — inverse conversion call site 1
- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift:~50] — inverse conversion call site 2
- [Source: Peach/Core/Training/Comparison.swift:13-17] — forward conversion call sites 1-2
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:~185-200] — forward conversion call sites 3-4
- [Source: Peach/Core/Audio/Interval.swift:46-55] — `pitch(at:in:)` to delete
- [Source: PeachTests/Core/Audio/PitchTests.swift] — tests to migrate/delete
- [Source: docs/implementation-artifacts/22-2-domain-type-documentation-and-api-cleanup.md] — previous story patterns
- [Source: docs/project-context.md] — project rules and conventions

### Previous Story Intelligence (22.2)

**Patterns established in 22.1 and 22.2 to follow:**
- Replace utility/convenience with domain-type methods (22.1 deleted `FrequencyCalculation`, 22.2 deleted `MIDINote.frequency()`)
- Domain types as parameters instead of raw primitives (`Frequency` instead of `Double`)
- Named constants replace magic numbers (`referenceMIDINote`, `semitonesPerOctave`, etc.)
- Test migration preserves numerical assertions exactly — same Hz values, same precision thresholds
- Doc comments follow pattern: one-line summary of role, then "where does it appear" paragraph

**Files modified in 22.2 that may be touched again:**
- `Pitch.swift` — will be deleted entirely
- `Comparison.swift` — frequency methods get `tuningSystem` parameter
- `ComparisonSession.swift` — caller of Comparison frequency methods
- `PitchMatchingSession.swift` — has Pitch forward-conversion calls
- `PitchTests.swift` — will be deleted/migrated entirely
- `MIDINoteTests.swift` — uses `Pitch(note:cents:).frequency()`, needs migration
- `ComparisonTests.swift` — tests frequency methods, needs `tuningSystem` param

### Git Intelligence

**Recent commits (22.1-22.2):**
- `e5cb19a` Implement story 22.1: Migrate FrequencyCalculation to Domain Types
- `5fc64e6` Fix code review findings for story 22.1 and mark done
- `d6f3a93` Implement story 22.2: Domain Type Documentation and API Cleanup
- `a20bd35` Revise Epic 22-23 stories for two-world architecture (DetunedMIDINote)
- `c82bbc7` Fix Epic 22 story numbering collision

**Patterns:** Commit directly to main, one commit per story, code review as separate commit.

## File List

### New Files
- `Peach/Core/Audio/DetunedMIDINote.swift` — DetunedMIDINote value type (note + cent offset)
- `PeachTests/Core/Audio/DetunedMIDINoteTests.swift` — 10 tests for DetunedMIDINote

### Modified Files
- `Peach/Core/Audio/TuningSystem.swift` — Added `frequency(for:referencePitch:)` bridge methods (DetunedMIDINote and MIDINote overloads)
- `Peach/Core/Audio/Interval.swift` — Removed `MIDINote.pitch(at:in:)` method, updated doc comment
- `Peach/Core/Audio/MIDINote.swift` — Updated doc comment to reference TuningSystem bridge
- `Peach/Core/Audio/Cents.swift` — Updated doc comment to reference DetunedMIDINote
- `Peach/Core/Audio/Frequency.swift` — Updated doc comment to reference two-world architecture
- `Peach/Core/Audio/SoundFontNotePlayer.swift` — Added `nonisolated static decompose(frequency:)` helper, replaced Pitch usage
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — Replaced Pitch usage with SoundFontNotePlayer.decompose()
- `Peach/Core/Training/Comparison.swift` — Added `tuningSystem` parameter to frequency methods, replaced Pitch usage
- `Peach/Comparison/ComparisonSession.swift` — Passes `.equalTemperament` to Comparison frequency methods
- `Peach/PitchMatching/PitchMatchingSession.swift` — Replaced Pitch usage with TuningSystem.frequency() bridge
- `PeachTests/Core/Audio/TuningSystemTests.swift` — Added 14 forward-conversion bridge method tests
- `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` — Added 10 decompose() inverse-conversion tests
- `PeachTests/Core/Audio/MIDINoteTests.swift` — Migrated frequency tests to use TuningSystem bridge
- `PeachTests/Core/Training/ComparisonTests.swift` — Added `tuningSystem` parameter to frequency test calls
- `docs/project-context.md` — Documented two-world architecture, updated conversion guidance, added Pitch to "Never Do This"
- `docs/implementation-artifacts/sprint-status.yaml` — Status: in-progress → review

### Deleted Files
- `Peach/Core/Audio/Pitch.swift` — Dissolved; forward conversion moved to TuningSystem, inverse to SoundFont
- `PeachTests/Core/Audio/PitchTests.swift` — Tests migrated to TuningSystemTests, SoundFontNotePlayerTests, DetunedMIDINoteTests

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- SoundFont `decompose()` initially used `@MainActor`-isolated types (`Frequency.concert440`, `MIDINote.validRange`, `Cents()`) in a `nonisolated` context — fixed by using raw values directly (440.0, 0...127 range, Double return)

### Completion Notes List

- Task 1: Created `DetunedMIDINote` struct with note/offset properties, Hashable, Sendable, convenience init. 10 tests.
- Task 2: Added `TuningSystem.frequency(for:referencePitch:)` with DetunedMIDINote and MIDINote overloads. Moved forward-conversion math from Pitch. 14 tests.
- Task 3: Migrated all 5 forward-conversion call sites (Comparison x2, PitchMatchingSession x2, Interval.swift x1). Added `tuningSystem` parameter to Comparison frequency methods. Updated all callers and tests.
- Task 4: Removed `MIDINote.pitch(at:in:)` from Interval.swift. Deleted 5 tests from PitchTests.swift.
- Task 5: Created `SoundFontNotePlayer.decompose(frequency:)` — `nonisolated static` helper returning `(note: UInt8, cents: Double)`. Updated SoundFontNotePlayer.play() and SoundFontPlaybackHandle.adjustFrequency(). 10 tests.
- Task 6: Deleted `Pitch.swift` and `PitchTests.swift`. Verified no remaining type references. Updated doc comments on Cents, Frequency, MIDINote.
- Task 7: Updated project-context.md with two-world model documentation, updated domain rules and "Never Do This" section.
- Task 8: Full test suite passes with zero regressions.

### Change Log

- 2026-02-28: Implemented story 22.3 — Introduced DetunedMIDINote and two-world architecture. Created DetunedMIDINote value type, added TuningSystem frequency bridge methods, migrated all production call sites, privatized inverse conversion to SoundFont layer, dissolved Pitch struct, updated project documentation.
