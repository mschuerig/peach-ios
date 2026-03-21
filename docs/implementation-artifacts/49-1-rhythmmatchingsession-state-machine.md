# Story 49.1: RhythmMatchingSession State Machine

Status: ready-for-dev

## Story

As a **developer**,
I want a `RhythmMatchingSession` that plays 3 lead-in notes and measures the user's tap timing,
so that the rhythm matching training loop works end-to-end with proper state management.

## Acceptance Criteria

1. **Given** `RhythmMatchingSession` is `@Observable`, **when** inspected, **then** it follows the state machine: `idle -> playingLeadIn -> awaitingTap -> showingFeedback -> loop`.

2. **Given** `start()` is called, **when** the session transitions from idle, **then** it builds a `RhythmPattern` with 3 events at sixteenth-note intervals at the configured tempo **and** calls `rhythmPlayer.play(pattern)` and awaits the handle.

3. **Given** the lead-in pattern completes, **when** the session transitions to `awaitingTap`, **then** the session records the expected tap time (pattern end + one sixteenth-note duration).

4. **Given** the user taps, **when** tap timing is measured, **then** the session uses `CACurrentMediaTime()` for microsecond precision **and** computes `userOffset = RhythmOffset(duration: .seconds(actualTapTime - expectedTapTime))` **and** observers are notified with a `CompletedRhythmMatchingTrial`.

5. **Given** the session transitions to `showingFeedback`, **when** ~400ms elapses, **then** it automatically starts the next lead-in.

6. **Given** interruption occurs, **when** in any state other than idle, **then** the session stops, discards incomplete exercises, transitions to idle (FR79, FR79a).

7. **Given** no strategy protocol is needed, **when** challenged, **then** selection is trivial — play 3 notes at the configured tempo. No `NextRhythmMatchingStrategy` protocol.

8. **Given** unit tests using `MockRhythmPlayer`, **when** all state transitions are tested, **then** full coverage including interruption and tap timing measurement.

## Tasks / Subtasks

