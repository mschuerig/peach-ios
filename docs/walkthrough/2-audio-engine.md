# Layer 2: Audio Engine (`Core/Audio/` + `Core/Ports/`)

**Status:** discussed  
**Session date:** 2026-04-03

## Architecture: Ports & Adapters

The audio layer follows a **ports & adapters** (hexagonal) pattern. Protocols live in `Core/Ports/`; implementations live in `Core/Audio/`. The rest of the app only sees the ports.

### The Ports (protocols)

| Protocol | Purpose | Key methods |
|----------|---------|-------------|
| `NotePlayer` | Play a single note | `play(frequency:velocity:amplitudeDB:) → PlaybackHandle`, `play(frequency:duration:velocity:amplitudeDB:)`, `stopAll()` |
| `PlaybackHandle` | Control a currently-playing note | `stop()`, `adjustFrequency(_:)` |
| `BeatSequencer` | Drive a gapless looping `Beat`/`Subdivision` pattern. Used by both rhythm disciplines (Timing Offset Detection and Continuous Rhythm Matching). | `start(tempo:beatProvider:)`, `stop()`, `timing`, `playImmediateNote(velocity:)` |
| `BeatProvider` | Supplies the next `Beat` whenever the sequencer refills its scheduling batch | `nextBeat() → Beat` |
| `SoundSourceProvider` | Discover available instrument sounds | `availableSources` |
| `AudioInterruptionObserving` | React to system audio interruptions | `setupObservers(notificationCenter:onStopRequired:)` |

Key design decisions:
- `NotePlayer` speaks **only in `Frequency`** — no MIDI notes, no tuning systems, no domain concepts
- `PlaybackHandle` enables the pitch matching feature: start a note, then `adjustFrequency()` in real time as the user drags the slider
- The timed `play(frequency:duration:...)` variant is a **protocol extension** in `NotePlayer+TimedPlay.swift` — implemented once, shared by all conformers

### The Adapters (implementations)

The implementation is a **three-layer stack:**

```
SoundFontPlayer / SoundFontBeatSequencer    ← high-level: conforms to NotePlayer / BeatSequencer
        │                    │
        ▼                    ▼
      SoundFontEngine                       ← mid-level: owns AVAudioEngine, manages channels
        │
        ▼
      AVAudioUnitSampler (Apple framework)  ← low-level: SF2 playback
```

#### `SoundFontEngine` — the core audio machine

This is the most complex file in the project (~670 lines). It owns:
- A single `AVAudioEngine` instance (the only one in the entire app)
- Multiple `AVAudioUnitSampler` instances, one per MIDI channel
- A **lock-free double-buffered schedule** for sample-accurate MIDI event dispatch on the real-time audio render thread

**The double-buffer mechanism** (`DoubleBufferedScheduleState`):
- Two event buffer slots, one active (read by the render thread), one inactive (written by the main thread)
- An atomic `generation` counter; active slot = `generation % 2`
- Main thread writes events to the inactive slot, then does an atomic release-store of `generation+1` to swap
- Render thread does an acquire-load of `generation` before reading, ensuring all writes are visible
- This eliminates locks on the real-time audio thread (locks cause audio glitches)

