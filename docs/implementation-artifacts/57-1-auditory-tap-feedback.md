# Story 57.1: Auditory Tap Feedback

Status: review

## Story

As a **user training continuous rhythm matching**,
I want my tap to produce the same click sound as the sequencer notes,
So that I hear my timing as part of the rhythm and can judge my accuracy by ear.

## Context

Currently `ContinuousRhythmMatchingSession.handleTap()` records the tap time via `CACurrentMediaTime()`, evaluates the offset, and shows visual feedback — but produces no sound. The user fills a gap in the rhythm silently, which makes it hard to judge timing by ear.

This story adds immediate note playback on tap. The tap triggers the same MIDI note (76) at the appropriate velocity (accent for beat one, normal for other positions). The tap instant is both the trigger time and the measurement point — a DAW recording of the session should show perfectly spaced notes for a perfect performance.

### Key files

- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — `handleTap()`
- `Peach/Core/Audio/SoundFontStepSequencer.swift` — audio engine, note scheduling
- `Peach/Core/Audio/StepSequencer.swift` — `StepSequencer` protocol, `StepVelocity`
- `Peach/Core/Audio/SoundFontEngine.swift` — low-level MIDI event scheduling

## Acceptance Criteria

1. **Tap plays a note** — When the user taps within the gap window, a MIDI note-on for note 76 is triggered immediately on the step sequencer's audio channel.

2. **Velocity matches position** — If the gap is at beat one (`.first`), the note plays at accent velocity (127). Otherwise, normal velocity (100).

3. **Note duration** — The tap-triggered note has the same note-off delay as sequencer notes (50ms).

4. **Measurement point unchanged** — The tap instant (`currentTime()`) remains the measurement point for offset calculation. Since the note triggers at tap time, these are effectively the same moment.

5. **Protocol extension** — `StepSequencer` protocol gains a method for immediate (non-scheduled) note playback, e.g., `func playImmediateNote(velocity: MIDIVelocity) throws`.

6. **Taps outside the window** — No sound is produced for taps that fall outside the evaluation window (they are still silently ignored).

7. **All existing tests pass** with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Add immediate note playback to `StepSequencer` protocol
  - [x] Add `func playImmediateNote(velocity: MIDIVelocity) throws` to `StepSequencer`
  - [x] Update `MockStepSequencer` in tests to record calls

- [x] Task 2: Implement in `SoundFontStepSequencer`
  - [x] Schedule a note-on event at `currentSamplePosition` (i.e., "now") via `engine.scheduleEvents()`
  - [x] Schedule the corresponding note-off at `currentSamplePosition + noteOffDelaySamples`
  - [x] Use the same MIDI note (76) and channel as the sequencer's regular notes

- [x] Task 3: Call from `ContinuousRhythmMatchingSession.handleTap()`
  - [x] After confirming the tap is within the window, determine the velocity from the gap position
  - [x] Call `stepSequencer.playImmediateNote(velocity:)`
  - [x] Handle errors gracefully (log, don't crash — audio glitches shouldn't stop training)

- [x] Task 4: Update tests
  - [x] Test that `handleTap()` within window calls `playImmediateNote` with correct velocity
  - [x] Test accent velocity for gap at `.first`, normal velocity for other positions
  - [x] Test that taps outside the window do not trigger note playback
  - [x] Test that `playImmediateNote` schedules correct MIDI events at current sample position

## Dev Agent Record

### Implementation Plan

- Added `playImmediateNote(velocity:)` to the `StepSequencer` protocol as a synchronous throwing method
- `StepSequencerEngine` protocol gained `immediateNoteOn`/`immediateNoteOff` for direct MIDI dispatch — these bypass the render-thread schedule buffer entirely, preventing schedule corruption
- `SoundFontStepSequencer` implements `playImmediateNote` using direct MIDI dispatch: `immediateNoteOn` fires immediately, a fire-and-forget Task sends `immediateNoteOff` after 50ms
- `SoundFontEngine` implements `immediateNoteOn`/`immediateNoteOff` by calling `AVAudioUnitSampler.startNote`/`stopNote` directly
- `ContinuousRhythmMatchingSession.handleTap()` determines velocity from gap position (accent for `.first`, normal otherwise) and calls `playImmediateNote` with graceful error handling (log + continue)
- TDD: wrote 6 new tests (4 session tests + 2 sequencer tests), confirmed RED then GREEN

### Completion Notes

- All 4 tasks completed with full test coverage
- 1436 tests pass with zero regressions
- Critical design decision: immediate note playback uses direct MIDI dispatch (`AVAudioUnitSampler.startNote`) rather than `engine.scheduleEvents()`, because `scheduleEvents()` replaces the entire schedule buffer — which would wipe out the pre-scheduled pattern events
- `MockStepSequencer` tracks call count, last velocity, velocity history, and supports error injection
- `PreviewStepSequencer` updated with no-op conformance
- Error handling uses `logger.warning` — audio glitches don't interrupt training

## File List

- `Peach/Core/Audio/StepSequencer.swift` — added `playImmediateNote(velocity:)` to protocol
- `Peach/Core/Audio/SoundFontStepSequencer.swift` — implemented `playImmediateNote(velocity:)`, added `immediateNoteOn`/`immediateNoteOff` to `StepSequencerEngine` protocol
- `Peach/Core/Audio/SoundFontEngine.swift` — implemented `immediateNoteOn`/`immediateNoteOff` via direct `AVAudioUnitSampler` calls
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — call `playImmediateNote` from `handleTap()`
- `Peach/App/EnvironmentKeys.swift` — added no-op `playImmediateNote` to `PreviewStepSequencer`
- `PeachTests/Mocks/MockStepSequencer.swift` — added call tracking for `playImmediateNote`
- `PeachTests/Mocks/MockStepSequencerEngine.swift` — added tracking for `immediateNoteOn`/`immediateNoteOff`
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift` — 4 new tests for tap audio feedback
- `PeachTests/Core/Audio/SoundFontStepSequencerTests.swift` — 2 new tests for immediate note (note-on + schedule non-interference)

## Change Log

- 2026-03-23: Implemented auditory tap feedback — taps within the gap window now play the click sound at position-appropriate velocity. Fixed initial implementation that used `scheduleEvents()` (which replaces the entire schedule buffer) — switched to direct MIDI dispatch via `AVAudioUnitSampler.startNote`/`stopNote`

## Technical Notes

- `SoundFontEngine.scheduleEvents()` accepts events with arbitrary sample offsets. Scheduling at `currentSamplePosition` means "play now" — the render thread picks it up on the next buffer callback (typically within 5–10ms at 44.1kHz with 512-sample buffers). This latency is negligible for the user but means the tap sound is effectively instantaneous.
- The offset measurement still uses `currentTime()` (wall clock), not audio sample time. Since the tap triggers the note immediately, these are equivalent for precision purposes.
- The `StepSequencerEngine` protocol already exposes `currentSamplePosition` and `scheduleEvents()`, so `SoundFontStepSequencer` has everything it needs.
