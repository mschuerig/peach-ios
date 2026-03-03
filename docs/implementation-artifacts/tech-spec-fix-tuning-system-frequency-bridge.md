---
title: 'Fix TuningSystem frequency bridge to respect tuning system'
slug: 'fix-tuning-system-frequency-bridge'
created: '2026-03-03'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'Swift Testing', 'AVAudioEngine']
files_to_modify: ['Peach/Core/Audio/TuningSystem.swift', 'PeachTests/Core/Audio/TuningSystemTests.swift']
code_patterns: ['enum with computed methods', 'value types', 'private by default', 'two-world architecture (logical→physical bridge)', 'Euclidean modular decomposition']
test_patterns: ['Swift Testing @Test/@Suite/#expect', 'struct-based suites', 'async test functions', 'behavioral descriptions', '0.1-cent precision tolerance']
---

# Tech-Spec: Fix TuningSystem frequency bridge to respect tuning system

**Created:** 2026-03-03

## Overview

### Problem Statement

`TuningSystem.frequency(for:referencePitch:)` uses hardcoded 12-TET math (`semitones / 12`) regardless of the tuning system variant. The method ignores `self` entirely — `.equalTemperament` and `.justIntonation` produce identical frequencies for the same input. The `centOffset(for: Interval)` method correctly encodes just intonation cent values (e.g., perfect fifth = 701.955 cents) but has zero production call sites. The tuning system's core musical knowledge is completely disconnected from the audio pipeline.

### Solution

Add an internal method that decomposes the MIDI distance from `referenceMIDINote` to the target note into whole octaves + a remainder interval (0–12 semitones), looks up the tuning-system-specific cent offset via `centOffset(for:)`, and returns the total cent offset including any microtonal `DetunedMIDINote.offset`. Rewrite `frequency()` to convert that total cent offset to Hz using `ref × 2^(cents/1200)`.

### Scope

**In Scope:**
- `TuningSystem.swift`: Add internal cent-offset-from-reference method, rewrite `frequency()` to use it
- `TuningSystemTests.swift`: Rewrite JI frequency tests that currently pre-bake offsets as workaround

**Out of Scope:**
- Callers of `frequency()` (confirmed: no caller compensates for the bug)
- New tuning systems beyond equalTemperament/justIntonation
- UI changes
- Changes to `Interval`, `MIDINote`, `DetunedMIDINote`, `Cents`, or `Frequency` types

## Context for Development

### Codebase Patterns

