# Story 56.1: Quarter-Note Timing Grid Alignment

Status: review

## Story

As a **user training rhythm offset discrimination**,
I want each pattern's first note to land exactly on a quarter-note grid established at session start,
So that I can internalize a continuous beat across trials and judge offsets against a steady pulse.

## Context

Currently `RhythmOffsetDetectionSession` plays patterns back-to-back: play → answer → feedback → play next immediately. There is no temporal alignment between successive patterns, so the user cannot build an internalized beat across trials.

The fix: the first note played in a session establishes a quarter-note grid (period = `tempo.sixteenthNoteDuration * 4`). Before each subsequent pattern, the session waits until the next grid point. The grid is never skipped — even if the wait is very short, the pattern starts on the beat.

### Key files

- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` — state machine, pattern scheduling
- `Peach/Core/Music/TempoBPM.swift` — `sixteenthNoteDuration`, `quarterNoteDuration`

## Acceptance Criteria

1. **Grid origin** — When the first pattern plays, its first note's play time becomes the grid origin `t₀`.

2. **Grid alignment** — Before each subsequent pattern plays, the session computes the next grid point ≥ current time and sleeps until that point. The first note of the pattern plays at that grid point.

3. **Never skip** — The grid is never skipped regardless of how short the wait would be.

4. **Waiting state** — If feedback ends before the next grid point, the session holds (dots dimmed, buttons disabled) until the grid point.

5. **Grid survives variable delays** — Answer time and feedback time may vary; the grid point calculation always uses `t₀ + n * quarterNoteDuration` where `n` is chosen as the smallest integer such that the grid point is ≥ current time.

6. **All existing tests pass** with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Add grid tracking state to `RhythmOffsetDetectionSession`
  - [x] Add `private var gridOrigin: Double?` (set from `currentTime()` when first pattern plays)
  - [x] Add `currentTime: @escaping () -> Double` injectable dependency (following ContinuousRhythmMatchingSession pattern)
  - [x] Add a method `nextGridPoint(quarterNoteDuration:) -> Double` returning `gridOrigin + ceil((now - gridOrigin) / quarterNoteDuration) * quarterNoteDuration`

- [x] Task 2: Align first pattern to grid origin
  - [x] In `playNextTrial()`, on the very first pattern, record `gridOrigin = currentTime()` immediately before playing
  - [x] First pattern needs no wait — it defines the grid

- [x] Task 3: Add grid wait before subsequent patterns
  - [x] After feedback ends (in `transitionToFeedback`'s scheduled callback), compute the next grid point
  - [x] Sleep until that grid point before calling `playNextTrial()`
  - [x] Added `.waitingForGrid` state value with buttons disabled

- [x] Task 4: Update tests
  - [x] Test that first pattern sets grid origin
  - [x] Test that subsequent patterns wait for grid alignment using a mock `currentTime`
  - [x] Test that the grid is never skipped (set current time to just before a grid point, verify the session waits for that point)
  - [x] Test that variable answer+feedback times still produce grid-aligned patterns
  - [x] Test that waitingForGrid state keeps buttons disabled
  - [x] Test that grid origin resets on stop

## Technical Notes

- The `currentTime` closure is already injectable in the session (used for testing). Grid calculations should use the same closure.
- `TempoBPM` already has `sixteenthNoteDuration`. A `quarterNoteDuration` convenience may be useful but can also be computed as `sixteenthNoteDuration * 4`.
- The grid wait replaces the current immediate transition from feedback → playNextTrial. The `feedbackTask` completion handler is the natural place to insert the wait.

## Dev Agent Record

### Implementation Plan
- Added `currentTime: @escaping () -> Double` dependency to `RhythmOffsetDetectionSession` (defaulting to `CACurrentMediaTime()`), following the same pattern as `ContinuousRhythmMatchingSession`
- Added `gridOrigin: Double?` to track when the first pattern established the beat grid
- Added `nextGridPoint(quarterNoteDuration:)` method using ceiling division to find the next grid-aligned time
- Added `.waitingForGrid` state to `RhythmOffsetDetectionSessionState` enum
- Modified `playNextTrial()` to set `gridOrigin` on first call
- Modified `transitionToFeedback()` to compute next grid point after feedback, enter `.waitingForGrid`, sleep until grid point, then play next trial
- Added `quarterNoteDuration` computed property to `TempoBPM`
- Reset `gridOrigin` in `stop()`

### Debug Log
- Story mentioned `currentTime` closure was already injectable — it wasn't. Added it following the `ContinuousRhythmMatchingSession` pattern.
- Used `Double?` for gridOrigin instead of `Double = 0` to clearly distinguish "no grid yet" from "grid at time 0"

### Completion Notes
✅ All 4 tasks completed. 6 new grid alignment tests added. All 1417 tests pass with zero regressions.

## File List

- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` — modified (added currentTime dependency, gridOrigin, waitingForGrid state, nextGridPoint method, grid alignment logic)
- `Peach/Core/Music/TempoBPM.swift` — modified (added quarterNoteDuration computed property)
- `PeachTests/RhythmOffsetDetection/RhythmOffsetDetectionSessionTests.swift` — modified (updated fixture for currentTime, added 6 grid alignment tests)
- `docs/implementation-artifacts/sprint-status.yaml` — modified (epic-56 and story 56.1 set to in-progress)

## Change Log

- 2026-03-23: Implemented quarter-note timing grid alignment for RhythmOffsetDetectionSession with injectable currentTime, waitingForGrid state, and 6 new tests
