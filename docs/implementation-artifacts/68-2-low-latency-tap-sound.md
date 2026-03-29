# Story 68.2: Low-Latency Tap Sound via Render-Thread Dispatch

Status: done

## Story

As a **musician practicing continuous rhythm matching**,
I want the tap feedback sound to be sample-accurate like the pattern notes,
so that auditory feedback precisely reflects my timing.

## Acceptance Criteria

1. **Given** a tap event **When** dispatching the tap sound **Then** it routes through the audio render callback (not `AVAudioUnitSampler.startNote()` from MainActor).

2. **Given** tap and pattern events **When** playing concurrently **Then** pattern playback is unaffected.

3. **Given** the tap note-off **When** dispatched **Then** it is also render-thread dispatched, not scheduled via `Task.sleep`.

4. **Given** the immediate event mechanism **When** accessed from main thread (writer) and render thread (reader) **Then** it is lock-free with no undefined behavior.

5. **Given** the full test suite **When** run on both platforms **Then** all SoundFontEngineTests and ContinuousRhythmMatchingSessionTests pass.

## Tasks / Subtasks

- [x] Task 1: Add immediate event ring buffer to `DoubleBufferedScheduleState` (AC: #1, #4)
  - [x] 1.1 Add a small lock-free SPSC ring buffer (capacity 8-16) inside `DoubleBufferedScheduleState` for immediate events, separate from the double-buffered pattern slots
  - [x] 1.2 Use atomic head/tail indices with acquire/release semantics for thread safety
  - [x] 1.3 Producer (main thread) writes `ScheduledMIDIEvent` with `sampleOffset` set to current sample position read from `scheduleState.samplePosition`
  - [x] 1.4 Consumer (render thread) drains the ring buffer each frame

- [x] Task 2: Route `immediateNoteOn`/`immediateNoteOff` through the render callback (AC: #1, #3)
  - [x] 2.1 Replace `sampler.startNote()` call in `SoundFontEngine.immediateNoteOn()` with a write to the immediate event ring buffer
  - [x] 2.2 Replace `sampler.stopNote()` call in `SoundFontEngine.immediateNoteOff()` with a write to the ring buffer at current position + note-off duration in samples
  - [x] 2.3 Remove the `Task.sleep`-based note-off in `SoundFontStepSequencer.playImmediateNote()` -- both note-on and note-off are now enqueued atomically

- [x] Task 3: Dispatch immediate events in the render callback (AC: #1, #2)
  - [x] 3.1 In the render callback, after dispatching scheduled pattern events, drain the immediate event ring buffer
  - [x] 3.2 Immediate events with `sampleOffset <= frameStart` dispatch at intra-buffer offset 0
  - [x] 3.3 Immediate events with `sampleOffset` within the current frame dispatch at the correct intra-buffer offset
  - [x] 3.4 Verify pattern event dispatch logic is completely untouched
  - [x] 3.5 Future-timestamped events (`sampleOffset >= windowEnd`) are retained in the ring buffer (peek-without-consume) and deferred to the correct callback

- [x] Task 4: Update `StepSequencerEngine` protocol if needed (AC: #1, #2)
  - [x] 4.1 If `immediateNoteOn`/`immediateNoteOff` signatures change, update the `StepSequencerEngine` protocol and `MockStepSequencerEngine`
  - [x] 4.2 Update `SoundFontStepSequencer.playImmediateNote()` to use the new path (should be simpler -- no Task for note-off)

- [x] Task 5: Tests (AC: #5)
  - [x] 5.1 Test that an immediate event is dispatched within one render callback cycle
  - [x] 5.2 Test that immediate and scheduled events coexist without interference
  - [x] 5.3 Test that note-off fires after the specified duration without `Task.sleep`
  - [x] 5.4 Verify no regression in existing `SoundFontEngineTests` pattern scheduling tests
  - [x] 5.5 Verify `ContinuousRhythmMatchingSessionTests` still pass (mock path unchanged)
  - [x] 5.6 Run `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Current Architecture -- Two Dispatch Paths

1. **Scheduled (sample-accurate):** `scheduleEvents()` writes to inactive slot of `DoubleBufferedScheduleState`, increments generation atomically. Render callback reads active slot, dispatches events via `AUScheduleMIDIEventBlock` at exact sample offsets. Used for pattern notes in the step sequencer.

2. **Immediate (MainActor-bound, current tap path):** `immediateNoteOn()` calls `sampler.startNote()` directly from the main thread. No render callback involvement. `SoundFontStepSequencer.playImmediateNote()` manages note-off via `Task.sleep(for: .milliseconds(50))`. This adds ~8-16 ms latency and jitter that varies with MainActor load.

### Design Approach: Immediate Event Ring Buffer

Add a small lock-free SPSC ring buffer to `DoubleBufferedScheduleState`:

- **Separate from pattern double-buffer**: The ring buffer is independent -- it does not disturb the generation counter or pattern event slots.
- **Main thread (producer)**: Writes both note-on (at current sample position) and note-off (at current position + duration in samples) as two events in one call.
- **Render thread (consumer)**: After pattern event dispatch, drains the ring buffer. Events with `sampleOffset <= currentFrameStart` fire at offset 0; events within the frame fire at correct intra-buffer position.
- **Capacity**: 8-16 events is sufficient -- only tap notes, never a full pattern.

This eliminates `Task.sleep` for note-off entirely and brings tap latency down to within one audio buffer frame (~5 ms at 256-sample buffer).

### What NOT to Change

- The double-buffered pattern scheduling mechanism (generation counter, slot swapping)
- `startNote`/`stopNote` methods used by `SoundFontPlayer` for pitch training (different channel and path)
- `ContinuousRhythmMatchingSession.handleTap()` call site -- it calls `stepSequencer.playImmediateNote()`, the change is internal to the engine
- `MockStepSequencer.playImmediateNote()` -- mock path is unchanged, tests that verify tap behavior at the session level are unaffected

### Project Structure Notes

- All changes in existing files -- no new files needed
- Ring buffer implementation goes inside `DoubleBufferedScheduleState` in `SoundFontEngine.swift`
- `SoundFontStepSequencer.playImmediateNote()` becomes simpler (no Task for note-off)

### References

- [Source: Peach/Core/Audio/SoundFontEngine.swift -- DoubleBufferedScheduleState (lines 27-111), immediateNoteOn/Off (lines 400-408), render callback (lines 203-265)]
- [Source: Peach/Core/Audio/SoundFontStepSequencer.swift -- playImmediateNote (lines 147-158), noteOffTask using Task.sleep]
- [Source: Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift -- handleTap() calls stepSequencer.playImmediateNote()]
- [Source: PeachTests/Core/Audio/SoundFontEngineTests.swift -- existing render-thread dispatch tests]
- [Source: PeachTests/Core/Audio/SoundFontStepSequencerTests.swift -- playImmediateNote tests (lines 451-503)]
- [Source: docs/implementation-artifacts/65-1-lock-free-midi-event-scheduling.md -- lock-free pattern scheduling design]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None

### Completion Notes List
- Added lock-free SPSC ring buffer (capacity 16) with atomic head/tail indices to `DoubleBufferedScheduleState` for immediate events
- `immediateNoteOn`/`immediateNoteOff` now enqueue `ScheduledMIDIEvent` to the ring buffer instead of calling `sampler.startNote()`/`sampler.stopNote()` directly
- Render callback drains immediate ring buffer after pattern events, dispatching at correct intra-buffer offsets
- `SoundFontStepSequencer.playImmediateNote()` simplified to synchronous note-on + note-off enqueue — no more `Task.sleep` or `noteOffTask`
- `StepSequencerEngine` protocol updated — `immediateNoteOff` gains `delaySamples: Int64` parameter for sample-accurate note-off scheduling
- `playImmediateNote()` computes note-off delay from `noteOffDuration` and `sampleRate`, passing it to `immediateNoteOff`
- Early-return guard updated: skips timing/dispatch only when both pattern schedule and immediate ring buffer are empty (preserves existing test semantics while enabling immediate event path)
- Render callback uses peek-before-consume for immediate events: future-timestamped events (e.g., note-off) are retained in the ring buffer until their target callback window
- `clearSchedule()` and generation-change detection now reset the immediate ring buffer to prevent stale events after stop/restart
- `immediateBuffer` properly initialized in `init` and deinitialized in `deinit` for memory safety consistency
- Assertions on `enqueueImmediate` return value to catch ring buffer overflow in debug builds
- Updated existing `SoundFontStepSequencerTests` for synchronous note-off behavior
- Added 3 new integration tests in `SoundFontEngineTests`: immediate dispatch within one frame, coexistence with scheduled events, note-off via render thread

### File List
- Peach/Core/Audio/SoundFontEngine.swift (modified)
- Peach/Core/Audio/SoundFontStepSequencer.swift (modified)
- PeachTests/Core/Audio/SoundFontEngineTests.swift (modified)
- PeachTests/Core/Audio/SoundFontStepSequencerTests.swift (modified)

## Change Log

- 2026-03-29: Story created
- 2026-03-29: Implemented low-latency tap sound via render-thread dispatch with SPSC ring buffer
- 2026-03-29: Code review fixes — note-off duration offset, peek-before-consume for future events, ring buffer reset on clearSchedule, buffer init/deinit, enqueue assertions
