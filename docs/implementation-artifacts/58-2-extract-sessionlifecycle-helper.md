# Story 58.2: Extract SessionLifecycle Helper

Status: done

## Story

As a **developer maintaining Peach**,
I want shared session lifecycle boilerplate extracted into a reusable helper,
so that feedback task management and interruption monitor wiring are defined once instead of duplicated across four sessions.

## Acceptance Criteria

1. **`SessionLifecycle` helper exists in `Core/Training/`** — A new `SessionLifecycle` struct (or similar) owns: `feedbackTask` (Task creation, cancellation, nil-out), `interruptionMonitor` (AudioSessionInterruptionMonitor setup and wiring), and the shared `stop()` cleanup sequence (guard-against-double-stop, task cancellation, logging).

2. **Four sessions delegate to `SessionLifecycle` via composition** — `PitchDiscriminationSession`, `PitchMatchingSession`, `RhythmOffsetDetectionSession`, and `ContinuousRhythmMatchingSession` each delegate feedback task and interruption monitor management to the helper. No inheritance.

3. **Domain-specific logic unchanged** — Each session's state machine, training-specific behavior, and domain state cleanup remain in the session. The helper handles only shared mechanical lifecycle.

4. **Zero regressions** — Full test suite passes.

5. **Finding closed** — `docs/pre-existing-findings.md` entry CD-1 is updated to CLOSED (removed per convention) with reference to this story.

## Tasks / Subtasks