- [ ] Task 1: Create `RhythmMatchingSettings` value type (AC: #2, #5)
  - [ ] Create `Peach/Core/Training/RhythmMatchingSettings.swift`
  - [ ] Properties: `tempo: TempoBPM`, `feedbackDuration: Duration = .milliseconds(400)`
  - [ ] Conform to `Sendable`
  - [ ] Write tests in `PeachTests/Core/Training/RhythmMatchingSettingsTests.swift`

- [ ] Task 2: Create `RhythmMatchingSession` with state machine (AC: #1, #2, #3, #4, #5, #6)
  - [ ] Create `Peach/RhythmMatching/RhythmMatchingSession.swift`
  - [ ] Define `RhythmMatchingSessionState` enum: `idle`, `playingLeadIn`, `awaitingTap`, `showingFeedback`
  - [ ] `@Observable final class RhythmMatchingSession: TrainingSession`
  - [ ] Dependencies: `rhythmPlayer: RhythmPlayer`, `observers: [RhythmMatchingObserver]`, `sampleRate: SampleRate`, `notificationCenter: NotificationCenter`
  - [ ] Observable state: `state`, `showFeedback: Bool`, `litDotCount: Int`, `lastUserOffsetPercentage: Double?`
  - [ ] `start(settings: RhythmMatchingSettings)` — guards idle, stores settings, starts training loop
  - [ ] `handleTap()` — guards `awaitingTap`, records `CACurrentMediaTime()`, computes `RhythmOffset`, notifies observers, transitions to feedback
  - [ ] `stop()` — cancels tasks, stops player, resets all state to idle
  - [ ] Private: `runTrainingLoop()`, `playNextTrial()`, `buildPattern(settings:)`, `transitionToFeedback(settings:)`
  - [ ] `AudioSessionInterruptionMonitor` for interruption handling (same as RhythmOffsetDetectionSession)

- [ ] Task 3: Implement `buildPattern` — 3-note lead-in only (AC: #2, #7)
  - [ ] Build `RhythmPattern` with exactly 3 events (note indices 0, 1, 2) at sixteenth-note intervals
  - [ ] No 4th note — the user provides the 4th beat by tapping
  - [ ] `totalDuration = sixteenthDuration * 3` (3 notes, not 4)
  - [ ] Use same click note (`MIDINote(76)`) and velocity (`MIDIVelocity(100)`) as RhythmOffsetDetectionSession

- [ ] Task 4: Implement dot animation and expected tap time (AC: #3)
  - [ ] In `playNextTrial()`: animate `litDotCount` 1, 2, 3 at sixteenth-note intervals during `playingLeadIn`
  - [ ] After 3rd dot + one sixteenth-note wait: record `expectedTapTime = CACurrentMediaTime()` (the moment the 4th beat should fall)
  - [ ] Transition to `awaitingTap`

- [ ] Task 5: Implement `handleTap()` with microsecond precision (AC: #4)
  - [ ] Record `actualTapTime = CACurrentMediaTime()` immediately
  - [ ] Compute `userOffset = RhythmOffset(duration: .seconds(actualTapTime - expectedTapTime))`
  - [ ] Light 4th dot: `litDotCount = 4`
  - [ ] Create `CompletedRhythmMatchingTrial(tempo:expectedOffset:userOffset:timestamp:)`
  - [ ] `expectedOffset` is always `.zero` (4th note should fall exactly on the beat)
  - [ ] Notify all observers
  - [ ] Transition to feedback

- [ ] Task 6: Wire into `PeachApp.swift` (AC: #1)
  - [ ] Add `@State private var rhythmMatchingSession: RhythmMatchingSession`
  - [ ] Create `createRhythmMatchingSession()` private method (mirror `createRhythmOffsetDetectionSession()`)
  - [ ] Inject via `.environment(\.rhythmMatchingSession, rhythmMatchingSession)`
  - [ ] Add `onChange(of: rhythmMatchingSession.isIdle)` monitoring for active session tracking
  - [ ] Add `@Entry var rhythmMatchingSession` in `EnvironmentKeys.swift`

- [ ] Task 7: Write comprehensive tests (AC: #8)
  - [ ] Create `PeachTests/RhythmMatching/RhythmMatchingSessionTests.swift`
  - [ ] Test initial state is `idle`
  - [ ] Test `start()` transitions to `playingLeadIn`
  - [ ] Test `start()` when not idle is ignored
  - [ ] Test pattern has exactly 3 events (no 4th note)
  - [ ] Test transition from `playingLeadIn` to `awaitingTap`
  - [ ] Test `handleTap()` transitions to `showingFeedback` and notifies observers
  - [ ] Test `handleTap()` when not `awaitingTap` is ignored
  - [ ] Test feedback auto-starts next lead-in after duration
  - [ ] Test `stop()` transitions to idle and cancels playback
  - [ ] Test `stop()` when idle is no-op
  - [ ] Test interruption stops session
  - [ ] Test `litDotCount` increments 1, 2, 3 during lead-in and 4 on tap
  - [ ] Test `lastUserOffsetPercentage` updates after tap
  - [ ] Test observer receives `CompletedRhythmMatchingTrial` with correct tempo and offsets
  - [ ] Create `PeachTests/Core/Training/RhythmMatchingSettingsTests.swift`

- [ ] Task 8: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Mirror `RhythmOffsetDetectionSession` — with key differences

`RhythmMatchingSession` follows the same patterns as `RhythmOffsetDetectionSession` but with these critical differences:

| RhythmOffsetDetection | RhythmMatching |
|---|---|
| Plays 4 notes (4th offset early/late) | Plays 3 notes (user taps 4th) |
| `awaitingAnswer` — user picks Early/Late | `awaitingTap` — user taps at correct moment |
| `handleAnswer(direction:)` | `handleTap()` |
| Binary correct/incorrect | Continuous signed offset |
| Needs `NextRhythmOffsetDetectionStrategy` | No strategy needed — always 3 notes at tempo |
| `CompletedRhythmOffsetDetectionTrial` | `CompletedRhythmMatchingTrial` |
| `RhythmOffsetDetectionObserver` | `RhythmMatchingObserver` |
| `isLastAnswerCorrect: Bool?` | No correctness — always valid |
| `sessionBestOffsetPercentage` | Not needed (no "correct" baseline) |
| `currentOffsetPercentage` (difficulty) | Not applicable |

### State machine: `idle -> playingLeadIn -> awaitingTap -> showingFeedback -> loop`

```
idle ──start()──> playingLeadIn ──pattern done──> awaitingTap ──handleTap()──> showingFeedback ──400ms──> playingLeadIn
  ^                                                                                                          |
  └──────────────────────── stop() / interruption ◄──────────────────────────────────────────────────────────┘
```

### Tap timing with `CACurrentMediaTime()`

Record `expectedTapTime` at the moment the 4th beat should fall (after 3 sixteenth-note intervals from lead-in start). When the user taps, immediately capture `actualTapTime = CACurrentMediaTime()`. Compute:

```swift
let offset = actualTapTime - expectedTapTime
let userOffset = RhythmOffset(duration: .seconds(offset))
// Negative = early, positive = late
```

**The tap button is always enabled** (UX-DR3). Tapping during lead-in produces valid (likely poor) timing data. If the user taps before `awaitingTap`, let `handleTap()` guard and ignore it — the button being always enabled is a UI concern for Story 49.2.

### Pattern construction — 3 notes only

Unlike `RhythmOffsetDetectionSession.buildPattern()` which builds 4 events (with the 4th offset), rhythm matching builds exactly 3:

```swift
private func buildPattern(settings: RhythmMatchingSettings) -> RhythmPattern {
    let sixteenthDuration = settings.tempo.sixteenthNoteDuration
    let samplesPerSixteenth = Int64(sampleRate.rawValue * sixteenthDuration.timeInterval)
    let clickNote = MIDINote(76)
    let velocity = MIDIVelocity(100)

    let events = (0..<3).map { i in
        RhythmPattern.Event(
            sampleOffset: Int64(i) * samplesPerSixteenth,
            midiNote: clickNote,
            velocity: velocity
        )
    }
    return RhythmPattern(
        events: events,
        sampleRate: sampleRate,
        totalDuration: sixteenthDuration * 3
    )
}
```

### Expected tap time calculation

After pattern playback + dot animation, wait one more sixteenth-note duration (the gap where the 4th note should fall), then:

```swift
expectedTapTime = CACurrentMediaTime()
state = .awaitingTap
```

This captures the precise moment the beat should land. The `awaitingTap` state begins at this point.

### `CompletedRhythmMatchingTrial` — already exists

```swift
struct CompletedRhythmMatchingTrial: Sendable {
    let tempo: TempoBPM
    let expectedOffset: RhythmOffset  // always .zero (on the beat)
    let userOffset: RhythmOffset      // actual timing error
    let timestamp: Date
}
```

Set `expectedOffset` to `RhythmOffset(duration: .zero)` — the target is always exactly on the beat.

### Observer infrastructure — already wired

Both `PerceptualProfile` and `TrainingDataStore` already conform to `RhythmMatchingObserver`:

- `PerceptualProfile.rhythmMatchingCompleted(_:)` — updates statistics keyed by `TempoRange` and `RhythmDirection`
- `TrainingDataStore.rhythmMatchingCompleted(_:)` — persists `RhythmMatchingRecord(tempoBPM:userOffsetMs:timestamp:)`

Pass both as `observers` array in `PeachApp.swift`.

### Observable properties for the screen (Story 49.2)

Expose for the future screen:
- `state: RhythmMatchingSessionState` — screen reads this for button/dot state
- `showFeedback: Bool` — feedback visibility
- `litDotCount: Int` — 0-4, for dot visualization (3 during lead-in, 4 after tap)
- `lastUserOffsetPercentage: Double?` — signed percentage for feedback display

```swift
var lastUserOffsetPercentage: Double? {
    guard let trial = lastCompletedTrial else { return nil }
    let pct = trial.userOffset.percentageOfSixteenthNote(at: trial.tempo)
    return trial.userOffset.direction == .early ? -pct : pct
}
```

### `RhythmMatchingSettings` — minimal

```swift
struct RhythmMatchingSettings: Sendable {
    var tempo: TempoBPM
    var feedbackDuration: Duration

    init(tempo: TempoBPM = TempoBPM(80), feedbackDuration: Duration = .milliseconds(400)) {
        self.tempo = tempo
        self.feedbackDuration = feedbackDuration
    }
}
```

No adaptive difficulty range, no min/max offset. Tempo comes from user settings (default 80 BPM, configurable in Epic 50).

### `PeachApp.swift` wiring — mirror rhythm offset detection

Follow the exact pattern of `createRhythmOffsetDetectionSession()`:

```swift
private func createRhythmMatchingSession() -> RhythmMatchingSession {
    RhythmMatchingSession(
        rhythmPlayer: soundFontPlayer,
        observers: [trainingDataStore, perceptualProfile, progressTimeline],
        sampleRate: SampleRate(soundFontPlayer.sampleRate),
        notificationCenter: .default
    )
}
```

Note: No `strategy` or `profile` parameter — rhythm matching has neither.

Check whether `progressTimeline` is passed as an observer for rhythm offset detection — if so, mirror that. If `ProgressTimeline` conforms to `RhythmMatchingObserver`, include it.

### What NOT to do

- Do NOT create a `NextRhythmMatchingStrategy` protocol — no strategy needed (AC #7)
- Do NOT add UI screens — that's Story 49.2
- Do NOT add Start Screen buttons — that's Epic 50
- Do NOT add tempo stepper to Settings — that's Epic 50
- Do NOT create a `from(userSettings:)` factory on settings — tempo stepper doesn't exist yet
- Do NOT use `ObservableObject` / `@Published` — use `@Observable`
- Do NOT add explicit `@MainActor` — redundant with default isolation
- Do NOT use Combine
- Do NOT add haptic feedback on tap — rhythm matching has no binary correct/incorrect (UX spec)
- Do NOT re-create existing mocks (`MockRhythmPlayer`, `MockRhythmMatchingObserver`)

### Project Structure Notes

New files:
```
Peach/
├── Core/Training/
│   └── RhythmMatchingSettings.swift              # NEW
├── RhythmMatching/
│   └── RhythmMatchingSession.swift               # NEW
├── App/
│   ├── PeachApp.swift                            # MODIFIED — wire session
│   └── EnvironmentKeys.swift                     # MODIFIED — add @Entry

PeachTests/
├── Core/Training/
│   └── RhythmMatchingSettingsTests.swift          # NEW
├── RhythmMatching/
│   └── RhythmMatchingSessionTests.swift           # NEW
```

### References

- [Source: Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift — primary pattern to mirror]
- [Source: Peach/Core/Training/RhythmOffsetDetectionSettings.swift — settings pattern]
- [Source: Peach/Core/Training/RhythmMatchingObserver.swift — observer protocol, already exists]
- [Source: Peach/Core/Training/CompletedRhythmMatchingTrial.swift — result type, already exists]
- [Source: Peach/Core/Data/RhythmMatchingRecord.swift — SwiftData model, already exists]
- [Source: Peach/Core/Audio/RhythmPlayer.swift — player protocol + RhythmPattern + RhythmPlaybackHandle]
- [Source: Peach/Core/Music/RhythmOffset.swift — percentageOfSixteenthNote(at:), direction]
- [Source: Peach/Core/Music/TempoBPM.swift — sixteenthNoteDuration]
- [Source: Peach/Core/Music/SampleRate.swift — rawValue for sample offset calculation]
- [Source: Peach/Core/TrainingSession.swift — protocol conformance: stop(), isIdle]
- [Source: Peach/Core/Profile/PerceptualProfile.swift:124-131 — already conforms to RhythmMatchingObserver]
- [Source: Peach/Core/Data/TrainingDataStore.swift — already conforms to RhythmMatchingObserver]
- [Source: Peach/Core/Profile/TrainingDisciplineConfig.swift — .rhythmMatching already configured]
- [Source: Peach/App/PeachApp.swift — composition root, wire new session here]
- [Source: Peach/App/EnvironmentKeys.swift — add @Entry for rhythmMatchingSession]
- [Source: PeachTests/Mocks/MockRhythmPlayer.swift — reuse existing mock]
- [Source: docs/planning-artifacts/epics.md#Epic 49 Story 49.1 — acceptance criteria]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
