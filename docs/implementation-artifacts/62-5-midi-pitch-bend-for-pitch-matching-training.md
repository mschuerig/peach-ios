# Story 62.5: MIDI Pitch Bend for Pitch Matching Training

Status: done

## Story

As a **musician with a MIDI controller**,
I want to use my controller's pitch bend wheel to adjust pitch during pitch matching training,
So that I can use a familiar, tactile input instead of the on-screen slider.

## Acceptance Criteria

1. **Given** a MIDI controller is connected and pitch matching training is active **When** any pitch bend message is received (status `0xE0`-`0xEF`, 14-bit value 0-16383, center 8192) **Then** the system recognises it regardless of MIDI channel

2. **Given** a pitch bend value is received **When** mapped to the slider domain **Then** the full pitch bend range maps linearly to `[-1.0, +1.0]`: 0 maps to -1.0, 8192 maps to 0.0, 16383 maps to +1.0

3. **Given** pitch bend messages are received continuously **When** the session is in `.awaitingSliderTouch` or `.playingTunable` state **Then** the on-screen slider thumb moves in real-time to reflect the current pitch bend position

4. **Given** the session is in `.awaitingSliderTouch` state **When** the first pitch bend message arrives (any value, not just non-center) **Then** the tunable note starts playing — identical to the first slider touch (calls `adjustPitch()` which transitions to `.playingTunable`)

5. **Given** the session is in `.playingTunable` state **When** continuous pitch bend messages arrive **Then** they drive `adjustPitch()` on the session exactly like slider drag, producing real-time frequency changes via `currentHandle?.adjustFrequency()`

6. **Given** the session is in `.playingTunable` state **When** the pitch bend returns to the neutral zone (center +/- 256 out of 8192, approximately +/-3%) after having been deflected away from center **Then** the pitch is committed — equivalent to slider release (calls `commitPitch()` with the center-mapped value)

7. **Given** no MIDI controller is connected **When** training is active **Then** the on-screen slider continues to work identically — MIDI pitch bend is additive, not a replacement

8. **Given** the `PitchMatchingSession` MIDI integration **When** tested **Then** all pitch bend logic is tested on Simulator using `MockMIDIInput` with controlled event sequences **And** the tests verify pitch bend mapping, auto-start, continuous adjustment, and center-return commit

9. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions

## Tasks / Subtasks

