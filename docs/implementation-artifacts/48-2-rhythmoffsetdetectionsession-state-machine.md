# Story 48.2: RhythmOffsetDetectionSession State Machine

Status: ready-for-dev

## Story

As a **developer**,
I want a `RhythmOffsetDetectionSession` that plays 4-note patterns and records Early/Late judgments,
So that the rhythm offset detection training loop works end-to-end with proper state management.

## Acceptance Criteria

1. **Given** `RhythmOffsetDetectionSession` is `@Observable`, **when** inspected, **then** it follows the state machine: `idle -> playingPattern -> awaitingAnswer -> showingFeedback -> loop`.

2. **Given** `start(settings:)` is called, **when** the session transitions from idle, **then** it calls `strategy.nextRhythmOffsetDetectionTrial(profile:settings:lastResult:)` to get a `RhythmOffsetDetectionTrial`, builds a `RhythmPattern` with 4 events at sixteenth-note intervals (4th shifted by the trial offset), and calls `rhythmPlayer.play(pattern)`.

3. **Given** the pattern completes, **when** the session transitions to `awaitingAnswer`, **then** the user can tap "Early" or "Late".

4. **Given** the user answers, **when** the answer is recorded, **then** observers are notified with a `CompletedRhythmOffsetDetectionTrial`, the session transitions to `showingFeedback` for the configured feedback duration (~400ms), and then automatically starts the next trial.

5. **Given** interruption occurs (navigation away, backgrounding, headphone disconnect), **when** in any state other than idle, **then** the session stops via `rhythmPlaybackHandle.stop()`, discards incomplete exercises, and transitions to idle.

6. **Given** the session conforms to `TrainingSession`, **when** inspected, **then** it exposes `stop()` and `isIdle`.

7. **Given** unit tests using `MockRhythmPlayer` and `MockNextRhythmOffsetDetectionStrategy`, **when** all state transitions are tested, **then** full coverage of the state machine including interruption paths and error handling.

## Tasks / Subtasks

