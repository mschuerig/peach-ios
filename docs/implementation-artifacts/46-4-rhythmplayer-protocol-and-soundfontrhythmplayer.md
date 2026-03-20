# Story 46.4: RhythmPlayer Protocol and SoundFontRhythmPlayer

Status: ready-for-dev

## Story

As a **developer**,
I want a `RhythmPlayer` protocol and `SoundFontRhythmPlayer` implementation,
So that rhythm sessions can play pre-computed patterns through a clean protocol boundary.

## Acceptance Criteria

1. **Given** the `RhythmPlayer` protocol, **when** inspected, **then** it declares `play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle` and `stopAll() async throws`.

2. **Given** the `RhythmPlaybackHandle` protocol, **when** inspected, **then** it declares `stop() async throws` where first call silences audio and subsequent calls are no-ops.

3. **Given** the `RhythmPattern` value type, **when** inspected, **then** it contains `events: [Event]` (each with `sampleOffset: Int64`, `soundSourceID: SoundSourceID`, `velocity: MIDIVelocity`), `sampleRate: Double`, and `totalDuration: Duration`, **and** events use absolute sample offsets from pattern start (no relative deltas).

4. **Given** `SoundFontRhythmPlayer` delegates to `SoundFontEngine`, **when** `play(_:)` is called with a `RhythmPattern`, **then** all pattern events are pre-calculated before playback starts (FR94), **and** events are dispatched on the render thread via the engine's scheduling mechanism.

5. **Given** `SoundFontRhythmPlayer`, **when** it loads percussion sounds, **then** it resolves `SoundSourceID` values through the existing `SoundSourceProvider` pattern (FR95).

6. **Given** `MockRhythmPlayer` and `MockRhythmPlaybackHandle`, **when** created for testing, **then** they are placed in `PeachTests/Mocks/` for use by session tests in later epics.

7. **Given** file locations, **when** files are created, **then** protocols are at `Core/Audio/RhythmPlayer.swift` and `Core/Audio/RhythmPlaybackHandle.swift`; implementations at `Core/Audio/SoundFontRhythmPlayer.swift` and `Core/Audio/SoundFontRhythmPlaybackHandle.swift`.

## Tasks / Subtasks

