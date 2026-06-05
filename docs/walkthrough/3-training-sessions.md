# Layer 3: Training Sessions

**Status:** in progress
**Session date:** 2026-04-06

## Architecture Overview

The training layer is built on a **discipline registry** pattern with a strict separation of concerns:

```
TrainingDisciplineRegistry          ← knows which disciplines exist
    │
    ├── TrainingDiscipline          ← protocol: metadata, statistics keys, CSV, data feeding
    │       ↓ implemented by
    │   UnisonPitchDiscrimination, IntervalPitchDiscrimination,
    │   UnisonPitchMatching, IntervalPitchMatching,
    │   TimingOffsetDetection, ContinuousRhythmMatching
    │
TrainingSession                     ← protocol: stop(), isIdle (shared lifecycle contract)
    │       ↓ implemented by
    │   PitchDiscriminationSession, PitchMatchingSession,
    │   TimingOffsetDetectionSession, ContinuousRhythmMatchingSession
    │
SessionLifecycle                    ← manages Task lifetimes + audio interruption monitoring
```

**Key insight:** `TrainingDiscipline` and `TrainingSession` are *separate* types. A discipline is a static descriptor (metadata, config, CSV columns, data feeding). A session is a live state machine. This means unison and interval pitch discrimination share one session class (`PitchDiscriminationSession`) but have two separate discipline descriptors.

## The Six Disciplines

| ID | Display Name | Session Class | Metric | Optimal Baseline |
|----|-------------|---------------|--------|-----------------|
| `unisonPitchDiscrimination` | Compare Pitch | `PitchDiscriminationSession` | cents | 8 |
| `intervalPitchDiscrimination` | Compare Intervals | `PitchDiscriminationSession` | cents | 12 |
| `unisonPitchMatching` | Match Pitch | `PitchMatchingSession` | cents | 5 |
| `intervalPitchMatching` | Match Pitch (intervals) | `PitchMatchingSession` | cents | 5 |
| `timingOffsetDetection` | Compare Timing | `TimingOffsetDetectionSession` | ms | 15 |
| `continuousRhythmMatching` | Fill the Gap | `ContinuousRhythmMatchingSession` | ms | 20 |

Note: 6 disciplines but only 4 session classes. Unison/interval variants share session logic and are distinguished at the discipline level by filtering on `record.interval == 0` vs `!= 0`.

## Core Infrastructure (`Core/Training/`)

### `TrainingDiscipline` protocol
The big protocol. Each discipline provides:
- **Identity & config:** `id`, `config` (display name, unit label, baseline, EWMA parameters)
- **Statistics keys:** pitch disciplines return one key; rhythm disciplines return `tempoRange × direction` permutations
- **Record type:** the `PersistentModel` type this discipline persists
- **Profile feeding:** `feedRecords(from:into:)` — replay stored records into a profile builder
- **CSV round-trip:** export columns, key-value pairs, row parsing, duplicate detection, merge

### `TrainingDisciplineRegistry`
Singleton. The *only* place that knows which disciplines are active. All 6 registered in display order. Also pre-computes CSV parser lookup and column union for the export/import system.

### `TrainingDisciplineConfig`
Display name, unit label, optimal baseline, and `StatisticsConfig` (EWMA halflife: 7 days, session gap: 30 min).

### `TrainingDisciplineStatistics`
Per-mode statistical state: Welford accumulator (running mean/stddev), EWMA over session-bucketed means, and trend detection (improving/stable/declining). Fully recomputable from metric points via `rebuild(from:config:)`.

### `SessionLifecycle`
Manages the `Task` handles for the training loop and feedback timer, plus the `AudioSessionInterruptionMonitor`. Shared by all 4 session classes — no duplicated task management code.

### `TrainingSession` protocol
Minimal: `stop()` and `isIdle`. Used by the composition root to stop any active session regardless of type.

### `Resettable` protocol
Single method: `reset()`. Applied to types whose accumulated state can be cleared (e.g., data store).

## The Four Session State Machines

### 1. PitchDiscriminationSession

**States:** `idle → playingReferenceNote → playingTargetNote → awaitingAnswer → showingFeedback → (loop)`

**Flow:**
1. `start(settings:)` — stores settings, launches training Task via `SessionLifecycle`
2. `playNextTrial()` — asks the strategy for a trial, computes loudness variation, plays reference note (timed), optional gap, plays target note (timed)
3. User can answer during `playingTargetNote` or `awaitingAnswer`
4. `handleAnswer(isHigher:)` — stops target note if still playing, creates `CompletedPitchDiscriminationTrial`, tracks session best, notifies observers, transitions to feedback
5. After `feedbackDuration` (400ms), loops to step 2

