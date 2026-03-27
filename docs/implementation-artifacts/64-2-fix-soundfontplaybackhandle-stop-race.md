# Story 64.2: Fix SoundFontPlaybackHandle Stop Race Condition

Status: done

## Story

As a **user training with Peach**,
I want playback handles to stop cleanly even when stop is called concurrently,
so that the audio engine's mute count stays balanced and notes don't get stuck muted or unmuted.

## Acceptance Criteria

1. **Given** a `SoundFontPlaybackHandle` that is active **When** `stop()` is called twice concurrently **Then** only the first call executes the mute/fade sequence; the second call is a no-op.

2. **Given** `SoundFontEngine.activeMuteCount` **When** a handle is stopped **Then** the count is decremented exactly once per handle, never twice.

3. **Given** `ContinuousRhythmMatchingSession.nextCycle()` **When** `stop()` is called concurrently **Then** `gapPositions` is not mutated concurrently — the fallback path does not append to the array after `stop()` has cleared it.

4. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Fix `SoundFontPlaybackHandle.stop()` double-stop race (AC: #1, #2)
  - [x] 1.1 Read `SoundFontPlaybackHandle.swift` and identify the `hasStopped` guard
  - [x] 1.2 Ensure `hasStopped` is set to `true` before any async work begins — the check-and-set must not have a window where both calls pass the guard
  - [x] 1.3 Since this code runs on `@MainActor`, verify that no unstructured Task dispatches the stop sequence off the main actor

- [x] Task 2: Fix `ContinuousRhythmMatchingSession.nextCycle()` concurrent mutation (AC: #3)
  - [x] 2.1 Read `ContinuousRhythmMatchingSession.swift` and find the fallback path in `nextCycle()` that appends to `gapPositions` when `isRunning` is false
  - [x] 2.2 Remove the append in the fallback guard path — when the session is stopped, `nextCycle()` should return a fallback `CycleDefinition` without mutating session state
  - [x] 2.3 Verify that `stop()` clears `gapPositions` and that the sequencer's render thread cannot call `nextCycle()` after `stop()` has completed (or if it can, the fallback is safe)

- [x] Task 3: Write tests (AC: #1, #2, #3, #4)
  - [x] 3.1 Test: `SoundFontPlaybackHandle.stop()` called twice — second call is a no-op (verify via `stopCallCount` or similar)
  - [x] 3.2 Test: `ContinuousRhythmMatchingSession.stop()` followed by `nextCycle()` — `gapPositions` remains empty

- [x] Task 4: Run full test suite (AC: #4)

## Dev Notes

### SoundFontPlaybackHandle Race

The `stop()` method checks `guard !hasStopped else { return }` then sets `hasStopped = true`. On `@MainActor` this should be serialized, but the method is called from Tasks that may dispatch to MainActor. The fix ensures the flag is set immediately and the mute sequence follows.

### ContinuousRhythmMatchingSession.nextCycle() Race

`nextCycle()` is called by the step sequencer's provider closure, which runs from a polling timer. The fallback path (when `isRunning == false`) still appends to `gapPositions`:

```swift
guard isRunning, let settings else {
    let fallback = StepPosition.fourth
    gapPositions.append(fallback)  // <-- mutates after stop
    return CycleDefinition(gapPosition: fallback)
}
```

During `stop()`, `gapPositions.removeAll()` is called. If `nextCycle()` is invoked between the `isRunning = false` assignment and the `removeAll()` call, or after `removeAll()`, it appends a stale value. Fix: remove the append from the fallback path.

### Source File Locations

| File | Path |
|------|------|
| SoundFontPlaybackHandle | `Peach/Core/Audio/SoundFontPlaybackHandle.swift` |
| ContinuousRhythmMatchingSession | `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` |

### References

- [Source: Peach/Core/Audio/SoundFontPlaybackHandle.swift] — hasStopped guard
- [Source: Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift] — nextCycle fallback

## Dev Agent Record

### Implementation Plan

- Task 1: Verified `SoundFontPlaybackHandle.stop()` is already safe — `hasStopped` is set synchronously (line 27) before the first `await` (line 30), and default `@MainActor` isolation serializes all calls. No unstructured Tasks dispatch stop off the main actor. No code change needed.
- Task 2: Removed `gapPositions.append(fallback)` from the `nextCycle()` fallback guard path. The fallback now returns a `CycleDefinition` without mutating session state.
- Task 3: Added `doubleStopKeepsMuteCountBalanced` test (verifies mute count stays balanced after double stop by confirming subsequent play+stop cycles work). Added `nextCycleAfterStopDoesNotMutateState` test (verifies that nextCycle after stop doesn't append to gapPositions by checking evaluatePlaybackPosition doesn't observe stale gap data).
- Task 4: Full test suite passes — 1522 tests, zero regressions.

### Completion Notes

- `SoundFontPlaybackHandle.stop()` was already correctly implemented with the hasStopped guard set before any async suspension point. The adversarial review flagged a theoretical concern, but the code was safe due to `@MainActor` serialization.
- `ContinuousRhythmMatchingSession.nextCycle()` had a real bug: the fallback path mutated `gapPositions` after `stop()` cleared it. Fixed by removing the append — the fallback now returns a CycleDefinition without side effects.
- Both `handleTap()` and `evaluatePlaybackPosition()` already guard against out-of-bounds gapPositions access, so the fix is safe.

## File List

- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` (modified)
- `PeachTests/Core/Audio/SoundFontPlaybackHandleTests.swift` (modified)
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift` (modified)
- `docs/implementation-artifacts/64-2-fix-soundfontplaybackhandle-stop-race.md` (modified)
- `docs/implementation-artifacts/sprint-status.yaml` (modified)

## Change Log

- Removed stale `gapPositions.append()` from `nextCycle()` fallback path to prevent post-stop mutation (2026-03-27)
- Added `doubleStopKeepsMuteCountBalanced` test for SoundFontPlaybackHandle (2026-03-27)
- Added `nextCycleAfterStopDoesNotMutateState` test for ContinuousRhythmMatchingSession (2026-03-27)
