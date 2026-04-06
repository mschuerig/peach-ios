# Layer 1: Domain Types (`Core/Music/`)

**Status:** discussed  
**Session date:** 2026-04-03

## The "Two-World Architecture"

The central design idea is a strict separation between two worlds:

| World | Represents | Key types | Lives in |
|-------|-----------|-----------|----------|
| **Logical** | Musical identity — "which note, how far apart" | `MIDINote`, `Cents`, `Interval`, `DirectedInterval`, `DetunedMIDINote` | `Core/Music/` |
| **Physical** | What the speaker produces — Hz | `Frequency` | `Core/Music/` |

The **bridge** between them is `TuningSystem.frequency(for:referencePitch:)`. No type in the logical world knows about Hz; no type in the physical world knows about MIDI note numbers. The bridge is always explicit — you must pass a `TuningSystem` and a `referencePitch` every time.

## Type-by-type breakdown

### Foundational value types (the "vocabulary")

- **`MIDINote`** — a position on the 128-note MIDI grid (0–127). Pure index, no tuning knowledge. Has a `name` computed property (`"C4"`, `"A#3"`) and supports `random(in:)` for training.

- **`Frequency`** — a positive Hz value. The *output* of the bridge. Has a `concert440` constant.

- **`Cents`** — a microtonal offset (1/1200 of an octave). The universal "how far off" unit. Used for detuning, difficulty measurement, and profile statistics. Has a `magnitude` helper for absolute distance.

### Musical relationships

- **`Interval`** — semitone distance 0–12 (prime through octave). Raw value = semitone count. Has `abbreviation` (`"P5"`, `"m3"`) and localized `name`. Can compute `between(_:_:)` two MIDINotes.

- **`Direction`** — `.up` or `.down`. Simple enum.

- **`DirectedInterval`** — combines `Interval` + `Direction`. This is what the app uses to express "a perfect fifth up" vs "a perfect fifth down". Has static factories (`.up(.perfectFifth)`, `.down(.majorThird)`) and a `between(_:_:)` factory. Also extends `MIDINote` with `transposed(by:)`.

### The bridge type

- **`DetunedMIDINote`** — a `MIDINote` + `Cents` offset. This is the logical identity of a pitch that isn't exactly on the MIDI grid. Example: "MIDI note 69 detuned by +15 cents". Still logical — no frequency. The convenience init `DetunedMIDINote(note)` creates a zero-offset version.

### The tuning system (the actual bridge)

- **`TuningSystem`** — enum with `.equalTemperament` and `.justIntonation`. The core method is `frequency(for:referencePitch:)` which converts any `DetunedMIDINote` (or `MIDINote`) to Hz. The algorithm:
  1. Compute distance from MIDI note 69 (A4)
  2. Decompose into octaves + remainder (0–11 semitones)
  3. Look up the tuning-system-specific cent value for that remainder interval
  4. Add octave cents + interval cents + microtonal offset
  5. Apply `f = referencePitch * 2^(totalCents/1200)`

  For equal temperament, all intervals are exact multiples of 100 cents. For just intonation, intervals use mathematically pure ratios (e.g., perfect fifth = 701.955 cents instead of 700).

### Audio parameter types

- **`MIDIVelocity`** — 1–127, how hard a note is struck (controls loudness in SoundFont playback).
- **`AmplitudeDB`** — -90 to +12 dB, clamped. Used for volume control.
- **`NoteDuration`** — 0.3–3.0 seconds, clamped. How long a note sustains.

### Support types

- **`NoteRange`** — a validated lower/upper `MIDINote` pair with minimum 12-semitone span. Ensures training note selection always has a reasonable range.
- **`SoundSourceID`** / **`SoundSourceTag`** — protocol + lightweight struct for identifying sound presets (e.g., `"sf2:0:0"` = Grand Piano). Decouples settings storage from the full SoundFont catalog.
- **`Duration+TimeInterval`** — small extension bridging Swift `Duration` to `TimeInterval` for platform APIs.

## Design patterns observed

1. **"No raw primitives" philosophy** — every domain concept gets its own type. You never see a bare `Double` for cents or a bare `Int` for MIDI notes. This makes the compiler catch misuse (can't accidentally pass a cent value where a frequency is expected).

2. **`ExpressibleByIntegerLiteral` / `ExpressibleByFloatLiteral`** — most types conform to these, so you can write `let note: MIDINote = 60` instead of `MIDINote(60)`. Convenience without losing type safety.

3. **`precondition` for invariants** — invalid values crash early at construction rather than propagating silently. `MIDINote` checks 0–127, `Frequency` checks > 0, `NoteRange` checks minimum span.

4. **`clamped(to:)` for user-facing values** — `NoteDuration` and `AmplitudeDB` clamp rather than crashing, because their inputs come from UI sliders.

5. **No framework imports in Core** — none of these files import SwiftUI or UIKit. They are pure Swift value types.

## Observations and questions

1. **`MIDINote.name` — `noteNames` array** (line 21): Re-created on every call. Could be a `private static let`. Minor perf-wise (not a hot path) but cleaner.
2. **`Rhythm*` vs "Timing" naming split**: Types use `RhythmOffset`, `RhythmDirection`, `RhythmOffsetDetection*`, but user-facing UI says "Compare Timing" and code comments say "Timing State", "Timing Feedback". The domain language shifted to "timing" during implementation but the type-level rename never happened. Consider `TimingOffset`/`TimingDirection`.
3. **`MIDINote` missing `a4` constant**: `TuningSystem` references MIDI note 69 (A4) as `private static let referenceMIDINote = 69` — a raw `Int`. Should be `MIDINote.a4` defined on `MIDINote` itself, then used as `MIDINote.a4.rawValue` in `TuningSystem`.
4. **Inconsistent `nonisolated` across value types**: `MIDINote` and `MIDIVelocity` are `nonisolated struct`, but `Cents`, `Frequency`, `AmplitudeDB`, `NoteDuration` only have `nonisolated` on individual members (or not at all). All pure `Sendable` value types should be `nonisolated struct` for consistency. Artifact of fixing compiler errors reactively.
