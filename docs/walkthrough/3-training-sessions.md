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
    │   RhythmOffsetDetection, ContinuousRhythmMatching
    │
TrainingSession                     ← protocol: stop(), isIdle (shared lifecycle contract)
    │       ↓ implemented by
    │   PitchDiscriminationSession, PitchMatchingSession,
    │   RhythmOffsetDetectionSession, ContinuousRhythmMatchingSession
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
| `rhythmOffsetDetection` | Compare Timing | `RhythmOffsetDetectionSession` | ms | 15 |
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

### 3. RhythmOffsetDetectionSession

**States:** `idle → playingPattern → awaitingAnswer → showingFeedback → waitingForGrid → (loop)`

**Flow:**
1. `start(settings:)` — stores settings, launches training Task
2. `playNextTrial()` — strategy generates trial (tempo + offset), builds a 4-note `RhythmPattern` with one offset note (3rd note by default), plays via `RhythmPlayer`, animates dot lights
3. After pattern finishes, enters `awaitingAnswer`
4. `handleAnswer(direction: .early/.late)` — checks against trial offset direction, records result
5. Feedback, then **waits for grid alignment** — snaps to the next quarter-note boundary before starting the next trial (musically correct phrasing)

**Unique features:**
- Grid tracking: `gridOrigin` established on first play, all subsequent trials align to quarter-note boundaries
- `CACurrentMediaTime()` injected for testability
- 4-dot UI animation: `litDotCount` incremented on each sixteenth-note onset
- `waitingForGrid` state: sits silently between feedback and next trial to maintain musical timing

**Trial type:** `RhythmOffsetDetectionTrial` — just `tempo: TempoBPM` + `offset: RhythmOffset`.

### 4. ContinuousRhythmMatchingSession

**States:** `isRunning` boolean (no enum — continuous, not discrete trials)

**Flow:**
1. `start(settings:)` — starts the `StepSequencer` with `self` as `StepProvider`, starts MIDI listening, starts tracking loop
2. `StepSequencer` calls `nextCycle()` repeatedly — session picks a random gap position from enabled positions, appends to `gapPositions` array
3. Tracking loop polls at ~120Hz, reads sample position from sequencer, derives `currentStep` and `currentGapPosition` for UI
4. `handleTap()` — user taps (touch or MIDI note-on). Computes sample position, checks if within ±half-step of the gap. If hit: plays immediate click, records `GapResult`, shows feedback
5. After `cyclesPerTrial` (16) cycles (hit or missed), completes a trial, notifies observers, resets counters — continues seamlessly

**Unique features:**
- Implements `StepProvider` protocol — the session itself feeds cycle definitions to the sequencer
- No discrete "playing pattern / awaiting answer" — it's a continuous real-time loop
- MIDI note-on events are converted to sample positions via `samplePosition(forHostTime:)` for accurate timing
- Trials are batched: every 16 cycles forms one trial, but the metronome never stops

## The Observer Pattern

Each session type has its own observer protocol:

| Protocol | Method |
|----------|--------|
| `PitchDiscriminationObserver` | `pitchDiscriminationCompleted(_:)` |
| `PitchMatchingObserver` | `pitchMatchingCompleted(_:)` |
| `RhythmOffsetDetectionObserver` | `rhythmOffsetDetectionCompleted(_:)` |
| `ContinuousRhythmMatchingObserver` | `continuousRhythmMatchingCompleted(_:)` |

Each has a **StoreAdapter** that implements the observer, converts the completed trial into a `PersistentModel` record, and saves it. This cleanly decouples the session from persistence.

Other observer conformers (from docs): `PerceptualProfile`, `ProgressTimeline`, `HapticFeedbackManager`.

## Adaptive Strategies (`Core/Algorithm/`)

Two strategy protocols, two implementations:

| Protocol | Implementation | Purpose |
|----------|---------------|---------|
| `NextPitchDiscriminationStrategy` | `KazezNoteStrategy` | Adapts cent difficulty based on profile (staircase-like) |
| `NextRhythmOffsetDetectionStrategy` | `AdaptiveRhythmOffsetDetectionStrategy` | Adapts timing offset based on profile |

Both are **stateless** — all inputs come via parameters, making them easy to test. No `PitchMatchingStrategy` or `ContinuousRhythmMatchingStrategy` exist — those generate trials inline in the session.

## Settings Types

Each session has its own settings struct, constructed from `UserSettings` via a static `from(_:)` factory:

- `PitchDiscriminationSettings` — noteRange, referencePitch, intervals, tuningSystem, noteDuration, varyLoudness, etc.
- `PitchMatchingSettings` — similar + initialCentOffsetRange
- `RhythmOffsetDetectionSettings` — tempo, offset ranges, feedbackDuration
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
11. `RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` — grid alignment
12. `ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — continuous mode, StepProvider
13. `Core/Algorithm/KazezNoteStrategy.swift` — adaptive pitch selection
14. `Core/Algorithm/AdaptiveRhythmOffsetDetectionStrategy.swift` — adaptive rhythm selection

## Observations and questions

1. **`Core/Data/DuplicateKey.swift` belongs in the feature layer, not Core.** `PitchDuplicateKey` has convenience inits referencing concrete `PitchDiscriminationRecord`/`PitchMatchingRecord`, and the free `build*DuplicateKeys` functions call discipline-specific fetch methods. Core shouldn't know about concrete training disciplines. Move the entire file to a shared import/export area near the discipline types.
2. **`AudioSessionInterruptionMonitor` background/foreground observers are identical.** Both register the same `onStopRequired()` handler — only the notification name differs. Replace with a single `[Notification.Name]` parameter and loop. The foreground stop may be entirely redundant.
3. **Training feature directories should be grouped under a `Training/` parent.** Currently `PitchDiscrimination/`, `PitchMatching/`, `RhythmOffsetDetection/`, and `ContinuousRhythmMatching/` are top-level siblings of unrelated screens (`Info/`, `Profile/`, `Settings/`). Move all four under `Training/` to reflect the shared infrastructure and architectural grouping.
4. **Session state machines interweave transitions with side effects.** All four sessions mix state transitions, audio control, result recording, feedback display, and next-trial scheduling in the same methods. `PitchDiscriminationSession.transitionToFeedback` is named as a feedback concern but also plays the next trial. `PitchMatchingSession.commitResult` stops audio, computes error, records, shows feedback, and schedules the next trial — five responsibilities in one method. **Action:** research explicit/idiomatic state machine patterns in Swift (e.g. state + event → (newState, [Effect]) separation) and evaluate whether refactoring to that pattern would clarify the session code.
