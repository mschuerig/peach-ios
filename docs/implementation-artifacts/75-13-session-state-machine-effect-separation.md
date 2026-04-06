# Story 75.13: Session State Machine — Explicit State/Effect Separation

Status: ready-for-dev

## Story

As a **developer maintaining training sessions**,
I want session state machines to separate state transitions from side effects,
so that methods named `transitionToFeedback` don't also play the next trial, and `commitResult` doesn't handle 5 responsibilities.

## Background

The walkthrough (Layer 3) found that all four session classes interweave state transitions with side effects. `PitchDiscriminationSession.transitionToFeedback` is named as a feedback concern but also plays the next trial. `PitchMatchingSession.commitResult` stops audio, computes error, records the result, shows feedback, and schedules the next trial — five responsibilities in one method.

The open-questions.md already logged this as a research topic: "Research the `state + event → (newState, [Effect])` pattern and other idiomatic Swift approaches."

This story covers both the research and the implementation.

**Walkthrough source:** Layer 3 observation #4; open-questions.md research topic #1.

## Acceptance Criteria

1. **Given** a state machine event **When** processed **Then** it produces a new state and a list of effects, without executing any side effects inline.
2. **Given** the effect list **When** interpreted **Then** each effect (play audio, record result, show feedback, schedule next trial, notify observers) is executed by a separate effect handler.
3. **Given** all 4 session classes **When** inspected **Then** they follow the state + event → (newState, [Effect]) pattern (or a well-documented variant chosen during research).
4. **Given** each session's state transitions **When** tested **Then** they can be tested as pure functions without mocking audio, persistence, or UI.
5. **Given** the effect handler **When** tested **Then** each effect type can be tested independently.
6. **Given** both platforms **When** built and tested **Then** all existing tests pass, and new state transition tests are added for each session.

## Tasks / Subtasks

- [ ] Task 1: Research state machine patterns in Swift (AC: #1, #2)
  - [ ] Evaluate `state + event → (newState, [Effect])` with enum states and effect interpreters
  - [ ] Evaluate protocol-based approaches (e.g., `StateMachine` protocol with associated types)
  - [ ] Evaluate lighter approaches: just separating "decide" from "execute" within the existing class structure
  - [ ] Consider `ContinuousRhythmMatchingSession` which uses a boolean `isRunning` instead of an enum — does the pattern fit?
  - [ ] Document the chosen approach and rationale before implementing

- [ ] Task 2: Define the state/effect types for PitchDiscriminationSession (AC: #1, #2)
  - [ ] Define state enum (idle, playingReference, playingTarget, awaitingAnswer, showingFeedback)
  - [ ] Define event enum (referenceFinished, targetFinished, answerReceived, feedbackTimerFired)
  - [ ] Define effect enum (playNote, stopNote, recordResult, notifyObservers, showFeedback, scheduleNextTrial, etc.)
  - [ ] Implement pure `reduce(state:event:) -> (State, [Effect])` function

- [ ] Task 3: Implement effect handler for PitchDiscriminationSession (AC: #2)
  - [ ] Create an effect interpreter that maps each effect to the actual side effect call
  - [ ] Wire the reduce function and effect handler into the session's training loop

- [ ] Task 4: Apply pattern to PitchMatchingSession (AC: #3)
  - [ ] Adapt for the unique aspects: `CheckedContinuation` for slider touch, `PlaybackHandle` for live pitch adjustment
  - [ ] Particular focus on `commitResult` decomposition

- [ ] Task 5: Apply pattern to RhythmOffsetDetectionSession (AC: #3)
  - [ ] Adapt for grid alignment and dot animation timing

- [ ] Task 6: Apply pattern to ContinuousRhythmMatchingSession (AC: #3)
  - [ ] This session is structurally different (continuous loop, no discrete states). Evaluate whether the pattern applies directly or needs adaptation
  - [ ] If the pattern doesn't fit naturally, document why and use a lighter separation

- [ ] Task 7: Add state transition tests (AC: #4, #5)
  - [ ] Test pure `reduce` functions for each session without any mocks
  - [ ] Test effect handler with mocked dependencies

- [ ] Task 8: Build and test both platforms (AC: #6)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| `Peach/PitchDiscrimination/PitchDiscriminationSession.swift` (284 lines) | First refactor target |
| `Peach/PitchMatching/PitchMatchingSession.swift` (220 lines) | Second target |
| `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` (248 lines) | Third target |
| `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` (233 lines) | Fourth target (may need adaptation) |

### The Core Pattern

```swift
// Pure function — no side effects
func reduce(state: State, event: Event) -> (State, [Effect]) {
    switch (state, event) {
    case (.playingTarget, .answerReceived(let isHigher)):
        let result = computeResult(isHigher)
        return (.showingFeedback(result), [.stopNote, .recordResult(result), .notifyObservers(result), .scheduleFeedbackTimer])
    // ...
    }
}

// Impure — executes effects
func interpret(effect: Effect) async {
    switch effect {
    case .playNote(let frequency, let duration):
        await notePlayer.play(frequency: frequency, duration: duration)
    case .recordResult(let result):
        observers.forEach { $0.completed(result) }
    // ...
    }
}
```

### ContinuousRhythmMatchingSession Challenge

This session doesn't have discrete states like the others. It's a continuous real-time loop where the sequencer drives timing, and taps are evaluated against the current position. The state/effect pattern may apply to tap handling (tap event → evaluate → record/feedback effects) even if the overall session lifecycle stays as a `isRunning` flag.

### Existing WALKTHROUGH Annotations

- `Peach/PitchDiscrimination/PitchDiscriminationSession.swift` (lines 305–306)
- `Peach/PitchMatching/PitchMatchingSession.swift` (lines 192–193)

### What NOT to Change

- Do not change the session's external API (`start(settings:)`, `stop()`, `isIdle`)
- Do not change the observer protocols or store adapters
- Do not change `SessionLifecycle` — it manages Task handles, which are an effect execution concern
- Do not change the `NextPitchDiscriminationStrategy` or `AdaptiveRhythmOffsetDetectionStrategy` interfaces

### Risk: Async/Await Interaction

The current sessions use structured concurrency (`Task`, `withCheckedContinuation`). Effects that involve async operations (playing notes, waiting for timers) need careful handling. The effect interpreter may need to be `async` and process effects sequentially, or effects could carry continuations.

### References

- [Source: docs/walkthrough/3-training-sessions.md — observation #4]
- [Source: docs/walkthrough/open-questions.md — research topic #1]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
