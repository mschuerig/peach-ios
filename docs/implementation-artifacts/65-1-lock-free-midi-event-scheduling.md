# Story 65.1: Lock-Free MIDI Event Scheduling in SoundFontEngine

Status: review

## Story

As a **user training rhythm at fast tempos**,
I want every scheduled MIDI event to be dispatched reliably,
so that I never hear dropped notes or timing gaps caused by lock contention between the main thread and the audio render thread.

## Acceptance Criteria

1. **Given** the audio render callback in `SoundFontEngine` **When** the main thread is updating the event schedule **Then** the render thread still dispatches all due MIDI events — no events are silently dropped.

2. **Given** the current try-lock pattern (`withLockIfAvailable`) in the render callback **When** replaced **Then** a lock-free mechanism (e.g., double-buffered event arrays, lock-free ring buffer, or atomic pointer swap) is used so the render thread never blocks and never skips a frame.

3. **Given** the main thread schedules new events **When** the schedule is swapped **Then** the swap is atomic — the render thread sees either the old complete schedule or the new complete schedule, never a partial state.

4. **Given** high-tempo rhythm patterns (200 BPM) with 4 events per beat **When** the step sequencer refills the schedule **Then** zero events are lost (verified by test with event counting).

5. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Analyze current locking strategy (AC: #1, #2)
  - [x] 1.1 Read `SoundFontEngine.swift` — map the render callback's lock acquisition, the main thread's schedule update, and the shared `ScheduleData` struct
  - [x] 1.2 Document exactly which fields are shared and which access patterns exist (read-only in render, read-write on main)

- [x] Task 2: Design lock-free scheduling (AC: #2, #3)
  - [x] 2.1 Option A: **Double-buffered event arrays** — main thread writes to back buffer, atomically swaps pointer. Render thread reads from front buffer without locking
  - [x] 2.2 Option B: **Lock-free SPSC ring buffer** — main thread enqueues events, render thread dequeues. Natural for streaming event schedules
  - [x] 2.3 Option C: **Atomic pointer swap** on the entire `ScheduleData` — main thread prepares a new `ScheduleData`, publishes via `os_unfair_lock`-free atomic store
  - [x] 2.4 Choose based on: simplicity, compatibility with existing `ScheduleData` structure, and testability

- [x] Task 3: Implement the chosen approach (AC: #1, #2, #3)
  - [x] 3.1 Replace `withLockIfAvailable` in the render callback with the lock-free read path
  - [x] 3.2 Replace the main-thread lock acquisition with the lock-free write/swap path
  - [x] 3.3 Preserve all existing behavior: sample position tracking, event dispatch ordering, pitch bend, note-off scheduling

- [x] Task 4: Write tests (AC: #4, #5)
  - [x] 4.1 Test: schedule 500 events, verify all 500 are dispatched (via atomic dispatch counter)
  - [x] 4.2 Test: concurrent schedule update during render — no events from new schedule are lost
  - [x] 4.3 Stress test: rapid schedule updates at 200 BPM equivalent timing — verify event count matches expected

- [x] Task 5: Run full test suite (AC: #5)

## Dev Notes

### Current Problem

`SoundFontEngine` uses `OSAllocatedUnfairLock` with a try-lock in the render callback:

```swift
// Render thread (audio callback)
guard let data = lock.withLockIfAvailable({ scheduleData }) else {
    return  // ENTIRE FRAME SKIPPED — all events in this frame are lost
}
```

When the main thread holds the lock (during `scheduleEvents()` or `clearSchedule()`), the render callback returns without dispatching any MIDI events for that frame. At 44.1kHz with 512-sample buffers, each frame is ~11.6ms. A single missed frame at 200 BPM (one sixteenth note = 75ms) loses ~15% of the timing window.

### The events are not deferred — they're lost. The render callback doesn't retry; it returns silence for that frame and moves on.

### Design Constraints

- Render thread **must not block** — no locks, no allocation, no syscalls
- Main thread can block briefly (acceptable for schedule preparation)
- Events must be dispatched in sample-position order
- `samplePosition` tracking must remain accurate across buffer boundaries
- The fix must work with the existing `SoundFontStepSequencer` refill pattern

### Source File Locations

| File | Path |
|------|------|
| SoundFontEngine | `Peach/Core/Audio/SoundFontEngine.swift` |
| SoundFontStepSequencer | `Peach/Core/Audio/SoundFontStepSequencer.swift` |
| SoundFontPlayer | `Peach/Core/Audio/SoundFontPlayer.swift` |

### References

- [Source: Peach/Core/Audio/SoundFontEngine.swift] — Render callback with try-lock
- [Source: Peach/Core/Audio/SoundFontStepSequencer.swift] — Schedule refill pattern

## Dev Agent Record

### Implementation Plan

**Chosen approach:** Option A — Double-buffered event arrays with atomic generation counter (hybrid of Options A and C).

- Two pre-allocated `UnsafeMutablePointer<ScheduledMIDIEvent>` event buffers (slots 0 and 1)
- `Atomic<Int>` generation counter from `Synchronization` module; active slot = `generation % 2`
- Main thread writes to inactive slot, then atomically increments generation with `.releasing` ordering
- Render thread loads generation with `.acquiring` ordering, detects changes, resets cursor
- Separate `Atomic<Int64/UInt64>` for timing state (samplePosition, hostTime) — written by render thread, read by main thread
- MIDI blocks copied into each slot's 16-element `UnsafeMutablePointer<AUScheduleMIDIEventBlock?>` on `scheduleEvents`
- `Atomic<Int>` dispatch counter for test verification; reset by render thread on generation change
- Removed `OSAllocatedUnfairLock<ScheduleData>` entirely — render thread never blocks

**Safety invariant (documented in code):** Double-buffering ensures no concurrent read-write on the same slot. The main thread writes only to the inactive slot. The generation counter's release/acquire ordering ensures all slot writes are visible before the render thread reads them.

### Completion Notes

- Replaced `OSAllocatedUnfairLock` + `withLockIfAvailable` with `DoubleBufferedScheduleState` class using `Atomic` from `Synchronization` module
- Render thread never blocks — reads active slot directly, no lock acquisition
- All 1619 tests pass with zero regressions on two consecutive runs
- Added 4 new tests verifying lock-free dispatch: 500-event full dispatch, schedule replacement, 200 BPM stress test, counter reset semantics
- Dispatch counter reset moved to render thread (on generation change detection) to eliminate race between main thread reset and render thread increment

## File List

- `Peach/Core/Audio/SoundFontEngine.swift` — Replaced `ScheduleData` + `OSAllocatedUnfairLock` with `DoubleBufferedScheduleState` + `Atomic`; updated render callback, `scheduleEvents`, `clearSchedule`, `scheduledEventCount`, `currentSamplePosition`, `samplePosition(forHostTime:)`; added `dispatchedEventCount`; removed `scheduleBuffer` property
- `PeachTests/Core/Audio/SoundFontEngineTests.swift` — Added 4 new tests: `allEventsDispatched`, `scheduleReplacementDispatchesNewEvents`, `stressTestRapidScheduleUpdates`, `dispatchCounterResetsOnNewSchedule`
- `docs/implementation-artifacts/sprint-status.yaml` — Updated epic-65 and 65-1 status

## Change Log

- Replaced lock-based MIDI event scheduling with lock-free double-buffered approach using `Synchronization.Atomic` (Date: 2026-03-28)
