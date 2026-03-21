# Story 48.1: NextRhythmOffsetDetectionStrategy Protocol and Initial Implementation

Status: done

## Story

As a **developer**,
I want a `NextRhythmOffsetDetectionStrategy` that decides rhythm offset detection trial parameters based on asymmetric early/late profile data,
So that rhythm offset detection difficulty adapts independently per direction (FR83).

## Acceptance Criteria

1. **Given** the `NextRhythmOffsetDetectionStrategy` protocol, **when** inspected, **then** it declares `nextRhythmOffsetDetectionTrial(profile:settings:lastResult:) -> RhythmOffsetDetectionTrial`.

2. **Given** the `RhythmOffsetDetectionTrial` value type, **when** inspected, **then** it contains `tempo: TempoBPM` and `offset: RhythmOffset` (signed — encodes direction + magnitude).

3. **Given** the initial implementation (`AdaptiveRhythmOffsetDetectionStrategy`), **when** it selects the next trial, **then** it considers the profile's asymmetric early/late tracking and the last completed result to decide both direction and magnitude.

4. **Given** the strategy receives a profile with no data, **when** selecting the first trial, **then** it provides a reasonable starting difficulty (analogous to 100 cents cold start for pitch).

5. **Given** unit tests with a `MockTrainingProfile`, **when** various profile states are tested, **then** the strategy adapts difficulty appropriately — narrower on correct, wider on wrong, per direction.

6. **Given** file locations, **when** created, **then** protocol at `Core/Algorithm/NextRhythmOffsetDetectionStrategy.swift`, implementation at `Core/Algorithm/AdaptiveRhythmOffsetDetectionStrategy.swift`, trial at `RhythmOffsetDetection/RhythmOffsetDetectionTrial.swift`.

## Tasks / Subtasks

