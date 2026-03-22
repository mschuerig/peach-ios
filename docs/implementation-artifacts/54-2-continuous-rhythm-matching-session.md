# Story 54.2: ContinuousRhythmMatchingSession

Status: backlog

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

- [ ] Task 1: Define `GapPosition` and settings types (AC: #3)
  - [ ] Reuse `StepPosition` from Story 54.1 as the gap position type (or create a typealias `GapPosition = StepPosition`)
  - [ ] Verify `ContinuousRhythmMatchingSettings` has `enabledGapPositions: Set<StepPosition>` and `tempo: TempoBPM` (may be created in Story 54.3 — if so, define a minimal version here for development and let 54.3 extend it)

- [ ] Task 2: Define `CompletedContinuousRhythmMatchingTrial` (AC: #7)
  - [ ] Create `Peach/Core/Training/CompletedContinuousRhythmMatchingTrial.swift`
  - [ ] Properties: `tempo: TempoBPM`, `gapResults: [GapResult]`, `meanOffsetMs: Double`, `hitRate: Double`, `gapPositionBreakdown: [StepPosition: PositionStats]`, `timestamp: Date`
  - [ ] `GapResult` struct: `position: StepPosition`, `offset: RhythmOffset?` (nil = miss), `isHit: Bool`
  - [ ] `PositionStats` struct: `hitCount: Int`, `missCount: Int`, `meanOffsetMs: Double`
  - [ ] Conform to `Sendable`
  - [ ] Write tests in `PeachTests/Core/Training/CompletedContinuousRhythmMatchingTrialTests.swift`

- [ ] Task 3: Define `ContinuousRhythmMatchingObserver` protocol (AC: #7)
  - [ ] Create `Peach/Core/Training/ContinuousRhythmMatchingObserver.swift`
  - [ ] `func continuousRhythmMatchingCompleted(_ result: CompletedContinuousRhythmMatchingTrial)`

- [ ] Task 4: Implement `ContinuousRhythmMatchingSession` (AC: #1, #2, #3, #9)
  - [ ] Create `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift`
  - [ ] `@Observable final class ContinuousRhythmMatchingSession: TrainingSession, StepProvider`
  - [ ] Dependencies: `stepSequencer: StepSequencer`, `observers: [ContinuousRhythmMatchingObserver]`, `notificationCenter: NotificationCenter`
  - [ ] Settings: `enabledGapPositions: Set<StepPosition>`, `tempo: TempoBPM`
  - [ ] Observable state: `isRunning: Bool`, `currentStep: StepPosition?`, `currentGapPosition: StepPosition?`, `cyclesInCurrentTrial: Int`, `lastTrialResult: CompletedContinuousRhythmMatchingTrial?`
  - [ ] `start(settings:)` — starts step sequencer with self as provider
  - [ ] `stop()` — stops sequencer, discards incomplete trial
  - [ ] `nextCycle() -> CycleDefinition` — randomly selects gap from enabled positions

- [ ] Task 5: Implement tap evaluation with timing window (AC: #4, #5, #6)
  - [ ] `handleTap()` — captures `CACurrentMediaTime()`, checks if within evaluation window
  - [ ] Evaluation window: gap's expected time ± 50% of sixteenth-note duration
  - [ ] Inside window: compute `RhythmOffset`, record as hit in current trial's gap results
  - [ ] Outside window: silently ignore
  - [ ] Track expected gap time: computed from sequencer start time + cycle count × cycle duration + gap position × sixteenth duration
  - [ ] Detect missed gaps: when a new cycle starts and the previous gap was not hit, record as miss

- [ ] Task 6: Implement trial aggregation (AC: #7, #8)
  - [ ] Accumulate `GapResult` entries in an array, one per cycle
  - [ ] When array reaches 16: compute aggregate stats, create `CompletedContinuousRhythmMatchingTrial`, notify observers, reset
  - [ ] On `stop()` or interruption: clear accumulated results without notifying

- [ ] Task 7: Interruption handling (AC: #8)
  - [ ] Use `AudioSessionInterruptionMonitor` (same pattern as `RhythmMatchingSession`)
  - [ ] On interruption: stop session, discard incomplete trial

- [ ] Task 8: Wire into `PeachApp.swift` (AC: #1)
  - [ ] Add `@State private var continuousRhythmMatchingSession: ContinuousRhythmMatchingSession`
  - [ ] Create `createContinuousRhythmMatchingSession()` factory method
  - [ ] Inject via `.environment(\.continuousRhythmMatchingSession, ...)`
  - [ ] Add `@Entry var continuousRhythmMatchingSession` in `EnvironmentKeys.swift`
  - [ ] Add `onChange(of: continuousRhythmMatchingSession.isIdle)` for active session tracking

- [ ] Task 9: Write comprehensive tests (AC: #10)
  - [ ] Create `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift`
  - [ ] Test initial state is idle
  - [ ] Test `start()` starts sequencer
  - [ ] Test `nextCycle()` selects from enabled positions
  - [ ] Test `nextCycle()` with single enabled position always returns it
  - [ ] Test tap inside window records hit with correct offset
  - [ ] Test tap outside window is ignored
  - [ ] Test missed gap is recorded as miss
  - [ ] Test trial completes after 16 cycles and notifies observers
  - [ ] Test trial aggregation: meanOffsetMs, hitRate, positionBreakdown
  - [ ] Test `stop()` discards incomplete trial
  - [ ] Test interruption discards incomplete trial
  - [ ] Test multiple consecutive trials
  - [ ] Create `PeachTests/Mocks/MockStepSequencer.swift`
  - [ ] Create `PeachTests/Mocks/MockContinuousRhythmMatchingObserver.swift`

- [ ] Task 10: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

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
