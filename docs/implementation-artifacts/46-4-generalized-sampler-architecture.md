# Story 46.4: Unified SoundFontPlayer with Generalized Sampler Channels

Status: review

## Story

As a **developer**,
I want a single `SoundFontPlayer` class that supports both immediate and scheduled dispatch on any engine channel,
So that pitched playback and rhythm playback use the same player type — just separate instances configured for different channels and presets — eliminating code duplication and making new sound sources trivial to add.

## Context: Why This Replaces the Previous 46.4

The previous 46.4 implementation created two separate player types (`SoundFontNotePlayer` for pitched sounds, `SoundFontRhythmPlayer` for percussion) and hardcoded two samplers in `SoundFontEngine`. This duplicated:

- Preset loading logic (one method per sampler)
- Engine lifecycle management (ensureRunning, ensureConfigured)
- MIDI dispatch routing (hardcoded if/else in render callback)
- The player pattern itself (both hold engine + library, convert domain types to MIDI)

The root cause: the engine and player layer both encoded the melodic/percussion distinction. The timing and control mode (immediate vs. scheduled) was conflated with sound type. In reality, these are orthogonal: any sampler channel can do either dispatch mode. A melodic channel could schedule a pattern; a percussion channel could fire an immediate note.

**This story replaces the previous 46.4 with:**
1. A generalized `SoundFontEngine` that manages N sampler channels
2. A unified `SoundFontPlayer` that replaces `SoundFontNotePlayer` and provides both dispatch modes
3. `RhythmPlayer` protocol + `RhythmPattern` + `RhythmPlaybackHandle` as the rhythm-facing interface
4. `SoundFontPlayer` conforms to both `NotePlayer` and `RhythmPlayer`

Two instances of `SoundFontPlayer` — one on a melodic channel, one on a percussion channel — replace the two separate classes.

**Cleanup:** The previous 46.4 story file (`46-4-rhythmplayer-protocol-and-soundfontrhythmplayer.md`) must be deleted as part of this work. All uncommitted changes from that implementation must be reverted. The sprint-status entry for `46-4-rhythmplayer-protocol-and-soundfontrhythmplayer` must be renamed to match this story.

## Acceptance Criteria

### Engine generalization

1. **Given** `SoundFontEngine`, **when** a consumer calls `createChannel(_:)`, **then** the engine creates, attaches, and connects a new `AVAudioUnitSampler` identified by a `ChannelID`, **and** registers its `AUScheduleMIDIEventBlock` for scheduled dispatch.