- [x] Task 1: Create `SessionLifecycle` in `Core/Training/` (AC: #1)
  - [x] Define `SessionLifecycle` as a helper struct/class owned by each session
  - [x] Move `interruptionMonitor` property and its initialization here — accept `Logger`, `NotificationCenter`, optional background/foreground notification names, and `onStopRequired` closure
  - [x] Move `feedbackTask` property and its cancel/nil pattern here — provide `cancelFeedbackTask()` and `setFeedbackTask(_:)` methods
  - [x] Move `trainingTask` property and its cancel/nil pattern here — provide `cancelTrainingTask()` and `setTrainingTask(_:)` methods
  - [x] Provide a `cancelAllTasks()` method that cancels and nils both training and feedback tasks
  - [x] Include the guard-against-double-stop + logging pattern as a `guardNotIdle(isIdle:)` helper
  - [x] `ContinuousRhythmMatchingSession` has 3 tasks (`startTask`, `trackingTask`, `feedbackTask`) — session manages extra tasks alongside the helper (Option A)

- [x] Task 2: Refactor `PitchDiscriminationSession` to use `SessionLifecycle` (AC: #2, #3)
  - [x] Replace `interruptionMonitor`, `trainingTask`, `feedbackTask` properties with a `SessionLifecycle` instance
  - [x] In `init()`: create `SessionLifecycle` with `notificationCenter`, `logger`, `onStopRequired: { [weak self] in self?.stop() }`
  - [x] In `stop()`: delegate task cancellation to helper; keep domain state cleanup in session
  - [x] In `start()`: use helper's `setTrainingTask` instead of direct `trainingTask = Task { ... }`
  - [x] In feedback scheduling: use helper's `setFeedbackTask` instead of direct `feedbackTask = Task { ... }`
  - [x] Keep `notePlayer.stopAll()` call in session's `stop()` — audio cleanup is session-specific

- [x] Task 3: Refactor `PitchMatchingSession` to use `SessionLifecycle` (AC: #2, #3)
  - [x] Same pattern as Task 2
  - [x] This session passes `backgroundNotificationName` and `foregroundNotificationName` to `AudioSessionInterruptionMonitor` — helper accepts these optional parameters
  - [x] Keep session-specific `stop()` cleanup: `sliderTouchContinuation?.resume()`, `currentHandle` stop, frequency/trial state nil-outs
  - [x] Keep `notePlayer.stopAll()` and `handleToStop?.stop()` in session's `stop()`

- [x] Task 4: Refactor `RhythmOffsetDetectionSession` to use `SessionLifecycle` (AC: #2, #3)
  - [x] Same pattern as Task 2
  - [x] Keep session-specific `stop()` cleanup: `currentHandle?.stop()`, `rhythmPlayer.stopAll()`, `gridOrigin = nil`, `litDotCount = 0`, offset state nil-outs

- [x] Task 5: Refactor `ContinuousRhythmMatchingSession` to use `SessionLifecycle` (AC: #2, #3)
  - [x] This session has 3 tasks: `startTask`, `trackingTask`, `feedbackTask` — only `feedbackTask` is universally shared; `startTask`/`trackingTask` are session-specific
  - [x] Option A: helper manages `feedbackTask` only; session keeps `startTask`/`trackingTask` directly
  - [x] Keep `stepSequencer.stop()` in session's `stop()`
  - [x] Keep all timing state cleanup (`sequencerStartTime`, `sixteenthDuration`, etc.) in session

- [x] Task 6: Write tests for `SessionLifecycle` (AC: #4)
  - [x] Test `cancelAllTasks()` cancels and nils both tasks
  - [x] Test `setFeedbackTask` replaces previous task (cancels old, starts new)
  - [x] Test `setTrainingTask` replaces previous task (cancels old, starts new)
  - [x] Test `interruptionMonitor` calls `onStopRequired` on audio interruption
  - [x] Test guard-against-double-stop returns false when already idle

- [x] Task 7: Run full test suite and verify zero regressions (AC: #4)

- [x] Task 8: Close CD-1 in pre-existing findings catalog (AC: #5)
  - [x] Remove CD-1 entry from `docs/pre-existing-findings.md` (closed findings are removed per convention)

## Dev Notes

### The Duplication (CD-1)

All four sessions duplicate ~15–20 lines of identical boilerplate each:

**Identical across all 4 sessions:**
- `private var interruptionMonitor: AudioSessionInterruptionMonitor?` property
- `AudioSessionInterruptionMonitor(notificationCenter:logger:onStopRequired: { [weak self] in self?.stop() })` initialization in `init()`
- `private var trainingTask: Task<Void, Never>?` property
- `private var feedbackTask: Task<Void, Never>?` property
- `trainingTask?.cancel(); trainingTask = nil; feedbackTask?.cancel(); feedbackTask = nil` in `stop()`
- `guard state != .idle else { logger.debug("stop() called but already idle"); return }` in `stop()`

**Session-specific (stays in each session):**
- Audio cleanup method: `notePlayer.stopAll()` (pitch sessions), `rhythmPlayer.stopAll()` (rhythm offset), `stepSequencer.stop()` (continuous rhythm)
- Domain state cleanup: each session nils out its own observable/internal state properties
- `PitchMatchingSession` passes extra `backgroundNotificationName`/`foregroundNotificationName` to monitor
- `PitchMatchingSession` has unique `sliderTouchContinuation?.resume()` and `PlaybackHandle` cleanup
- `ContinuousRhythmMatchingSession` has 3 tasks instead of 2 (`startTask`, `trackingTask`, `feedbackTask`) and uses `isRunning: Bool` instead of a state enum

### Design Constraints

- **Composition, not inheritance** — sessions are `final class` and `@Observable`; the helper is owned via stored property
- **No `@Observable` on the helper** — the helper manages tasks and the monitor; it does not own observable state. Sessions keep their own `@Observable` state properties
- **`weak self` in `onStopRequired`** — the closure pattern `{ [weak self] in self?.stop() }` must survive refactoring; the monitor callback must not create a retain cycle
- **`AudioSessionInterruptionMonitor` must stay alive** — the monitor is reference-counted via `NSObjectProtocol` observers; the helper must hold a strong reference for the session's lifetime

### Source File Locations

| File | Path | Lines of Interest |
|------|------|-------------------|
| PitchDiscriminationSession | `Peach/PitchDiscrimination/PitchDiscriminationSession.swift` | init: 50–68, stop: 139–166, feedbackTask: 42, trainingTask: 41, monitor: 34 |
| PitchMatchingSession | `Peach/PitchMatching/PitchMatchingSession.swift` | init: 61–80, stop: 166–194, feedbackTask: 57, trainingTask: 56, monitor: 32 |
| RhythmOffsetDetectionSession | `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` | init: 65–85, stop: 144–174, feedbackTask: 46, trainingTask: 45, monitor: 37 |
| ContinuousRhythmMatchingSession | `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` | init: 58–72, stop: 78–111, feedbackTask: 51, startTask: 49, trackingTask: 50, monitor: 38 |
| AudioSessionInterruptionMonitor | `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift` | Full file (138 lines) — no changes needed |
| TrainingSession protocol | `Peach/Core/TrainingSession.swift` | Full file (4 lines) — no changes needed |

### Testing Strategy

1. Create `SessionLifecycleTests.swift` in `PeachTests/Core/Training/` — test task management and cancellation behavior in isolation
2. After each session refactoring, run full test suite to catch regressions immediately — do NOT batch all four refactors before testing
3. Existing session tests already cover the observable behavior (state transitions, feedback timing, interruption handling); they serve as regression guards
4. No changes to existing test files should be needed — the refactoring is internal; session public APIs are unchanged

### Project Structure Notes

- New file: `Peach/Core/Training/SessionLifecycle.swift`
- New test file: `PeachTests/Core/Training/SessionLifecycleTests.swift`
- Modified: all four session files (internal refactoring only)
- Modified: `docs/pre-existing-findings.md` (remove CD-1)
- No dependency direction changes — `Core/Training/` already exists and is the correct location

### References

- [Source: docs/pre-existing-findings.md#CD-1] — Bug description and provenance
- [Source: docs/planning-artifacts/epics.md#Epic 58, Story 58.2] — Acceptance criteria
- [Source: Peach/Core/TrainingSession.swift] — TrainingSession protocol (unchanged)
- [Source: Peach/Core/Audio/AudioSessionInterruptionMonitor.swift] — Monitor implementation (unchanged)
- [Source: Peach/PitchDiscrimination/PitchDiscriminationSession.swift:34-42,50-68,139-166] — Duplicated lifecycle in pitch discrimination
- [Source: Peach/PitchMatching/PitchMatchingSession.swift:32-57,61-80,166-194] — Duplicated lifecycle in pitch matching
- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift:37-46,65-85,144-174] — Duplicated lifecycle in rhythm offset detection
- [Source: Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift:38-51,58-72,78-111] — Duplicated lifecycle in continuous rhythm matching (3 tasks)

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Created `SessionLifecycle` final class in `Core/Training/` — owns `interruptionMonitor`, `trainingTask`, and `feedbackTask` with `setTrainingTask(_:)`, `setFeedbackTask(_:)`, `cancelAllTasks()`, and `guardNotIdle(isIdle:)` API
- API uses `Task<Void, Never>` parameters (not `@Sendable` closures) to preserve MainActor isolation — Task creation stays in the caller's `@MainActor` scope where it can capture isolated session state
- Refactored all 4 sessions to delegate lifecycle management via composition (`private var lifecycle: SessionLifecycle?`)
- `ContinuousRhythmMatchingSession` uses Option A: helper manages `feedbackTask` only; session keeps `startTask`/`trackingTask` directly
- Each session retains its domain-specific `stop()` cleanup (audio, state, UI)
- 7 new tests in `SessionLifecycleTests` (cancelAllTasks, setFeedbackTask replacement, setTrainingTask replacement, interruption monitor callback, guardNotIdle true/false)
- Full regression suite: 1468 tests pass, zero regressions
- CD-1 removed from pre-existing findings catalog

### File List

- `Peach/Core/Training/SessionLifecycle.swift` (new)
- `PeachTests/Core/Training/SessionLifecycleTests.swift` (new)
- `Peach/PitchDiscrimination/PitchDiscriminationSession.swift` (modified)
- `Peach/PitchMatching/PitchMatchingSession.swift` (modified)
- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` (modified)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` (modified)
- `docs/pre-existing-findings.md` (modified — CD-1 removed)
- `docs/implementation-artifacts/sprint-status.yaml` (modified)
