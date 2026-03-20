# Story 46.5: On-Device Rhythm Timing POC

Status: ready-for-dev

## Story

As a **developer testing the architecture**,
I want a temporary demo screen accessible from the Start Screen that plays a pre-computed 4-click rhythm pattern at a fixed tempo,
So that I can verify on real hardware that the three-layer audio architecture delivers audibly tight timing before building sessions on top of it.

## Acceptance Criteria

1. **Given** a temporary "Rhythm POC" button on the Start Screen, **when** tapped, **then** it navigates to a minimal demo screen.

2. **Given** the demo screen, **when** displayed, **then** it shows a "Play Pattern" button and a tempo label (e.g., "120 BPM").

3. **Given** the user taps "Play Pattern", **when** the button is tapped, **then** the system plays 4 percussion clicks at sixteenth-note intervals at 120 BPM using `SoundFontPlayer` (as `RhythmPlayer`), **and** the pattern is pre-computed as a `RhythmPattern` with absolute sample offsets.

4. **Given** the user taps "Play Pattern" again, **when** the previous pattern is still playing, **then** the previous pattern is stopped before the new one starts.

5. **Given** the demo screen, **when** a tempo selector is available (stepper or toggle between 80/120/160 BPM), **then** the user can switch tempos and hear the pattern at different speeds to verify timing at various rates.

6. **Given** this is a temporary POC, **when** rhythm training screens are implemented (Epics 48-49), **then** the POC screen and its Start Screen button are removed.

7. **Given** the POC plays audio, **when** evaluated on a real iPhone, **then** the 4 clicks sound evenly spaced with no audible jitter or drift — confirming the architecture works.

## Tasks / Subtasks

