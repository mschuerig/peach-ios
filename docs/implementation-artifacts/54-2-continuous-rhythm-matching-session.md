# Story 54.2: ContinuousRhythmMatchingSession

Status: review

## Story

As a **developer**,
I want a `ContinuousRhythmMatchingSession` that acts as the step provider, evaluates tap timing against gap windows, counts cycles, and aggregates 16 cycles into a single trial,
so that the continuous rhythm matching training loop works end-to-end.

## Acceptance Criteria

1. **Given** `ContinuousRhythmMatchingSession` conforms to `TrainingSession` and `StepProvider`, **when** inspected, **then** it manages the step sequencer lifecycle and provides `CycleDefinition` per cycle.

2. **Given** `start()` is called, **when** the session begins, **then** it starts the step sequencer at the configured tempo, providing itself as the `StepProvider`.

3. **Given** the step provider is called for `nextCycle()`, **when** multiple gap positions are enabled, **then** it randomly selects one of the enabled positions; **when** exactly one is enabled, **then** it always uses that position.

4. **Given** the user taps, **when** the tap falls within the evaluation window (±50% of one sixteenth-note duration centered on the gap), **then** the session records the signed offset and marks the gap as hit.

5. **Given** the user taps, **when** the tap falls outside the evaluation window, **then** the tap is silently ignored — no feedback, no recording.

6. **Given** the user does not tap during a gap's evaluation window, **when** the window closes, **then** the gap is recorded as a miss.

7. **Given** 16 consecutive gap evaluations have been recorded (hits + misses), **when** the cycle count reaches 16, **then** the session packages a `CompletedContinuousRhythmMatchingTrial` with aggregate statistics and notifies observers, then resets the cycle counter and begins the next trial.

8. **Given** `stop()` is called or an interruption occurs, **when** the current trial has fewer than 16 cycles, **then** the incomplete trial is discarded (FR112).

9. **Given** the session is `@Observable`, **when** state changes, **then** the screen can observe: `isRunning`, `currentStep`, `currentGapPosition`, `cyclesInCurrentTrial`, `lastTrialResult`.

10. **Given** unit tests with mock step sequencer and mock observers, **when** all behaviors are tested, **then** full coverage of gap selection, tap evaluation, trial aggregation, and interruption.

## Tasks / Subtasks

