# Story 62.3: MIDIKit Adapter Implementation

Status: ready-for-dev

## Story

As a **developer**,
I want a production `MIDIInput` implementation wrapping MIDIKit,
So that MIDI events from any connected device flow into the app as an `AsyncStream<MIDIInputEvent>`.

## Acceptance Criteria

1. **Given** the MIDIKit adapter **When** initialized **Then** it creates an `ObservableMIDIManager` with client name "Peach" **And** starts the manager **And** adds an input connection with `.allOutputs` mode and `[.filterActiveSensingAndClock]` filter

2. **Given** a MIDI device connected via USB or Bluetooth **When** a note-on event is received **Then** the adapter maps it to `.noteOn(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)` **And** yields it into the `AsyncStream` continuation

3. **Given** a MIDI note-on with velocity 0 **When** received **Then** the adapter translates it to `.noteOff` (MIDI convention; `MIDIVelocity` enforces range 1-127)

4. **Given** a MIDI note-off event **When** received **Then** the adapter maps it to `.noteOff` with the correct `MIDINote`, `MIDIVelocity`, and raw `MIDITimeStamp`

5. **Given** a MIDI pitch bend event **When** received **Then** the adapter maps it to `.pitchBend(value: PitchBendValue, channel: MIDIChannel, timestamp: UInt64)`

6. **Given** a MIDI device is connected or disconnected **When** the setup changes **Then** `isConnected` reflects whether any MIDI source is currently connected **And** MIDIKit's managed connection handles reconnection automatically

7. **Given** `PeachApp.swift` **When** the adapter is wired **Then** it replaces the `nil` default with the production instance via `.environment(\.midiInput, adapter)`

8. **Given** the adapter implementation **When** reviewed **Then** `import MIDIKitIO` appears only in the adapter file and `PeachApp.swift`

9. **Given** the full test suite **When** run on Simulator **Then** all tests pass (adapter is not exercised on Simulator -- domain logic tested via mock)

## Tasks / Subtasks

