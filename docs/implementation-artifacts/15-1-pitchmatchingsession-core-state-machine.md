# Story 15.1: PitchMatchingSession Core State Machine

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want a pitch matching training loop where I hear a reference note, then tune a second note to match it,
So that I train my ability to actively reproduce a target pitch.

## Acceptance Criteria

1. **PitchMatchingSession class created** — `@Observable final class` with dependencies: `notePlayer: NotePlayer`, `profile: PitchMatchingProfile`, `observers: [PitchMatchingObserver]`, `settingsOverride: TrainingSettings?`, `noteDurationOverride: TimeInterval?`, `notificationCenter: NotificationCenter`. Starts in `idle` state. File located at `Peach/PitchMatching/PitchMatchingSession.swift`.

2. **PitchMatchingSessionState enum created** — Cases: `idle`, `playingReference`, `playingTunable`, `showingFeedback`. Defined in the same file as `PitchMatchingSession`.

3. **startPitchMatching() begins the loop** — Generates a random `PitchMatchingChallenge` (random MIDI note within configured training range, random initial offset ±100 cents). Plays the reference note for configured duration using `notePlayer.play(frequency:duration:velocity:amplitudeDB:)`. State transitions to `playingReference`.

4. **Reference note completion auto-starts tunable** — When the reference note finishes, the session immediately starts the tunable note at the offset frequency using `notePlayer.play(frequency:velocity:amplitudeDB:)` (handle-returning, indefinite). State transitions to `playingTunable`. The session holds the returned `PlaybackHandle`.

5. **adjustFrequency delegates to handle** — When `adjustFrequency(_ frequency: Double)` is called (from slider movement) in `playingTunable` state, the session calls `currentHandle?.adjustFrequency(frequency)`.

6. **commitResult records and notifies** — When `commitResult(userFrequency: Double)` is called (slider released) in `playingTunable` state: stops the tunable note via `currentHandle?.stop()`, computes signed cent error between user frequency and reference frequency using `FrequencyCalculation`, creates a `CompletedPitchMatching` with referenceNote/initialCentOffset/userCentError/timestamp, notifies all observers via `pitchMatchingCompleted(_:)`, transitions to `showingFeedback`.

7. **Feedback auto-advances** — After ~400ms in `showingFeedback`, the session automatically starts the next challenge (back to `playingReference`).

8. **Random challenge generation** — Note is random within `TrainingSettings.noteRangeMin...noteRangeMax`. Initial cent offset is random within ±100 cents. This logic is a private method — no protocol, no separate file.

9. **All existing tests pass** — New tests verify: state transitions (idle → playingReference → playingTunable → showingFeedback → loop), random challenge generation within configured range, adjustFrequency delegation to handle, commitResult computation and observer notification, feedback timer auto-advance.

## Tasks / Subtasks