**Dependencies:**
- `NotePlayer` — plays timed notes
- `NextPitchDiscriminationStrategy` — selects next trial (adaptive, reads profile)
- `TrainingProfile` — read-only query for current statistics
- `[PitchDiscriminationObserver]` — notified on completion (store adapter, profile, haptics)
- `[Resettable]` — for data reset

**Trial type:** `PitchDiscriminationTrial` — `referenceNote: MIDINote`, `targetNote: DetunedMIDINote` (note + cent offset). The `isTargetHigher` is derived from the offset sign.

**Keyboard shortcuts:** Localized letter keys for Higher/Lower.

### 2. PitchMatchingSession

**States:** `idle → playingReference → awaitingSliderTouch → playingTunable → showingFeedback → (loop)`

**Flow:**
1. `start(settings:)` — stores settings, starts MIDI listening, launches training Task
2. `playNextTrial()` — generates trial (reference note + target note + initial cent offset), plays reference note (timed), computes detuned frequency, enters `awaitingSliderTouch`
3. **Suspends** via `withCheckedContinuation` until the user touches the slider or adjusts via keyboard/MIDI
4. On touch: resumes continuation, starts a *long-running* tunable note via `notePlayer.play(frequency:)` (no duration), returns `PlaybackHandle`
5. `adjustPitch(_:)` — converts slider value to frequency, calls `handle.adjustFrequency()` for real-time pitch bend
6. `commitPitch(_:)` — stops the tunable note, computes `userCentError` from final frequency, records result, transitions to feedback
7. After feedback, loops to step 2

**Key differences from PitchDiscrimination:**
- Uses `PlaybackHandle` for live pitch adjustment (not just timed play)
- The `awaitingSliderTouch` state uses a `CheckedContinuation` to suspend the async training loop until user interaction
- Three input sources: touch slider, keyboard arrows (fine pitch step ±0.05), MIDI pitch bend wheel
- MIDI commit is triggered when the pitch bend wheel returns to the neutral zone after being deflected

**Trial type:** `PitchMatchingTrial` — `referenceNote`, `targetNote` (both `MIDINote`), `initialCentOffset: Cents`. Simpler than PitchDiscrimination because the offset is a UI starting position, not a musical parameter.

### 3. TimingOffsetDetectionSession

A pure-reducer state machine on top of a looping `BeatSequencer`. The session conforms to both `TrainingSession` and `BeatProvider` — the sequencer pulls the pattern back from the session by asking for the next `Beat` whenever it refills its scheduling batch.

**States:** `idle → playingPatternLoop → awaitingAnswer → showingFeedback → waitingForGrid → (loop)`

```swift
enum TimingOffsetDetectionSessionState {
    case idle
    case playingPatternLoop  // sequencer running, 4-sixteenth pattern looping
    case awaitingAnswer      // cap reached, sequencer stopped, user must still answer
    case showingFeedback     // result recorded, feedback shown (~400 ms)
    case waitingForGrid      // sleeping until the next quarter-note boundary
}
```

**Events:** `.startRequested`, `.answerReceived(direction:)`, `.feedbackTimerFired`, `.gridAlignmentReached`, `.repetitionCapReached`. `.stopRequested` and `.audioError` are caught from any state and transition to `.idle` via the `.stopAll` effect.

**Effects:** `.beginNextTrial`, `.stopSequencer`, `.stopSequencerAtCap`, `.evaluateAnswer(direction:)`, `.scheduleFeedbackTimer`, `.stopAll`. The reducer (`static func reduce(state: inout, event:) -> [Effect]`) only mutates state and returns effects; `interpret(_:)` runs the side effects (sequencer, observers, feedback timer) separately. Reducer behavior is therefore table-testable without any audio or timer infrastructure.

**Flow:**
1. `start(settings:)` — stores settings and sends `.startRequested`. The reducer transitions `idle → playingPatternLoop` and emits `.beginNextTrial`.
2. `beginNextTrial()` — asks the strategy for a trial, establishes `gridOrigin` on the first call, then `await beatSequencer.start(tempo:beatProvider:)` with `self` as the `BeatProvider`. The sequencer drives a gapless metronome; the session's `nextBeat()` returns the 4-sixteenth pattern (accent on subdivision 0, signed offset on the tested third subdivision).
3. A ~125 Hz tracking poll (`evaluatePlaybackPosition()`) reads `beatSequencer.timing.samplePosition`, advances `litDotCount`, and watches the per-trial repetition counter. Once `completedCycles >= settings.maxRepetitions`, the poll sends `.repetitionCapReached`; the reducer transitions `playingPatternLoop → awaitingAnswer` and emits `.stopSequencerAtCap`. The user must still answer — audio is silenced but the trial is open.
4. `handleAnswer(direction:)` is accepted from both `.playingPatternLoop` and `.awaitingAnswer` (case-pattern union). The reducer transitions to `.showingFeedback` and emits `[.stopSequencer, .evaluateAnswer(direction:), .scheduleFeedbackTimer]` — mechanism (silence the audio) ordered ahead of policy (compute the result, notify observers). From `.awaitingAnswer` the sequencer is already stopped; the redundant `.stopSequencer` is harmless because `enqueueSequencerStop` serializes back-to-back stops.
5. After `feedbackDuration` (~400 ms) the feedback task sends `.feedbackTimerFired` (→ `.waitingForGrid`), then sleeps until the next quarter-note grid point relative to `gridOrigin` and sends `.gridAlignmentReached` (→ `.playingPatternLoop`, new trial).