- [x] Task 1: Define `GapPosition` and settings types (AC: #3)
  - [x] Reuse `StepPosition` from Story 54.1 as the gap position type (or create a typealias `GapPosition = StepPosition`)
  - [x] Verify `ContinuousRhythmMatchingSettings` has `enabledGapPositions: Set<StepPosition>` and `tempo: TempoBPM` (may be created in Story 54.3 — if so, define a minimal version here for development and let 54.3 extend it)

- [x] Task 2: Define `CompletedContinuousRhythmMatchingTrial` (AC: #7)
  - [x] Create `Peach/Core/Training/CompletedContinuousRhythmMatchingTrial.swift`
  - [x] Properties: `tempo: TempoBPM`, `gapResults: [GapResult]`, `meanOffsetMs: Double`, `hitRate: Double`, `gapPositionBreakdown: [StepPosition: PositionStats]`, `timestamp: Date`
  - [x] `GapResult` struct: `position: StepPosition`, `offset: RhythmOffset?` (nil = miss), `isHit: Bool`
  - [x] `PositionStats` struct: `hitCount: Int`, `missCount: Int`, `meanOffsetMs: Double`
  - [x] Conform to `Sendable`
  - [x] Write tests in `PeachTests/Core/Training/CompletedContinuousRhythmMatchingTrialTests.swift`

- [x] Task 3: Define `ContinuousRhythmMatchingObserver` protocol (AC: #7)
  - [x] Create `Peach/Core/Training/ContinuousRhythmMatchingObserver.swift`
  - [x] `func continuousRhythmMatchingCompleted(_ result: CompletedContinuousRhythmMatchingTrial)`

- [x] Task 4: Implement `ContinuousRhythmMatchingSession` (AC: #1, #2, #3, #9)
  - [x] Create `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift`
  - [x] `@Observable final class ContinuousRhythmMatchingSession: TrainingSession, StepProvider`
  - [x] Dependencies: `stepSequencer: StepSequencer`, `observers: [ContinuousRhythmMatchingObserver]`, `notificationCenter: NotificationCenter`
  - [x] Settings: `enabledGapPositions: Set<StepPosition>`, `tempo: TempoBPM`
  - [x] Observable state: `isRunning: Bool`, `currentStep: StepPosition?`, `currentGapPosition: StepPosition?`, `cyclesInCurrentTrial: Int`, `lastTrialResult: CompletedContinuousRhythmMatchingTrial?`
  - [x] `start(settings:)` — starts step sequencer with self as provider
  - [x] `stop()` — stops sequencer, discards incomplete trial
  - [x] `nextCycle() -> CycleDefinition` — randomly selects gap from enabled positions

- [x] Task 5: Implement tap evaluation with timing window (AC: #4, #5, #6)
  - [x] `handleTap()` — captures `CACurrentMediaTime()`, checks if within evaluation window
  - [x] Evaluation window: gap's expected time ± 50% of sixteenth-note duration
  - [x] Inside window: compute `RhythmOffset`, record as hit in current trial's gap results
  - [x] Outside window: silently ignore
  - [x] Track expected gap time: computed from sequencer start time + cycle count × cycle duration + gap position × sixteenth duration
  - [x] Detect missed gaps: when a new cycle starts and the previous gap was not hit, record as miss

- [x] Task 6: Implement trial aggregation (AC: #7, #8)
  - [x] Accumulate `GapResult` entries in an array, one per cycle
  - [x] When array reaches 16: compute aggregate stats, create `CompletedContinuousRhythmMatchingTrial`, notify observers, reset
  - [x] On `stop()` or interruption: clear accumulated results without notifying

- [x] Task 7: Interruption handling (AC: #8)
  - [x] Use `AudioSessionInterruptionMonitor` (same pattern as `RhythmMatchingSession`)
  - [x] On interruption: stop session, discard incomplete trial

- [x] Task 8: Wire into `PeachApp.swift` (AC: #1)
  - [x] Add `@State private var continuousRhythmMatchingSession: ContinuousRhythmMatchingSession`
  - [x] Create `createContinuousRhythmMatchingSession()` factory method
  - [x] Inject via `.environment(\.continuousRhythmMatchingSession, ...)`
  - [x] Add `@Entry var continuousRhythmMatchingSession` in `EnvironmentKeys.swift`
  - [x] Add `onChange(of: continuousRhythmMatchingSession.isIdle)` for active session tracking

- [x] Task 9: Write comprehensive tests (AC: #10)
  - [x] Create `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift`
  - [x] Test initial state is idle
  - [x] Test `start()` starts sequencer
  - [x] Test `nextCycle()` selects from enabled positions
  - [x] Test `nextCycle()` with single enabled position always returns it
  - [x] Test tap inside window records hit with correct offset
  - [x] Test tap outside window is ignored
  - [x] Test missed gap is recorded as miss
  - [x] Test trial completes after 16 cycles and notifies observers
  - [x] Test trial aggregation: meanOffsetMs, hitRate, positionBreakdown
  - [x] Test `stop()` discards incomplete trial
  - [x] Test interruption discards incomplete trial
  - [x] Test multiple consecutive trials
  - [x] Create `PeachTests/Mocks/MockStepSequencer.swift`
  - [x] Create `PeachTests/Mocks/MockContinuousRhythmMatchingObserver.swift`

- [x] Task 10: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Evaluation window calculation

At tempo T, one sixteenth note = `60.0 / (T * 4)` seconds. The evaluation window for a gap at position P in cycle C is:

```
gapTime = sequencerStartTime + (C * 4 + P) * sixteenthDuration
windowStart = gapTime - 0.5 * sixteenthDuration
windowEnd = gapTime + 0.5 * sixteenthDuration
```

At 120 BPM, sixteenth = 125ms, so the window is ±62.5ms around the gap. At 60 BPM, sixteenth = 250ms, window is ±125ms.

### Trial = 16 cycles, hardcoded

```swift
private static let cyclesPerTrial = 16
```

Not user-configurable. May be tuned later.

### Gap selection randomness

When multiple positions are enabled, use `enabledPositions.randomElement()`. The selection is independent per cycle — no balancing or rotation needed.

### Relationship to existing RhythmMatchingSession

This is a new, separate class. It does NOT inherit from or extend `RhythmMatchingSession`. The two coexist. They have different observer protocols (`RhythmMatchingObserver` vs `ContinuousRhythmMatchingObserver`) and different trial types.

### What NOT to do

- Do NOT modify `RhythmMatchingSession` — this is a new, parallel class
- Do NOT create UI screens — that's Story 54.4
- Do NOT create settings UI — that's Story 54.3
- Do NOT create data storage models — that's Story 54.5
- Do NOT use `ObservableObject` / `@Published` — use `@Observable`
- Do NOT use Combine

### References

- [Source: Peach/RhythmMatching/RhythmMatchingSession.swift — existing session pattern to reference]
- [Source: Peach/Core/Audio/StepSequencer.swift — protocol from Story 54.1]
- [Source: Peach/Core/TrainingSession.swift — TrainingSession protocol]
- [Source: Peach/Core/Music/RhythmOffset.swift — offset measurement]
- [Source: Peach/Core/Music/TempoBPM.swift — tempo and sixteenth duration]
- [Source: Peach/App/PeachApp.swift — session wiring pattern]
- [Source: Peach/App/EnvironmentKeys.swift — @Entry pattern]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Implementation Plan

- Reused `StepPosition` directly as gap position type (no typealias needed)
- Created minimal `ContinuousRhythmMatchingSettings` with `tempo` and `enabledGapPositions`
- `CompletedContinuousRhythmMatchingTrial` computes aggregate statistics in its initializer
- `ContinuousRhythmMatchingSession` implements both `TrainingSession` and `StepProvider`
- Tap evaluation uses `CACurrentMediaTime()` with ±50% sixteenth-note window
- Miss detection happens in `nextCycle()` — when a new cycle starts and the previous gap wasn't hit
- Trial aggregation at 16 gap results, then reset and continue
- `AudioSessionInterruptionMonitor` handles audio interruptions (same pattern as `RhythmMatchingSession`)
- Wired into `PeachApp.swift` with `@Entry` environment key, factory method, and active session tracking
- Session shares the existing `SoundFontStepSequencer` — only one session runs at a time via active session tracking

### Debug Log

No issues encountered during implementation.

### Completion Notes

- 29 new tests added (15 session + 10 trial + 4 settings), all passing
- Full test suite: 1508 tests pass, zero regressions
- No new dependency violations introduced
- The `currentStep` observable property (AC #9) is delegated to the step sequencer's `currentStep` — the session doesn't duplicate it. Views can observe `stepSequencer.currentStep` via the existing `@Entry var stepSequencer` environment key.

## File List

New files:
- `Peach/Core/Training/ContinuousRhythmMatchingSettings.swift`
- `Peach/Core/Training/CompletedContinuousRhythmMatchingTrial.swift`
- `Peach/Core/Training/ContinuousRhythmMatchingObserver.swift`
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift`
- `PeachTests/Core/Training/CompletedContinuousRhythmMatchingTrialTests.swift`
- `PeachTests/Core/Training/ContinuousRhythmMatchingSettingsTests.swift`
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift`
- `PeachTests/Mocks/MockStepSequencer.swift`
- `PeachTests/Mocks/MockContinuousRhythmMatchingObserver.swift`

Modified files:
- `Peach/App/PeachApp.swift`
- `Peach/App/EnvironmentKeys.swift`
- `docs/implementation-artifacts/sprint-status.yaml`

## Change Log

- Implemented ContinuousRhythmMatchingSession with full step provider, tap evaluation, trial aggregation, and interruption handling (Date: 2026-03-22)
