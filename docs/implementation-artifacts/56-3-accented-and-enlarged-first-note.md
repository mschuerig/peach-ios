# Story 56.3: Accented and Enlarged First Note

Status: review

## Story

As a **user training rhythm offset discrimination**,
I want the first note to be visually larger and audibly accented,
So that I can clearly identify the downbeat, matching the Continuous Rhythm Matching convention.

## Context

Currently all four notes in `RhythmOffsetDetectionSession.buildPattern()` use the same velocity (100), and all four dots in `RhythmDotView` use the same diameter (16pt). Continuous Rhythm Matching already distinguishes beat one with accent velocity (127) and a larger dot (22pt). This story brings that convention to Rhythm Offset Discrimination.

### Key files

- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` — `buildPattern(for:settings:)`
- `Peach/RhythmOffsetDetection/RhythmDotView.swift` — dot rendering
- `Peach/Core/Audio/StepSequencer.swift` — `StepVelocity.accent` / `.normal` constants
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingDotView.swift` — reference for beat-one diameter

## Acceptance Criteria

1. **Accent velocity** — `buildPattern()` uses `StepVelocity.accent` (127) for event 0 and `StepVelocity.normal` (100) for events 1–3.

2. **Enlarged first dot** — `RhythmDotView` renders the first dot at 22pt diameter (matching `ContinuousRhythmMatchingDotView.beatOneDotDiameter`). Dots 2–4 remain at 16pt.

3. **All existing tests pass** with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Update `buildPattern()` to use accent velocity for event 0
  - [x] Import or reference `StepVelocity.accent` and `StepVelocity.normal`
  - [x] First event: velocity = `StepVelocity.accent`
  - [x] All other events: velocity = `StepVelocity.normal`

- [x] Task 2: Update `RhythmDotView` to enlarge first dot
  - [x] Add `static let beatOneDotDiameter: CGFloat = 22` (matching CRM)
  - [x] In the `ForEach`, use `beatOneDotDiameter` for index 0, `dotDiameter` for others
  - [x] Extract a `diameter(forStepIndex:)` static method for testability (matching CRM pattern)

- [x] Task 3: Update tests
  - [x] Test `buildPattern()` event velocities
  - [x] Test `RhythmDotView.diameter(forStepIndex:)` returns correct values

## Technical Notes

- `StepVelocity` is already defined in `StepSequencer.swift` and used by `SoundFontStepSequencer`. Reusing it here keeps the accent convention consistent.
- The `RhythmDotView` currently uses a simple `Circle()` in a `ForEach`. The diameter change follows the same pattern as `ContinuousRhythmMatchingDotView.diameter(forStepIndex:)`.

## File List

- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` — modified (accent velocity for event 0)
- `Peach/RhythmOffsetDetection/RhythmDotView.swift` — modified (beatOneDotDiameter, diameter(forStepIndex:))
- `PeachTests/RhythmOffsetDetection/RhythmOffsetDetectionSessionTests.swift` — modified (velocity assertions)
- `PeachTests/RhythmOffsetDetection/RhythmDotViewTests.swift` — modified (beatOneDotDiameter and diameter tests)

## Change Log

- 2026-03-23: Implemented accent velocity and enlarged first dot (all 3 tasks)

## Dev Agent Record

### Completion Notes

- Task 1: Replaced single `velocity` constant with per-event velocity using `StepVelocity.accent` for index 0 and `StepVelocity.normal` for indices 1-3
- Task 2: Added `beatOneDotDiameter` (22pt) constant, extracted `diameter(forStepIndex:)` static method (matching CRM pattern), updated `ForEach` to use dynamic diameter
- Task 3: Updated existing velocity test to check accent/normal split; added 3 new tests for `beatOneDotDiameter`, `diameter(forStepIndex: 0)`, and `diameter(forStepIndex: 1-3)`
- All 1426 tests pass with zero regressions