- **Two-world architecture:** Logical world (`MIDINote`, `DetunedMIDINote`, `Interval`, `Cents`) and physical world (`Frequency`), bridged exclusively by `TuningSystem.frequency(for:referencePitch:)`. All forward conversion (logical → physical) goes through `TuningSystem`.
- **`TuningSystem` is an enum** with computed methods — not a protocol. Adding behavior means adding/modifying methods on the enum. New private methods are fine.
- **`Interval` enum** has raw values 0–12 (semitone count). `Interval(rawValue:)` is failable; values 0–12 are valid. The decomposition remainder (0–11 via Euclidean mod) always maps to a valid case.
- **`centOffset(for: Interval) -> Double`** is the single source of truth for tuning-system-specific interval sizes. Equal temperament: `semitones × 100`. Just intonation: lookup table of acoustically pure ratios.
- **`DetunedMIDINote`** carries a `MIDINote` + `Cents` offset. The offset represents microtonal deviation (training difficulty), not tuning-system correction.
- **Access control:** `private` by default. The new decomposition method should be `private`.

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Core/Audio/TuningSystem.swift` | Bug location — `frequency()` ignores `self`, `centOffset()` is orphaned |
| `PeachTests/Core/Audio/TuningSystemTests.swift` | 3 JI frequency tests (lines 276–312) pre-bake offsets — need rewriting |
| `Peach/Core/Audio/Interval.swift` | `Interval` enum (raw values 0–12), used by decomposition |
| `Peach/Core/Audio/MIDINote.swift` | `MIDINote` value type (raw value 0–127) |
| `Peach/Core/Audio/DetunedMIDINote.swift` | `MIDINote` + `Cents` offset — input to `frequency()` |
| `Peach/Core/Audio/Frequency.swift` | `Frequency` value type — output of `frequency()` |
| `Peach/Core/Audio/Cents.swift` | `Cents` value type — microtonal offset |

### Technical Decisions

**Decomposition algorithm (Euclidean modular arithmetic):**

Given a `DetunedMIDINote` with MIDI note `n` and cent offset `o`:

1. `distance = n - referenceMIDINote` (signed integer, can be negative)
2. `remainder = ((distance % 12) + 12) % 12` (always 0–11, Euclidean mod)
3. `octaves = (distance - remainder) / 12` (signed integer, can be negative)
4. `interval = Interval(rawValue: remainder)!` (always valid since 0–11 ⊂ 0–12)
5. `totalCents = Double(octaves) × 1200.0 + centOffset(for: interval) + o`
6. `frequency = referencePitch × 2^(totalCents / 1200.0)`

**Why Euclidean mod:** Swift's `%` operator preserves dividend sign (`-7 % 12 == -7`), so we normalize to always-positive remainder. This ensures notes below the reference are decomposed correctly: e.g., D4 (MIDI 62, distance -7) → octaves -1, remainder 5 (perfect fourth) → `-1200 + 498.045 = -701.955` cents — identical to negating the perfect fifth (701.955).

**Equal temperament equivalence:** For equal temperament, `centOffset(for: interval) = interval.semitones × 100`, so `octaves × 1200 + semitones × 100 = totalSemitones × 100`. This is algebraically identical to the current formula `semitones / 12` (since `totalSemitones × 100 / 1200 = totalSemitones / 12`). All existing 12-TET tests pass unchanged.

**Blast radius:** Only `TuningSystemTests.swift` calls `.justIntonation.frequency()`. ComparisonSessionTests and PitchMatchingSessionTests mention `.justIntonation` but only test state reflection, never frequency calculations. No other tests break.

## Implementation Plan

### Tasks

- [ ] Task 1: Add private `totalCentOffset(for:)` method to `TuningSystem`
  - File: `Peach/Core/Audio/TuningSystem.swift`
  - Action: Add a new `private` method below the existing constants block:
    ```swift
    private func totalCentOffset(for note: DetunedMIDINote) -> Double {
        let distance = note.note.rawValue - Self.referenceMIDINote
        let remainder = ((distance % 12) + 12) % 12
        let octaves = (distance - remainder) / 12
        let interval = Interval(rawValue: remainder)!
        return Double(octaves) * 1200.0 + centOffset(for: interval) + note.offset.rawValue
    }
    ```
  - Notes: Uses Euclidean mod to ensure remainder is always 0–11. `Interval(rawValue:)` force-unwrap is safe because 0–11 are all valid `Interval` cases.

- [ ] Task 2: Rewrite `frequency(for: DetunedMIDINote, referencePitch:)` to use `totalCentOffset`
  - File: `Peach/Core/Audio/TuningSystem.swift`
  - Action: Replace the existing method body with:
    ```swift
    func frequency(for note: DetunedMIDINote, referencePitch: Frequency) -> Frequency {
        let cents = totalCentOffset(for: note)
        return Frequency(referencePitch.rawValue * pow(2.0, cents / 1200.0))
    }
    ```
  - Notes: The `frequency(for: MIDINote, ...)` convenience overload delegates to this method and needs no changes.

- [ ] Task 3: Remove unused constants
  - File: `Peach/Core/Audio/TuningSystem.swift`
  - Action: Remove `semitonesPerOctave`, `centsPerSemitone`, and `octaveRatio` constants — they are no longer referenced. Keep `referenceMIDINote` (still used by `totalCentOffset`).

- [ ] Task 4: Rewrite JI frequency tests that pre-bake offsets
  - File: `PeachTests/Core/Audio/TuningSystemTests.swift`
  - Action: Rewrite the three NFR14 tests (lines 276–312) to test correct behavior — pass plain `MIDINote` values (no pre-baked cent offsets) and verify JI frequencies directly:
    - `justIntonationFrequencyMajorThird`: `TuningSystem.justIntonation.frequency(for: MIDINote(73), referencePitch: .concert440)` should produce `440.0 × 5/4 = 550.0 Hz` (within 0.1-cent precision)
    - `justIntonationFrequencyPerfectFifth`: `TuningSystem.justIntonation.frequency(for: MIDINote(76), referencePitch: .concert440)` should produce `440.0 × 3/2 = 660.0 Hz` (within 0.1-cent precision)
    - `justIntonationFrequencyMinorSeventh`: `TuningSystem.justIntonation.frequency(for: MIDINote(79), referencePitch: .concert440)` should produce `440.0 × 9/5 = 792.0 Hz` (within 0.1-cent precision)
  - Notes: Update test descriptions to reflect the new behavior (e.g., "justIntonation produces just major third frequency for MIDINote 4 semitones above A4").

- [ ] Task 5: Add new tests for decomposition edge cases
  - File: `PeachTests/Core/Audio/TuningSystemTests.swift`
  - Action: Add tests covering:
    - **Notes below reference:** `TuningSystem.justIntonation.frequency(for: MIDINote(62), referencePitch: .concert440)` — D4 is 7 semitones below A4; expected Hz = `440.0 / (3/2) = 293.333...` (within 0.1-cent precision)
    - **Multi-octave span:** `TuningSystem.justIntonation.frequency(for: MIDINote(88), referencePitch: .concert440)` — 19 semitones above A4 = 1 octave + perfect fifth; expected Hz = `440.0 × 2 × 3/2 = 1320.0` (within 0.1-cent precision)
    - **Equal temperament unchanged:** `TuningSystem.equalTemperament.frequency(for: MIDINote(76), referencePitch: .concert440)` still produces the 12-TET perfect fifth (`659.255 Hz`)
    - **JI with DetunedMIDINote offset:** `TuningSystem.justIntonation.frequency(for: DetunedMIDINote(note: MIDINote(76), offset: Cents(10)), referencePitch: .concert440)` — JI perfect fifth + 10 cents microtonal offset
  - Notes: Follow existing test patterns — `@Test("behavioral description")`, `async`, 0.1-cent tolerance via `centError < 0.1`.

- [ ] Task 6: Run full test suite
  - Action: Run `bin/test.sh` to confirm all tests pass (existing 12-TET tests unchanged + new/rewritten JI tests green).

### Acceptance Criteria

- [ ] AC 1: Given `TuningSystem.equalTemperament`, when `frequency(for: MIDINote(76), referencePitch: .concert440)` is called, then the result equals the 12-TET perfect fifth (659.255 Hz within 0.01 Hz) — identical to current behavior.
- [ ] AC 2: Given `TuningSystem.justIntonation`, when `frequency(for: MIDINote(76), referencePitch: .concert440)` is called, then the result equals `440.0 × 3/2 = 660.0 Hz` within 0.1-cent precision.
- [ ] AC 3: Given `TuningSystem.justIntonation`, when `frequency(for: MIDINote(73), referencePitch: .concert440)` is called, then the result equals `440.0 × 5/4 = 550.0 Hz` within 0.1-cent precision.
- [ ] AC 4: Given `TuningSystem.justIntonation`, when `frequency(for: MIDINote(62), referencePitch: .concert440)` is called (note below reference), then the result equals `440.0 / (3/2) = 293.333 Hz` within 0.1-cent precision.
- [ ] AC 5: Given `TuningSystem.justIntonation`, when `frequency(for: MIDINote(88), referencePitch: .concert440)` is called (multi-octave span), then the result equals `440.0 × 2 × 3/2 = 1320.0 Hz` within 0.1-cent precision.
- [ ] AC 6: Given `TuningSystem.justIntonation`, when `frequency(for: DetunedMIDINote(note: MIDINote(76), offset: Cents(10)), referencePitch: .concert440)` is called, then the microtonal offset is applied on top of the JI perfect fifth frequency.
- [ ] AC 7: Given `TuningSystem.equalTemperament`, when any existing frequency test is run, then all results are identical to before the change (no regression).
- [ ] AC 8: Given `TuningSystem` of either variant, when `frequency(for: MIDINote(69), referencePitch: .concert440)` is called (reference note itself), then the result is exactly `440.0 Hz`.

## Additional Context

### Dependencies

None. This change is self-contained within `TuningSystem.swift` and its test file. No external libraries, no new types, no changes to other files.

### Testing Strategy

**Unit tests (all in `TuningSystemTests.swift`):**
- Rewrite 3 existing JI frequency tests to remove pre-baked offsets (Task 4)
- Add 4+ new tests for decomposition edge cases: below-reference, multi-octave, equal-temperament-unchanged, JI-with-offset (Task 5)
- Existing 12-TET frequency tests (12+ tests) serve as regression — must pass unchanged

**Full suite gate:**
- Run complete test suite via `bin/test.sh` before commit — all tests must pass

**No integration or manual testing needed** — this is a pure computation fix with no UI or audio session impact.

### Notes

- `centOffset(for:)` gains its first production call site through `totalCentOffset(for:)` — the orphaned method becomes load-bearing
- The `semitonesPerOctave`, `centsPerSemitone`, and `octaveRatio` constants become unused after the rewrite and should be removed to avoid confusion
- The force-unwrap on `Interval(rawValue: remainder)!` is safe by construction: Euclidean mod produces 0–11, and `Interval` has cases for 0–12. A comment explaining this invariant is warranted
- Future tuning systems (e.g., Pythagorean, meantone) only need to add a case to `centOffset(for:)` — the decomposition and frequency bridge work generically
