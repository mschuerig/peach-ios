# Story 75.13: Session State Machine — Explicit State/Effect Separation

Status: done

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
5. ~~**Given** the effect handler **When** tested **Then** each effect type can be tested independently.~~ *Deferred — requires mock infrastructure for NotePlayer, RhythmPlayer, StepSequencer. Tracked as separate backlog item.*
6. **Given** both platforms **When** built and tested **Then** all existing tests pass, and new state transition tests are added for each session.

## Tasks / Subtasks

- [x] Task 1: Research state machine patterns in Swift (AC: #1, #2)
  - [x] Evaluate `state + event → (newState, [Effect])` with enum states and effect interpreters
  - [x] Evaluate protocol-based approaches (e.g., `StateMachine` protocol with associated types)
  - [x] Evaluate lighter approaches: just separating "decide" from "execute" within the existing class structure
  - [x] Consider `ContinuousRhythmMatchingSession` which uses a boolean `isRunning` instead of an enum — does the pattern fit?
  - [x] Document the chosen approach and rationale before implementing

- [x] Task 2: Define the state/effect types for PitchDiscriminationSession (AC: #1, #2)
  - [x] Define state enum (idle, playingReference, playingTarget, awaitingAnswer, showingFeedback)
  - [x] Define event enum (referenceFinished, targetFinished, answerReceived, feedbackTimerFired)
  - [x] Define effect enum (playNote, stopNote, recordResult, notifyObservers, showFeedback, scheduleNextTrial, etc.)
  - [x] Implement pure `reduce(state:event:) -> (State, [Effect])` function

- [x] Task 3: Implement effect handler for PitchDiscriminationSession (AC: #2)
  - [x] Create an effect interpreter that maps each effect to the actual side effect call
  - [x] Wire the reduce function and effect handler into the session's training loop

- [x] Task 4: Apply pattern to PitchMatchingSession (AC: #3)
  - [x] Adapt for the unique aspects: `CheckedContinuation` for slider touch, `PlaybackHandle` for live pitch adjustment
  - [x] Particular focus on `commitResult` decomposition

- [x] Task 5: Apply pattern to TimingOffsetDetectionSession (AC: #3)
  - [x] Adapt for grid alignment and dot animation timing

- [x] Task 6: Apply pattern to ContinuousRhythmMatchingSession (AC: #3)
  - [x] Pattern applies directly with idle/running states and tap/cycle/trial events within running
  - [x] No adaptation needed — same unified reduce/interpret pattern as discrete sessions

- [x] Task 7: Add state transition tests (AC: #4)
  - [x] Test pure `reduce` functions for each session without any mocks
  - Note: Effect handler tests (AC #5) deferred — requires mock infrastructure for NotePlayer, RhythmPlayer, StepSequencer. Tracked as a separate backlog item.

- [x] Task 8: Build and test both platforms (AC: #6)
  - [x] `bin/test.sh && bin/test.sh -p mac`

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
Claude Opus 4.6

### Implementation Plan

#### Chosen Pattern: Unified `reduce(state:event:) → [Effect]` with `inout State`

**Evaluated alternatives:**
1. **Protocol-based `StateMachine` with associated types** — rejected. Adds framework-level abstraction for 4 state machines in a zero-dependency app. Over-engineered.
2. **Lightweight decide/execute split** (no formal types) — rejected. Lacks exhaustive switch coverage and effect inspectability in tests. Doesn't provide a single function to read the entire flow.
3. **Mixed approaches per session** — rejected. Michael requires one consistent pattern across all four sessions.

**Why this pattern:**
- The single `reduce` switch **is** the entire session flow, readable top to bottom in one place. Today that logic is scattered across `playTrialNotes`, `handleAnswer`, `transitionToFeedback`, and `playNextTrial`.
- `static func reduce` on the session class cannot touch `self` — pure by construction.
- Effects are coarse-grained data descriptions (e.g., `evaluateAnswer`, not `computeResult` + `trackBest` + `notify`). The state machine handles only state transitions; effect details are the interpreter's concern.
- Invalid state/event combinations are logged as warnings (matching current guard-and-return behavior).

**Structure per session:**
```swift
final class FooSession: TrainingSession {
    enum State { ... }
    enum Event { ... }
    enum Effect { ... }

    static func reduce(state: inout State, event: Event) -> [Effect] { ... }

    private func send(_ event: Event) {
        let effects = Self.reduce(state: &state, event: event)
        for effect in effects { interpret(effect) }
    }

    private func interpret(_ effect: Effect) { ... }
}
```

**ContinuousRhythmMatchingSession:** Uses the same pattern with two states (`idle`, `running`). The 120Hz tracking loop is an effect started on entering `running` (equivalent to Miro Samek's TIME_TICK pattern from embedded systems). Taps, cycle completions, and trial boundaries are events processed by `reduce` within the `running` state. The tap evaluation logic is already nearly pure computation — extracting it into `reduce` is natural.

**Key design decisions (confirmed by Michael):**
- Effects are coarse-grained: `evaluateAnswer` is one effect, not multiple sub-effects
- Invalid transitions: log as warnings, do not crash
- `reduce` lives as `static func` nested in the session class (no separate files)

### Debug Log References
### Completion Notes List

- Task 1: Researched three Swift state machine approaches (reducer, protocol-based, decide/execute). Chose unified `reduce(state:event:) → [Effect]` pattern for all four sessions. ContinuousRhythmMatching fits with `idle`/`running` states and tap/cycle events within `running`. Design decisions confirmed: coarse effects, warn on invalid transitions, `static func reduce` on the session class.
- Tasks 2–6: Implemented reduce/interpret pattern across all four sessions. PitchMatchingSession eliminated CheckedContinuation entirely. ContinuousRhythmMatching uses idle/running states with tap/cycle/trial events within running.
- Task 7: Added 40 pure reduce tests across 4 test files. All transitions and invalid-transition cases covered. Effect handler tests deferred (separate story scope).
- Task 8: iOS 1770 tests pass, macOS 1763 tests pass.

### File List

- `Peach/Training/PitchDiscrimination/PitchDiscriminationSession.swift` — refactored with reduce/interpret
- `Peach/Training/PitchMatching/PitchMatchingSession.swift` — refactored, eliminated CheckedContinuation
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — refactored with reduce/interpret
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — refactored, boolean → enum state
- `PeachTests/Training/PitchDiscrimination/PitchDiscriminationReduceTests.swift` — new reduce tests
- `PeachTests/Training/PitchMatching/PitchMatchingReduceTests.swift` — new reduce tests
- `PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionReduceTests.swift` — new reduce tests
- `PeachTests/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingReduceTests.swift` — new reduce tests

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-07: Task 1 complete — research and design decision documented
- 2026-04-07: Tasks 2–8 complete — all four sessions refactored, 40 reduce tests added, both platforms pass