- [ ] Task 0: Fix `SoundFontLibrary` preset filter and add percussion support (AC: #5)
  - [ ] Add `SF2Preset.percussionBank = 128` named constant and `isPercussion` computed property
  - [ ] Remove the bogus `$0.bank < 120 && $0.program < 120` filter in `SoundFontLibrary.init`
  - [ ] Replace with `allPresets.filter { !$0.isPercussion }` for `melodicPresets` (UI-facing)
  - [ ] Rename `availablePresets` → `melodicPresets` in `SoundFontLibrary` (the `SoundSourceProvider.availableSources` computed property keeps its protocol name, just bridges to `melodicPresets`)
  - [ ] Add `percussionPresets: [SF2Preset]` property (`allPresets.filter { $0.isPercussion }`)
  - [ ] Add `resolvePercussion(_ id: any SoundSourceID) -> SF2Preset?` method
  - [ ] Update `SF2PresetParserTests` if preset count assertion needs adjusting
  - [ ] Verify `SoundFontLibrary` tests and preset stress tests still pass

- [ ] Task 1: Create `RhythmPlaybackHandle` protocol (AC: #2)
  - [ ] Define protocol at `Core/Audio/RhythmPlaybackHandle.swift`
  - [ ] Single method: `func stop() async throws`
  - [ ] Mirrors `PlaybackHandle` but without `adjustFrequency` (rhythm patterns are fixed once playing)

- [ ] Task 2: Create `RhythmPattern` value type (AC: #3)
  - [ ] Define `RhythmPattern` struct at `Core/Audio/RhythmPlayer.swift` (co-located with protocol)
  - [ ] Nested `Event` struct with `sampleOffset: Int64`, `soundSourceID: any SoundSourceID`, `velocity: MIDIVelocity`
  - [ ] Top-level properties: `events: [Event]`, `sampleRate: Double`, `totalDuration: Duration`
  - [ ] Both `RhythmPattern` and `Event` must be `Sendable`
  - [ ] Events use absolute sample offsets from pattern start — no relative deltas

- [ ] Task 3: Create `RhythmPlayer` protocol (AC: #1)
  - [ ] Define protocol at `Core/Audio/RhythmPlayer.swift`
  - [ ] `func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle`
  - [ ] `func stopAll() async throws`

- [ ] Task 4: Add percussion sampler support to `SoundFontEngine` (AC: #4, #5)
  - [ ] Add a second `AVAudioUnitSampler` for percussion to `SoundFontEngine`
  - [ ] Attach and connect the percussion sampler to `engine.mainMixerNode` in `init`
  - [ ] Add `loadPercussionPreset(_ preset: SF2Preset) async throws` method
  - [ ] Define named MIDI constants: `melodicChannel`, `percussionChannel`, `channelMask`, `noteOnBase`, `noteOffBase` (rename existing `channel` to `melodicChannel`)
  - [ ] The render callback must dispatch to the correct sampler based on `midiStatus & channelMask` (`melodicChannel` → melodic sampler, `percussionChannel` → percussion sampler)
  - [ ] Cache the percussion sampler's `scheduleMIDIEventBlock` in `ScheduleData` alongside the existing melodic block
  - [ ] Existing immediate dispatch and melodic scheduling must continue to work unchanged

- [ ] Task 5: Implement `SoundFontRhythmPlaybackHandle` (AC: #2)
  - [ ] Create at `Core/Audio/SoundFontRhythmPlaybackHandle.swift`
  - [ ] Holds reference to `SoundFontEngine`
  - [ ] `stop()` calls `engine.clearSchedule()` and stops all notes — first call silences, subsequent calls are no-ops (track `hasStopped` flag, same pattern as `SoundFontPlaybackHandle`)

- [ ] Task 6: Implement `SoundFontRhythmPlayer` (AC: #4, #5)
  - [ ] Create at `Core/Audio/SoundFontRhythmPlayer.swift`
  - [ ] Init takes `engine: SoundFontEngine` and `library: SoundFontLibrary`
  - [ ] Define `private nonisolated static let percussionNoteOffDuration: Duration = .milliseconds(50)` for note-off delay
  - [ ] `play(_ pattern:)` implementation:
    1. Resolve each event's `SoundSourceID` to an `SF2Preset` via the library
    2. Load the percussion preset if not already loaded
    3. Convert each `RhythmPattern.Event` to a pair of `ScheduledMIDIEvent` (note-on + note-off after `percussionNoteOffDuration`) — domain types → raw `UInt8` on the main thread, using `SoundFontEngine` MIDI constants (`noteOnBase`, `percussionChannel`, etc.)
    4. Call `engine.configureForRhythmScheduling()` for 5ms buffer
    5. Call `engine.scheduleEvents(...)` to load the batch
    6. Return a `SoundFontRhythmPlaybackHandle`
  - [ ] `stopAll()` implementation: clear schedule, restore default buffer duration

- [ ] Task 7: Create `MockRhythmPlayer` and `MockRhythmPlaybackHandle` (AC: #6)
  - [ ] `MockRhythmPlaybackHandle` at `PeachTests/Mocks/MockRhythmPlaybackHandle.swift` — follows mock contract (call counts, error injection, callbacks, reset)
  - [ ] `MockRhythmPlayer` at `PeachTests/Mocks/MockRhythmPlayer.swift` — follows mock contract (playCallCount, stopAllCallCount, lastPattern, shouldThrowError, instantPlayback mode, onPlayCalled/onStopAllCalled callbacks, waitForPlay/waitForStopAll continuations, reset)

- [ ] Task 8: Write tests (AC: #1–#7)
  - [ ] Test: `RhythmPattern` events are stored with absolute sample offsets
  - [ ] Test: `SoundFontRhythmPlayer.play()` converts pattern events to scheduled MIDI events
  - [ ] Test: `SoundFontRhythmPlayer.play()` configures rhythm scheduling on engine
  - [ ] Test: `SoundFontRhythmPlayer.stopAll()` clears schedule and restores buffer
  - [ ] Test: `SoundFontRhythmPlaybackHandle.stop()` is idempotent (second call is no-op)
  - [ ] Test: `MockRhythmPlayer` tracks calls and supports error injection
  - [ ] Test: `MockRhythmPlaybackHandle` tracks calls and supports error injection
  - [ ] Test: existing `SoundFontEngineTests` still pass (no regressions from percussion sampler)

- [ ] Task 9: Verify no regressions (AC: #4)
  - [ ] `bin/build.sh` — zero errors, zero warnings
  - [ ] `bin/test.sh` — full suite passes, zero regressions
  - [ ] All existing `SoundFontEngineTests`, `SoundFontNotePlayerTests`, and `SoundFontPresetStressTests` pass unchanged

## Dev Notes

### This story adds the rhythm playback layer on top of story 46.3's scheduling infrastructure

`SoundFontEngine` already has render-thread scheduling via `AVAudioSourceNode` (story 46.3). This story builds the protocol layer above it: `RhythmPlayer`/`RhythmPlaybackHandle` are to rhythm what `NotePlayer`/`PlaybackHandle` are to pitch. The engine grows percussion support; the rhythm player converts domain-level patterns to raw MIDI events for the render thread.

### Architecture: three-layer audio stack

```
Layer 3 (protocols):  NotePlayer / PlaybackHandle      RhythmPlayer / RhythmPlaybackHandle
Layer 2 (impl):       SoundFontNotePlayer               SoundFontRhythmPlayer
Layer 1 (engine):     SoundFontEngine (shared — one instance, one AVAudioEngine)
```

Both player implementations delegate to the same `SoundFontEngine`. NotePlayer uses immediate dispatch; RhythmPlayer uses scheduled dispatch. They coexist without interference.

### Percussion sampler in SoundFontEngine

The engine currently has one `AVAudioUnitSampler` for melodic sounds. This story adds a second sampler for percussion. Both connect to `engine.mainMixerNode`:

```
AVAudioSourceNode (silence, render clock)
    ↓
AVAudioUnitSampler (melodic) ─────┐
AVAudioUnitSampler (percussion) ──┤
                                  ↓
                          mainMixerNode → output
```

The render callback dispatches MIDI events to the correct sampler based on the MIDI channel encoded in `ScheduledMIDIEvent.midiStatus`. Define named constants on `SoundFontEngine` for all MIDI byte manipulation:

```swift
// On SoundFontEngine — alongside the existing `channel` constant:
// `internal` (default) visibility — SoundFontRhythmPlayer needs these for event construction.
// `channelMask` stays `private` — only used inside the render callback.
nonisolated static let melodicChannel: UInt8 = 0
nonisolated static let percussionChannel: UInt8 = 1
private nonisolated static let channelMask: UInt8 = 0x0F
nonisolated static let noteOnBase: UInt8 = 0x90
nonisolated static let noteOffBase: UInt8 = 0x80
```

The render callback reads `midiStatus & channelMask` and dispatches to the correct sampler's `scheduleMIDIEventBlock`. Store both `AUScheduleMIDIEventBlock` references in `ScheduleData` (the lock-protected struct). This requires no new locking — both blocks are captured at schedule time and read alongside existing data.

Note: the existing `channel` constant (currently `0`) should be renamed to `melodicChannel` for clarity now that a second channel exists.

### Prerequisite: percussion presets in Samples.sf2

Samples.sf2 is hand-assembled in Polyphone. Before this story can produce audible percussion, percussion presets must be added to Samples.sf2 at **bank 128** (the General MIDI percussion bank convention). The MIDI note number selects the specific sound within the drum kit (e.g., GM standard: 37 = side stick, 42 = closed hi-hat, 76 = high wood block).

The code in this story must work correctly whether or not percussion presets are present yet — `SoundFontRhythmPlayer` should handle the case where a `SoundSourceID` cannot be resolved (log a warning, skip the event or throw).

### Fix SoundFontLibrary: remove bogus preset filter

`SoundFontLibrary.init` currently filters presets with `$0.bank < 120 && $0.program < 120`. This threshold is arbitrary and doesn't align with any standard (GM uses bank 0–127 for melodic, bank 128 for percussion, programs 0–127). Since Samples.sf2 is hand-built and contains only intentional presets, the filter serves no purpose and would incorrectly exclude valid presets.

Replace with a clean separation:
- `melodicPresets` (the UI-facing `SoundSourceProvider` list) = all presets **except** bank 128 (percussion)
- Add `percussionPresets: [SF2Preset]` = presets where `bank == 128`
- Add `resolvePercussion(_ id: any SoundSourceID) -> SF2Preset?` that searches `percussionPresets`
- Add `SF2Preset.isPercussion: Bool` computed property (`bank == 128`) — use the named constant `SF2Preset.percussionBank`

```swift
// On SF2Preset:
nonisolated static let percussionBank = 128

var isPercussion: Bool { bank == Self.percussionBank }
```

This keeps all preset resolution in `SoundFontLibrary`. The existing `resolve()` continues to search melodic presets; the new `resolvePercussion()` searches percussion presets. Both use the same `findPreset(rawValue:in:)` helper.

Update the `SF2PresetParserTests` preset count expectation if needed (currently asserts 149 for the raw parser output — this won't change, but the library's `melodicPresets.count` will now be correct for any bank numbering).

### RhythmPattern.Event → ScheduledMIDIEvent conversion

This conversion happens in `SoundFontRhythmPlayer.play()` on the main thread, before scheduling:

```swift
// Named constant for percussion note-off delay:
private nonisolated static let percussionNoteOffDuration: Duration = .milliseconds(50)

// For each RhythmPattern.Event:
// GM percussion: bank 128 selects the drum kit (preset/program);
// the MIDI note number selects the specific sound within that kit
// (e.g., 37 = side stick, 42 = closed hi-hat, 76 = high wood block).
// SoundSourceID encodes both: "sf2:128:<program>" identifies the kit,
// and the player maps each sound to its GM MIDI note number.
let preset = library.resolvePercussion(event.soundSourceID)
let midiNote = preset.percussionMIDINote  // resolved from SoundSourceID → GM note mapping
let noteOn = ScheduledMIDIEvent(
    sampleOffset: event.sampleOffset,
    midiStatus: SoundFontEngine.noteOnBase | SoundFontEngine.percussionChannel,
    midiNote: midiNote,
    velocity: event.velocity.rawValue
)
let noteOffDelaySamples = Int64(pattern.sampleRate * Self.percussionNoteOffDuration.timeInterval)
let noteOff = ScheduledMIDIEvent(
    sampleOffset: event.sampleOffset + noteOffDelaySamples,
    midiStatus: SoundFontEngine.noteOffBase | SoundFontEngine.percussionChannel,
    midiNote: midiNote,
    velocity: 0
)
```

All MIDI status byte construction uses the named constants from `SoundFontEngine` — no hex literals in `SoundFontRhythmPlayer`.

**GM percussion mapping**: In a GM drum kit, the `program` number selects which kit to load on the sampler (e.g., program 0 = Standard Kit). The individual percussion sounds are selected by MIDI note number (e.g., 37 = side stick). The `SoundSourceID` encoding for percussion needs to capture both the kit and the specific sound. The exact encoding scheme (e.g., `"sf2:128:0:37"` for Standard Kit, side stick) is an implementation decision — pick something that extends the existing `"sf2:{bank}:{program}"` format naturally.

### RhythmPlaybackHandle lifecycle

`SoundFontRhythmPlaybackHandle` follows the same pattern as `SoundFontPlaybackHandle`:
- Holds a reference to `SoundFontEngine` (not `SoundFontRhythmPlayer`)
- `stop()` calls `engine.clearSchedule()` then `engine.stopAllNotes(stopPropagationDelay:)` — first call silences, subsequent calls are no-ops
- `hasStopped` flag prevents double-stop
- No `adjustFrequency` — rhythm patterns are immutable once playing

### SoundFontRhythmPlayer does NOT wire into PeachApp yet

This story creates the types and their tests. The composition root wiring (`PeachApp.swift`, `EnvironmentKeys.swift`) happens in a later story when rhythm sessions need the player. Do NOT modify `PeachApp.swift` or `EnvironmentKeys.swift` in this story.

### Mock contract for MockRhythmPlayer

Follow the established mock pattern (see `MockNotePlayer` in `PeachTests/PitchComparison/MockNotePlayer.swift`):

```swift
final class MockRhythmPlayer: RhythmPlayer {
    var playCallCount = 0
    var stopAllCallCount = 0
    var lastPattern: RhythmPattern?
    var playHistory: [RhythmPattern] = []
    var lastHandle: MockRhythmPlaybackHandle?
    var handleHistory: [MockRhythmPlaybackHandle] = []

    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")

    var instantPlayback = true
    var simulatedPlaybackDuration: Duration = .milliseconds(10)

    var onPlayCalled: (() -> Void)?
    var onStopAllCalled: (() -> Void)?

    // Continuation-based wait (same pattern as MockNotePlayer)
    func waitForPlay(minCount: Int = 1) async
    func waitForStopAll() async

    func reset()
}
```

`MockRhythmPlaybackHandle` mirrors `MockPlaybackHandle`:
```swift
final class MockRhythmPlaybackHandle: RhythmPlaybackHandle {
    var stopCallCount = 0
    var shouldThrowError = false
    var errorToThrow: AudioError = .engineStartFailed("Mock error")
    var onStopCalled: (() -> Void)?
    var isStopped: Bool { stopCallCount > 0 }
    func reset()
}
```

### Previous story (46.3) learnings

- `ScheduledMIDIEvent` is `nonisolated` and `Sendable` with raw `UInt8` fields — keep it this way, convert from domain types on the main thread
- `ScheduleData` uses `OSAllocatedUnfairLock` with `withLockIfAvailable` (try-lock) on render thread — extend this with a second `AUScheduleMIDIEventBlock` for percussion
- Pre-allocated buffer capacity is 4096 events — sufficient for rhythm patterns
- `@preconcurrency import AVFoundation` handles non-Sendable AVFAudio types
- `scanSchedule()` is `nonisolated static` — test the dispatch logic deterministically
- `configureForRhythmScheduling()` and `restoreDefaultBufferDuration()` already exist

### Testing approach

- **Unit tests for RhythmPattern**: verify event construction, sampleRate, totalDuration
- **Unit tests for SoundFontRhythmPlayer**: use the real `SoundFontEngine` with `TestSoundFont.makeLibrary()` — verify events are scheduled on the engine after `play()`, cleared after `stopAll()`
- **Unit tests for SoundFontRhythmPlaybackHandle**: verify idempotent stop behavior
- **Mock tests**: verify MockRhythmPlayer and MockRhythmPlaybackHandle track calls correctly and support error injection
- **Regression tests**: run full existing test suite — all SoundFontEngine, SoundFontNotePlayer, and stress tests must pass unchanged
- All tests use Swift Testing (`@Test`, `@Suite`, `#expect`) — never XCTest
- All test functions must be `async`
- Test file: `PeachTests/Core/Audio/SoundFontRhythmPlayerTests.swift`

### What NOT to do

- **Do NOT create `RhythmComparisonSession` or `RhythmMatchingSession`** — those are later epics (48, 49)
- **Do NOT wire into `PeachApp.swift` or `EnvironmentKeys.swift`** — no composition root changes
- **Do NOT modify `NotePlayer`, `PlaybackHandle`, or `SoundFontNotePlayer`** — unchanged
- **Do NOT modify existing `SoundFontPlaybackHandle`** — unchanged
- **Do NOT create a POC/demo screen** — that is story 46.5
- **Do NOT add UI components** — this is a pure audio/protocol layer
- **Do NOT use XCTest** — Swift Testing only
- **Do NOT use Combine** — forbidden
- **Do NOT add explicit `@MainActor`** — redundant with default isolation
- **Do NOT allocate in the render callback** — the percussion sampler's `scheduleMIDIEventBlock` must be captured before entering the render path

### Project Structure Notes

New files:
- `Peach/Core/Audio/RhythmPlayer.swift` — `RhythmPlayer` protocol + `RhythmPattern` value type
- `Peach/Core/Audio/RhythmPlaybackHandle.swift` — `RhythmPlaybackHandle` protocol
- `Peach/Core/Audio/SoundFontRhythmPlayer.swift` — `SoundFontRhythmPlayer` implementation
- `Peach/Core/Audio/SoundFontRhythmPlaybackHandle.swift` — `SoundFontRhythmPlaybackHandle` implementation
- `PeachTests/Core/Audio/SoundFontRhythmPlayerTests.swift` — tests
- `PeachTests/Mocks/MockRhythmPlayer.swift` — mock
- `PeachTests/Mocks/MockRhythmPlaybackHandle.swift` — mock

Modified files:
- `Peach/Core/Audio/SoundFontEngine.swift` — add percussion sampler, MIDI constants, update render callback to dispatch to both samplers, add `loadPercussionPreset()` method
- `Peach/Core/Audio/SoundFontLibrary.swift` — remove bogus `< 120` filter, add `percussionPresets`, `resolvePercussion()`, separate melodic/percussion by GM bank 128 convention
- `Peach/Core/Audio/SF2PresetParser.swift` — add `SF2Preset.percussionBank` constant and `isPercussion` computed property
- `PeachTests/Core/Audio/SF2PresetParserTests.swift` — update preset count assertion if needed, add `isPercussion` test

### References

- [Source: docs/planning-artifacts/epics.md#Epic 46, Story 46.4]
- [Source: docs/planning-artifacts/architecture.md#Layer 3: RhythmPlayer Protocol and Implementation]
- [Source: docs/planning-artifacts/architecture.md#Layer 1: SoundFontEngine — percussion sound management]
- [Source: docs/planning-artifacts/rhythm-training-spec.md#Audio Timing & Playback Model]
- [Source: docs/planning-artifacts/epics.md#FR93, FR94, FR95, FR96]
- [Source: Peach/Core/Audio/SoundFontEngine.swift — engine to extend with percussion]
- [Source: Peach/Core/Audio/NotePlayer.swift — protocol pattern to mirror]
- [Source: Peach/Core/Audio/PlaybackHandle.swift — protocol pattern to mirror]
- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift — handle pattern to mirror]
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift — player pattern to mirror]
- [Source: Peach/Core/Audio/SoundFontLibrary.swift — preset resolution to extend]
- [Source: PeachTests/Mocks/MockPlaybackHandle.swift — mock pattern to follow]
- [Source: PeachTests/PitchComparison/MockNotePlayer.swift — mock pattern to follow]
- [Source: docs/implementation-artifacts/46-3-add-render-thread-scheduling-to-soundfontengine.md — previous story]
- [Source: docs/project-context.md#AVAudioEngine, Testing Rules, Mock Contract]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
