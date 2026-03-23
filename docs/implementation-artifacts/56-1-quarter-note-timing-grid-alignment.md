# Story 56.1: Quarter-Note Timing Grid Alignment

Status: backlog

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

- [ ] Task 1: Add grid tracking state to `RhythmOffsetDetectionSession`
  - [ ] Add `private var gridOrigin: Double = 0` (set from `currentTime()` when first pattern plays)
  - [ ] Add `private var quarterNoteDuration: Double = 0` (computed from tempo at start)
  - [ ] Add a computed method `nextGridPoint() -> Double` returning `gridOrigin + ceil((now - gridOrigin) / quarterNoteDuration) * quarterNoteDuration`

- [ ] Task 2: Align first pattern to grid origin
  - [ ] In `playNextTrial()`, on the very first pattern, record `gridOrigin = currentTime()` immediately before playing
  - [ ] First pattern needs no wait — it defines the grid

- [ ] Task 3: Add grid wait before subsequent patterns
  - [ ] After feedback ends (in `transitionToFeedback`'s scheduled callback), compute the next grid point
  - [ ] Sleep until that grid point before calling `playNextTrial()`
  - [ ] Consider a new state value (e.g., `.waitingForGrid`) or reuse `.idle`-like state with buttons disabled

- [ ] Task 4: Update tests
  - [ ] Test that first pattern sets grid origin
  - [ ] Test that subsequent patterns wait for grid alignment using a mock `currentTime`
  - [ ] Test that the grid is never skipped (set current time to just before a grid point, verify the session waits for that point)
  - [ ] Test that variable answer+feedback times still produce grid-aligned patterns

## Technical Notes

- The `currentTime` closure is already injectable in the session (used for testing). Grid calculations should use the same closure.
- `TempoBPM` already has `sixteenthNoteDuration`. A `quarterNoteDuration` convenience may be useful but can also be computed as `sixteenthNoteDuration * 4`.
- The grid wait replaces the current immediate transition from feedback → playNextTrial. The `feedbackTask` completion handler is the natural place to insert the wait.
