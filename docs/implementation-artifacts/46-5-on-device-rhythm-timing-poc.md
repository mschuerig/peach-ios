# Story 46.5: On-Device Rhythm Timing POC

Status: review

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

- [x] Task 1: Expose engine sample rate (AC: #3)
  - [x] Add `var sampleRate: SampleRate` computed property to `SoundFontEngine` that returns `SampleRate(engine.outputNode.outputFormat(forBus: 0).sampleRate)`
  - [x] This is needed so the POC (and future rhythm sessions) can build `RhythmPattern` with the correct `sampleRate` matching the audio engine's output

- [x] Task 2: Create percussion `SoundFontPlayer` instance in `PeachApp.swift` (AC: #3)
  - [x] Create channel 1 on the existing `SoundFontEngine`: `soundFontEngine.createChannel(SoundFontEngine.ChannelID(1))`
  - [x] Create a second `SoundFontPlayer` instance for percussion
  - [x] Store as `@State private var rhythmPlayer: any RhythmPlayer`
  - [x] Inject into environment: add `@Entry var rhythmPlayer: (any RhythmPlayer)?` in `EnvironmentKeys.swift`, set `.environment(\.rhythmPlayer, rhythmPlayer)` in `PeachApp.body`

- [x] Task 3: Add `rhythmPOC` navigation destination (AC: #1)
  - [x] Add `case rhythmPOC` to `NavigationDestination` enum in `App/NavigationDestination.swift`
  - [x] Add routing in `StartScreen.swift`: `.navigationDestination` switch case for `.rhythmPOC` → `RhythmPOCScreen()`

- [x] Task 4: Add "Rhythm POC" button to Start Screen (AC: #1)
  - [x] Add a `NavigationLink(value: NavigationDestination.rhythmPOC)` below the existing sections
  - [x] Style it distinctly (orange background with border) to make it obvious this is temporary
  - [x] Label: "Rhythm POC" with a `metronome` SF Symbol

- [x] Task 5: Create `RhythmPOCScreen` (AC: #2, #3, #4, #5)
  - [x] Create `Peach/RhythmPOC/RhythmPOCScreen.swift`
  - [x] UI elements: navigation title, tempo display, segmented picker (80/120/160 BPM), play button, status text
  - [x] State: `tempo`, `playbackHandle`, `isPlaying`
  - [x] Dependencies: `@Environment(\.rhythmPlayer)`, `@Environment(\.audioSampleRate)`
  - [x] Play logic: builds 4-click RhythmPattern with sample-accurate offsets, plays via RhythmPlayer
  - [x] Handle "Play" while already playing: stop previous handle first (AC #4)

- [x] Task 6: Inject `SoundFontEngine` into environment for sample rate access (AC: #3)
  - [x] **Preferred approach used**: Inject `audioSampleRate` only, not the engine. Views don't have direct engine access (architectural boundary)
  - [x] Added `@Entry var audioSampleRate: SampleRate = .standard48000` in `EnvironmentKeys.swift`
  - [x] Set from `soundFontEngine.sampleRate` in `PeachApp.body`

- [x] Task 7: Localization (AC: #2)
  - [x] Added English + German strings: "Rhythm POC", "Play Pattern", "Playing...", "Stopped", "Tempo"
  - [x] Used `bin/add-localization.swift` for German translations

- [x] Task 8: Build and test (AC: #7)
  - [x] `bin/build.sh` — zero errors, zero warnings (only pre-existing AppIntents warning)
  - [x] `bin/test.sh` — full suite passes (1173 tests), no regressions
  - [x] No new tests required (POC is a throwaway screen for on-device verification)

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

Claude Opus 4.6

### Debug Log References

- **Growing MIDI latency bug**: `AUScheduleMIDIEventBlock` with absolute `hostSampleTime` caused stale events to accumulate in the sampler's internal queue. Source node and sampler render in engine-determined order — when the source node fires after the sampler in a cycle, events targeting the current buffer's sample time are "past" for the sampler and queue up indefinitely.
- **Fix**: Switched to `AUEventSampleTimeImmediate + intraBufferOffset` (relative "now" timestamps) and added `auAudioUnit.reset()` before each schedule to flush stale events.
- **IO buffer toggling removed**: Per-play `configureForRhythmScheduling`/`restoreDefaultBufferDuration` calls were disrupting the render pipeline. Set 5ms buffer once in `SoundFontEngine.init` instead.

### Completion Notes List

- Added `sampleRate` computed property to `SoundFontEngine` for audio engine sample rate access
- Promoted `Duration.timeInterval` extension from private (in SoundFontPlayer) to internal shared extension in `Core/Music/Duration+TimeInterval.swift` — needed by POC and future rhythm sessions
- Created percussion `SoundFontPlayer` on channel 1 in `PeachApp.init`, typed as `any RhythmPlayer`
- Injected `rhythmPlayer` and `audioSampleRate` into SwiftUI environment (preferred approach: sample rate only, not engine)
- Added `rhythmPOC` navigation destination and orange-styled temporary button on Start Screen
- Created `RhythmPOCScreen` with segmented tempo picker (80/120/160 BPM), play button, and status indicator
- Pattern construction: 4 Hi Wood Block (MIDI 76) clicks at sixteenth-note intervals using sample-accurate offsets
- Previous playback is stopped before starting new pattern (AC #4)
- Added 5 German translations via `bin/add-localization.swift`
- Fixed render-thread MIDI scheduling: `AUEventSampleTimeImmediate` + sampler reset eliminates accumulated latency
- Removed per-play IO buffer toggling; set 5ms low-latency buffer once at engine init
- Removed dead `configureForRhythmScheduling`/`restoreDefaultBufferDuration` methods from engine
- Updated SF2 preset count test (149 → 150) for new percussion preset
- Build: zero errors. Tests: 1173 passed, zero failures. On-device timing verified: no audible jitter.

### Change Log

- 2026-03-20: Implemented story 46.5 — On-Device Rhythm Timing POC
- 2026-03-20: Fixed render-thread MIDI scheduling latency (AUEventSampleTimeImmediate + sampler reset)

### File List

- `Peach/Core/Audio/SoundFontEngine.swift` — added `sampleRate`, fixed MIDI dispatch to use `AUEventSampleTimeImmediate`, added sampler reset in `scheduleEvents`, set 5ms buffer at init, removed `configureForRhythmScheduling`/`restoreDefaultBufferDuration`
- `Peach/Core/Audio/SoundFontPlayer.swift` — removed private `Duration.timeInterval` extension, removed buffer duration calls from `play`/`stopAll`
- `Peach/Core/Audio/SoundFontRhythmPlaybackHandle.swift` — removed `restoreDefaultBufferDuration` from `stop()`
- `Peach/Core/Audio/RhythmPlayer.swift` — protocol (unchanged from story 46.4)
- `Peach/Core/Music/Duration+TimeInterval.swift` — **new** shared `Duration.timeInterval` extension
- `Peach/RhythmPOC/RhythmPOCScreen.swift` — **new** temporary POC screen
- `Peach/App/NavigationDestination.swift` — added `rhythmPOC` case
- `Peach/App/EnvironmentKeys.swift` — added `rhythmPlayer` and `audioSampleRate` entries
- `Peach/App/PeachApp.swift` — created percussion player on channel 1, injected environment values
- `Peach/Start/StartScreen.swift` — added Rhythm POC button and navigation destination handler
- `Peach/Resources/Localizable.xcstrings` — added 5 German translations
- `PeachTests/Core/Audio/SF2PresetParserTests.swift` — updated preset count (149 → 150)
- `PeachTests/Mocks/MockRhythmPlayer.swift` — kept in sync with protocol
