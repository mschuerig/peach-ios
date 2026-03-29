# Story: Low-Latency Tap Sound via Render-Thread Dispatch

Status: draft

## Story

As a musician practicing continuous rhythm matching,
I want the tap feedback sound to be sample-accurate like the pattern notes,
so that the auditory feedback precisely reflects my timing instead of lagging behind my tap.

## Background

Pattern notes are sample-accurate because they're dispatched inline during the audio render callback via `SoundFontEngine`'s double-buffered schedule. Tap feedback takes a slower path: SwiftUI gesture → MainActor → `AVAudioUnitSampler.startNote()` → audio render thread. This adds noticeable latency (~8–16 ms) and jitter that varies with MainActor load.

Story 65.1 introduced lock-free double-buffered scheduling for pattern notes, but tap notes still bypass this system entirely. The infrastructure for sample-accurate dispatch exists — tap notes just need a way to inject into it.

**Source:** future-work.md "Low-Latency Tap Sound for Continuous Rhythm Matching"

## Acceptance Criteria

1. **Tap sound dispatched on the render thread:** `immediateNoteOn` must route through the audio render callback's MIDI dispatch, not through `AVAudioUnitSampler.startNote()` from the MainActor. The tap note must be dispatched at (or near) the current sample position.

2. **Pattern playback unaffected:** The existing double-buffered schedule for pattern notes must not be disturbed. Tap events and pattern events must coexist without interference — a tap must not cause a pattern note to be skipped or delayed.

3. **Note-off dispatched on the render thread:** The corresponding note-off must also be render-thread dispatched (after a short duration), not scheduled via `Task.sleep` from the MainActor as today.

4. **No audible regression:** Pattern notes remain sample-accurate. Tap latency is reduced to within one audio buffer frame (~5 ms at 256-sample buffer, ~2.7 ms at 128-sample buffer).

5. **Thread safety:** The mechanism for injecting immediate events must be lock-free and safe for concurrent access from the main thread (writer) and the audio render thread (reader). No locks, no blocking, no undefined behavior.

6. **Existing tests pass:** All `SoundFontEngineTests` and `ContinuousRhythmMatchingSessionTests` must continue to pass. New tests must verify immediate event dispatch.

## Tasks / Subtasks

- [ ] Task 1: Add immediate event slot to `DoubleBufferedScheduleState` (AC: #1, #5)
  - [ ] Add a small lock-free ring buffer or single-slot atomic for immediate events, separate from the pattern event buffers
  - [ ] The main thread writes immediate events; the render thread reads and dispatches them
  - [ ] Use atomic operations for visibility (same acquire/release pattern as the generation counter)

- [ ] Task 2: Route `immediateNoteOn`/`Off` through the render callback (AC: #1, #3)
  - [ ] Replace `sampler.startNote()` calls in `immediateNoteOn` with a write to the immediate event slot
  - [ ] Schedule both note-on and note-off as immediate events (note-off offset = current sample position + duration in samples)
  - [ ] Remove the `Task.sleep`-based note-off in `SoundFontStepSequencer.playImmediateNote()`

- [ ] Task 3: Dispatch immediate events in the render callback (AC: #1, #2, #4)
  - [ ] In the render callback, after dispatching scheduled pattern events, check and dispatch any pending immediate events
  - [ ] Immediate events at sample offset ≤ current frame start should dispatch at frame offset 0
  - [ ] Ensure pattern event dispatch is not affected

- [ ] Task 4: Tests (AC: #6)
  - [ ] Test that an immediate event is dispatched within one render callback cycle
  - [ ] Test that immediate and scheduled events coexist without interference
  - [ ] Test note-off fires after the specified duration
  - [ ] Verify no regression in existing pattern scheduling tests

## Dev Notes

### Current Architecture

**Two dispatch paths today:**

1. **Scheduled (sample-accurate):** `scheduleEvents()` writes to inactive slot of `DoubleBufferedScheduleState`, increments generation atomically. Render callback reads active slot, dispatches events via `AUScheduleMIDIEventBlock` at exact sample offsets. Used by pattern notes.

2. **Immediate (MainActor-bound):** `immediateNoteOn()` calls `sampler.startNote()` directly from the main thread. No render callback involvement. Used by tap feedback. `SoundFontStepSequencer.playImmediateNote()` manages note-off via `Task.sleep`.

### Design Approach: Immediate Event Ring Buffer

Add a small lock-free SPSC (single-producer, single-consumer) ring buffer to `DoubleBufferedScheduleState` for immediate events. This is separate from the double-buffered pattern slots:

- **Main thread (producer):** Writes `ScheduledMIDIEvent` with `sampleOffset = currentSamplePosition` (read from `scheduleState.samplePosition` atomic)
- **Render thread (consumer):** Drains the ring buffer each frame, dispatching any events with `sampleOffset ≤ frameStartSample + frameLength`
- **Capacity:** Small (e.g., 8–16 events) — only tap notes, never a full pattern
- **Ordering:** Atomic head/tail indices with acquire/release semantics

This approach:
- Keeps the double-buffered pattern schedule untouched (AC #2)
- Is lock-free (AC #5)
- Achieves within-one-frame latency (AC #4)

### Key Files

- `Peach/Core/Audio/SoundFontEngine.swift` — `DoubleBufferedScheduleState`, `immediateNoteOn/Off`, render callback
- `Peach/Core/Audio/SoundFontStepSequencer.swift` — `playImmediateNote(velocity:)` (caller of `immediateNoteOn`)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — `handleTap()` (triggers tap sound)
- `PeachTests/Core/Audio/SoundFontEngineTests.swift` — existing render-thread dispatch tests

### What NOT to Change

- The double-buffered pattern scheduling mechanism — do not merge immediate events into pattern slots
- `startNote`/`stopNote` methods used by `SoundFontPlayer` for pitch training — those use a different channel and path
- `ContinuousRhythmMatchingSession.handleTap()` call site — it should still call `stepSequencer.playImmediateNote()`, the change is internal to the engine

### Project Structure Notes

- No new files needed — all changes in existing audio engine files
- Ring buffer implementation goes inside `DoubleBufferedScheduleState` (same file as existing lock-free primitives)

### References

- [Source: docs/implementation-artifacts/future-work.md#Low-Latency Tap Sound]
- [Source: Peach/Core/Audio/SoundFontEngine.swift — DoubleBufferedScheduleState, immediateNoteOn/Off]
- [Source: Peach/Core/Audio/SoundFontStepSequencer.swift lines 147–158 — playImmediateNote]
- [Source: docs/implementation-artifacts/65-1-lock-free-midi-event-scheduling.md — lock-free pattern scheduling design]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
