# Story 62.4: MIDI Input for Continuous Rhythm Matching Training

Status: done (reviewed)

## Story

As a **musician with a MIDI controller**,
I want to tap rhythms on my MIDI controller during continuous rhythm matching training,
So that I can use a familiar instrument interface instead of the screen tap button.

## Acceptance Criteria

1. **Given** a MIDI controller is connected and continuous rhythm matching is active **When** the user plays any note on any channel **Then** the system treats the MIDI note-on as a tap **And** the system uses the event's `MIDITimeStamp` for hit detection against the audio engine's sample-accurate timing, not wall-clock time

2. **Given** a MIDI note-on is received during active training **When** the tap falls within the evaluation window around the gap **Then** the system plays immediate auditory tap feedback via `stepSequencer.playImmediateNote()` **And** visual feedback is shown (same as screen tap)

3. **Given** a MIDI note-on tap is evaluated **When** the result is recorded **Then** it produces the same `RhythmOffset`, `GapResult`, observer notifications, and trial aggregation as a screen tap

4. **Given** a MIDI note-on is received outside the evaluation window **When** processing **Then** it is silently ignored (same behavior as screen taps outside the window)

5. **Given** no MIDI controller is connected **When** training is active **Then** screen tap continues to work identically — MIDI input is additive, not a replacement

6. **Given** the `ContinuousRhythmMatchingSession` MIDI integration **When** tested **Then** all timing logic is tested on Simulator using `MockMIDIInput` with controlled event sequences and timestamps **And** the tests verify timestamp-based hit detection, feedback triggering, and result recording

7. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions

## Tasks / Subtasks

