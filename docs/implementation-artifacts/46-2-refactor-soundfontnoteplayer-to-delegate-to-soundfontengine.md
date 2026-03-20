# Story 46.2: Refactor SoundFontNotePlayer to Delegate to SoundFontEngine

Status: ready-for-dev

## Story

As a **developer**,
I want `SoundFontNotePlayer` to delegate to `SoundFontEngine` instead of owning `AVAudioEngine` directly,
So that pitch training continues to work identically while sharing the engine with future rhythm playback.

## Acceptance Criteria

1. **Given** `SoundFontNotePlayer` is refactored, **when** it receives a `SoundFontEngine` dependency, **then** it delegates all MIDI dispatch to the engine's immediate dispatch methods.

2. **Given** the `NotePlayer` protocol, **when** inspected after refactoring, **then** it is completely unchanged — no API changes.

3. **Given** the `PlaybackHandle` protocol and `SoundFontPlaybackHandle`, **when** inspected after refactoring, **then** `SoundFontPlaybackHandle` uses the engine's immediate dispatch but its public interface is unchanged.

4. **Given** all existing pitch comparison and pitch matching tests, **when** run after refactoring, **then** all tests pass without modification — no behavioral changes.

## Tasks / Subtasks

- [ ] Task 1: Refactor `SoundFontNotePlayer` to accept and delegate to `SoundFontEngine` (AC: #1, #2)
  - [ ] Change `init` to accept `SoundFontEngine` instead of creating `AVAudioEngine`/`AVAudioUnitSampler`
  - [ ] Remove `engine: AVAudioEngine`, `sampler: AVAudioUnitSampler`, `loadedProgram`, `loadedBank`, `isSessionConfigured` properties
  - [ ] Add `private let soundFontEngine: SoundFontEngine` property
  - [ ] Delegate `play()` MIDI dispatch to `soundFontEngine.startNote(_:velocity:amplitudeDB:pitchBend:)`
  - [ ] Delegate `stopAll()` to `soundFontEngine.stopAllNotes(stopPropagationDelay:)`
  - [ ] Delegate `loadPreset(program:bank:)` to `soundFontEngine.loadPreset(_:)` using `SF2Preset`
  - [ ] Delegate `ensureAudioSessionConfigured()` to `soundFontEngine.ensureAudioSessionConfigured()`
  - [ ] Delegate `ensureEngineRunning()` to `soundFontEngine.ensureEngineRunning()`
  - [ ] Remove `sendPitchBendRange()` (engine handles this in init and after preset load)
  - [ ] Keep `ensurePresetLoaded()`, `validateFrequency(_:)`, `decompose(frequency:)`, `pitchBendValue(forCents:)` in `SoundFontNotePlayer`

- [ ] Task 2: Refactor `SoundFontPlaybackHandle` to use `SoundFontEngine` dispatch (AC: #3)
  - [ ] Replace `sampler: AVAudioUnitSampler` + `channel: UInt8` with `engine: SoundFontEngine`
  - [ ] Replace `midiNote: UInt8` with `midiNote: MIDINote`
  - [ ] `stop()`: delegate to `engine.stopNote(_:)` and `engine.sendPitchBend(.center)` with volume fade via `engine.sampler`
  - [ ] `adjustFrequency(_:)`: use `engine.sendPitchBend(_:)` instead of direct `sampler.sendPitchBend`
  - [ ] Update references to `SoundFontNotePlayer.pitchBendCenter` to use `PitchBendValue.center`
  - [ ] Update references to `SoundFontNotePlayer.pitchBendRangeCents` to use `SoundFontEngine.pitchBendRangeCents`
  - [ ] Update `SoundFontNotePlayer.pitchBendValue(forCents:)` calls to return `PitchBendValue` domain type

- [ ] Task 3: Update `PeachApp.swift` composition root (AC: #1)
  - [ ] Create `SoundFontEngine` first: `let engine = try SoundFontEngine(library: soundFontLibrary, preset: initialPreset)`
  - [ ] Pass engine to `SoundFontNotePlayer`: update init call to use new signature
  - [ ] Resolve initial preset from `userSettings.soundSource` via `soundFontLibrary.resolve()`

- [ ] Task 4: Verify all tests pass without modification (AC: #4)
  - [ ] `bin/build.sh` — zero errors, zero warnings
  - [ ] `bin/test.sh` — full suite passes, zero regressions
  - [ ] No existing test files modified

## Dev Notes

### This is a delegation refactoring — behavior is 100% unchanged

`SoundFontNotePlayer` currently owns `AVAudioEngine` and `AVAudioUnitSampler` directly. After this story, it holds a reference to `SoundFontEngine` and delegates all audio hardware operations through it. The `NotePlayer` and `PlaybackHandle` protocols are unchanged. All 66 `SoundFontNotePlayerTests` must continue to pass without modification.

### Current SoundFontNotePlayer init signature

```swift
init(library: SoundFontLibrary, userSettings: UserSettings, stopPropagationDelay: Duration = .milliseconds(25)) throws
```

### New SoundFontNotePlayer init signature

```swift
init(engine: SoundFontEngine, library: SoundFontLibrary, userSettings: UserSettings, stopPropagationDelay: Duration = .milliseconds(25))
```

Key change: accepts a `SoundFontEngine` instead of creating one. No longer `throws` from init (engine creation is the caller's responsibility). The `library` dependency remains because `ensurePresetLoaded()` needs it to resolve `userSettings.soundSource`.

### What moves out of SoundFontNotePlayer

| Removed property/method | Replacement |
|--------------------------|-------------|
| `private let engine: AVAudioEngine` | `soundFontEngine` (delegates) |
| `private let sampler: AVAudioUnitSampler` | `soundFontEngine.sampler` or engine dispatch methods |
| `private var isSessionConfigured: Bool` | `soundFontEngine.ensureAudioSessionConfigured()` (idempotent) |
| `private var loadedProgram: Int` | Engine tracks loaded preset internally |
| `private var loadedBank: Int` | Engine tracks loaded preset internally |
| `ensureAudioSessionConfigured()` | `soundFontEngine.ensureAudioSessionConfigured()` |
| `ensureEngineRunning()` | `soundFontEngine.ensureEngineRunning()` |
| `sendPitchBendRange()` | Engine handles in init + after preset load |
| `loadPreset(program:bank:)` body | `soundFontEngine.loadPreset(SF2Preset(...))` |

### What stays in SoundFontNotePlayer

| Member | Reason |
|--------|--------|
| `play(frequency:velocity:amplitudeDB:) -> PlaybackHandle` | NotePlayer protocol |
| `stopAll()` | NotePlayer protocol — delegates to engine |
| `ensurePresetLoaded()` | Resolves `userSettings.soundSource` via library |
| `validateFrequency(_:)` | Domain validation |
| `startNote(frequency:velocity:amplitudeDB:) -> MIDINote` | Frequency decomposition + calls engine dispatch |
| `decompose(frequency:)` | Static helper: Hz -> MIDI + cents |
| `pitchBendValue(forCents:)` | Static helper: cents -> pitch bend value |
| `validFrequencyRange` | Domain constant |
| `stopPropagationDelay` | Passed to engine's `stopAllNotes` |

### SoundFontPlaybackHandle refactoring

Current init:
```swift
init(sampler: AVAudioUnitSampler, midiNote: UInt8, channel: UInt8, stopPropagationDelay: Duration)
```

New init:
```swift
init(engine: SoundFontEngine, midiNote: MIDINote, stopPropagationDelay: Duration)
```

Changes:
- Replaces `sampler` + `channel` with `engine` (engine encapsulates channel as private detail)
- Uses `MIDINote` domain type instead of raw `UInt8`
- `stop()` uses `engine.stopNote(_:)` + `engine.sendPitchBend(.center)` + volume fade via `engine.sampler`
- `adjustFrequency(_:)` uses `engine.sendPitchBend(_:)` instead of direct sampler calls
- References to `SoundFontNotePlayer.pitchBendCenter` replaced with `PitchBendValue.center`
- References to `SoundFontNotePlayer.pitchBendRangeCents` replaced with `SoundFontEngine.pitchBendRangeCents`

### PeachApp.swift composition root changes

Current wiring:
```swift
let notePlayer: any NotePlayer = try SoundFontNotePlayer(
    library: soundFontLibrary,
    userSettings: userSettings,
    stopPropagationDelay: .zero
)
```

New wiring:
```swift
let initialPreset = soundFontLibrary.resolve(userSettings.soundSource)
let soundFontEngine = try SoundFontEngine(library: soundFontLibrary, preset: initialPreset)
let notePlayer: any NotePlayer = SoundFontNotePlayer(
    engine: soundFontEngine,
    library: soundFontLibrary,
    userSettings: userSettings,
    stopPropagationDelay: .zero
)
```

The `SoundFontEngine` instance will later be shared with `SoundFontRhythmPlayer` (story 46.4). For now, only `SoundFontNotePlayer` uses it.

### SoundFontNotePlayerTests — no modifications allowed

All 66 existing tests in `SoundFontNotePlayerTests.swift` must pass without changes. The `makePlayer()` factory currently does:
```swift
try SoundFontNotePlayer(library: Self.testLibrary, userSettings: userSettings)
```

After refactoring, this needs updating to create a `SoundFontEngine` first:
```swift
let engine = try SoundFontEngine(library: Self.testLibrary, preset: Self.testLibrary.resolve(userSettings.soundSource))
return SoundFontNotePlayer(engine: engine, library: Self.testLibrary, userSettings: userSettings)
```

This is a factory-level change, not a test logic change — the tests themselves remain identical. The assertion: "all tests pass without modification" means no test assertions or test method bodies change. The helper factory adapts to the new init signature.

### pitchBendValue(forCents:) return type consideration

Currently `SoundFontNotePlayer.pitchBendValue(forCents:)` returns `UInt16`. After this story, it should return `PitchBendValue` to align with the domain type created in 46.1. This is a natural part of the delegation refactoring — `SoundFontPlaybackHandle.adjustFrequency()` calls this method and passes the result to `engine.sendPitchBend(_:)` which expects `PitchBendValue`.

### Constants cleanup

After delegation, these `SoundFontNotePlayer` constants become unused and should be removed:
- `channel: UInt8 = 0` — engine handles channel internally
- `defaultBankMSB: UInt8 = 0x79` — engine handles bank MSB internally
- `pitchBendCenter: UInt16 = 8192` — replaced by `PitchBendValue.center`

These should remain (still used in `SoundFontNotePlayer`'s static helpers):
- `pitchBendRangeSemitones` — but now read from `SoundFontEngine.pitchBendRangeSemitones`
- `pitchBendRangeCents` — but now read from `SoundFontEngine.pitchBendRangeCents`
- `validFrequencyRange` — domain validation, stays

If `pitchBendValue(forCents:)` is updated to use `SoundFontEngine.pitchBendRangeCents` and `PitchBendValue.center`, then `pitchBendRangeSemitones`, `pitchBendRangeCents`, and `pitchBendCenter` can all be removed from `SoundFontNotePlayer`.

### Anti-patterns to avoid

- **Do NOT change `NotePlayer` protocol** — it is unchanged
- **Do NOT change `PlaybackHandle` protocol** — it is unchanged
- **Do NOT modify test assertions** — only factory helpers adapt to new init
- **Do NOT create a second `AVAudioEngine`** — the whole point is single engine ownership
- **Do NOT add render-thread scheduling** — that is story 46.3
- **Do NOT add percussion support** — that is story 46.4
- **Do NOT use XCTest** — Swift Testing only
- **Do NOT add explicit `@MainActor`** — redundant with default isolation
- **Do NOT add `import Combine`** — forbidden
- **Do NOT modify `SoundFontEngine`** — it was completed in 46.1; this story only changes its consumers

### Previous story (46.1) learnings

- `SoundFontEngine` uses `SF2Preset` domain type for preset loading (not raw `program: Int, bank: Int`)
- `SoundFontEngine.sampler` is exposed as read-only `let` — available for volume fade in `stopAllNotes` and `SoundFontPlaybackHandle`
- `PitchBendValue` domain type exists at `Core/Music/PitchBendValue.swift` with `.center` constant (8192)
- Engine's `startNote` takes `MIDINote`, `MIDIVelocity`, `AmplitudeDB`, `PitchBendValue` — all domain types
- Engine's `stopNote` takes `MIDINote`
- Engine's `stopAllNotes` takes `stopPropagationDelay: Duration`
- Engine's `loadPreset` takes `SF2Preset` (validates range, skip-if-same, sends pitch bend range RPN)
- Engine's `ensureAudioSessionConfigured()` is idempotent (no flag tracking)
- Engine's `ensureEngineRunning()` checks `engine.isRunning` and restarts if needed
- MIDI channel is a `private` constant in `SoundFontEngine` — not exposed to consumers

### Project Structure Notes

Modified files:
- `Peach/Core/Audio/SoundFontNotePlayer.swift` — remove audio graph ownership, delegate to engine
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — use engine dispatch instead of direct sampler
- `Peach/App/PeachApp.swift` — create `SoundFontEngine`, pass to `SoundFontNotePlayer`
- `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` — update `makePlayer()` factory only

No new files created.

### References

- [Source: docs/planning-artifacts/epics.md#Epic 46, Story 46.2]
- [Source: docs/planning-artifacts/architecture.md#Layer 2: SoundFontNotePlayer Refactoring]
- [Source: docs/project-context.md#AVAudioEngine — SoundFontNotePlayer ownership]
- [Source: docs/project-context.md#Composition Root (PeachApp.swift)]
- [Source: Peach/Core/Audio/SoundFontEngine.swift — engine to delegate to]
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift — current implementation to refactor]
- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift — current implementation to refactor]
- [Source: Peach/App/PeachApp.swift — composition root to update]
- [Source: Peach/Core/Music/PitchBendValue.swift — domain type for pitch bend values]
- [Source: docs/implementation-artifacts/46-1-extract-soundfontengine-from-soundfontnoteplayer.md — previous story]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