2. **Given** a `ChannelID`, **when** `loadPreset(_:channel:)` is called, **then** the correct sampler loads the `SF2Preset` using `SF2Preset.melodicBankMSB` or `SF2Preset.percussionBankMSB` (derived automatically from the preset's bank), **and** no other channel is affected.

3. **Given** scheduled MIDI events, **when** the render callback processes them, **then** each event dispatches to the sampler whose channel matches `midiStatus & channelMask`, using a channel-indexed lookup (not hardcoded branching).

4. **Given** multiple channels, **when** `muteForFade` or `restoreAfterFade` are called, **then** all channels are affected.

### Unified player

5. **Given** `SoundFontPlayer`, **when** initialized with an engine and a `ChannelID`, **then** it uses that channel for all dispatch — both immediate and scheduled.

6. **Given** `SoundFontPlayer` conforms to `NotePlayer`, **when** `play(frequency:velocity:amplitudeDB:)` is called, **then** it uses immediate dispatch and returns a `PlaybackHandle` (identical behavior to the former `SoundFontNotePlayer`).

7. **Given** `SoundFontPlayer` conforms to `RhythmPlayer`, **when** `play(_: RhythmPattern)` is called, **then** it converts pattern events to `ScheduledMIDIEvent`s and dispatches via the engine's scheduling mechanism, **and** returns a `RhythmPlaybackHandle`.

8. **Given** `SoundFontPlayer`, **when** created as two instances (one for melodic, one for percussion), **then** pitch sessions use one instance typed as `NotePlayer` and rhythm sessions use the other typed as `RhythmPlayer`.

9. **Given** `SoundFontPlayer.stopAll()`, **when** called, **then** it stops all notes on THIS player's channel only — not all channels in the engine. It clears any active schedule, restores buffer duration, and sends all-notes-off on its channel. One implementation satisfies both `NotePlayer.stopAll()` and `RhythmPlayer.stopAll()`.

### Protocol layer

10. **Given** the `RhythmPlayer` protocol, **when** inspected, **then** it declares `play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle` and `stopAll() async throws`.

11. **Given** `RhythmPlaybackHandle` protocol, **when** inspected, **then** it declares `stop() async throws` (first call silences, subsequent calls are no-ops).

12. **Given** `RhythmPattern`, **when** inspected, **then** it contains `events: [Event]` (each with `sampleOffset: Int64`, `soundSourceID: any SoundSourceID`, `velocity: MIDIVelocity`), `sampleRate: Double`, and `totalDuration: Duration`, **and** events use absolute sample offsets.

### Backward compatibility

13. **Given** the `NotePlayer` protocol, **when** inspected after refactoring, **then** it is completely unchanged.

14. **Given** all existing pitch comparison and pitch matching tests, **when** run after refactoring, **then** all tests pass without modification.

### Mocks

15. **Given** `MockRhythmPlayer` and `MockRhythmPlaybackHandle`, **when** created for testing, **then** they follow the established mock contract (call counts, error injection, callbacks, reset) and are placed in `PeachTests/Mocks/`.

## Tasks / Subtasks

- [x] Task 0: Revert uncommitted 46.4 changes and clean up (prerequisite) — DONE during story creation
  - [x] Discarded all uncommitted changes from the previous 46.4 implementation
  - [x] Removed untracked files: `RhythmPlayer.swift`, `RhythmPlaybackHandle.swift`, `SoundFontRhythmPlayer.swift`, `SoundFontRhythmPlaybackHandle.swift`, `SoundFontRhythmPlayerTests.swift`, `MockRhythmPlayer.swift`, `MockRhythmPlaybackHandle.swift`
  - [x] Delete `docs/implementation-artifacts/46-4-rhythmplayer-protocol-and-soundfontrhythmplayer.md`
  - [x] Update sprint-status.yaml: rename key `46-4-rhythmplayer-protocol-and-soundfontrhythmplayer` to `46-4-unified-soundfontplayer-with-generalized-sampler-channels` and set status to `in-progress`
  - [x] Verify clean state: `bin/build.sh` zero errors, `bin/test.sh` all pass

- [x] Task 1: Add `SF2Preset` MIDI constants and `SoundFontLibrary` percussion resolution (AC: #2)
  - [x] Add named constants to `SF2Preset` in `SF2PresetParser.swift`:
    ```swift
    /// General MIDI percussion bank number (bank 128).
    nonisolated static let percussionBank = 128

    /// Bank MSB for melodic presets (`kAUSampler_DefaultMelodicBankMSB`).
    nonisolated static let melodicBankMSB: UInt8 = 0x79

    /// Bank MSB for percussion presets (`kAUSampler_DefaultPercussionBankMSB`).
    nonisolated static let percussionBankMSB: UInt8 = 0x78
    ```
  - [x] Add computed properties to `SF2Preset`:
    ```swift
    var isPercussion: Bool { bank == Self.percussionBank }
    var bankMSB: UInt8 { isPercussion ? Self.percussionBankMSB : Self.melodicBankMSB }
    ```
  - [x] Update `SoundFontLibrary.init`: replace `$0.bank < 120 && $0.program < 120` filter with `!$0.isPercussion`
  - [x] Rename `availablePresets` to `melodicPresets`
  - [x] Add `percussionPresets: [SF2Preset]` property
  - [x] Add `resolvePercussion(_ id: any SoundSourceID) -> SF2Preset?` method
  - [x] Update tests

- [x] Task 2: Generalize `SoundFontEngine` with channel registry (AC: #1, #3, #4)
  - [x] Define `SoundFontEngine.ChannelID` as `UInt8` wrapper (`Hashable`, `Sendable`)
  - [x] Replace the single `sampler` property with `channels: [ChannelID: AVAudioUnitSampler]`
  - [x] Add `createChannel(_ id: ChannelID)` that creates, attaches, connects an `AVAudioUnitSampler` and registers its MIDI block in `ScheduleData`
  - [x] Update `ScheduleData`: replace `melodicMIDIBlock` with `midiBlocks: [UInt8: AUScheduleMIDIEventBlock]`
  - [x] Update render callback: `let midiBlock = data.midiBlocks[channel]` (channel-indexed lookup)
  - [x] Replace `loadPreset(_ preset:)` with `loadPreset(_:channel:)` that uses `preset.bankMSB` (no raw hex in the engine — bank MSB constants live on `SF2Preset`)
  - [x] Track loaded preset per channel: `loadedPresets: [ChannelID: SF2Preset]`
  - [x] Send pitch bend range RPN only for non-percussion presets (`!preset.isPercussion`)
  - [x] Parameterize immediate dispatch with channel: `startNote(_:velocity:amplitudeDB:pitchBend:channel:)`, `stopNote(_:channel:)`, `sendPitchBend(_:channel:)`
  - [x] Add channel-scoped stop: `stopNotes(channel:stopPropagationDelay:)` — sends all-notes-off + pitch bend reset on one channel only
  - [x] `muteForFade()` / `restoreAfterFade()` iterate all channels
  - [x] Pre-create channel 0 in `init` for backward compatibility
  - [x] Remove `soundSource` parameter from `init` — the engine no longer loads an initial preset; that's the player's job. Init becomes `init(sf2URL: URL)` (SF2 URL needed for preset loading)
  - [x] Remove `defaultBankMSB` / `percussionBankMSB` private constants from engine (now on `SF2Preset`)
  - [x] Keep `noteOnBase`, `noteOffBase`, `channelMask`, `pitchBendRangeSemitones`, `pitchBendRangeCents` as static constants (MIDI protocol values used by players for event construction)

- [x] Task 3: Create `RhythmPlaybackHandle` protocol and `RhythmPattern` value type (AC: #11, #12)
  - [x] `RhythmPlaybackHandle` protocol at `Core/Audio/RhythmPlaybackHandle.swift`: `func stop() async throws`
  - [x] `RhythmPattern` struct at `Core/Audio/RhythmPlayer.swift` (co-located with protocol):
    - Nested `Event` struct: `sampleOffset: Int64`, `soundSourceID: any SoundSourceID`, `velocity: MIDIVelocity`
    - Top-level: `events: [Event]`, `sampleRate: Double`, `totalDuration: Duration`
    - Both `Sendable`

- [x] Task 4: Create `RhythmPlayer` protocol (AC: #10)
  - [x] Define at `Core/Audio/RhythmPlayer.swift`:
    ```swift
    protocol RhythmPlayer {
        func play(_ pattern: RhythmPattern) async throws -> RhythmPlaybackHandle
        func stopAll() async throws
    }
    ```

- [x] Task 5: Rename `SoundFontNotePlayer` to `SoundFontPlayer` and add `RhythmPlayer` conformance (AC: #5, #6, #7, #8, #9)
  - [x] Rename file: `SoundFontNotePlayer.swift` → `SoundFontPlayer.swift`
  - [x] Rename class: `SoundFontNotePlayer` → `SoundFontPlayer`
  - [x] Accept `ChannelID` in init, pass to all engine calls
  - [x] Existing `NotePlayer` conformance unchanged (immediate dispatch via channel)
  - [x] Add `RhythmPlayer` conformance:
    - `play(_ pattern: RhythmPattern)` converts each `RhythmPattern.Event` to a `ScheduledMIDIEvent` pair (note-on + note-off after `Self.percussionNoteOffDuration`), resolves `SoundSourceID` via library, loads percussion preset if needed, calls `engine.scheduleEvents()`, returns `SoundFontRhythmPlaybackHandle`
    - `stopAll()` is channel-scoped: clears schedule, restores buffer duration, sends all-notes-off on this player's channel only. One implementation satisfies both `NotePlayer.stopAll()` and `RhythmPlayer.stopAll()`
  - [x] Define named constant for note-off delay:
    ```swift
    /// Delay between note-on and note-off for percussion hits.
    /// Percussion samples have natural decay; this just ensures the MIDI note-off
    /// doesn't cut the sample short while still releasing the voice promptly.
    private nonisolated static let percussionNoteOffDuration: Duration = .milliseconds(50)
    ```
  - [x] Create `SoundFontRhythmPlaybackHandle` at `Core/Audio/SoundFontRhythmPlaybackHandle.swift` (same pattern as `SoundFontPlaybackHandle`: engine reference, channel, `hasStopped` guard, clears schedule + stops notes on channel)
  - [x] Update `SoundFontPlaybackHandle` to accept and use `ChannelID`
  - [x] Update all references: `PeachApp.swift` (rename type + update engine init — remove `soundSource` parameter, player loads initial preset after creation), `EnvironmentKeys.swift` (`PreviewNotePlayer` stays as-is — conforms to protocol not concrete class), `project-context.md` references to `SoundFontNotePlayer`
  - [x] The `decompose(frequency:)` and `pitchBendValue(forCents:)` static helpers stay on `SoundFontPlayer` (used by `SoundFontPlaybackHandle.adjustFrequency`)

- [x] Task 6: Create `MockRhythmPlayer` and `MockRhythmPlaybackHandle` (AC: #15)
  - [x] `MockRhythmPlaybackHandle` at `PeachTests/Mocks/MockRhythmPlaybackHandle.swift` — call counts, error injection, callbacks, reset
  - [x] `MockRhythmPlayer` at `PeachTests/Mocks/MockRhythmPlayer.swift` — playCallCount, stopAllCallCount, lastPattern, shouldThrowError, instantPlayback, continuation-based waits, reset

- [x] Task 7: Write tests (AC: all)
  - [x] Engine tests: multi-channel creation, per-channel preset loading, channel-isolated dispatch, channel-scoped stop, muteForFade across all channels
  - [x] `SoundFontPlayer` as `NotePlayer`: existing behavior preserved (immediate dispatch, pitch bend, handle lifecycle)
  - [x] `SoundFontPlayer` as `RhythmPlayer`: pattern→MIDI conversion, scheduled dispatch, handle stop idempotency
  - [x] `SoundFontPlayer.stopAll()` only affects its own channel
  - [x] `RhythmPattern` construction and event ordering
  - [x] Mock contract tests for `MockRhythmPlayer` and `MockRhythmPlaybackHandle`
  - [x] `SF2Preset.isPercussion`, `bankMSB`, `melodicBankMSB`, `percussionBankMSB` tests

- [x] Task 8: Verify no regressions (AC: #13, #14)
  - [x] `bin/build.sh` — zero errors, zero warnings
  - [x] `bin/test.sh` — full suite passes, zero regressions
  - [x] All existing pitch comparison, pitch matching, and preset stress tests pass

## Dev Notes

### The unified player in one picture

```
                    ┌─────────────────────────────────────────────┐
                    │           SoundFontEngine                   │
                    │                                             │
                    │  channels: [ChannelID: AVAudioUnitSampler]  │
                    │  ┌───────────┐  ┌───────────┐              │
                    │  │ Channel 0 │  │ Channel 1 │  ... N       │
                    │  └───────────┘  └───────────┘              │
                    │                                             │
                    │  immediate dispatch ─── any channel         │
                    │  scheduled dispatch ─── any channel         │
                    └─────────────────────────────────────────────┘
                           ▲                    ▲
                           │                    │
               ┌───────────┴──┐      ┌──────────┴───┐
               │ SoundFontPlayer    │ SoundFontPlayer │
               │ (channel 0)  │     │ (channel 1)    │
               │              │     │                 │
               │ conforms to: │     │ conforms to:    │
               │ NotePlayer   │     │ NotePlayer      │
               │ RhythmPlayer │     │ RhythmPlayer    │
               └──────────────┘     └─────────────────┘
                      │                      │
             used as NotePlayer      used as RhythmPlayer
             by pitch sessions       by rhythm sessions
```

Both instances are the same type. Pitch sessions receive their instance typed as `NotePlayer`. Rhythm sessions receive theirs typed as `RhythmPlayer`. The type system ensures each consumer sees only the API it needs.

### Why one class can do both

The two dispatch modes are engine capabilities, not player identities:

- **Immediate dispatch** = call `engine.startNote(channel:)` now, get a handle to stop later. Used when timing is human-interactive (pitch training).
- **Scheduled dispatch** = pre-compute `[ScheduledMIDIEvent]`, call `engine.scheduleEvents()`. Used when timing must be sample-accurate (rhythm training).

Both modes operate on the same sampler channel through the same engine. The player class just exposes both as protocol methods.

### Named constants reference

All MIDI/SoundFont magic numbers are defined as named constants:

| Constant | Location | Value | Purpose |
|----------|----------|-------|---------|
| `SF2Preset.percussionBank` | `SF2PresetParser.swift` | `128` | General MIDI percussion bank number |
| `SF2Preset.melodicBankMSB` | `SF2PresetParser.swift` | `0x79` | `kAUSampler_DefaultMelodicBankMSB` — bank MSB for melodic presets |
| `SF2Preset.percussionBankMSB` | `SF2PresetParser.swift` | `0x78` | `kAUSampler_DefaultPercussionBankMSB` — bank MSB for percussion presets |
| `SoundFontEngine.noteOnBase` | `SoundFontEngine.swift` | `0x90` | MIDI note-on status byte (channel added via bitwise OR) |
| `SoundFontEngine.noteOffBase` | `SoundFontEngine.swift` | `0x80` | MIDI note-off status byte (channel added via bitwise OR) |
| `SoundFontEngine.channelMask` | `SoundFontEngine.swift` | `0x0F` | Extracts channel from MIDI status byte (private — render callback only) |
| `SoundFontEngine.pitchBendRangeSemitones` | `SoundFontEngine.swift` | `2` | Pitch bend range set via MIDI RPN; all bend calculations derive from this |
| `SoundFontEngine.pitchBendRangeCents` | `SoundFontEngine.swift` | `200.0` | Derived: `pitchBendRangeSemitones * 100` |
| `SoundFontEngine.scheduleCapacity` | `SoundFontEngine.swift` | `4096` | Pre-allocated event buffer size for render-thread scheduling |
| `SoundFontPlayer.percussionNoteOffDuration` | `SoundFontPlayer.swift` | `.milliseconds(50)` | Delay between note-on and note-off for percussion hits |
| `SoundFontPlayer.validFrequencyRange` | `SoundFontPlayer.swift` | `20.0...20000.0` | Human-audible frequency range for input validation |

No raw hex or numeric literals should appear in implementation code outside these constant definitions.

### `stopAll()` is channel-scoped

Both `NotePlayer` and `RhythmPlayer` declare `stopAll() async throws`. `SoundFontPlayer` implements it once — it clears any active schedule, restores default buffer duration, and sends all-notes-off on **this player's channel only**. One implementation satisfies both protocols.

The engine does NOT have a public `stopAllNotes()` that silences everything. If an engine-wide stop is needed in the future, it can be added then. For now, each player controls its own channel.

### Preset loading strategy per dispatch mode

- **As `NotePlayer`** (immediate dispatch): `SoundFontPlayer` reads `userSettings.soundSource` on each `play(frequency:)` call and loads the resolved melodic preset on its channel. Same as current `SoundFontNotePlayer` behavior.
- **As `RhythmPlayer`** (scheduled dispatch): `SoundFontPlayer` resolves each pattern event's `SoundSourceID` via `library.resolvePercussion()` and loads the percussion preset on its channel before scheduling. The preset for the channel is whatever the last pattern needed.

This works because the two instances use different channels. Loading a percussion preset on channel 1 doesn't affect the melodic preset on channel 0.

### RhythmPattern.Event → ScheduledMIDIEvent conversion

Happens in `SoundFontPlayer.play(_ pattern:)` on the main thread:

```swift
// For each event in pattern.events:
// 1. Resolve SoundSourceID → SF2Preset via library.resolvePercussion()
// 2. Load preset on this player's channel if different from current
// 3. Extract MIDI note from SoundSourceID (format: "sf2:128:{program}:{midiNote}")
// 4. Create note-on ScheduledMIDIEvent at event.sampleOffset
//    midiStatus = SoundFontEngine.noteOnBase | channel.rawValue
// 5. Create note-off at event.sampleOffset + noteOffDelaySamples
//    noteOffDelaySamples = Int64(pattern.sampleRate * Self.percussionNoteOffDuration.timeInterval)
//    midiStatus = SoundFontEngine.noteOffBase | channel.rawValue
// 6. Sort all events by sampleOffset, call engine.scheduleEvents()
```

The player encodes its own `channel.rawValue` into the MIDI status byte. The engine's render callback routes to the correct sampler by reading it back.

### SoundFontRhythmPlaybackHandle

Follows the same pattern as `SoundFontPlaybackHandle`:

```swift
final class SoundFontRhythmPlaybackHandle: RhythmPlaybackHandle {
    private let engine: SoundFontEngine
    private let channel: SoundFontEngine.ChannelID
    private var hasStopped = false

    func stop() async throws {
        guard !hasStopped else { return }
        hasStopped = true
        engine.clearSchedule()
        await engine.stopNotes(channel: channel, stopPropagationDelay: .zero)
    }
}
```

No `adjustFrequency` — rhythm patterns are immutable once playing.

### Rename: SoundFontNotePlayer → SoundFontPlayer

All references to `SoundFontNotePlayer` must be updated:
- `PeachApp.swift` (creates the instance)
- `EnvironmentKeys.swift` (creates `PreviewNotePlayer` — stays as-is, conforms to `NotePlayer` protocol)
- `project-context.md` (documentation references)
- `SoundFontPlaybackHandle.swift` (references `SoundFontNotePlayer.validFrequencyRange` and `SoundFontNotePlayer.decompose()` — update to `SoundFontPlayer`)
- Test files that reference the type name

The `NotePlayer` and `PlaybackHandle` protocols are **untouched**. `MockNotePlayer` is **untouched** — it conforms to `NotePlayer`, not the concrete class.

### ChannelID design

Simple `UInt8` wrapper, nested in `SoundFontEngine`:

```swift
struct ChannelID: Hashable, Sendable {
    let rawValue: UInt8
    init(_ rawValue: UInt8) { self.rawValue = rawValue }
}
```

No static constants on the engine for specific channels — the engine doesn't know or care what each channel is for. `PeachApp` assigns channels when creating `SoundFontPlayer` instances.

### What this story does NOT do

- **Does NOT wire a second player instance into PeachApp.swift** — the percussion `SoundFontPlayer` instance will be created in a later story when rhythm sessions need it
- **Does NOT create a POC/demo screen** — that comes after
- **Does NOT add UI components** — pure audio/protocol layer
- **Does NOT modify `NotePlayer`, `PlaybackHandle`, or `MockNotePlayer`** — unchanged

### Previous story (46.3) infrastructure that remains unchanged

- `ScheduledMIDIEvent` struct — unchanged
- `AVAudioSourceNode` render callback structure — updated only for channel-indexed lookup
- `OSAllocatedUnfairLock<ScheduleData>` synchronization — unchanged
- Pre-allocated event buffer — unchanged
- `scheduleEvents()`, `clearSchedule()`, `scheduledEventCount` API — unchanged
- `configureForRhythmScheduling()`, `restoreDefaultBufferDuration()` — unchanged
- `scanSchedule()` static helper — unchanged

### Key architectural principle

**The engine is a MIDI sampler pool.** It manages sampler instances, routes MIDI events to them, and provides both immediate and scheduled dispatch. It knows nothing about pitch training, rhythm training, melodic vs. percussion, or any higher-level concept.

**The player is a channel owner.** It holds one engine channel, loads presets on it, and exposes both dispatch modes through protocol conformances. Different instances serve different consumers, but they're the same type with the same code.

### Project Structure Notes

Renamed files:
- `Peach/Core/Audio/SoundFontNotePlayer.swift` → `Peach/Core/Audio/SoundFontPlayer.swift`
- `PeachTests/Core/Audio/SoundFontNotePlayerTests.swift` → `PeachTests/Core/Audio/SoundFontPlayerTests.swift`

New files:
- `Peach/Core/Audio/RhythmPlayer.swift` — protocol + `RhythmPattern`
- `Peach/Core/Audio/RhythmPlaybackHandle.swift` — protocol
- `Peach/Core/Audio/SoundFontRhythmPlaybackHandle.swift` — implementation
- `PeachTests/Mocks/MockRhythmPlayer.swift`
- `PeachTests/Mocks/MockRhythmPlaybackHandle.swift`

Deleted files:
- `docs/implementation-artifacts/46-4-rhythmplayer-protocol-and-soundfontrhythmplayer.md` — replaced by this story

Modified files:
- `Peach/Core/Audio/SoundFontEngine.swift` — channel registry, generalized dispatch, channel-scoped stop
- `Peach/Core/Audio/SF2PresetParser.swift` — `percussionBank`, `isPercussion`, `bankMSB`, `melodicBankMSB`, `percussionBankMSB`
- `Peach/Core/Audio/SoundFontLibrary.swift` — melodic/percussion split, `resolvePercussion()`
- `Peach/Core/Audio/SoundFontPlaybackHandle.swift` — accept `ChannelID`, update `SoundFontPlayer` references
- `Peach/App/PeachApp.swift` — rename `SoundFontNotePlayer` → `SoundFontPlayer`, update engine init
- `PeachTests/Core/Audio/SoundFontEngineTests.swift` — multi-channel tests, channel-scoped stop tests
- `PeachTests/Core/Audio/SoundFontLibraryTests.swift` — percussion split tests
- `PeachTests/Core/Audio/SoundFontPresetStressTests.swift` — update type references
- `docs/project-context.md` — update `SoundFontNotePlayer` references
- `docs/implementation-artifacts/sprint-status.yaml` — rename story key

### References

- [Source: docs/planning-artifacts/architecture.md#Layer 1: SoundFontEngine]
- [Source: docs/planning-artifacts/architecture.md#Layer 3: RhythmPlayer Protocol and Implementation]
- [Source: docs/planning-artifacts/rhythm-training-spec.md#ADR-4: Unified Sample-Accurate Audio Model]
- [Source: docs/planning-artifacts/epics.md#Epic 46, Story 46.4]
- [Source: Peach/Core/Audio/SoundFontEngine.swift — engine to generalize]
- [Source: Peach/Core/Audio/SoundFontNotePlayer.swift — player to rename and extend]
- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift — handle to update]
- [Source: Peach/Core/Audio/SoundFontLibrary.swift — preset resolution to extend]
- [Source: Peach/Core/Audio/NotePlayer.swift — protocol unchanged]
- [Source: Peach/Core/Audio/PlaybackHandle.swift — protocol unchanged]
- [Source: PeachTests/PitchComparison/MockNotePlayer.swift — mock unchanged]
- [Source: docs/implementation-artifacts/46-3-add-render-thread-scheduling-to-soundfontengine.md — previous story]
- [Source: docs/project-context.md#AVAudioEngine, Testing Rules, Mock Contract]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Engine init crash: reordered sampler attach/connect before engine.start() — audio graph must be wired before starting
- Percussion bankLSB: AVAudioUnitSampler expects bankLSB=0 for percussion (bankMSB=0x78 selects the bank), not the SF2 bank number (128) which overflows UInt8

### Completion Notes List

- **Task 0**: Deleted old 46-4 story file, renamed sprint-status key, verified clean build (1135 tests)
- **Task 1**: Added `SF2Preset` MIDI constants (percussionBank, melodicBankMSB, percussionBankMSB, isPercussion, bankMSB). Updated `SoundFontLibrary` to split melodic/percussion presets and added `resolvePercussion()`. Renamed `availablePresets` → `melodicPresets`. +11 tests
- **Task 2**: Generalized `SoundFontEngine` with `ChannelID` wrapper, channel registry (`channels: [ChannelID: AVAudioUnitSampler]`), channel-indexed MIDI dispatch in render callback, per-channel preset loading with `bankMSB` from `SF2Preset`, channel-scoped stop, multi-channel mute/restore. Init simplified to `init(sf2URL:)`. Backward-compatible channel-0 wrappers preserved. +6 tests
- **Task 3-4**: Created `RhythmPlaybackHandle` protocol, `RhythmPattern` value type with nested `Event` struct, `RhythmPlayer` protocol
- **Task 5**: Renamed `SoundFontNotePlayer` → `SoundFontPlayer`, added `RhythmPlayer` conformance (pattern→MIDI conversion with channel-encoded status bytes), channel-scoped `stopAll()`, `SoundFontRhythmPlaybackHandle`. Updated `SoundFontPlaybackHandle` for ChannelID. Updated all references in PeachApp, project-context.md, tests
- **Task 6**: Created `MockRhythmPlayer` and `MockRhythmPlaybackHandle` following established mock contract
- **Task 7-8**: Added 35 new tests total (mock contracts, RhythmPattern, engine multi-channel, player conformance). Full suite: 1170 tests, 0 failures, 0 regressions

### Change Log

- 2026-03-20: Implemented unified SoundFontPlayer with generalized sampler channels (all 8 tasks complete)

### File List

New:
- Peach/Core/Audio/SoundFontPlayer.swift
- Peach/Core/Audio/RhythmPlayer.swift
- Peach/Core/Audio/RhythmPlaybackHandle.swift
- Peach/Core/Audio/SoundFontRhythmPlaybackHandle.swift
- PeachTests/Mocks/MockRhythmPlayer.swift
- PeachTests/Mocks/MockRhythmPlaybackHandle.swift
- PeachTests/Mocks/MockRhythmPlayerTests.swift

Deleted:
- Peach/Core/Audio/SoundFontNotePlayer.swift
- docs/implementation-artifacts/46-4-rhythmplayer-protocol-and-soundfontrhythmplayer.md

Modified:
- Peach/Core/Audio/SoundFontEngine.swift
- Peach/Core/Audio/SF2PresetParser.swift
- Peach/Core/Audio/SoundFontLibrary.swift
- Peach/Core/Audio/SoundFontPlaybackHandle.swift
- Peach/App/PeachApp.swift
- docs/project-context.md
- docs/implementation-artifacts/sprint-status.yaml
- PeachTests/Core/Audio/SoundFontEngineTests.swift
- PeachTests/Core/Audio/SoundFontLibraryTests.swift
- PeachTests/Core/Audio/SF2PresetParserTests.swift
- PeachTests/Core/Audio/SoundFontPlaybackHandleTests.swift
- PeachTests/Core/Audio/SoundFontPresetStressTests.swift
- PeachTests/Core/Audio/SoundFontNotePlayerTests.swift → PeachTests/Core/Audio/SoundFontPlayerTests.swift