**The render callback** (the `AVAudioSourceNode` closure, lines 265–360):
- Outputs silence (it's a clock, not a sound source)
- On each audio buffer callback: loads generation, detects schedule changes, dispatches MIDI events whose sample offset falls within the current buffer window
- Also drains an **immediate event ring buffer** (SPSC lock-free) for tap/click sounds that need to fire NOW

**Channel management:**
- `ChannelID` wraps a MIDI channel (0–15)
- Channel 0 is pre-created at init for backward compatibility
- Additional channels can be created for multi-voice scenarios (e.g., metronome on a separate channel)

**Preset loading:**
- `loadPreset(_:channel:)` loads an SF2 instrument via `AVAudioUnitSampler.loadSoundBankInstrument()`
- After loading, configures pitch bend range via MIDI RPN messages (±2 semitones)
- Includes a 20ms sleep to let the audio graph settle (empirically necessary)

#### `SoundFontPlayer` — melodic note playback

Conforms to `NotePlayer`. Relatively thin wrapper around `SoundFontEngine`:
- `play(frequency:...)`: decomposes `Frequency` into nearest MIDI note + cent remainder (12-TET, A4=440), starts the note with a pitch bend to hit the exact frequency
- Returns a `SoundFontPlaybackHandle` for ongoing control
- `stopAll()`: clears schedule + stops notes with a fade-out delay

**`decompose(frequency:)`** (line 150): The inverse bridge — goes from Hz back to MIDI note + cents. Always uses 12-TET regardless of the user's tuning system, because MIDI pitch bend is a 12-TET concept.

**`pitchBendValue(forCents:)`** (line 140): Converts a cent offset to a 14-bit MIDI pitch bend value (0–16383, center=8192).

#### `SoundFontPlaybackHandle` — live note control

Returned from `play()`. Supports:
- `stop()`: mute → wait for propagation → note-off → reset pitch bend
- `adjustFrequency(_:)`: recalculates pitch bend for the new frequency (used during pitch matching slider drag)

The stop propagation delay (25ms) prevents click/pop artifacts by muting before sending note-off.

#### `SoundFontBeatSequencer` — gapless looped beat playback

`@Observable` class conforming to `BeatSequencer`. Drives a gapless loop where each cycle is a `Beat` (an array of `Subdivision` cases — `.rest`, `.note(velocity:offset:)` with a signed `Duration` offset, or `.nested(Beat)`). Used by both rhythm disciplines:
- **Timing Offset Detection** keeps a 4-sixteenth test pattern in phase across an arbitrary repetition count; the offset rides on the third subdivision.
- **Continuous Rhythm Matching** loops a 4-subdivision beat with one gap, and the session decides where the gap falls.

Mechanics:
- Pulls each next beat from a `BeatProvider` (the session itself, in both disciplines) when refilling the schedule. Pre-schedules batches of 500 beats so the playback never sees the seam between batches.
- Exposes a `timing` view (`samplePosition`, `samplesPerBeat`) so the session can derive per-subdivision UI state and detect cycle boundaries from sample position alone.
- Runs a polling loop (~120 Hz) that publishes `currentBeat` for `@Observable` subscribers.
- Supports "immediate" notes (user taps) via the engine's lock-free ring buffer path.

#### `SoundFontLibrary` — instrument discovery

Parses the bundled SF2 file at startup via `SF2PresetParser`, filters out unpitched presets (bank ≥ 120, program ≥ 120), sorts alphabetically. Conforms to `SoundSourceProvider`.

#### `SF2PresetParser` — binary SF2 file parser

A stateless `enum` that reads the RIFF structure of an SF2 (SoundFont 2) file:
1. Validates RIFF header and "sfbk" form type
2. Walks chunks to find the "pdta" LIST chunk
3. Within pdta, finds the "phdr" sub-chunk
4. Parses 38-byte PHDR records (preset name + program + bank)
5. Returns `[SF2Preset]`

Pure Swift, no dependencies — hand-rolled binary parsing.

#### `AudioSessionInterruptionMonitor` — lifecycle safety

Listens for audio interruptions (phone calls, Siri), backgrounding, and foregrounding. Calls `onStopRequired` to stop the active training session. Platform-specific observers injected via `AudioInterruptionObserving` protocol.

### Supporting types

- **`AudioError`** — typed error enum: `engineStartFailed`, `invalidFrequency`, `invalidDuration`, `invalidPreset`, `contextUnavailable`, `invalidInterval`
- **`SF2Preset`** — value type conforming to `SoundSourceID`. Identity is `(bank, program)` — name is just display.
- **`ScheduledMIDIEvent`** — raw MIDI bytes + sample offset for render-thread dispatch
- **`SequencerTypes`** — `Beat`, `Subdivision`, `BeatProvider`, `SequencerTiming`, `RhythmVelocity`

## Files to read (suggested order)

1. `Core/Ports/NotePlayer.swift` — the protocol everything depends on
2. `Core/Ports/PlaybackHandle.swift` — the handle returned by play()
3. `Core/Audio/NotePlayer+TimedPlay.swift` — elegant protocol extension
4. `Core/Audio/SoundFontPlayer.swift` — the NotePlayer implementation
5. `Core/Audio/SoundFontPlaybackHandle.swift` — live note control
6. `Core/Audio/SoundFontEngine.swift` — the big one; read top-to-bottom
7. `Core/Audio/SF2PresetParser.swift` — binary parsing, surprisingly readable
8. `Core/Audio/SoundFontLibrary.swift` — preset discovery
9. `Core/Audio/SequencerTypes.swift` — `Beat` / `Subdivision` / `BeatProvider` / `SequencerTiming` and `Beat.events(...)` compilation
10. `Core/Ports/BeatSequencer.swift` + `Core/Audio/SoundFontBeatSequencer.swift` — beat sequencer shared by both rhythm disciplines
11. `Core/Audio/AudioSessionInterruptionMonitor.swift` — lifecycle safety

## Observations and questions

1. **`SoundFontPlayer.decompose()` redeclares domain constants**: Lines 153–157 define local constants (`referenceMIDINote = 69`, `concert440 = 440.0`, `midiRange = 0...127`, `semitonesPerOctave = 12.0`, `centsPerSemitone = 100.0`) that all duplicate existing domain type members (`MIDINote.a4` (to be added), `Frequency.concert440`, `MIDINote.validRange`, `Interval.octave.semitones`). Only `centsPerSemitone` is missing — add `Cents.perSemitone = 100.0`.
2. **`SoundFontEngine.ChannelID` duplicates `MIDIChannel`**: Nested struct in `SoundFontEngine` is identical to `MIDIChannel` in `Core/Music/` — same `UInt8`, same `0...15` range, same precondition. `ChannelID` predates `MIDIChannel` (added for MIDI input). Mechanical rename to unify.
3. **`SoundFontEngine.init()` is 133 lines**: The render callback closure alone is ~95 lines nested inside init. Should be extracted to a static method (it already captures only `shared` and `Self` constants). `createChannel()` and `scheduleEvents()` also share a "write to inactive slot, copy MIDI blocks, bump generation" pattern that could be extracted into a shared helper.
4. **`SoundFontPlayer.pitchBendValue(forCents:)` duplicates clamping**: Line 143 manually clamps to `0...16383` with `Swift.min/max`, but `PitchBendValue` already defines `validRange` and `precondition`s in its init. The magic numbers duplicate the type's knowledge. Fix: add a clamping initializer to `PitchBendValue` (matching the pattern of `AmplitudeDB`/`NoteDuration`).
5. **`SoundFontBeatSequencer.buildBatch` is testable in isolation**: Implementation detail rather than a port. Tests should exercise the public surface (`start()`/`stop()`/`timing`) via a `SequencerEngine` mock and let `buildBatch` stay private; testing the batch shape directly couples tests to the scheduling internals.
