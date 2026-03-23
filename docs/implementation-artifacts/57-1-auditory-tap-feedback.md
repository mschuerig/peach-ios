# Story 57.1: Auditory Tap Feedback

Status: backlog

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

- [ ] Task 1: Add immediate note playback to `StepSequencer` protocol
  - [ ] Add `func playImmediateNote(velocity: MIDIVelocity) throws` to `StepSequencer`
  - [ ] Update `MockStepSequencer` in tests to record calls

- [ ] Task 2: Implement in `SoundFontStepSequencer`
  - [ ] Schedule a note-on event at `currentSamplePosition` (i.e., "now") via `engine.scheduleEvents()`
  - [ ] Schedule the corresponding note-off at `currentSamplePosition + noteOffDelaySamples`
  - [ ] Use the same MIDI note (76) and channel as the sequencer's regular notes

- [ ] Task 3: Call from `ContinuousRhythmMatchingSession.handleTap()`
  - [ ] After confirming the tap is within the window, determine the velocity from the gap position
  - [ ] Call `stepSequencer.playImmediateNote(velocity:)`
  - [ ] Handle errors gracefully (log, don't crash — audio glitches shouldn't stop training)

- [ ] Task 4: Update tests
  - [ ] Test that `handleTap()` within window calls `playImmediateNote` with correct velocity
  - [ ] Test accent velocity for gap at `.first`, normal velocity for other positions
  - [ ] Test that taps outside the window do not trigger note playback
  - [ ] Test that `playImmediateNote` schedules correct MIDI events at current sample position

## Technical Notes

- `SoundFontEngine.scheduleEvents()` accepts events with arbitrary sample offsets. Scheduling at `currentSamplePosition` means "play now" — the render thread picks it up on the next buffer callback (typically within 5–10ms at 44.1kHz with 512-sample buffers). This latency is negligible for the user but means the tap sound is effectively instantaneous.
- The offset measurement still uses `currentTime()` (wall clock), not audio sample time. Since the tap triggers the note immediately, these are equivalent for precision purposes.
- The `StepSequencerEngine` protocol already exposes `currentSamplePosition` and `scheduleEvents()`, so `SoundFontStepSequencer` has everything it needs.