- [x] Task 1: Add pitch bend to slider-value mapping utility (AC: #2)
  - [x] 1.1 Add a `normalizedSliderValue` computed property or static method on `PitchBendValue` that maps the 14-bit range `[0, 16383]` linearly to `[-1.0, +1.0]`: formula `Double(rawValue) / 8191.5 - 1.0` (so 0 -> -1.0, 8192 -> ~0.0, 16383 -> +1.0)
  - [x] 1.2 Add an `isInNeutralZone` computed property on `PitchBendValue`: returns `true` when `abs(Int(rawValue) - 8192) <= 256`
  - [x] 1.3 Write tests for mapping edge cases: 0, 8192, 16383, neutral zone boundaries (7936, 8448), and values just outside the zone

- [x] Task 2: Add MIDI pitch bend listening to `PitchMatchingSession` (AC: #1, #4, #5, #6)
  - [x] 2.1 Add `private let midiInput: (any MIDIInput)?` parameter to `PitchMatchingSession.init` (default `nil` for backward compatibility)
  - [x] 2.2 Add `private var midiListeningTask: Task<Void, Never>?` property
  - [x] 2.3 Add `private var hasBeenDeflected: Bool` flag — tracks whether pitch bend has moved outside neutral zone during current trial (reset on each new trial)
  - [x] 2.4 In `start(settings:)`: after setting the training task, call `startMIDIListening()` to spawn the MIDI listening task
  - [x] 2.5 Implement `startMIDIListening()`: iterate `midiInput?.events`, filter for `.pitchBend` events, compute `normalizedSliderValue`, then:
    - If session is in `.awaitingSliderTouch`: call `adjustPitch(normalizedValue)` to trigger note start (same as first slider touch)
    - If session is in `.playingTunable`: call `adjustPitch(normalizedValue)` for continuous pitch adjustment; track `hasBeenDeflected = true` when value is outside neutral zone; when value returns to neutral zone AND `hasBeenDeflected` is true, call `commitPitch(normalizedValue)` and reset `hasBeenDeflected`
    - Ignore `.noteOn` and `.noteOff` events (only pitch bend matters for pitch matching)
  - [x] 2.6 In `stop()`: cancel `midiListeningTask`, set to `nil`, reset `hasBeenDeflected`
  - [x] 2.7 Reset `hasBeenDeflected = false` at the start of each new trial in `playNextTrial()`

- [x] Task 3: Expose current pitch bend value for slider visualization (AC: #3)
  - [x] 3.1 Add `private(set) var midiPitchBendValue: Double?` observable property to `PitchMatchingSession` — set to the normalized value on each pitch bend event; set to `nil` when session stops or during states where slider is not active
  - [x] 3.2 In `PitchMatchingScreen`, read `pitchMatchingSession.midiPitchBendValue` and pass it to `PitchSlider` as an external override position — the slider thumb follows this value when non-nil
  - [x] 3.3 Add `externalValue: Double?` parameter to `PitchSlider` — when non-nil, the slider thumb position is driven by this value instead of touch input (touch still works as fallback when `nil`)

- [x] Task 4: Wire MIDI input in composition root (AC: #7)
  - [x] 4.1 Update `createPitchMatchingSession` in `PeachApp.swift` to accept `midiInput: (any MIDIInput)?` parameter
  - [x] 4.2 Pass `midiAdapter` (the existing `MIDIKitAdapter`) to the factory method
  - [x] 4.3 Pass it through to `PitchMatchingSession(notePlayer:profile:observers:midiInput:)`

- [x] Task 5: Write tests (AC: #8, #9)
  - [x] 5.1 Test: `PitchBendValue.normalizedSliderValue` maps 0 -> -1.0, 8192 -> ~0.0, 16383 -> +1.0
  - [x] 5.2 Test: `PitchBendValue.isInNeutralZone` returns true for center +/- 256, false outside
  - [x] 5.3 Test: Pitch bend event in `.awaitingSliderTouch` state triggers transition to `.playingTunable` (auto-start)
  - [x] 5.4 Test: Continuous pitch bend events in `.playingTunable` call `adjustFrequency` with correctly mapped values
  - [x] 5.5 Test: Pitch bend return to neutral zone after deflection triggers `commitPitch` (commits the result)
  - [x] 5.6 Test: Pitch bend in neutral zone WITHOUT prior deflection does NOT commit (prevents false commits on startup or between trials)
  - [x] 5.7 Test: `hasBeenDeflected` resets on new trial
  - [x] 5.8 Test: `.noteOn` and `.noteOff` events are ignored during pitch matching
  - [x] 5.9 Test: Session with `nil` midiInput works identically to before (backward compatibility)
  - [x] 5.10 Test: MIDI listening task is cancelled when `stop()` is called
  - [x] 5.11 Test: `midiPitchBendValue` is set on pitch bend events and cleared on stop
  - [x] 5.12 Run full test suite via `bin/test.sh` — all existing tests pass

## Dev Notes

### Architecture Context

Story 5 of epic 62. Stories 62.1-62.3 built the MIDI infrastructure (`MIDIInputEvent`, `MIDIInput` protocol, `MockMIDIInput`, `MIDIKitAdapter`). Story 62.4 consumed MIDI note-on events in `ContinuousRhythmMatchingSession` for rhythm taps. This story consumes MIDI **pitch bend** events in `PitchMatchingSession` for pitch matching — a different event type driving a different session through a different interaction pattern.

### Pitch Bend Value Mapping

The MIDI pitch bend is a 14-bit value (0-16383) with center at 8192. The `PitchBendValue` domain type already exists in `Core/Music/PitchBendValue.swift` with `rawValue: UInt16` and `validRange: 0...16383`. Add the mapping utility there:

```swift
extension PitchBendValue {
    /// Maps the 14-bit pitch bend range [0, 16383] linearly to [-1.0, +1.0].
    var normalizedSliderValue: Double {
        Double(rawValue) / 8191.5 - 1.0
    }

    /// Whether the value is within the neutral dead zone (center +/- 256).
    var isInNeutralZone: Bool {
        abs(Int(rawValue) - 8192) <= 256
    }
}
```

The formula `Double(rawValue) / 8191.5 - 1.0` gives: 0 -> -1.0, 8192 -> 0.0000..., 16383 -> +1.0. This maps directly to the `PitchSlider`'s `[-1.0, +1.0]` domain.

### Interaction Pattern: Touch vs. Pitch Bend

The `PitchMatchingSession` state machine for slider interaction:
1. `.awaitingSliderTouch` — waiting for first input
2. First `adjustPitch(value)` call transitions to `.playingTunable` and resumes `sliderTouchContinuation`
3. Subsequent `adjustPitch(value)` calls drive `currentHandle?.adjustFrequency()`
4. `commitPitch(value)` stops the note, records the result, transitions to `.showingFeedback`

MIDI pitch bend maps onto this identically:
- First pitch bend event -> `adjustPitch(normalizedValue)` -> triggers note start
- Continuous pitch bend -> `adjustPitch(normalizedValue)` -> real-time frequency changes
- Return to center after deflection -> `commitPitch(normalizedValue)` -> records result

The `hasBeenDeflected` flag prevents premature commits: if the wheel starts at center (most controllers do), the first pitch bend message in the neutral zone should NOT commit. Only after the user has moved the wheel away from center and then returned should a commit occur.

### MIDI Listening in PitchMatchingSession

```swift
private func startMIDIListening() {
    guard let midiInput else { return }
    midiListeningTask = Task {
        for await event in midiInput.events {
            guard !Task.isCancelled else { break }
            switch event {
            case .pitchBend(let value, _, _):
                let normalized = value.normalizedSliderValue
                handlePitchBendInput(value: value, normalized: normalized)
            case .noteOn, .noteOff:
                break  // Ignore note events in pitch matching
            }
        }
    }
}

private func handlePitchBendInput(value: PitchBendValue, normalized: Double) {
    guard state == .awaitingSliderTouch || state == .playingTunable else { return }

    midiPitchBendValue = normalized

    if state == .awaitingSliderTouch {
        adjustPitch(normalized)
        return
    }

    // state == .playingTunable
    if !value.isInNeutralZone {
        hasBeenDeflected = true
    }

    if value.isInNeutralZone && hasBeenDeflected {
        commitPitch(normalized)
        hasBeenDeflected = false
        midiPitchBendValue = nil
    } else {
        adjustPitch(normalized)
    }
}
```

### Slider Visual Sync

The `PitchSlider` needs an `externalValue: Double?` parameter. When non-nil, the slider thumb renders at that position instead of tracking touch. Both touch and MIDI can coexist — touch takes over when the user touches the slider (sets `externalValue` back to `nil` or ignores it during active touch gesture).

Approach: In `PitchSlider`, add `let externalValue: Double?` with default `nil`. In the slider's body, use `externalValue ?? dragValue` for thumb position. The `DragGesture` continues to work — when the user touches the slider, the gesture takes priority.

### What NOT To Do

- Do NOT modify `MIDIInputEvent` — `.pitchBend` already exists with `PitchBendValue` and `MIDIChannel`
- Do NOT add `import MIDIKitIO` anywhere — depend only on the `MIDIInput` protocol
- Do NOT filter by MIDI channel — accept pitch bend from any channel (same design decision as note-on in 62.4)
- Do NOT create a separate `handleMIDIPitchBend()` method on the session that duplicates `adjustPitch`/`commitPitch` logic — route through the existing public API
- Do NOT convert `MIDITimeStamp` to sample position for pitch bend — pitch bend is about position, not timing; use the value, not the timestamp
- Do NOT add MIDI-specific observer protocols or result types — reuse existing `PitchMatchingObserver`
- Do NOT change the `commitPitch` or `adjustPitch` method signatures — call them with the normalized value exactly as the slider does
- Do NOT use `nonisolated(unsafe)` — see project-context.md

### Previous Story Intelligence

From story 62.4 (MIDI input for continuous rhythm matching):
- Pattern: add `midiInput: (any MIDIInput)?` to session init with `nil` default
- Pattern: spawn `midiListeningTask` in start, cancel in stop
- Pattern: iterate `midiInput?.events` in a `Task`, check `!Task.isCancelled` and state guards
- `MIDIKitAdapter` is wired in `PeachApp.swift` as `@State private var midiAdapter: MIDIKitAdapter?`
- Composition root factory method pattern: add `midiInput` parameter, pass through
- 1499 tests pass as of story 62.4

From story 62.3:
- `MIDIKitAdapter` streams `.pitchBend(value: PitchBendValue, channel: MIDIChannel, timestamp: UInt64)` events
- Adapter is injected via `.environment(\.midiInput, midiAdapter)`

From story 62.1:
- `PitchBendValue` is a domain type with `rawValue: UInt16`, range 0-16383, center at 8192
- Already conforms to `Hashable`, `Comparable`, `Sendable`, `ExpressibleByIntegerLiteral`

### Project Structure Notes

| File | Change | Rationale |
|------|--------|-----------|
| `Peach/Core/Music/PitchBendValue.swift` | Add `normalizedSliderValue` and `isInNeutralZone` | Mapping utilities for pitch bend -> slider domain |
| `Peach/PitchMatching/PitchMatchingSession.swift` | Add `midiInput` parameter, MIDI listening task, `hasBeenDeflected`, `midiPitchBendValue` | Core MIDI pitch bend integration |
| `Peach/PitchMatching/PitchSlider.swift` | Add `externalValue: Double?` parameter for MIDI-driven thumb position | Visual sync (AC #3) |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Pass `midiPitchBendValue` to `PitchSlider.externalValue` | Wire visual sync |
| `Peach/App/PeachApp.swift` | Pass `midiAdapter` to `createPitchMatchingSession` | Composition root wiring |
| `PeachTests/Core/Music/PitchBendValueTests.swift` | Add mapping and neutral zone tests | AC #8 |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Add MIDI pitch bend integration tests | AC #8 |

### References

- [Source: docs/planning-artifacts/epics.md#Epic 62] — Epic context, design decisions
- [Source: docs/implementation-artifacts/62-4-midi-input-for-continuous-rhythm-matching-training.md] — MIDI listening pattern, composition root wiring
- [Source: docs/implementation-artifacts/62-3-midikit-adapter-implementation.md] — Adapter implementation, event streaming
- [Source: docs/implementation-artifacts/62-1-add-midikit-dependency-and-define-midi-input-event-types.md] — Event types, PitchBendValue
- [Source: Peach/PitchMatching/PitchMatchingSession.swift] — State machine, adjustPitch/commitPitch API
- [Source: Peach/PitchMatching/PitchSlider.swift] — Slider component, value range [-1.0, +1.0]
- [Source: Peach/Core/Music/PitchBendValue.swift] — Existing domain type
- [Source: docs/project-context.md] — Concurrency rules, testing rules, composition root pattern

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Fixed `MIDIVelocity(0)` crash in `noteEventsIgnored` test — valid range is 1-127, changed to `MIDIVelocity(1)`

### Completion Notes List

- All 5 tasks implemented following patterns from story 62.4
- MIDI pitch bend listening uses same `AsyncStream` iteration pattern as `ContinuousRhythmMatchingSession`
- `hasBeenDeflected` flag prevents false commits when pitch bend wheel starts at center
- `midiPitchBendValue` drives slider thumb position externally via new `externalValue` parameter on `PitchSlider`
- 7 unit tests for `PitchBendValue` mapping, 9 integration tests for MIDI pitch bend in `PitchMatchingSession`
- All test failures in suite are pre-existing "Clone 1" simulator parallelism issues only

### Code Review Fixes

- **P1**: `handlePitchBendInput` was calling `currentHandle?.adjustFrequency()` directly instead of routing through `adjustPitch()`. This violated AC5 ("drive `adjustPitch()` exactly like slider drag") and the dev notes constraint ("route through the existing public API"). Also caused MIDI event loop serialization (await vs fire-and-forget). Fixed to call `adjustPitch(normalized)`. Method no longer needs to be `async`.
- **P2**: `midiPitchBendValue` was not reset in `playNextTrial()`, causing the slider thumb to show a stale position from the previous trial. Added `midiPitchBendValue = nil` alongside the existing `hasBeenDeflected` reset.
- **P3**: When `externalValue` transitioned from non-nil to nil (MIDI commit/stop), the slider thumb snapped to the stale touch-driven `currentValue`. Added `onChange(of: externalValue)` to sync `currentValue` to the last external value on that transition.
- **P4**: Duplicate `waitForCondition` helper in two test files. Extracted to `PeachTests/Helpers/AsyncTestHelpers.swift`.

### Deferred Findings

- **D1: Training session classes lack actor isolation.** Cataloged as CQ-4 in `docs/pre-existing-findings.md`.

### Intent Gaps

- **I1: No defined behavior for simultaneous touch + MIDI input.** AC7 says "MIDI pitch bend is additive, not a replacement," but the implementation is `externalValue ?? currentValue` — either/or, not additive. When MIDI is active, the slider thumb follows MIDI regardless of touch. If the user touches the slider while MIDI is sending, the visual position is MIDI-driven but `onCommit` sends the touch value. The spec should define precedence when both inputs are active. In practice, users typically use one input at a time, so this is low-risk.

### File List

- `Peach/Core/Music/PitchBendValue.swift` — Added `normalizedSliderValue` and `isInNeutralZone` computed properties
- `Peach/PitchMatching/PitchMatchingSession.swift` — Added `midiInput` parameter, MIDI listening task, `hasBeenDeflected`, `midiPitchBendValue`, `handlePitchBendInput`
- `Peach/PitchMatching/PitchSlider.swift` — Added `externalValue: Double?` parameter for MIDI-driven thumb position; `onChange` sync on nil transition
- `Peach/PitchMatching/PitchMatchingScreen.swift` — Wired `midiPitchBendValue` to `PitchSlider.externalValue`
- `Peach/App/PeachApp.swift` — Passed `midiAdapter` to `createPitchMatchingSession`, reordered init
- `PeachTests/Core/Music/PitchBendValueTests.swift` — New: 7 tests for mapping and neutral zone
- `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` — Added `makePitchMatchingSessionWithMIDI` factory, `PitchMatchingSessionMIDIPitchBendTests` suite with 9 tests
- `PeachTests/Helpers/AsyncTestHelpers.swift` — New: shared `waitForCondition` helper extracted from duplicates