- [ ] Task 1: Create PitchMatchingSessionState enum and PitchMatchingSession skeleton (AC: #1, #2)
  - [ ] 1.1 Create `Peach/PitchMatching/PitchMatchingSession.swift` with `PitchMatchingSessionState` enum and `@Observable final class PitchMatchingSession`
  - [ ] 1.2 Add constructor with all dependencies: `notePlayer: NotePlayer`, `profile: PitchMatchingProfile`, `observers: [PitchMatchingObserver]`, `settingsOverride: TrainingSettings?`, `noteDurationOverride: TimeInterval?`, `notificationCenter: NotificationCenter`
  - [ ] 1.3 Add observable `state: PitchMatchingSessionState = .idle` property
  - [ ] 1.4 Add `currentChallenge: PitchMatchingChallenge?` read-only property for UI consumption
  - [ ] 1.5 Add `lastResult: CompletedPitchMatching?` read-only property for feedback display
  - [ ] 1.6 Write initial tests: session starts in idle state, state is observable

- [ ] Task 2: Implement challenge generation (AC: #8)
  - [ ] 2.1 Add private `currentSettings: TrainingSettings` computed property (read live from `UserDefaults`, same pattern as `ComparisonSession`)
  - [ ] 2.2 Add private `currentNoteDuration: TimeInterval` computed property (read from `UserDefaults` with `noteDurationOverride` support)
  - [ ] 2.3 Add private `generateChallenge() -> PitchMatchingChallenge` that picks random MIDI note in `noteRangeMin...noteRangeMax` and random offset in `-100...100` cents
  - [ ] 2.4 Write tests: generated challenges have note within configured range, offset within ±100 cents

- [ ] Task 3: Implement startPitchMatching() and main loop (AC: #3, #4, #7)
  - [ ] 3.1 Add `startPitchMatching()` method that generates a challenge and begins the training loop via a spawned `Task`
  - [ ] 3.2 Implement reference note playback: compute reference frequency via `FrequencyCalculation.frequency(midiNote:referencePitch:)`, play fixed-duration note, transition to `playingReference`
  - [ ] 3.3 Implement tunable note auto-start: after reference completes, compute tunable frequency at offset, play indefinite note via handle-returning `play(frequency:velocity:amplitudeDB:)`, store `PlaybackHandle`, transition to `playingTunable`
  - [ ] 3.4 Implement feedback timer: after result committed, wait ~400ms then auto-start next challenge
  - [ ] 3.5 Add `trainingTask: Task<Void, Never>?` and `feedbackTask: Task<Void, Never>?` for cancellation support
  - [ ] 3.6 Write tests: state transitions through full cycle (idle → playingReference → playingTunable → showingFeedback → playingReference), reference note played at correct frequency, tunable note played at offset frequency

- [ ] Task 4: Implement adjustFrequency and commitResult (AC: #5, #6)
  - [ ] 4.1 Add `adjustFrequency(_ frequency: Double)` — guard state is `playingTunable`, call `currentHandle?.adjustFrequency(frequency)`
  - [ ] 4.2 Add `commitResult(userFrequency: Double)` — guard state is `playingTunable`, stop handle, compute signed cent error via `FrequencyCalculation.midiNoteAndCents()` approach, create `CompletedPitchMatching`, notify observers, transition to `showingFeedback`
  - [ ] 4.3 Implement cent error computation: `userCentError = 1200 * log2(userFrequency / referenceFrequency)` (signed — positive means user was sharp, negative means flat)
  - [ ] 4.4 Write tests: adjustFrequency delegates to handle, commitResult stops handle and computes correct cent error, observers notified with correct CompletedPitchMatching

- [ ] Task 5: Create MockPitchMatchingProfile and MockPitchMatchingObserver (AC: #9)
  - [ ] 5.1 Create `PeachTests/PitchMatching/MockPitchMatchingProfile.swift` conforming to `PitchMatchingProfile` with call tracking
  - [ ] 5.2 Create `PeachTests/PitchMatching/MockPitchMatchingObserver.swift` conforming to `PitchMatchingObserver` with call tracking
  - [ ] 5.3 Create `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` test suite with factory method returning `(session:, notePlayer:, profile:, observer:)` tuple

- [ ] Task 6: Run full test suite and verify (AC: #9)
  - [ ] 6.1 Run `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] 6.2 Verify all existing tests pass (430 from story 14.2) with zero regressions
  - [ ] 6.3 Verify all new PitchMatchingSession tests pass

## Dev Notes

### Technical Requirements

- **`@Observable final class`** — use `@Observable` macro, NOT `ObservableObject`/`@Published`. [Source: docs/project-context.md#Technology-Stack]
- **Default MainActor isolation** — do NOT add explicit `@MainActor` to the class or methods. Swift 6.2 default isolation applies. Only use `@MainActor` inside `@Sendable` closures (e.g., notification callbacks). [Source: docs/project-context.md#Concurrency]
- **Protocol-typed dependencies** — constructor takes `NotePlayer` (not `SoundFontNotePlayer`), `PitchMatchingProfile` (not `PerceptualProfile`). This enables test mocking without frameworks. [Source: docs/project-context.md#Error-Handling]
- **Settings read live** — read `UserDefaults` on each new challenge, not cached. Support `settingsOverride` for test injection (same pattern as `ComparisonSession.currentSettings`). [Source: docs/project-context.md#State-Management]
- **Feedback phase is 0.4 seconds** — hardcoded `feedbackDuration` constant. This is a perceptual learning design decision. [Source: docs/project-context.md#Domain-Rules]
- **Spawned Tasks must produce observable side effects** — state changes that tests can synchronize on. No fire-and-forget without test hooks. [Source: docs/project-context.md#Async/Await]
- **Task cancellation** — check for `CancellationError` before generic error handling. Cancellation is a graceful stop, not a failure. [Source: docs/project-context.md#Async/Await]
- **Cent error computation** — `userCentError = 1200.0 * log2(userFrequency / referenceFrequency)`. This gives a signed value: positive = user was sharp, negative = user was flat. Do NOT use `FrequencyCalculation.midiNoteAndCents()` for this — it rounds to nearest MIDI note which loses precision. Compute directly from the two frequencies.
- **No `NextComparisonStrategy` dependency** — note selection is random for v0.2. Private method inside the session. No protocol, no separate file. [Source: docs/planning-artifacts/architecture.md#Note-Selection-v0.2]

### Architecture Compliance

- **Exact constructor signature from architecture doc:**
  ```swift
  init(
      notePlayer: NotePlayer,
      profile: PitchMatchingProfile,
      observers: [PitchMatchingObserver] = [],
      settingsOverride: TrainingSettings? = nil,
      noteDurationOverride: TimeInterval? = nil,
      notificationCenter: NotificationCenter = .default
  )
  ```
  [Source: docs/planning-artifacts/architecture.md#PitchMatchingSession-State-Machine]

- **State enum from architecture:**
  ```swift
  enum PitchMatchingSessionState {
      case idle
      case playingReference
      case playingTunable
      case showingFeedback
  }
  ```

- **State transition flow:**
  ```
  idle
    ↓ startPitchMatching()
  playingReference (configured duration)
    ↓ reference note finishes
  playingTunable (indefinite — auto-starts immediately)
    ↓ commitResult() — slider released
  showingFeedback (~400ms)
    ↓ feedback timer expires
  playingReference (next challenge, loop)
  ```

- **Data flow:**
  1. `PitchMatchingSession` generates a random `PitchMatchingChallenge` (note + offset)
  2. Plays reference note via `NotePlayer` (fixed duration) — uses `play(frequency:duration:velocity:amplitudeDB:)`
  3. Plays tunable note via `NotePlayer` (indefinite) — uses handle-returning `play(frequency:velocity:amplitudeDB:)`
  4. Receives frequency updates from slider → `handle.adjustFrequency(newFreq)`
  5. On slider release → `handle.stop()`, records result, notifies observers
  6. Observers persist (`TrainingDataStore`) and update profile (`PerceptualProfile`)
  [Source: docs/planning-artifacts/architecture.md#PitchMatchingSession-State-Machine]

- **Mirrors ComparisonSession patterns:**
  - Error boundary — catches all service errors; training loop continues gracefully
  - Observer injection — array of `PitchMatchingObserver` (mirrors `[ComparisonObserver]`)
  - Environment injection — wired in `PeachApp.swift`, injected via `@Environment`
  - `currentHandle: PlaybackHandle?` — held for interruption cleanup and frequency adjustment
  - `trainingTask` / `feedbackTask` — for cancellation support

- **Scope boundary:** This story creates the core state machine only. It does NOT include:
  - Interruption/lifecycle handling (story 15.2)
  - UI screen (story 16.x)
  - Navigation/wiring in `PeachApp.swift` (story 16.x or later)
  - `stop()` method — basic cancel via `trainingTask?.cancel()` for now; full stop() with handle cleanup in story 15.2

### Library & Framework Requirements

- **No new dependencies** — pure Swift, `Foundation` for `Date`/`TimeInterval`/`NotificationCenter`. [Source: docs/project-context.md#Technology-Stack]
- **Zero third-party dependencies** — project rule. [Source: docs/project-context.md#Technology-Stack]
- **`@Observable` interaction** — `PitchMatchingSession` is `@Observable`. Properties `state`, `currentChallenge`, `lastResult` participate in observation automatically. SwiftUI views will re-render on state changes.
- **Use existing `FrequencyCalculation`** — `FrequencyCalculation.frequency(midiNote:cents:referencePitch:)` for Hz conversion. Never reimplement frequency math. [Source: docs/project-context.md#Domain-Rules]
- **Use existing `PitchMatchingChallenge`** — value type already exists at `Peach/PitchMatching/PitchMatchingChallenge.swift` (created in architecture). Do not recreate.
- **Use existing `CompletedPitchMatching`** — value type at `Peach/PitchMatching/CompletedPitchMatching.swift` (created in story 13.1). Do not recreate.
- **Use existing `PitchMatchingObserver`** — protocol at `Peach/PitchMatching/PitchMatchingObserver.swift` (created in story 13.1). Do not recreate.
- **Use existing `PitchMatchingProfile`** — protocol at `Peach/Core/Profile/PitchMatchingProfile.swift` (created in story 14.2). Do not recreate.
- **Use existing `TrainingSettings`** — struct defined in `Peach/Core/Algorithm/NextComparisonStrategy.swift`. Read `noteRangeMin`, `noteRangeMax`, `referencePitch` from it.
- **Use existing mocks** — `MockNotePlayer` at `PeachTests/Comparison/MockNotePlayer.swift`, `MockPlaybackHandle` at `PeachTests/Mocks/MockPlaybackHandle.swift`. Both support handle tracking and `instantPlayback` mode.

### File Structure Requirements

**New files:**
| File | Location | Description |
|------|----------|-------------|
| `PitchMatchingSession.swift` | `Peach/PitchMatching/` | State machine + `PitchMatchingSessionState` enum |
| `PitchMatchingSessionTests.swift` | `PeachTests/PitchMatching/` | Test suite for session |
| `MockPitchMatchingProfile.swift` | `PeachTests/PitchMatching/` | Mock conforming to `PitchMatchingProfile` |
| `MockPitchMatchingObserver.swift` | `PeachTests/PitchMatching/` | Mock conforming to `PitchMatchingObserver` |

**No modified files** — This story only creates new files. `PeachApp.swift` wiring happens in a later story.

**`PitchMatching/` directory after this story:**
```
Peach/PitchMatching/
├── PitchMatchingSession.swift        # NEW: state machine
├── PitchMatchingObserver.swift       # Exists (story 13.1)
├── CompletedPitchMatching.swift      # Exists (story 13.1)
└── PitchMatchingChallenge.swift      # Exists (architecture)
```

**Test directory:**
```
PeachTests/PitchMatching/
├── PitchMatchingSessionTests.swift   # NEW
├── MockPitchMatchingProfile.swift    # NEW
└── MockPitchMatchingObserver.swift   # NEW
```

### Testing Requirements

- **Swift Testing only** — `@Test`, `@Suite`, `#expect()`. Never XCTest. [Source: docs/project-context.md#Testing-Rules]
- **All test functions must be `async`** — default MainActor isolation handles actor safety. [Source: docs/project-context.md#Testing-Rules]
- **No `test` prefix** on function names — `@Test` attribute marks the test. [Source: docs/project-context.md#Testing-Rules]
- **Behavioral test descriptions** — e.g., `@Test("starts in idle state")`. [Source: docs/project-context.md#Testing-Rules]
- **Struct-based suites** — no classes, no `setUp`/`tearDown`; use factory methods for fixtures. [Source: docs/project-context.md#Testing-Rules]
- **Run full suite**: `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'` [Source: docs/project-context.md#Pre-Commit-Gate]
- **`instantPlayback` mode on `MockNotePlayer`** — set `instantPlayback = true` (default) for deterministic timing. Fixed-duration `play()` completes instantly. [Source: PeachTests/Comparison/MockNotePlayer.swift]
- **Handle tracking on `MockNotePlayer`** — `lastHandle` and `handleHistory` track `MockPlaybackHandle` instances. Verify `adjustFrequency` calls via `handle.adjustFrequencyCallCount` and `handle.lastAdjustedFrequency`.

**New mocks to create:**

1. **MockPitchMatchingProfile** — follows mock contract from project-context.md:
   ```swift
   final class MockPitchMatchingProfile: PitchMatchingProfile {
       var updateMatchingCallCount = 0
       var lastNote: Int?
       var lastCentError: Double?
       var matchingMean: Double? = nil
       var matchingStdDev: Double? = nil
       var matchingSampleCount: Int = 0
       var resetMatchingCallCount = 0

       func updateMatching(note: Int, centError: Double) {
           updateMatchingCallCount += 1
           lastNote = note
           lastCentError = centError
       }

       func resetMatching() {
           resetMatchingCallCount += 1
       }

       func reset() { /* ... */ }
   }
   ```

2. **MockPitchMatchingObserver** — tracks observer calls:
   ```swift
   final class MockPitchMatchingObserver: PitchMatchingObserver {
       var pitchMatchingCompletedCallCount = 0
       var lastResult: CompletedPitchMatching?
       var resultHistory: [CompletedPitchMatching] = []

       func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
           pitchMatchingCompletedCallCount += 1
           lastResult = result
           resultHistory.append(result)
       }

       func reset() { /* ... */ }
   }
   ```

3. **Factory method** for test fixture:
   ```swift
   func makePitchMatchingSession(
       settingsOverride: TrainingSettings? = TrainingSettings(),
       noteDurationOverride: TimeInterval? = 0.0
   ) -> (session: PitchMatchingSession, notePlayer: MockNotePlayer, profile: MockPitchMatchingProfile, observer: MockPitchMatchingObserver)
   ```
   **Note:** Use `noteDurationOverride: 0.0` in tests — with `instantPlayback = true` on the mock, this makes the reference note complete instantly so the session transitions to `playingTunable` without delay.

**Key tests to write:**

1. **Starts in idle** — `session.state == .idle`
2. **startPitchMatching transitions to playingReference** — verify state after calling `startPitchMatching()`
3. **Reference note played at correct frequency** — verify `notePlayer.lastFrequency` matches `FrequencyCalculation.frequency(midiNote: challenge.referenceNote, referencePitch:)`
4. **Auto-transitions to playingTunable** — after reference note completes, state becomes `playingTunable`
5. **Tunable note played at offset frequency** — verify handle-returning `play()` called with frequency = reference + cent offset
6. **adjustFrequency delegates to handle** — call `session.adjustFrequency(newFreq)`, verify `handle.lastAdjustedFrequency == newFreq`
7. **commitResult stops handle** — call `session.commitResult(userFrequency:)`, verify `handle.stopCallCount == 1`
8. **commitResult computes correct cent error** — verify observer receives correct `userCentError` (signed)
9. **commitResult notifies observers** — verify `observer.pitchMatchingCompletedCallCount == 1` and result fields correct
10. **Transitions to showingFeedback after commitResult** — verify `session.state == .showingFeedback`
11. **Auto-advances from showingFeedback** — after feedback, state returns to `playingReference`
12. **Challenge has note within range** — verify `challenge.referenceNote` is within `noteRangeMin...noteRangeMax`
13. **Challenge has offset within ±100** — verify `abs(challenge.initialCentOffset) <= 100`

**State waiting pattern for PitchMatchingSession** — need a `waitForState` helper similar to ComparisonSession's:
```swift
func waitForState(
    _ session: PitchMatchingSession,
    _ expectedState: PitchMatchingSessionState,
    timeout: Duration = .seconds(2)
) async throws {
    let deadline = ContinuousClock.now + timeout
    while session.state != expectedState {
        guard ContinuousClock.now < deadline else {
            throw WaitError.timeout(expected: "\(expectedState)", actual: "\(session.state)")
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}
```

### Previous Story Intelligence (Story 14.2)

- **430 tests passing** as of story 14.2 completion. All must pass unchanged.
- **Key learning: `AnyObject` constraint on profile protocols** — `PitchMatchingProfile` already has `: AnyObject` (added in 14.2 following 14.1's learning). The mock must be a `class` (not `struct`).
- **Key learning: no default implementations in protocols** — all mock methods must be explicitly implemented.
- **Key learning: update ALL conforming types** — when creating new mocks, ensure they implement every protocol method.
- **Code review pattern: stale docstrings** — check that any comments reference correct type names. Do not add unnecessary documentation.
- **`CompletedPitchMatching` already exists** — created in story 13.1 with `init(referenceNote:initialCentOffset:userCentError:timestamp:)`. The `timestamp` parameter has a default value of `Date()`.
- **`PitchMatchingObserver` already exists** — protocol with single method `pitchMatchingCompleted(_ result: CompletedPitchMatching)`.
- **`PitchMatchingChallenge` already exists** — struct with `referenceNote: Int` and `initialCentOffset: Double`.
- **`TrainingDataStore` already conforms to `PitchMatchingObserver`** — from story 13.1. It persists `PitchMatchingRecord` on `pitchMatchingCompleted(_:)`.
- **`PerceptualProfile` already conforms to `PitchMatchingObserver`** — from story 14.2. It updates matching statistics via Welford's algorithm.

### Git Intelligence

```
397fef8 Fix code review findings for 14-2-pitchmatchingprofile-protocol-and-matching-statistics
486b158 Implement story 14.2: PitchMatchingProfile Protocol and Matching Statistics
49c5408 Add story 14.2: PitchMatchingProfile Protocol and Matching Statistics
c317de9 Fix code review findings for 14-1-extract-pitchdiscriminationprofile-protocol
feee989 Implement story 14.1: Extract PitchDiscriminationProfile Protocol
```

- **Commit pattern:** `Add story X.Y: Title` for story creation, `Implement story X.Y: Title` for implementation, `Fix code review findings for X-Y-slug` for review fixes.
- **Previous epics 13-14 built the PitchMatching data/profile foundation** — this story builds the session state machine on top.
- **All prerequisites already exist:** `PitchMatchingRecord` (13.1), `PitchMatchingObserver` (13.1), `CompletedPitchMatching` (13.1), `PitchMatchingChallenge` (architecture), `PitchMatchingProfile` (14.2), `PlaybackHandle` (12.1), `NotePlayer` handle-returning `play()` (12.1).

### Existing Code Patterns to Follow

**ComparisonSession constructor pattern** (mirror for PitchMatchingSession):
```swift
// ComparisonSession stores dependencies as private properties
private let notePlayer: NotePlayer
private let strategy: NextComparisonStrategy
private let profile: PitchDiscriminationProfile
private let observers: [ComparisonObserver]
private let settingsOverride: TrainingSettings?
private let noteDurationOverride: TimeInterval?
private let notificationCenter: NotificationCenter
```

**ComparisonSession settings reading pattern** (copy for PitchMatchingSession):
```swift
private var currentSettings: TrainingSettings {
    if let override = settingsOverride { return override }
    let defaults = UserDefaults.standard
    return TrainingSettings(
        noteRangeMin: defaults.object(forKey: SettingsKeys.noteRangeMin) as? Int ?? 36,
        noteRangeMax: defaults.object(forKey: SettingsKeys.noteRangeMax) as? Int ?? 84,
        // ... (only need noteRangeMin, noteRangeMax, referencePitch for pitch matching)
        referencePitch: defaults.object(forKey: SettingsKeys.referencePitch) as? Double ?? 440.0
    )
}
```

**ComparisonSession feedback timer pattern:**
```swift
feedbackTask = Task {
    try? await Task.sleep(for: .milliseconds(400))
    guard !Task.isCancelled else { return }
    // start next challenge
}
```

**MockPlaybackHandle usage pattern** (from existing tests):
- `MockNotePlayer.handleHistory` tracks all `MockPlaybackHandle` instances
- Verify handle calls: `handle.adjustFrequencyCallCount`, `handle.lastAdjustedFrequency`, `handle.stopCallCount`
- `MockNotePlayer.instantPlayback = true` makes fixed-duration `play()` complete immediately

### Pitfalls and Anti-Patterns to Avoid

1. **Do NOT use `ObservableObject` or `@Published`** — use `@Observable` macro. [Source: docs/project-context.md#Never-Do-This]
2. **Do NOT add explicit `@MainActor`** — redundant with default MainActor isolation. [Source: docs/project-context.md#Concurrency]
3. **Do NOT create a `NextPitchMatchingStrategy` protocol** — note selection is random in v0.2, implemented as a private method. [Source: docs/planning-artifacts/architecture.md#Note-Selection-v0.2]
4. **Do NOT reimplement frequency calculation** — use `FrequencyCalculation.frequency(midiNote:cents:referencePitch:)`. [Source: docs/project-context.md#Domain-Rules]
5. **Do NOT create `PitchMatchingChallenge`** — it already exists at `Peach/PitchMatching/PitchMatchingChallenge.swift`.
6. **Do NOT create `CompletedPitchMatching`** — it already exists at `Peach/PitchMatching/CompletedPitchMatching.swift`.
7. **Do NOT create `PitchMatchingObserver`** — it already exists at `Peach/PitchMatching/PitchMatchingObserver.swift`.
8. **Do NOT modify `ComparisonSession`** — it depends only on `PitchDiscriminationProfile` and has no awareness of pitch matching.
9. **Do NOT wire into `PeachApp.swift` yet** — composition root wiring happens in a later story when the UI screen is created.
10. **Do NOT implement `stop()` with full lifecycle handling** — story 15.2 covers interruption handling. For now, provide a basic `stop()` that cancels the training task and transitions to idle, but full notification observers and handle cleanup are 15.2 scope.
11. **Do NOT use `FrequencyCalculation.midiNoteAndCents()` for cent error** — it rounds to nearest MIDI note, losing sub-semitone precision. Compute cent error directly: `1200.0 * log2(userFrequency / referenceFrequency)`.
12. **Do NOT cache settings** — read from `UserDefaults` on each new challenge (same as `ComparisonSession`).
13. **Do NOT use Combine** (`PassthroughSubject`, `sink`) — use `async/await`. [Source: docs/project-context.md#Never-Do-This]
14. **Do NOT add `@testable import` to test private methods** — test through the public API. [Source: docs/project-context.md#Never-Do-This]

### Project Structure Notes

- `PitchMatchingSession.swift` goes in `Peach/PitchMatching/` alongside existing pitch matching types — matches architecture doc structure. [Source: docs/planning-artifacts/architecture.md#Updated-Project-Structure-v0.2]
- Test files go in `PeachTests/PitchMatching/` — create directory if it doesn't exist (mirrors `PeachTests/Comparison/`).
- Mocks go in test directory alongside tests (not in `PeachTests/Mocks/`) — follows the pattern where feature-specific mocks live with their tests.
- No new directories needed in source target.

### References

- [Source: docs/planning-artifacts/architecture.md#PitchMatchingSession-State-Machine]
- [Source: docs/planning-artifacts/architecture.md#Note-Selection-v0.2]
- [Source: docs/planning-artifacts/architecture.md#Updated-Project-Structure-v0.2]
- [Source: docs/planning-artifacts/epics.md#Epic-15-Story-15.1]
- [Source: docs/project-context.md#Technology-Stack]
- [Source: docs/project-context.md#Concurrency]
- [Source: docs/project-context.md#Testing-Rules]
- [Source: docs/project-context.md#Domain-Rules]
- [Source: docs/project-context.md#State-Management]
- [Source: docs/project-context.md#Never-Do-This]
- [Source: Peach/Comparison/ComparisonSession.swift — state machine pattern to mirror]
- [Source: Peach/Core/Audio/NotePlayer.swift — protocol with handle-returning play()]
- [Source: Peach/Core/Audio/PlaybackHandle.swift — handle protocol for stop/adjustFrequency]
- [Source: Peach/Core/Audio/FrequencyCalculation.swift — frequency conversion utilities]
- [Source: Peach/PitchMatching/PitchMatchingObserver.swift — observer protocol (exists)]
- [Source: Peach/PitchMatching/CompletedPitchMatching.swift — result value type (exists)]
- [Source: Peach/PitchMatching/PitchMatchingChallenge.swift — challenge value type (exists)]
- [Source: Peach/Core/Profile/PitchMatchingProfile.swift — profile protocol (exists)]
- [Source: Peach/Core/Algorithm/NextComparisonStrategy.swift — TrainingSettings struct]
- [Source: Peach/Settings/SettingsKeys.swift — UserDefaults key constants]
- [Source: PeachTests/Comparison/MockNotePlayer.swift — mock with handle tracking and instantPlayback]
- [Source: PeachTests/Mocks/MockPlaybackHandle.swift — mock with adjustFrequency tracking]
- [Source: docs/implementation-artifacts/14-2-pitchmatchingprofile-protocol-and-matching-statistics.md — previous story learnings]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