**Load-bearing properties:**
- **Pure reducer.** `reduce(_:_:)` never touches audio, observers, or timers. Effects are an enum the interpreter consumes — adding a transition does not risk a hidden side effect.
- **Cap-reached is a first-class state, not a flag.** The transition out of `.playingPatternLoop` is itself the idempotence latch: the state guard at the top of `evaluatePlaybackPosition` short-circuits any further polls in the same trial.
- **Effect ordering matters.** `.stopSequencer` is emitted before `.evaluateAnswer`/`.scheduleFeedbackTimer` so the audio is silenced before the result computation, never the other way around.
- **`enqueueSequencerStop` chains stops.** Each enqueued stop awaits the previous one and cancels any in-flight `startTask` before calling `beatSequencer.stop()`. Concurrent answer-driven stops and teardown stops cannot race on the sequencer's runloop task.
- **Grid-aligned phrasing.** `gridOrigin` is captured on the first trial; subsequent trials always resume on the next quarter-note boundary, so the pulse stays in phase across feedback gaps.
- **`BeatProvider` safety after teardown.** A sequencer refill scheduled before `stop()` may still call `nextBeat()` after `currentTrial` clears. `nextBeat()` returns an all-rest `silentBeat` in that case, so no audible click leaks past the session's lifetime.

**Dependencies:**

```swift
init(
    beatSequencer: any BeatSequencer,
    strategy: NextTimingOffsetDetectionStrategy,
    profile: TrainingProfile,
    observers: [TimingOffsetDetectionObserver] = [],
    notificationCenter: NotificationCenter = .default,
    audioInterruptionObserver: AudioInterruptionObserving,
    currentTime: @escaping () -> Double = { CACurrentMediaTime() }
)
```

No `RhythmPlayer` — TOD is built on `BeatSequencer` + `BeatProvider`, the same metronome primitive that drives `ContinuousRhythmMatchingSession`. `currentTime` is injected for deterministic grid-alignment tests.

**Trial type:** `TimingOffsetDetectionTrial { tempo: TempoBPM, offset: TimingOffset }`. The `offset` carries both direction (early/late) and magnitude. Completed trials are `CompletedTimingOffsetDetectionTrial`, adding `isCorrect` and `timestamp`.

**File location:** `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift`

### 4. ContinuousRhythmMatchingSession

**States:** `isRunning` boolean (no enum — continuous, not discrete trials)

**Flow:**
1. `start(settings:)` — starts the `BeatSequencer` with `self` as `BeatProvider`, starts MIDI listening, starts tracking loop
2. `BeatSequencer` calls `nextBeat()` repeatedly — session picks a random gap position from enabled positions, appends to `gapPositions` array, and returns a 4-subdivision `Beat` with `.rest` at the gap
3. Tracking loop polls at ~120Hz, reads sample position from sequencer, derives `currentStep` and `currentGapPosition` for UI
4. `handleTap()` — user taps (touch or MIDI note-on). Computes sample position, checks if within ±half-step of the gap. If hit: plays immediate click, records `GapResult`, shows feedback
5. After `cyclesPerTrial` (16) cycles (hit or missed), completes a trial, notifies observers, resets counters — continues seamlessly

**Unique features:**
- Implements `BeatProvider` protocol — the session itself feeds beats to the sequencer
- No discrete "playing pattern / awaiting answer" — it's a continuous real-time loop
- MIDI note-on events are converted to sample positions via `samplePosition(forHostTime:)` for accurate timing
- Trials are batched: every 16 cycles forms one trial, but the metronome never stops

## The Observer Pattern

Each session type has its own observer protocol:

| Protocol | Method |
|----------|--------|
| `PitchDiscriminationObserver` | `pitchDiscriminationCompleted(_:)` |
| `PitchMatchingObserver` | `pitchMatchingCompleted(_:)` |
| `TimingOffsetDetectionObserver` | `timingOffsetDetectionCompleted(_:)` |
| `ContinuousRhythmMatchingObserver` | `continuousRhythmMatchingCompleted(_:)` |