- [ ] Task 1: Create `MIDIKitAdapter` class (AC: #1, #2, #3, #4, #5, #6)
  - [ ] 1.1 Create `Peach/Core/Audio/MIDIKitAdapter.swift`
  - [ ] 1.2 `import MIDIKitIO` -- this is the ONLY source file besides `PeachApp.swift` that imports MIDIKit
  - [ ] 1.3 Declare `final class MIDIKitAdapter: MIDIInput` with `@Observable` for `isConnected`
  - [ ] 1.4 In `init()`: create `ObservableMIDIManager(clientName: "Peach", model: "Peach", manufacturer: "Peach")`
  - [ ] 1.5 In `init()`: call `midiManager.start()`
  - [ ] 1.6 In `init()`: call `midiManager.addInputConnection(to: .allOutputs, tag: "main", filter: .default(), receiver: .events(options: [.filterActiveSensingAndClock]) { ... })`
  - [ ] 1.7 In the receiver closure: map each `MIDIEvent` to `MIDIInputEvent` and yield into the `AsyncStream.Continuation`
  - [ ] 1.8 Implement velocity-0 noteOn -> noteOff translation: if `payload.velocity.midi1Value == 0`, yield `.noteOff` instead of `.noteOn`
  - [ ] 1.9 Implement `events` as `AsyncStream<MIDIInputEvent>` backed by a continuation created in `init()`
  - [ ] 1.10 Implement `isConnected` by checking `midiManager.managedInputConnections["main"]?.coreMIDIOutputEndpointRefs.isEmpty == false` (or equivalent MIDIKit API for endpoint count)
  - [ ] 1.11 Handle errors from `start()` and `addInputConnection()` gracefully with `os.Logger` -- do not crash
- [ ] Task 2: Wire adapter in `PeachApp.swift` (AC: #7, #8)
  - [ ] 2.1 `import MIDIKitIO` in `PeachApp.swift` (already has other framework imports)
  - [ ] 2.2 Add `@State private var midiAdapter: MIDIKitAdapter?` property
  - [ ] 2.3 In `init()`: create `MIDIKitAdapter()` -- wrap in do/catch, log errors, leave `nil` on failure
  - [ ] 2.4 In `body`: add `.environment(\.midiInput, midiAdapter)` to the environment chain
- [ ] Task 3: Verify no regressions (AC: #9)
  - [ ] 3.1 Run full test suite via `bin/test.sh`
  - [ ] 3.2 Verify build succeeds via `bin/build.sh` -- no new warnings
  - [ ] 3.3 Confirm adapter is inert on Simulator (no CoreMIDI, so `midiManager.start()` either no-ops or fails gracefully)

## Dev Notes

### Architecture Context

Story 3 of 4 in the MIDI input epic. Stories 62.1 and 62.2 created the foundation types (`MIDIInputEvent`, `MIDIChannel`, `PitchBendValue`) and port protocol (`MIDIInput`) with mock. This story creates the **production adapter** -- the only component that knows about MIDIKit. Story 62.4 consumes the `MIDIInput` protocol in `ContinuousRhythmMatchingSession`.

The adapter follows the same pattern as other production implementations of port protocols:
- `SoundFontPlayer` implements `NotePlayer` and `RhythmPlayer`
- `SoundFontStepSequencer` implements `StepSequencer`
- `HapticFeedbackManager` implements `HapticFeedback`

All are created in `PeachApp.init()` and injected via `.environment()`.

### MIDIKit API Reference

MIDIKit v0.11.0 is already added as SPM dependency (story 62.1). Only `MIDIKitIO` product is linked.

**Minimal setup pattern** (from research doc):

```swift
import MIDIKitIO

let midiManager = ObservableMIDIManager(
    clientName: "Peach",
    model: "Peach",
    manufacturer: "Peach"
)

try midiManager.start()

try midiManager.addInputConnection(
    to: .allOutputs,
    tag: "main",
    filter: .default(),
    receiver: .events(options: [.filterActiveSensingAndClock]) { events, timeStamp, source in
        for event in events {
            switch event {
            case .noteOn(let payload):
                // payload.note      — MIDIKit's UInt7 type
                // payload.velocity   — MIDIKit's value type
                // payload.channel    — MIDIKit's UInt4 type
            case .noteOff(let payload):
                // same shape
            case .pitchBend(let payload):
                // payload.value      — MIDIKit's value type
                // payload.channel    — MIDIKit's UInt4 type
            default: break
            }
        }
    }
)
```

**Key API choices:**
- `ObservableMIDIManager` -- SwiftUI-observable, endpoint lists update automatically
- `.allOutputs` -- auto-connects to every MIDI source; handles hot-plug automatically
- `.filterActiveSensingAndClock` -- drops high-frequency timing messages irrelevant to note input
- `.events` receiver -- closure-based, receives strongly-typed `[MIDIEvent]`

### Event Mapping

The receiver closure runs on MIDIKit's internal serial dispatch queue (NOT the CoreMIDI real-time thread). `AsyncStream.Continuation.yield()` is safe to call from this queue.

Map MIDIKit events to project domain types:

| MIDIKit Event | Peach `MIDIInputEvent` | Notes |
|---------------|----------------------|-------|
| `.noteOn(payload)` where `payload.velocity.midi1Value > 0` | `.noteOn(note: MIDINote(Int(payload.note.number)), velocity: MIDIVelocity(Int(payload.velocity.midi1Value)), timestamp: timeStamp)` | Normal note-on |
| `.noteOn(payload)` where `payload.velocity.midi1Value == 0` | `.noteOff(note: MIDINote(Int(payload.note.number)), velocity: MIDIVelocity(1), timestamp: timeStamp)` | MIDI convention: velocity-0 noteOn = noteOff. Use velocity 1 since `MIDIVelocity` range is 1-127 |
| `.noteOff(payload)` | `.noteOff(note: MIDINote(Int(payload.note.number)), velocity: MIDIVelocity(max(1, Int(payload.velocity.midi1Value))), timestamp: timeStamp)` | Clamp velocity to 1 minimum for `MIDIVelocity` range safety |
| `.pitchBend(payload)` | `.pitchBend(value: PitchBendValue(Int(payload.value.midi1Value)), channel: MIDIChannel(Int(payload.channel.number)), timestamp: timeStamp)` | 14-bit value (0-16383) |

**Timestamp:** The `timeStamp` parameter from MIDIKit's receiver closure is a raw `MIDITimeStamp` (`UInt64` host ticks). Pass it directly -- do NOT convert to `Duration` or `TimeInterval`.

**Important:** Check the actual MIDIKit API for property names and types. The research doc shows `.midi1Value` but verify against MIDIKit v0.11.0's actual API. The adapter must compile. Use Xcode autocompletion or read the MIDIKitIO module headers if names differ.

### `isConnected` Implementation

MIDIKit's managed input connection tracks connected endpoints. Check whether any MIDI output endpoints are currently reachable through the managed connection. The exact API depends on MIDIKit's `MIDIInputConnection` -- look for a property like `coreMIDIOutputEndpointRefs` or `endpoints` on the managed connection object accessed via `midiManager.managedInputConnections["main"]`.

If MIDIKit doesn't expose a convenient endpoint count, an alternative: observe `midiManager.observableEndpoints.outputs` (the `ObservableMIDIManager` publishes endpoint lists) and set `isConnected = !outputs.isEmpty`.

### Threading and Concurrency

- The receiver closure runs on MIDIKit's serial dispatch queue -- NOT the main actor
- `AsyncStream.Continuation.yield()` is safe from this queue (no real-time thread concern)
- The `MIDIKitAdapter` class is `@Observable` and lives on `@MainActor` (default isolation)
- The receiver closure must be `@Sendable` since it crosses isolation boundaries
- `isConnected` updates from the receiver closure must hop to `@MainActor` -- use `Task { @MainActor in self.isConnected = ... }` or check if MIDIKit's `ObservableMIDIManager` provides main-actor-safe observation

### Error Handling

- `midiManager.start()` and `addInputConnection()` can throw
- On Simulator, CoreMIDI is unavailable -- these calls may fail silently or throw
- Log errors with `os.Logger` at `.warning` level; do NOT crash
- If initialization fails, the adapter simply never yields events -- training works fine without MIDI (screen tap is always available)
- In `PeachApp.init()`: wrap adapter creation in do/catch, set to `nil` on failure

### File Placement

| File | Location | Rationale |
|------|----------|-----------|
| `MIDIKitAdapter.swift` | `Peach/Core/Audio/` | Production adapter alongside `SoundFontPlayer`, `SoundFontStepSequencer` |
| `PeachApp.swift` | `Peach/App/` | Existing file -- add adapter creation and environment injection |

**Why `Core/Audio/` not `Core/MIDI/`?** The existing audio adapters live in `Core/Audio/`. A single adapter file doesn't justify a new directory. If more MIDI files accumulate later, they can be extracted.

**Note:** The epic AC suggests `Core/Audio/` or `Core/MIDI/` -- prefer `Core/Audio/` for consistency.

### What NOT To Do

- Do NOT create tests for `MIDIKitAdapter` -- it wraps CoreMIDI which is unavailable on Simulator. All domain logic is tested via `MockMIDIInput` (story 62.2). Integration testing requires a physical device.
- Do NOT import `MIDIKitIO` in any file other than `MIDIKitAdapter.swift` and `PeachApp.swift`
- Do NOT add `MIDIKitIO` to the test target -- tests use mocks
- Do NOT filter by channel or note -- accept all notes, all channels (epic design decision)
- Do NOT add device selection UI -- deferred per research recommendations
- Do NOT add `start()`/`stop()` methods to the adapter -- the stream is always available; consumers subscribe by iterating
- Do NOT create a `Core/MIDI/` directory -- use `Core/Audio/` alongside existing adapters
- Do NOT convert `MIDITimeStamp` to `Duration` or `TimeInterval` -- raw `UInt64` host ticks preserve sub-millisecond precision

### Previous Story Intelligence

From story 62.2:
- `MIDIInput` protocol is `nonisolated` with `events: AsyncStream<MIDIInputEvent>` and `isConnected: Bool`
- `MockMIDIInput` uses `nonisolated(unsafe)` for stream/continuation storage and `nonisolated` for protocol conformance
- `@Entry var midiInput: (any MIDIInput)? = nil` already exists in EnvironmentKeys -- no changes needed there
- `PeachApp.swift` currently has no MIDI wiring -- the `@Entry` default is `nil`
- 1488 tests pass as of story 62.2

From story 62.1:
- MIDIKit v0.11.0 pinned with `upToNextMinorVersion`
- `MIDIInputEvent` is `nonisolated enum` with `.noteOn`, `.noteOff`, `.pitchBend`
- `MIDIVelocity` range is 1-127 (not 0-127) -- velocity-0 noteOn must map to noteOff
- `MIDIChannel` range is 0-15
- `PitchBendValue` range is 0-16383

### Nonisolated Protocol Conformance

The `MIDIInput` protocol is `nonisolated`. The adapter class (which is `@MainActor` by default isolation) must satisfy this:
- `events` property: can be `nonisolated` if backed by a stored property initialized in `init()` (the `AsyncStream` itself is `Sendable`)
- `isConnected` property: must be `nonisolated` for protocol conformance -- consider using `nonisolated(unsafe)` for the backing storage (same pattern as `MockMIDIInput`), or make the property a computed property checking MIDIKit state

Follow the same `nonisolated` conformance pattern used in `MockMIDIInput.swift` from story 62.2.

### Project Structure Notes

- `Core/Audio/` already contains 11 files -- `MIDIKitAdapter.swift` fits naturally
- Only `PeachApp.swift` changes among existing files (add adapter creation + environment injection)
- `EnvironmentKeys.swift` already has `@Entry var midiInput` -- no changes needed
- No new directories needed
- `import MIDIKitIO` is new in exactly 2 files

### References

- [Source: docs/planning-artifacts/epics.md#Epic 62, Story 62.3] -- AC and epic context
- [Source: docs/planning-artifacts/research/technical-midi-input-ios-research-2026-03-26.md] -- MIDIKit API patterns, threading model, event mapping
- [Source: docs/implementation-artifacts/62-1-add-midikit-dependency-and-define-midi-input-event-types.md] -- Domain types, MIDIKit version
- [Source: docs/implementation-artifacts/62-2-midiinput-port-protocol-mock-and-composition-root-wiring.md] -- Port protocol, mock pattern, nonisolated conformance
- [Source: docs/project-context.md] -- File placement, composition root pattern, concurrency rules
- FR114 (connect to all MIDI outputs), FR115 (filter active sensing/clock), FR116 (isConnected), FR117 (AsyncStream delivery), FR118 (event mapping with domain types), FR119 (yield from MIDIKit queue), FR127 (no entitlements), FR128 (testable via mock)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