- [x] Task 1: Create `RhythmOffsetDetectionTrial` value type (AC: #2)
  - [x] Create `Peach/RhythmOffsetDetection/RhythmOffsetDetectionTrial.swift`
  - [x] `struct RhythmOffsetDetectionTrial: Sendable` with `tempo: TempoBPM` and `offset: RhythmOffset`
  - [x] Write tests in `PeachTests/RhythmOffsetDetection/RhythmOffsetDetectionTrialTests.swift`

- [x] Task 2: Define `RhythmOffsetDetectionSettings` (AC: #1, #3)
  - [x] Create `Peach/Core/Training/RhythmOffsetDetectionSettings.swift`
  - [x] Include `tempo: TempoBPM`, `feedbackDuration: Duration`, `maxOffsetPercentage: Double`, `minOffsetPercentage: Double`
  - [x] Follow `PitchDiscriminationSettings` pattern — value type snapshot with sensible defaults

- [x] Task 3: Define `NextRhythmOffsetDetectionStrategy` protocol (AC: #1)
  - [x] Create `Peach/Core/Algorithm/NextRhythmOffsetDetectionStrategy.swift`
  - [x] Single method: `func nextRhythmOffsetDetectionTrial(profile: TrainingProfile, settings: RhythmOffsetDetectionSettings, lastResult: CompletedRhythmOffsetDetectionTrial?) -> RhythmOffsetDetectionTrial`
  - [x] Use `TrainingProfile` (not `RhythmProfile` — that protocol was removed in 47.3/47.4; the profile is now queried via `StatisticsKey`)

- [x] Task 4: Implement `AdaptiveRhythmOffsetDetectionStrategy` (AC: #3, #4)
  - [x] Create `Peach/Core/Algorithm/AdaptiveRhythmOffsetDetectionStrategy.swift`
  - [x] `final class AdaptiveRhythmOffsetDetectionStrategy: NextRhythmOffsetDetectionStrategy`
  - [x] Kazez-style adjustment: narrower on correct, wider on wrong
  - [x] Asymmetric: query profile separately for early and late via `StatisticsKey.rhythm(.rhythmOffsetDetection, tempoRange, .early/.late)`
  - [x] Cold start: use `maxOffsetPercentage` from settings (analogous to `maxCentDifference` = 100 cents)
  - [x] Direction selection: random, or weighted toward weaker direction based on profile
  - [x] Magnitude in percentage of sixteenth note — convert to `RhythmOffset` using `TempoBPM.sixteenthNoteDuration`

- [x] Task 5: Create `MockNextRhythmOffsetDetectionStrategy` (AC: #5)
  - [x] Create `PeachTests/Mocks/MockNextRhythmOffsetDetectionStrategy.swift`
  - [x] Follow existing mock contract: call count, captured parameters, configurable return value

- [x] Task 6: Write `AdaptiveRhythmOffsetDetectionStrategy` tests (AC: #3, #4, #5)
  - [x] Create `PeachTests/Core/Algorithm/AdaptiveRhythmOffsetDetectionStrategyTests.swift`
  - [x] Test cold start returns max difficulty offset
  - [x] Test narrowing after correct answer
  - [x] Test widening after incorrect answer
  - [x] Test asymmetric direction: early and late tracked independently
  - [x] Test offset stays within min/max bounds
  - [x] Test tempo from settings is passed through to trial

- [x] Task 7: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Pattern to follow: `NextPitchDiscriminationStrategy` and `KazezNoteStrategy`

The rhythm strategy mirrors the pitch strategy exactly:
- **Protocol** at `Core/Algorithm/NextPitchDiscriminationStrategy.swift` — stateless, all inputs via parameters, returns value type
- **Implementation** at `Core/Algorithm/KazezNoteStrategy.swift` — Kazez formula with `narrowingCoefficient = 0.05`, `wideningCoefficient = 0.09`

The rhythm equivalent uses the same Kazez adjustment formula but operates on **percentage of sixteenth note** instead of **cents**. The offset magnitude represents how far early or late the 4th note is displaced.

### Critical: `RhythmProfile` no longer exists as a protocol

Story 47.3/47.4 unified all profile access under `TrainingProfile` with `StatisticsKey`-based storage. The strategy must use:

```swift
profile.statistics(for: .rhythm(.rhythmOffsetDetection, tempoRange, direction))
```

This returns `StatisticalSummary?`. Pattern-match on `.continuous(let stats)` to access `stats.welford.mean` for the current mean offset magnitude at that tempo range and direction.

To find the correct `TempoRange` for the session's tempo:
```swift
guard let range = TempoRange.range(for: settings.tempo) else { /* fallback */ }
```

### Asymmetric early/late tracking (FR83)

The strategy decides **both** direction and magnitude:
1. Query profile for early stats: `.rhythm(.rhythmOffsetDetection, tempoRange, .early)`
2. Query profile for late stats: `.rhythm(.rhythmOffsetDetection, tempoRange, .late)`
3. Choose direction (random, or bias toward weaker side)
4. Use the chosen direction's stats to compute magnitude via Kazez formula
5. If `lastResult` exists, adjust from last magnitude; otherwise use profile mean or cold-start default

### Magnitude units: percentage of sixteenth note

The offset is expressed as a percentage of one sixteenth note at the session's tempo. Convert to `RhythmOffset` (a `Duration`):

```swift
let sixteenthDuration = settings.tempo.sixteenthNoteDuration
let offsetDuration = sixteenthDuration * (percentage / 100.0)
let rhythmOffset = RhythmOffset(direction == .early ? .zero - offsetDuration : offsetDuration)
```

### Cold start behavior

When the profile has no data for the current tempo range and direction:
- Use `maxOffsetPercentage` from settings (e.g., 20% — large enough to be obvious)
- This mirrors pitch's `maxCentDifference = 100` cold start

### Settings type: `RhythmOffsetDetectionSettings`

Follow the session-specific settings pattern established in the project (see `PitchDiscriminationSettings`). The architecture doc references a generic `TrainingSettings` but this was refactored into session-specific types. Create:

```swift
struct RhythmOffsetDetectionSettings {
    var tempo: TempoBPM
    var feedbackDuration: Duration
    var maxOffsetPercentage: Double  // e.g., 20.0 — cold start / upper bound
    var minOffsetPercentage: Double  // e.g., 1.0 — floor

    init(
        tempo: TempoBPM = TempoBPM(80),
        feedbackDuration: Duration = .milliseconds(400),
        maxOffsetPercentage: Double = 20.0,
        minOffsetPercentage: Double = 1.0
    ) { ... }
}
```

### `RhythmOffsetDetectionTrial` lives in `RhythmOffsetDetection/`

Per architecture, `RhythmOffsetDetectionTrial.swift` goes in the feature directory `RhythmOffsetDetection/`, not in `Core/`. It's a feature-specific value type consumed by `RhythmOffsetDetectionSession`.

### MockNextRhythmOffsetDetectionStrategy

Follow mock contract from `project-context.md`:
- Conform to `NextRhythmOffsetDetectionStrategy`
- Track call count: `nextRhythmOffsetDetectionTrialCallCount`
- Capture parameters: `lastProfile`, `lastSettings`, `lastResult`
- Configurable return: `trialToReturn: RhythmOffsetDetectionTrial`
- `reset()` method

### What NOT to do

- Do NOT use `RhythmProfile` protocol — it was removed; use `TrainingProfile` with `StatisticsKey`
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT add `@MainActor` annotations (redundant with default isolation)
- Do NOT use `ObservableObject`, `@Published`, or Combine
- Do NOT import SwiftUI in algorithm files
- Do NOT register anything in `PeachApp.swift` — session wiring happens in story 48.2
- Do NOT create the `RhythmOffsetDetection/` directory structure beyond `RhythmOffsetDetectionTrial.swift` — other files come in 48.2/48.3

### Project Structure Notes

New files:
```
Peach/
├── Core/
│   ├── Algorithm/
│   │   ├── NextRhythmOffsetDetectionStrategy.swift    # NEW protocol
│   │   └── AdaptiveRhythmOffsetDetectionStrategy.swift # NEW implementation
│   └── Training/
│       └── RhythmOffsetDetectionSettings.swift # NEW settings type
├── RhythmOffsetDetection/
│   └── RhythmOffsetDetectionTrial.swift                 # NEW value type

PeachTests/
├── Core/
│   └── Algorithm/
│       └── AdaptiveRhythmOffsetDetectionStrategyTests.swift # NEW
├── RhythmOffsetDetection/
│   └── RhythmOffsetDetectionTrialTests.swift            # NEW
└── Mocks/
    └── MockNextRhythmOffsetDetectionStrategy.swift    # NEW
```

All paths align with existing conventions: algorithms in `Core/Algorithm/`, training settings in `Core/Training/`, feature types in feature directories.

### References

- [Source: Peach/Core/Algorithm/NextPitchDiscriminationStrategy.swift — protocol pattern to mirror]
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift — Kazez formula, narrowing/widening coefficients]
- [Source: Peach/Core/Training/PitchDiscriminationSettings.swift — session-specific settings pattern]
- [Source: Peach/Core/Profile/TrainingProfile.swift — `statistics(for:)` returns `StatisticalSummary?`, `mergedStatistics(for:)` default extension]
- [Source: Peach/Core/Profile/StatisticsKey.swift — `.rhythm(TrainingDiscipline, TempoRange, RhythmDirection)` key structure]
- [Source: Peach/Core/Music/RhythmOffset.swift — signed Duration, `percentageOfSixteenthNote(at:)`]
- [Source: Peach/Core/Music/TempoBPM.swift — `sixteenthNoteDuration` computed property]
- [Source: Peach/Core/Music/TempoRange.swift — `range(for:)` lookup, `defaultRanges`]
- [Source: Peach/Core/Music/RhythmDirection.swift — `.early`/`.late`, `CaseIterable`]
- [Source: Peach/Core/Training/CompletedRhythmOffsetDetectionTrial.swift — result type with tempo, offset, isCorrect]
- [Source: Peach/Core/Profile/StatisticalSummary.swift — `.continuous(TrainingDisciplineStatistics)` sum type]
- [Source: docs/planning-artifacts/architecture.md#NextRhythmOffsetDetectionStrategy — protocol and RhythmOffsetDetectionTrial definition]
- [Source: docs/planning-artifacts/epics.md#Story 48.1 — acceptance criteria]
- [Source: docs/implementation-artifacts/47-4-progresstimeline-extension-to-six-training-modes.md — previous story, StatisticsKey-based API]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Created `RhythmOffsetDetectionTrial` as a minimal `Sendable` value type with `tempo: TempoBPM` and `offset: RhythmOffset`
- Created `RhythmOffsetDetectionSettings` following `PitchDiscriminationSettings` pattern with tempo, feedbackDuration, maxOffsetPercentage (20.0), minOffsetPercentage (1.0)
- Defined `NextRhythmOffsetDetectionStrategy` protocol with single method accepting `TrainingProfile`, settings, and optional last result
- Implemented `AdaptiveRhythmOffsetDetectionStrategy` with Kazez formula (narrowing=0.05, widening=0.09) operating on percentage of sixteenth note
- Direction selection biases toward weaker direction (less data in profile); random when equal or no data
- Cold start from profile converts welford mean (ms) to percentage of sixteenth note at current tempo
- Created mock with call count, captured parameters, configurable return, and reset()
- 12 new tests covering cold start, narrowing, widening, clamping, asymmetric direction tracking, profile mean cold start, and convergence
- All 1245 tests pass with no regressions

### Change Log

- 2026-03-21: Implemented story 48.1 — protocol, strategy, settings, trial, mock, and tests

### File List

- Peach/RhythmOffsetDetection/RhythmOffsetDetectionTrial.swift (NEW)
- Peach/Core/Training/RhythmOffsetDetectionSettings.swift (NEW)
- Peach/Core/Algorithm/NextRhythmOffsetDetectionStrategy.swift (NEW)
- Peach/Core/Algorithm/AdaptiveRhythmOffsetDetectionStrategy.swift (NEW)
- PeachTests/RhythmOffsetDetection/RhythmOffsetDetectionTrialTests.swift (NEW)
- PeachTests/Mocks/MockNextRhythmOffsetDetectionStrategy.swift (NEW)
- PeachTests/Core/Algorithm/AdaptiveRhythmOffsetDetectionStrategyTests.swift (NEW)
- docs/implementation-artifacts/sprint-status.yaml (MODIFIED)