- [x] Task 1: Add host-time-to-sample-position conversion to `StepSequencer` (AC: #1)
  - [x] 1.1 Add `hostTimeAtSample: UInt64` field to `ScheduleData` in `SoundFontEngine.swift` — stores the `mach_absolute_time()` captured at the moment `samplePosition` was last updated
  - [x] 1.2 In the `AVAudioSourceNode` render callback, capture `timestamp.pointee.mHostTime` alongside `data.samplePosition = windowEnd` so both are updated atomically under the lock
  - [x] 1.3 Add `samplePosition(forHostTime: UInt64) -> Int64` method to `StepSequencerEngine` protocol
  - [x] 1.4 Implement in `SoundFontEngine`: read `(hostTimeAtSample, samplePosition)` under the lock, use `mach_timebase_info` to convert the delta in host ticks to seconds, multiply by sample rate to get delta samples, add to known sample position
  - [x] 1.5 Add `samplePosition(forHostTime: UInt64) -> Int64` to `StepSequencer` protocol
  - [x] 1.6 Implement in `SoundFontStepSequencer`: delegate to `engine.samplePosition(forHostTime:)`
  - [x] 1.7 Add `samplePosition(forHostTime:)` to `MockStepSequencer` with a configurable return value (default: `currentSamplePosition`, allowing tests to override)
  - [x] 1.8 Reset `hostTimeAtSample` to 0 in `SoundFontEngine.clearSchedule()` and `clearAllEvents()`

- [x] Task 2: Refactor `handleTap()` to accept an optional sample position (AC: #1, #2, #3, #4)
  - [x] 2.1 Add `func handleTap(atSamplePosition samplePosition: Int64? = nil)` — when `nil`, reads `stepSequencer.timing.samplePosition` (current behavior); when provided, uses the given value
  - [x] 2.2 Rename existing internal logic to use the resolved sample position throughout
  - [x] 2.3 Existing screen-tap call sites (`ContinuousRhythmMatchingScreen.swift` line 124, 134) continue calling `session.handleTap()` with no arguments — zero screen changes

- [x] Task 3: Add MIDI listening to `ContinuousRhythmMatchingSession` (AC: #1, #2, #3, #4, #5)
  - [x] 3.1 Add `private let midiInput: (any MIDIInput)?` to init parameters (default `nil` for backward compatibility)
  - [x] 3.2 Add `private var midiListeningTask: Task<Void, Never>?` property
  - [x] 3.3 In `start(settings:)`: after starting the step sequencer, spawn `midiListeningTask` that iterates `midiInput?.events`
  - [x] 3.4 In the MIDI listening loop: on `.noteOn`, convert `timestamp` via `stepSequencer.samplePosition(forHostTime: timestamp)` then call `handleTap(atSamplePosition:)`
  - [x] 3.5 Ignore `.noteOff` and `.pitchBend` events (only note-on triggers a tap)
  - [x] 3.6 In `stop()`: cancel `midiListeningTask` and set to `nil`

- [x] Task 4: Wire MIDI input in composition root (AC: #5)
  - [x] 4.1 Update `createContinuousRhythmMatchingSession` in `PeachApp.swift` to accept `midiInput: (any MIDIInput)?` parameter
  - [x] 4.2 Pass `midiAdapter` (the `MIDIKitAdapter` from story 62.3) to the factory method
  - [x] 4.3 Pass it through to `ContinuousRhythmMatchingSession(stepSequencer:observers:midiInput:)`

- [x] Task 5: Write tests (AC: #6, #7)
  - [x] 5.1 Test: MIDI noteOn within evaluation window records a hit with correct `RhythmOffset` and `GapResult`
  - [x] 5.2 Test: MIDI noteOn within evaluation window triggers `playImmediateNote()` with correct velocity
  - [x] 5.3 Test: MIDI noteOn within evaluation window shows visual feedback (`showFeedback`, `lastHitOffsetMs`)
  - [x] 5.4 Test: MIDI noteOn outside evaluation window is silently ignored (no hit, no feedback, no audio)
  - [x] 5.5 Test: MIDI noteOn in already-hit cycle is ignored (double-tap prevention)
  - [x] 5.6 Test: MIDI noteOff and pitchBend events are ignored
  - [x] 5.7 Test: Session with `nil` midiInput works identically to before (backward compatibility)
  - [x] 5.8 Test: MIDI tap uses the converted sample position (from `samplePosition(forHostTime:)`), not the current position
  - [x] 5.9 Test: MIDI listening task is cancelled when `stop()` is called
  - [x] 5.10 Test: MIDI noteOn while session is not running is ignored
  - [x] 5.11 Test: Trial completion with mix of screen taps and MIDI taps produces correct aggregation
  - [x] 5.12 Run full test suite via `bin/test.sh` — all existing tests pass

## Dev Notes

### Architecture Context

Story 4 of 4 in the MIDI input epic. Stories 62.1-62.3 built the foundation: `MIDIInputEvent` types, `MIDIInput` port protocol with `MockMIDIInput`, and the production `MIDIKitAdapter`. This story **consumes** the `MIDIInput` protocol in `ContinuousRhythmMatchingSession` to treat MIDI note-on events as rhythm taps.

The key architectural constraint is **timestamp-based hit detection**: instead of reading the sequencer's current sample position (as screen taps do), MIDI taps must convert the event's `MIDITimeStamp` (host ticks from `mach_absolute_time()`) to the audio engine's sample position. This provides sub-millisecond accuracy regardless of event delivery latency.

### Host Time → Sample Position Conversion

The `SoundFontEngine`'s `AVAudioSourceNode` render callback receives an `AudioTimeStamp` with `.mHostTime` (host ticks) on every render call. The engine already tracks `samplePosition` (cumulative rendered samples). By capturing the host time alongside the sample position atomically (they're both updated under the same lock), we get a reference point for interpolation.

**Conversion formula:**
```swift
func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
    let (knownHostTime, knownSamplePos) = // read under lock
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let deltaTicks = Int64(hostTime) - Int64(knownHostTime)
    let deltaNanos = deltaTicks * Int64(timebase.numer) / Int64(timebase.denom)
    let deltaSeconds = Double(deltaNanos) / 1_000_000_000.0
    return knownSamplePos + Int64(deltaSeconds * sampleRate.rawValue)
}
```

**Important:** `mach_timebase_info` is cheap (cached by the kernel after first call). Call it once and store.

**Edge case:** If `hostTimeAtSample` is 0 (sequencer not yet started or just reset), fall back to `currentSamplePosition` — same behavior as a screen tap.

### `handleTap` Refactoring

The current `handleTap()` reads `stepSequencer.timing.samplePosition` for the sample position. Refactor to:

```swift
func handleTap(atSamplePosition overrideSamplePosition: Int64? = nil) {
    let timing = stepSequencer.timing
    let samplePosition = overrideSamplePosition ?? timing.samplePosition
    // ... rest uses samplePosition instead of timing.samplePosition
    // timing.samplesPerStep, timing.samplesPerCycle, timing.sampleRate still from timing
}
```

This keeps the default parameter so **all existing call sites are unchanged** (screen taps pass no argument). Only the MIDI listener passes a converted sample position.

### MIDI Listening Task

```swift
private func startMIDIListening() {
    guard let midiInput else { return }
    midiListeningTask = Task {
        for await event in midiInput.events {
            guard !Task.isCancelled, isRunning else { continue }
            switch event {
            case .noteOn(_, _, let timestamp):
                let samplePos = stepSequencer.samplePosition(forHostTime: timestamp)
                handleTap(atSamplePosition: samplePos)
            case .noteOff, .pitchBend:
                break
            }
        }
    }
}
```

Call `startMIDIListening()` after the sequencer starts in `start(settings:)`.

### What The Session Does NOT Know

- The session has no idea whether a tap came from screen or MIDI — `handleTap(atSamplePosition:)` is the same code path
- No MIDI-specific state, no MIDI-specific observer callbacks, no MIDI-specific result types
- MIDI is purely an additional input source routed through the same evaluation pipeline

### MockStepSequencer Extension for Tests

Add to `MockStepSequencer`:
```swift
var samplePositionForHostTimeOverride: Int64?

func samplePosition(forHostTime hostTime: UInt64) -> Int64 {
    samplePositionForHostTimeOverride ?? currentSamplePosition
}
```

Tests set `samplePositionForHostTimeOverride` to control exactly which sample position the MIDI timestamp resolves to. This lets tests verify that the converted position (not the current position) is used for hit evaluation.

### Test Pattern for MIDI Taps

```swift
@Test("MIDI noteOn within evaluation window records a hit")
func midiNoteOnWithinWindow() async {
    let f = makeSession()  // Updated to include MockMIDIInput
    f.session.start(settings: f.defaultSettings())
    await f.sequencer.waitForStart()

    // Set up timing: gap at step position 3 (fourth), cycle 0
    let gapSampleOffset = Int64(0 * 4 + 3) * f.samplesPerStep  // = 3 * 5512 = 16536
    let tapSamplePosition = gapSampleOffset + 100  // 100 samples late (well within window)

    // Configure mock: MIDI timestamp converts to our desired sample position
    f.sequencer.samplePositionForHostTimeOverride = tapSamplePosition
    f.sequencer.currentSamplePosition = tapSamplePosition  // timing reads need this too

    // Send MIDI noteOn
    f.midiInput.send(.noteOn(note: MIDINote(60), velocity: MIDIVelocity(100), timestamp: 12345))

    // Wait for async processing
    // ... verify hit recorded, feedback shown, playImmediateNote called
}
```

### File Changes

| File | Change | Rationale |
|------|--------|-----------|
| `Peach/Core/Audio/SoundFontEngine.swift` | Add `hostTimeAtSample` capture in render callback; add `samplePosition(forHostTime:)` | Host-time-to-sample conversion for MIDI timestamps |
| `Peach/Core/Audio/SoundFontStepSequencer.swift` | Add `samplePosition(forHostTime:)` delegating to engine | Protocol conformance |
| `Peach/Core/Ports/StepSequencer.swift` | Add `samplePosition(forHostTime: UInt64) -> Int64` | Protocol extension for timestamp conversion |
| `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` | Add `midiInput` parameter; MIDI listening task; refactor `handleTap` | Core MIDI integration |
| `Peach/App/PeachApp.swift` | Pass `midiAdapter` to session factory | Composition root wiring |
| `PeachTests/Mocks/MockStepSequencer.swift` | Add `samplePositionForHostTimeOverride` and mock method | Test support for timestamp conversion |
| `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift` | Add MIDI-specific tests; update fixture to include `MockMIDIInput` | AC #6 |

### What NOT To Do

- Do NOT modify `ContinuousRhythmMatchingScreen.swift` — screen taps continue to call `session.handleTap()` with no arguments; MIDI is handled entirely in the session
- Do NOT filter MIDI events by note number or channel — accept any note on any channel (epic design decision)
- Do NOT add MIDI-specific UI indicators (connection status, etc.) — deferred
- Do NOT add `import MIDIKitIO` anywhere — the session depends only on the `MIDIInput` protocol
- Do NOT create new observer protocols for MIDI — reuse existing `ContinuousRhythmMatchingObserver`
- Do NOT create a separate `handleMIDITap()` method — route through the same `handleTap(atSamplePosition:)` code path
- Do NOT use `nonisolated(unsafe)` — see project-context.md
- Do NOT convert `MIDITimeStamp` to `Duration` or `TimeInterval` before the sample position conversion — work in host ticks and samples

### Previous Story Intelligence

From story 62.3:
- `MIDIKitAdapter` is wired in `PeachApp.swift` as `@State private var midiAdapter: MIDIKitAdapter?`
- Injected via `.environment(\.midiInput, midiAdapter)` — available to views but **not yet consumed by any session**
- Adapter streams all events (noteOn, noteOff, pitchBend) — consumer must filter
- `import MIDIKitIO` appears only in `MIDIKitAdapter.swift` and `PeachApp.swift`
- 1488 tests pass as of story 62.3
- `MIDIKitAdapter.init()` does not throw — errors handled internally

From story 62.2:
- `MIDIInput` protocol is `nonisolated` with `events: AsyncStream<MIDIInputEvent>` and `isConnected: Bool`
- `MockMIDIInput.send(_ event:)` is `nonisolated` — safe to call from any context
- `@Entry var midiInput: (any MIDIInput)? = nil` in `EnvironmentKeys.swift`

From story 62.1:
- `MIDIInputEvent.noteOn` carries `(note: MIDINote, velocity: MIDIVelocity, timestamp: UInt64)`
- `timestamp` is raw `MIDITimeStamp` (host ticks from `mach_absolute_time()`)
- Do not convert to `Duration` or `TimeInterval` — preserve raw host ticks for sample-accurate conversion

### Git Intelligence

Recent commits show the MIDI epic progression (62.1 → 62.2 → 62.3). All followed TDD, all 1488 tests pass. Story 62.3's code review added a `deinit` to `MIDIKitAdapter` and consistent velocity clamping.

### Project Structure Notes

- Session file: `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` (286 lines)
- Test file: `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift`
- Mock: `PeachTests/Mocks/MockMIDIInput.swift` — already exists from story 62.2
- Mock: `PeachTests/Mocks/MockStepSequencer.swift` — needs `samplePosition(forHostTime:)` addition
- Composition root: `Peach/App/PeachApp.swift` — `createContinuousRhythmMatchingSession` factory method

### References

- [Source: docs/planning-artifacts/epics.md#Epic 62, Story 62.4] — AC and epic context
- [Source: docs/implementation-artifacts/62-3-midikit-adapter-implementation.md] — Adapter implementation, wiring pattern
- [Source: docs/implementation-artifacts/62-2-midiinput-port-protocol-mock-and-composition-root-wiring.md] — Protocol, mock, environment key
- [Source: docs/implementation-artifacts/62-1-add-midikit-dependency-and-define-midi-input-event-types.md] — Event types, MIDITimeStamp semantics
- [Source: docs/project-context.md] — Concurrency rules, testing rules, composition root pattern
- FR123 (any note, any channel = tap), FR124 (MIDITimeStamp for hit detection), FR125 (auditory tap feedback), FR126 (same result types as screen tap)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None

### Completion Notes List

- All 5 tasks completed with TDD workflow
- Host-time-to-sample-position conversion added to `SoundFontEngine` using `mach_timebase_info` and atomic capture of `mHostTime` in render callback
- `handleTap()` refactored to accept optional `atSamplePosition:` parameter — screen taps unchanged, MIDI taps pass converted sample position
- MIDI listening task iterates `midiInput.events` AsyncStream, converts noteOn timestamps via `stepSequencer.samplePosition(forHostTime:)`, routes through same `handleTap` code path
- Composition root passes `MIDIKitAdapter` to session factory
- 11 MIDI-specific tests added covering hit detection, feedback, double-tap prevention, event filtering, backward compatibility, mixed input, and cancellation
- Full test suite: 1499 tests pass, zero regressions

### File List

- `Peach/Core/Audio/SoundFontEngine.swift` — Added `hostTimeAtSample` to `ScheduleData`, capture in render callback, `samplePosition(forHostTime:)` method, cached `timebaseInfo`, reset in `clearSchedule()`
- `Peach/Core/Audio/SoundFontStepSequencer.swift` — Added `samplePosition(forHostTime:)` to `StepSequencerEngine` protocol and `SoundFontStepSequencer` implementation
- `Peach/Core/Ports/StepSequencer.swift` — Added `samplePosition(forHostTime:)` to `StepSequencer` protocol
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — Added `midiInput` parameter, MIDI listening task, refactored `handleTap` to accept optional sample position
- `Peach/App/PeachApp.swift` — Pass `midiAdapter` to `createContinuousRhythmMatchingSession`
- `Peach/App/EnvironmentKeys.swift` — Added `samplePosition(forHostTime:)` to `PreviewStepSequencer`
- `PeachTests/Mocks/MockStepSequencer.swift` — Added `samplePositionForHostTimeOverride` and mock implementation
- `PeachTests/Mocks/MockStepSequencerEngine.swift` — Added `samplePositionForHostTimeOverride` and mock implementation
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift` — Added `MIDIFixture`, `makeSessionWithMIDI()`, 11 MIDI integration tests