- [ ] Task 1: Create `RhythmOffsetDetectionSession` with state enum (AC: #1, #6)
  - [ ] Create `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift`
  - [ ] Define `RhythmOffsetDetectionSessionState` enum: `idle`, `playingPattern`, `awaitingAnswer`, `showingFeedback`
  - [ ] `@Observable final class RhythmOffsetDetectionSession: TrainingSession`
  - [ ] Observable state: `state`, `showFeedback`, `isLastAnswerCorrect`, `currentOffsetPercentage`
  - [ ] Dependencies: `rhythmPlayer`, `strategy`, `profile`, `observers`, `interruptionMonitor`, `sampleRate`

- [ ] Task 2: Implement `start(settings:)` and training loop (AC: #2)
  - [ ] Guard on `state == .idle` before starting
  - [ ] Store settings snapshot
  - [ ] Spawn training task via `Task { await runTrainingLoop() }`
  - [ ] `playNextTrial()`: call strategy, build `RhythmPattern`, call `rhythmPlayer.play(pattern)`, store handle
  - [ ] Transition to `playingPattern`, then `awaitingAnswer` after pattern completes

- [ ] Task 3: Implement pattern building (AC: #2)
  - [ ] Build `RhythmPattern` with 4 events at sixteenth-note intervals
  - [ ] 4th event shifted by `trial.offset` (converted to sample offset)
  - [ ] Use `sampleRate` for sample offset calculation: `Int64(sampleRate.rawValue * duration.timeInterval)`
  - [ ] Use percussion MIDI note (e.g., `MIDINote(76)` — hi-hat, matching POC) and standard velocity

- [ ] Task 4: Implement `handleAnswer(direction:)` (AC: #4)
  - [ ] Guard on `state == .awaitingAnswer`
  - [ ] Determine correctness: `direction == trial.offset.direction`
  - [ ] Create `CompletedRhythmOffsetDetectionTrial(tempo:offset:isCorrect:)`
  - [ ] Notify observers via `observers.forEach { $0.rhythmOffsetDetectionCompleted(completed) }`
  - [ ] Transition to `showingFeedback`

- [ ] Task 5: Implement feedback and loop (AC: #4)
  - [ ] `transitionToFeedback()`: set `isLastAnswerCorrect`, `showFeedback = true`, state = `.showingFeedback`
  - [ ] `feedbackTask`: sleep for `settings.feedbackDuration`, then `showFeedback = false`, call `playNextTrial()`
  - [ ] Cancel feedback task on stop

- [ ] Task 6: Implement `stop()` and interruption handling (AC: #5, #6)
  - [ ] Guard: return if already idle
  - [ ] Stop rhythm playback handle: `try? await currentHandle?.stop()`
  - [ ] Cancel training task and feedback task
  - [ ] Reset all state to idle defaults
  - [ ] Wire `AudioSessionInterruptionMonitor` in init with `onStopRequired: { [weak self] in self?.stop() }`

- [ ] Task 7: Wire into composition root (AC: #1)
  - [ ] Add `@Entry var rhythmOffsetDetectionSession` to `EnvironmentKeys.swift` with preview default
  - [ ] Add `@State private var rhythmOffsetDetectionSession` to `PeachApp`
  - [ ] Create `createRhythmOffsetDetectionSession()` helper in `PeachApp`
  - [ ] Pass `rhythmPlayer`, `AdaptiveRhythmOffsetDetectionStrategy()`, `profile`, observers (`[dataStore, profile, hapticManager]`)
  - [ ] Inject via `.environment(\.rhythmOffsetDetectionSession, rhythmOffsetDetectionSession)`
  - [ ] Add `onChange(of: rhythmOffsetDetectionSession.isIdle)` for active session tracking

- [ ] Task 8: Write tests (AC: #7)
  - [ ] Create `PeachTests/RhythmOffsetDetection/RhythmOffsetDetectionSessionTests.swift`
  - [ ] Factory method returning `(session:, mockPlayer:, mockStrategy:, mockObserver:)` tuple
  - [ ] Test starts in idle state
  - [ ] Test `start()` transitions to `playingPattern` and calls strategy + rhythm player
  - [ ] Test pattern has 4 events with correct sample offsets (3 regular + 1 offset)
  - [ ] Test transitions to `awaitingAnswer` after pattern completes
  - [ ] Test `handleAnswer(direction:)` records correct/incorrect result and notifies observers
  - [ ] Test feedback phase transitions and auto-advances to next trial
  - [ ] Test `stop()` transitions to idle and cancels tasks
  - [ ] Test `stop()` when already idle is a no-op
  - [ ] Test error handling: audio error stops session gracefully
  - [ ] Test `handleAnswer` ignored when not in `awaitingAnswer` state
  - [ ] Test `start()` ignored when not idle

- [ ] Task 9: Create `MockRhythmOffsetDetectionObserver` (AC: #7)
  - [ ] Create `PeachTests/Mocks/MockRhythmOffsetDetectionObserver.swift`
  - [ ] Track `completedCallCount`, `lastResult: CompletedRhythmOffsetDetectionTrial?`, `results: [CompletedRhythmOffsetDetectionTrial]`
  - [ ] `reset()` method

- [ ] Task 10: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Pattern to follow: `PitchDiscriminationSession`

Mirror `PitchDiscriminationSession` exactly in structure. Key correspondences:

| PitchDiscrimination | RhythmOffsetDetection |
|---|---|
| `PitchDiscriminationSessionState` | `RhythmOffsetDetectionSessionState` |
| `notePlayer: NotePlayer` | `rhythmPlayer: RhythmPlayer` |
| `NextPitchDiscriminationStrategy` | `NextRhythmOffsetDetectionStrategy` |
| `PitchDiscriminationObserver` | `RhythmOffsetDetectionObserver` |
| `PitchDiscriminationTrial` | `RhythmOffsetDetectionTrial` |
| `CompletedPitchDiscriminationTrial` | `CompletedRhythmOffsetDetectionTrial` |
| `PitchDiscriminationSettings` | `RhythmOffsetDetectionSettings` |
| `handleAnswer(isHigher:)` | `handleAnswer(direction: RhythmDirection)` |
| `playTrialNotes()` → sequential notes | `playPattern()` → `RhythmPattern` via `RhythmPlayer` |

### Building the `RhythmPattern`

The session must construct a `RhythmPattern` with 4 events. Events 1-3 are at regular sixteenth-note intervals. Event 4 is shifted by the trial's offset. Follow the POC pattern from `RhythmPOCScreen`:

```swift
let sixteenthDuration = settings.tempo.sixteenthNoteDuration
let samplesPerSixteenth = Int64(sampleRate.rawValue * sixteenthDuration.timeInterval)

let clickNote = MIDINote(76)  // Hi-hat, same as POC
let velocity = MIDIVelocity(100)

// Events 1-3: regular sixteenth-note intervals
var events = (0..<3).map { i in
    RhythmPattern.Event(
        sampleOffset: Int64(i) * samplesPerSixteenth,
        midiNote: clickNote,
        velocity: velocity
    )
}

// Event 4: shifted by trial offset
let baseOffset4 = 3 * samplesPerSixteenth
let offsetSamples = Int64(sampleRate.rawValue * trial.offset.duration.timeInterval)
events.append(RhythmPattern.Event(
    sampleOffset: baseOffset4 + offsetSamples,
    midiNote: clickNote,
    velocity: velocity
))

let pattern = RhythmPattern(
    events: events,
    sampleRate: sampleRate,
    totalDuration: sixteenthDuration * 4  // total window
)
```

Key: `trial.offset.duration` is signed — negative for early, positive for late. Adding it to `baseOffset4` naturally shifts the 4th note earlier or later.

### `sampleRate` injection

The session needs `SampleRate` to build patterns. Pass it as an init parameter. In `PeachApp`, use `soundFontEngine.sampleRate`. For tests, use `SampleRate.standard48000`.

### Determining correctness

The user taps "Early" or "Late". The answer is correct if the tapped direction matches the actual offset direction:

```swift
let isCorrect = (direction == trial.offset.direction)
```

Where `trial.offset.direction` returns `.early` (negative duration) or `.late` (positive duration) via `RhythmOffset.direction`.

### Observable state for the screen (story 48.3)

The screen will need:
- `state` — to enable/disable buttons and show dot animation
- `showFeedback` / `isLastAnswerCorrect` — for feedback indicator
- `currentOffsetPercentage: Double?` — current difficulty as percentage of sixteenth note, for feedback display

Compute `currentOffsetPercentage` from the current trial:
```swift
var currentOffsetPercentage: Double? {
    currentTrial?.offset.percentageOfSixteenthNote(at: currentTrial!.tempo)
}
```

### Training loop differences from PitchDiscriminationSession

1. **No sequential note playback** — rhythm plays a single `RhythmPattern` (all 4 notes scheduled at once via render-thread). The session calls `rhythmPlayer.play(pattern)` and the handle completes when the pattern finishes.
2. **Pattern completion detection** — `rhythmPlayer.play()` is async and returns a handle. The method awaits until the pattern has been scheduled. Since the render thread plays events at scheduled sample offsets, the session must sleep for the pattern's `totalDuration` to know when playback finishes, then transition to `awaitingAnswer`. Use `try await Task.sleep(for: pattern.totalDuration)` after the play call.
3. **No "early answer" during playback** — unlike pitch discrimination where the user can answer during `playingNote2`, rhythm offset detection requires the user to hear the full pattern before answering. Buttons are disabled during `playingPattern`.

### Interruption handling

Same pattern as `PitchDiscriminationSession`:
- `AudioSessionInterruptionMonitor` created in `init` with `onStopRequired: { [weak self] in self?.stop() }`
- `stop()` cancels all tasks, stops the rhythm playback handle, resets state to idle
- The handle's `stop()` calls `engine.clearSchedule()` which immediately silences the audio

### Composition root wiring in `PeachApp.swift`

Add a `createRhythmOffsetDetectionSession()` static helper:

```swift
private static func createRhythmOffsetDetectionSession(
    rhythmPlayer: RhythmPlayer,
    strategy: NextRhythmOffsetDetectionStrategy,
    profile: PerceptualProfile,
    dataStore: TrainingDataStore,
    sampleRate: SampleRate
) -> RhythmOffsetDetectionSession {
    let hapticManager = HapticFeedbackManager()
    let observers: [RhythmOffsetDetectionObserver] = [dataStore, profile, hapticManager]
    return RhythmOffsetDetectionSession(
        rhythmPlayer: rhythmPlayer,
        strategy: strategy,
        profile: profile,
        observers: observers,
        sampleRate: sampleRate
    )
}
```

Call in `init()` after the rhythm player is created. Inject via `.environment(\.rhythmOffsetDetectionSession, ...)`. Add `onChange(of: rhythmOffsetDetectionSession.isIdle)` for mutual exclusion with other sessions.

### Observer conformances

The following types already conform to `RhythmOffsetDetectionObserver`:
- `TrainingDataStore` — persists `RhythmOffsetDetectionRecord` to SwiftData
- `PerceptualProfile` — updates in-memory profile statistics
- `HapticFeedbackManager` — triggers haptic on incorrect answers

`ProgressTimeline` does NOT conform to `RhythmOffsetDetectionObserver`. It updates via `PerceptualProfile` changes, not direct observer notification.

### Environment key preview default

```swift
@Entry var rhythmOffsetDetectionSession: RhythmOffsetDetectionSession = {
    RhythmOffsetDetectionSession(
        rhythmPlayer: PreviewRhythmPlayer(),
        strategy: PreviewRhythmOffsetDetectionStrategy(),
        profile: PerceptualProfile(),
        sampleRate: .standard48000
    )
}()
```

You'll need `PreviewRhythmPlayer` and `PreviewRhythmOffsetDetectionStrategy` preview stubs in `EnvironmentKeys.swift`, following the existing pattern of `PreviewNotePlayer` and `PreviewPitchDiscriminationStrategy`.

### What NOT to do

- Do NOT use `ObservableObject` / `@Published` — use `@Observable`
- Do NOT add explicit `@MainActor` annotations — redundant with default isolation
- Do NOT import SwiftUI in the session file — it belongs in `RhythmOffsetDetection/`, not `Core/`; only import `Foundation`, `Observation`, `os`
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT use Combine (`PassthroughSubject`, `sink`)
- Do NOT poll with `while` loop + sleep for pattern completion — use `Task.sleep(for:)` after play call
- Do NOT access `UserSettings` from the session — all config comes through `RhythmOffsetDetectionSettings`
- Do NOT create the rhythm offset detection screen — that's story 48.3
- Do NOT re-create `MockRhythmPlayer` or `MockRhythmPlaybackHandle` — they already exist
- Do NOT re-create `MockNextRhythmOffsetDetectionStrategy` — it already exists
- Do NOT add the `@testable import` to test private methods — test through the public API

### Project Structure Notes

New files:
```
Peach/
├── RhythmOffsetDetection/
│   └── RhythmOffsetDetectionSession.swift    # NEW — session state machine
├── App/
│   ├── EnvironmentKeys.swift                 # MODIFIED — add @Entry + preview stubs
│   └── PeachApp.swift                        # MODIFIED — wire session

PeachTests/
├── RhythmOffsetDetection/
│   └── RhythmOffsetDetectionSessionTests.swift  # NEW
└── Mocks/
    └── MockRhythmOffsetDetectionObserver.swift   # NEW
```

### References

- [Source: Peach/PitchDiscrimination/PitchDiscriminationSession.swift — primary pattern to mirror]
- [Source: Peach/PitchMatching/PitchMatchingSession.swift — alternate session pattern]
- [Source: Peach/Core/TrainingSession.swift — protocol: `stop()`, `isIdle`]
- [Source: Peach/Core/Audio/RhythmPlayer.swift — `play(_ pattern:) async throws -> RhythmPlaybackHandle`, `stopAll()`]
- [Source: Peach/Core/Audio/RhythmPlaybackHandle.swift — `stop() async throws`]
- [Source: Peach/Core/Algorithm/NextRhythmOffsetDetectionStrategy.swift — `nextRhythmOffsetDetectionTrial(profile:settings:lastResult:)`]
- [Source: Peach/Core/Training/RhythmOffsetDetectionSettings.swift — `tempo`, `feedbackDuration`, `maxOffsetPercentage`, `minOffsetPercentage`]
- [Source: Peach/Core/Training/RhythmOffsetDetectionObserver.swift — `rhythmOffsetDetectionCompleted(_:)`]
- [Source: Peach/Core/Training/CompletedRhythmOffsetDetectionTrial.swift — `tempo`, `offset`, `isCorrect`, `timestamp`]
- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionTrial.swift — `tempo: TempoBPM`, `offset: RhythmOffset`]
- [Source: Peach/Core/Music/RhythmOffset.swift — `duration`, `direction`, `percentageOfSixteenthNote(at:)`]
- [Source: Peach/Core/Music/TempoBPM.swift — `sixteenthNoteDuration`]
- [Source: Peach/Core/Music/SampleRate.swift — `rawValue: Double`, `.standard48000`]
- [Source: Peach/Core/Music/Duration+TimeInterval.swift — `timeInterval` computed property]
- [Source: Peach/Core/Audio/AudioSessionInterruptionMonitor.swift — interruption handling pattern]
- [Source: Peach/RhythmPOC/RhythmPOCScreen.swift:71-92 — pattern building reference]
- [Source: Peach/App/PeachApp.swift — composition root, session creation, active session tracking]
- [Source: Peach/App/EnvironmentKeys.swift — `@Entry` pattern, preview stubs]
- [Source: PeachTests/Mocks/MockRhythmPlayer.swift — existing mock, do not re-create]
- [Source: PeachTests/Mocks/MockRhythmPlaybackHandle.swift — existing mock, do not re-create]
- [Source: PeachTests/Mocks/MockNextRhythmOffsetDetectionStrategy.swift — existing mock, do not re-create]
- [Source: Peach/PitchDiscrimination/HapticFeedbackManager.swift — already conforms to `RhythmOffsetDetectionObserver`]
- [Source: docs/planning-artifacts/architecture.md#RhythmOffsetDetectionSession — architecture specification]
- [Source: docs/planning-artifacts/epics.md#Story 48.2 — acceptance criteria]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