- [ ] Task 1: Expose engine sample rate (AC: #3)
  - [ ] Add `var sampleRate: SampleRate` computed property to `SoundFontEngine` that returns `SampleRate(engine.outputNode.outputFormat(forBus: 0).sampleRate)`
  - [ ] This is needed so the POC (and future rhythm sessions) can build `RhythmPattern` with the correct `sampleRate` matching the audio engine's output

- [ ] Task 2: Create percussion `SoundFontPlayer` instance in `PeachApp.swift` (AC: #3)
  - [ ] Create channel 1 on the existing `SoundFontEngine`: `soundFontEngine.createChannel(SoundFontEngine.ChannelID(1))`
  - [ ] Create a second `SoundFontPlayer` instance for percussion:
    ```swift
    let percussionPlayer: any RhythmPlayer = SoundFontPlayer(
        engine: soundFontEngine,
        preset: soundFontLibrary.percussionPresets.first ?? SF2Preset(name: "", program: 0, bank: SF2Preset.percussionBank),
        channel: SoundFontEngine.ChannelID(1)
    )
    ```
  - [ ] Store as `@State private var rhythmPlayer: any RhythmPlayer`
  - [ ] Inject into environment: add `@Entry var rhythmPlayer: (any RhythmPlayer)?` in `EnvironmentKeys.swift`, set `.environment(\.rhythmPlayer, rhythmPlayer)` in `PeachApp.body`

- [ ] Task 3: Add `rhythmPOC` navigation destination (AC: #1)
  - [ ] Add `case rhythmPOC` to `NavigationDestination` enum in `App/NavigationDestination.swift`
  - [ ] Add routing in `StartScreen.swift`: `.navigationDestination` switch case for `.rhythmPOC` → `RhythmPOCScreen()`

- [ ] Task 4: Add "Rhythm POC" button to Start Screen (AC: #1)
  - [ ] Add a `NavigationLink(value: NavigationDestination.rhythmPOC)` below the existing sections
  - [ ] Style it distinctly (e.g., `.tint(.orange)` or similar) to make it obvious this is temporary
  - [ ] Label: "Rhythm POC" with a `metronome` SF Symbol (or `waveform.path` if metronome unavailable)

- [ ] Task 5: Create `RhythmPOCScreen` (AC: #2, #3, #4, #5)
  - [ ] Create `Peach/RhythmPOC/RhythmPOCScreen.swift`
  - [ ] UI elements:
    - Navigation title: "Rhythm POC"
    - Tempo display showing current BPM
    - Tempo stepper or picker: 80 / 120 / 160 BPM (use `TempoBPM` domain type)
    - "Play Pattern" button
    - Status text showing "Playing..." / "Stopped"
  - [ ] State:
    - `@State private var tempo: TempoBPM = TempoBPM(120)`
    - `@State private var playbackHandle: RhythmPlaybackHandle?`
    - `@State private var isPlaying = false`
  - [ ] Dependencies:
    - `@Environment(\.rhythmPlayer) private var rhythmPlayer`
    - `@Environment(\.soundFontEngine) private var soundFontEngine` (for `sampleRate`)
  - [ ] Play logic:
    ```swift
    // Stop previous if still playing
    try? await playbackHandle?.stop()

    // Build pattern: 4 clicks at sixteenth-note intervals
    let sampleRate = soundFontEngine.sampleRate
    let sixteenthDuration = tempo.sixteenthNoteDuration
    let samplesPerSixteenth = Int64(sampleRate.rawValue * sixteenthDuration.timeInterval)

    let clickNote = MIDINote(76)  // Hi Wood Block (GM percussion)
    let velocity = MIDIVelocity(100)

    let events = (0..<4).map { i in
        RhythmPattern.Event(
            sampleOffset: Int64(i) * samplesPerSixteenth,
            midiNote: clickNote,
            velocity: velocity
        )
    }

    let totalSamples = Int64(3) * samplesPerSixteenth + samplesPerSixteenth
    let pattern = RhythmPattern(
        events: events,
        sampleRate: sampleRate,
        totalDuration: sixteenthDuration * 4
    )

    playbackHandle = try await rhythmPlayer?.play(pattern)
    isPlaying = true

    // Auto-stop after pattern completes
    try? await Task.sleep(for: pattern.totalDuration)
    isPlaying = false
    ```
  - [ ] Handle "Play" while already playing: stop previous handle first (AC #4)

- [ ] Task 6: Inject `SoundFontEngine` into environment for sample rate access (AC: #3)
  - [ ] Add `@Entry var soundFontEngine: SoundFontEngine` in `EnvironmentKeys.swift` — needs a dummy default for previews; consider using a lightweight approach
  - [ ] Alternative: Instead of injecting the engine, inject only the sample rate: `@Entry var audioSampleRate: SampleRate = .standard48000`. Set it from `soundFontEngine.sampleRate` in `PeachApp.body`. This is cleaner — the view doesn't need the engine, just the sample rate
  - [ ] **Preferred approach**: Inject `audioSampleRate` only, not the engine. Views should not have direct engine access (architectural boundary)

- [ ] Task 7: Localization (AC: #2)
  - [ ] Add English + German strings for:
    - "Rhythm POC" (screen title and button label)
    - "Play Pattern" button
    - "%d BPM" tempo label
  - [ ] Use `bin/add-localization.swift` for German translations

- [ ] Task 8: Build and test (AC: #7)
  - [ ] `bin/build.sh` — zero errors, zero warnings
  - [ ] `bin/test.sh` — full suite passes, no regressions
  - [ ] No new tests required (POC is a throwaway screen for on-device verification)

## Dev Notes

### This is a throwaway POC

The entire screen, navigation case, environment key, and Start Screen button are temporary. They will be removed in Epics 48-49 when real rhythm training screens replace them. Write minimal, clean code — but don't over-engineer. No tests needed for the POC screen itself.

### Percussion player wiring in PeachApp

This is the first time a second `SoundFontPlayer` instance is created. It uses channel 1 (the melodic player uses channel 0). The percussion player is typed as `any RhythmPlayer` — the POC screen never sees `SoundFontPlayer` directly.

The second player instance will survive the POC — rhythm sessions in later epics will need it. Only the POC screen and its UI wiring are temporary.

### Pattern construction

Use `TempoBPM.sixteenthNoteDuration` to derive timing — it already returns `Duration`. Convert to sample offsets using `sampleRate.rawValue * duration.timeInterval`.

Four events, absolute sample offsets:
- Event 0: offset 0
- Event 1: offset `1 * samplesPerSixteenth`
- Event 2: offset `2 * samplesPerSixteenth`
- Event 3: offset `3 * samplesPerSixteenth`

`totalDuration` = `4 * sixteenthNoteDuration` (includes decay time for last click).

### GM percussion MIDI note

Use `MIDINote(76)` — Hi Wood Block in General MIDI. Short, percussive, easy to evaluate timing by ear. Alternative: `MIDINote(37)` (Side Stick) if wood block sounds bad on the bundled SF2.

### Sample rate access

Do NOT inject `SoundFontEngine` into the environment. Instead, inject only the sample rate as `@Entry var audioSampleRate: SampleRate = .standard48000`. Set from `soundFontEngine.sampleRate` in `PeachApp.body`. This keeps the architectural boundary — views never access the engine directly.

### Duration.timeInterval

`Duration` has no built-in `.timeInterval` property. A `private extension Duration` with `var timeInterval: Double` already exists in `SoundFontPlayer.swift:171` but is scoped `private` to that file. The POC screen needs the same conversion to compute sample offsets. Options:
1. **Promote the existing extension to `internal`** — move from `private extension` to a file-level `extension` in a shared location (e.g., `Core/Music/Duration+TimeInterval.swift`)
2. **Duplicate as `private` in `RhythmPOCScreen`** — acceptable for a throwaway POC

Option 1 is preferred — future rhythm sessions will also need this conversion.

### What NOT to do

- Do NOT create a `RhythmPOCSession` or state machine — this is a simple button-to-play demo
- Do NOT create a protocol for the POC screen
- Do NOT add the POC screen to `TrainingSession` tracking or `activeSession`
- Do NOT add progress tracking or observers
- Do NOT create tests for the POC screen (it's temporary)
- Do NOT create a `Utils/` or `Helpers/` directory

### File locations

| File | Path | Notes |
|------|------|-------|
| `RhythmPOCScreen` | `Peach/RhythmPOC/RhythmPOCScreen.swift` | New directory for temporary POC |
| `NavigationDestination` | `Peach/App/NavigationDestination.swift` | Add `rhythmPOC` case |
| `EnvironmentKeys` | `Peach/App/EnvironmentKeys.swift` | Add `rhythmPlayer` and `audioSampleRate` entries |
| `PeachApp` | `Peach/App/PeachApp.swift` | Create percussion player, inject environment values |
| `StartScreen` | `Peach/Start/StartScreen.swift` | Add POC button, add navigation destination handler |
| `SoundFontEngine` | `Peach/Core/Audio/SoundFontEngine.swift` | Add `sampleRate` computed property |

### Previous story intelligence

From story 46.4:
- `SoundFontPlayer` already conforms to both `NotePlayer` and `RhythmPlayer`
- Channel 0 is pre-created in `SoundFontEngine.init`; additional channels via `createChannel()`
- `SoundFontPlayer.play(_ pattern:)` handles preset loading, event conversion, and scheduling
- Engine init crash was fixed by reordering attach/connect before `engine.start()` — don't change init order
- Percussion `bankLSB` must be 0 (not 128); `bankMSB=0x78` selects the percussion bank
- `MockRhythmPlayer` and `MockRhythmPlaybackHandle` already exist in `PeachTests/Mocks/`

### References

- [Source: docs/planning-artifacts/epics.md#Story 46.5: On-Device Rhythm Timing POC]
- [Source: docs/implementation-artifacts/46-4-generalized-sampler-architecture.md — previous story with architecture diagram]
- [Source: Peach/Core/Audio/SoundFontPlayer.swift — unified player with RhythmPlayer conformance]
- [Source: Peach/Core/Audio/SoundFontEngine.swift — engine with channel management and render-thread scheduling]
- [Source: Peach/Core/Audio/RhythmPlayer.swift — RhythmPlayer protocol and RhythmPattern type]
- [Source: Peach/Core/Music/TempoBPM.swift — tempo domain type with sixteenthNoteDuration]
- [Source: Peach/Core/Music/SampleRate.swift — sample rate domain type]
- [Source: Peach/Core/Music/MIDINote.swift — MIDI note domain type]
- [Source: Peach/App/PeachApp.swift — composition root where percussion player must be created]
- [Source: Peach/App/NavigationDestination.swift — navigation enum to extend]
- [Source: Peach/Start/StartScreen.swift — start screen to add POC button]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