Each has a **StoreAdapter** that implements the observer, converts the completed trial into a `PersistentModel` record, and saves it. This cleanly decouples the session from persistence.

Other observer conformers (from docs): `PerceptualProfile`, `ProgressTimeline`, `HapticFeedbackManager`.

## Adaptive Strategies (`Core/Algorithm/`)

Two strategy protocols, two implementations:

| Protocol | Implementation | Purpose |
|----------|---------------|---------|
| `NextPitchDiscriminationStrategy` | `KazezNoteStrategy` | Adapts cent difficulty based on profile (staircase-like) |
| `NextTimingOffsetDetectionStrategy` | `AdaptiveTimingOffsetDetectionStrategy` | Adapts timing offset based on profile |

Both are **stateless** — all inputs come via parameters, making them easy to test. No `PitchMatchingStrategy` or `ContinuousRhythmMatchingStrategy` exist — those generate trials inline in the session.

## Settings Types

Each session has its own settings struct, constructed from `UserSettings` via a static `from(_:)` factory:

- `PitchDiscriminationSettings` — noteRange, referencePitch, intervals, tuningSystem, noteDuration, varyLoudness, etc.
- `PitchMatchingSettings` — similar + initialCentOffsetRange
- `TimingOffsetDetectionSettings` — tempo, offset ranges, feedbackDuration, maxRepetitions (per-trial cap, sourced from `TimingOffsetDetectionUserSettings`)
- `ContinuousRhythmMatchingSettings` — tempo, enabledGapPositions

## Files to read (suggested order)

1. `Core/TrainingSession.swift` — tiny protocol, sets the contract
2. `Core/Training/TrainingDiscipline.swift` — the big descriptor protocol
3. `Core/Training/TrainingDisciplineRegistry.swift` — singleton registry
4. `Core/Training/SessionLifecycle.swift` — shared task management
5. `PitchDiscrimination/PitchDiscriminationSession.swift` — the reference session implementation
6. `PitchDiscrimination/PitchDiscriminationTrial.swift` — trial + completed trial types
7. `PitchDiscrimination/PitchDiscriminationObserver.swift` — observer protocol
8. `PitchDiscrimination/PitchDiscriminationStoreAdapter.swift` — observer → persistence bridge
9. `PitchDiscrimination/UnisonPitchDiscriminationDiscipline.swift` — discipline descriptor
10. `PitchMatching/PitchMatchingSession.swift` — slider/MIDI interaction complexity
11. `Training/TimingOffsetDetection/TimingOffsetDetectionSession.swift` — pure-reducer state machine, gapless loop, grid alignment
12. `ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — continuous mode, BeatProvider
13. `Core/Algorithm/KazezNoteStrategy.swift` — adaptive pitch selection
14. `Core/Algorithm/AdaptiveTimingOffsetDetectionStrategy.swift` — adaptive timing-offset selection

## Observations and questions

1. **`Core/Data/DuplicateKey.swift` belongs in the feature layer, not Core.** `PitchDuplicateKey` has convenience inits referencing concrete `PitchDiscriminationRecord`/`PitchMatchingRecord`, and the free `build*DuplicateKeys` functions call discipline-specific fetch methods. Core shouldn't know about concrete training disciplines. Move the entire file to a shared import/export area near the discipline types.
2. **`AudioSessionInterruptionMonitor` background/foreground observers are identical.** Both register the same `onStopRequired()` handler — only the notification name differs. Replace with a single `[Notification.Name]` parameter and loop. The foreground stop may be entirely redundant.
3. **Training feature directories should be grouped under a `Training/` parent.** *Resolved:* `PitchDiscrimination/`, `PitchMatching/`, `TimingOffsetDetection/`, and `ContinuousRhythmMatching/` now live under `Peach/Training/`, separated from unrelated screens (`Info/`, `Profile/`, `Settings/`).
4. **Session state machines interweave transitions with side effects.** The pitch sessions still mix state transitions, audio control, result recording, feedback display, and next-trial scheduling in the same methods. `PitchDiscriminationSession.transitionToFeedback` is named as a feedback concern but also plays the next trial. `PitchMatchingSession.commitResult` stops audio, computes error, records, shows feedback, and schedules the next trial — five responsibilities in one method. **Partial resolution:** `TimingOffsetDetectionSession` adopted the explicit state-machine pattern (pure `reduce(state:event:) -> [Effect]` + separate `interpret(_:)`) in Epic 80. The same refactoring is still open for the pitch sessions and `ContinuousRhythmMatchingSession`.
