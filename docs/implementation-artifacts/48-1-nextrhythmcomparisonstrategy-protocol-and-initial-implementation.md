# Story 48.1: NextRhythmComparisonStrategy Protocol and Initial Implementation

Status: ready-for-dev

## Story

As a **developer**,
I want a `NextRhythmComparisonStrategy` that decides rhythm comparison challenge parameters based on asymmetric early/late profile data,
So that rhythm comparison difficulty adapts independently per direction (FR83).

## Acceptance Criteria

1. **Given** the `NextRhythmComparisonStrategy` protocol, **when** inspected, **then** it declares `nextRhythmComparison(profile:settings:lastResult:) -> RhythmComparison`.

2. **Given** the `RhythmComparison` value type, **when** inspected, **then** it contains `tempo: TempoBPM` and `offset: RhythmOffset` (signed — encodes direction + magnitude).

3. **Given** the initial implementation (`AdaptiveRhythmComparisonStrategy`), **when** it selects the next challenge, **then** it considers the profile's asymmetric early/late tracking and the last completed result to decide both direction and magnitude.

4. **Given** the strategy receives a profile with no data, **when** selecting the first challenge, **then** it provides a reasonable starting difficulty (analogous to 100 cents cold start for pitch).

5. **Given** unit tests with a `MockTrainingProfile`, **when** various profile states are tested, **then** the strategy adapts difficulty appropriately — narrower on correct, wider on wrong, per direction.

6. **Given** file locations, **when** created, **then** protocol at `Core/Algorithm/NextRhythmComparisonStrategy.swift`, implementation at `Core/Algorithm/AdaptiveRhythmComparisonStrategy.swift`, challenge at `RhythmComparison/RhythmComparison.swift`.

## Tasks / Subtasks

- [ ] Task 1: Create `RhythmComparison` value type (AC: #2)
  - [ ] Create `Peach/RhythmComparison/RhythmComparison.swift`
  - [ ] `struct RhythmComparison: Sendable` with `tempo: TempoBPM` and `offset: RhythmOffset`
  - [ ] Write tests in `PeachTests/RhythmComparison/RhythmComparisonTests.swift`

- [ ] Task 2: Define `RhythmComparisonTrainingSettings` (AC: #1, #3)
  - [ ] Create `Peach/Core/Training/RhythmComparisonTrainingSettings.swift`
  - [ ] Include `tempo: TempoBPM`, `feedbackDuration: Duration`, `maxOffsetPercentage: Double`, `minOffsetPercentage: Double`
  - [ ] Follow `PitchComparisonTrainingSettings` pattern — value type snapshot with sensible defaults

- [ ] Task 3: Define `NextRhythmComparisonStrategy` protocol (AC: #1)
  - [ ] Create `Peach/Core/Algorithm/NextRhythmComparisonStrategy.swift`
  - [ ] Single method: `func nextRhythmComparison(profile: TrainingProfile, settings: RhythmComparisonTrainingSettings, lastResult: CompletedRhythmComparison?) -> RhythmComparison`
  - [ ] Use `TrainingProfile` (not `RhythmProfile` — that protocol was removed in 47.3/47.4; the profile is now queried via `StatisticsKey`)

- [ ] Task 4: Implement `AdaptiveRhythmComparisonStrategy` (AC: #3, #4)
  - [ ] Create `Peach/Core/Algorithm/AdaptiveRhythmComparisonStrategy.swift`
  - [ ] `final class AdaptiveRhythmComparisonStrategy: NextRhythmComparisonStrategy`
  - [ ] Kazez-style adjustment: narrower on correct, wider on wrong
  - [ ] Asymmetric: query profile separately for early and late via `StatisticsKey.rhythm(.rhythmComparison, tempoRange, .early/.late)`
  - [ ] Cold start: use `maxOffsetPercentage` from settings (analogous to `maxCentDifference` = 100 cents)
  - [ ] Direction selection: random, or weighted toward weaker direction based on profile
  - [ ] Magnitude in percentage of sixteenth note — convert to `RhythmOffset` using `TempoBPM.sixteenthNoteDuration`

- [ ] Task 5: Create `MockNextRhythmComparisonStrategy` (AC: #5)
  - [ ] Create `PeachTests/Mocks/MockNextRhythmComparisonStrategy.swift`
  - [ ] Follow existing mock contract: call count, captured parameters, configurable return value

- [ ] Task 6: Write `AdaptiveRhythmComparisonStrategy` tests (AC: #3, #4, #5)
  - [ ] Create `PeachTests/Core/Algorithm/AdaptiveRhythmComparisonStrategyTests.swift`
  - [ ] Test cold start returns max difficulty offset
  - [ ] Test narrowing after correct answer
  - [ ] Test widening after incorrect answer
  - [ ] Test asymmetric direction: early and late tracked independently
  - [ ] Test offset stays within min/max bounds
  - [ ] Test tempo from settings is passed through to challenge

- [ ] Task 7: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Pattern to follow: `NextPitchComparisonStrategy` and `KazezNoteStrategy`

The rhythm strategy mirrors the pitch strategy exactly:
- **Protocol** at `Core/Algorithm/NextPitchComparisonStrategy.swift` — stateless, all inputs via parameters, returns value type
- **Implementation** at `Core/Algorithm/KazezNoteStrategy.swift` — Kazez formula with `narrowingCoefficient = 0.05`, `wideningCoefficient = 0.09`

The rhythm equivalent uses the same Kazez adjustment formula but operates on **percentage of sixteenth note** instead of **cents**. The offset magnitude represents how far early or late the 4th note is displaced.

### Critical: `RhythmProfile` no longer exists as a protocol

Story 47.3/47.4 unified all profile access under `TrainingProfile` with `StatisticsKey`-based storage. The strategy must use:

```swift
profile.statistics(for: .rhythm(.rhythmComparison, tempoRange, direction))
```

This returns `StatisticalSummary?`. Pattern-match on `.continuous(let stats)` to access `stats.welford.mean` for the current mean offset magnitude at that tempo range and direction.

To find the correct `TempoRange` for the session's tempo:
```swift
guard let range = TempoRange.range(for: settings.tempo) else { /* fallback */ }
```

### Asymmetric early/late tracking (FR83)

The strategy decides **both** direction and magnitude:
1. Query profile for early stats: `.rhythm(.rhythmComparison, tempoRange, .early)`
2. Query profile for late stats: `.rhythm(.rhythmComparison, tempoRange, .late)`
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

### Settings type: `RhythmComparisonTrainingSettings`

Follow the session-specific settings pattern established in the project (see `PitchComparisonTrainingSettings`). The architecture doc references a generic `TrainingSettings` but this was refactored into session-specific types. Create:

```swift
struct RhythmComparisonTrainingSettings {
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

### `RhythmComparison` lives in `RhythmComparison/`

Per architecture, `RhythmComparison.swift` goes in the feature directory `RhythmComparison/`, not in `Core/`. It's a feature-specific value type consumed by `RhythmComparisonSession`.

### MockNextRhythmComparisonStrategy

Follow mock contract from `project-context.md`:
- Conform to `NextRhythmComparisonStrategy`
- Track call count: `nextRhythmComparisonCallCount`
- Capture parameters: `lastProfile`, `lastSettings`, `lastResult`
- Configurable return: `challengeToReturn: RhythmComparison`
- `reset()` method

### What NOT to do

- Do NOT use `RhythmProfile` protocol — it was removed; use `TrainingProfile` with `StatisticsKey`
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT add `@MainActor` annotations (redundant with default isolation)
- Do NOT use `ObservableObject`, `@Published`, or Combine
- Do NOT import SwiftUI in algorithm files
- Do NOT register anything in `PeachApp.swift` — session wiring happens in story 48.2
- Do NOT create the `RhythmComparison/` directory structure beyond `RhythmComparison.swift` — other files come in 48.2/48.3

### Project Structure Notes

New files:
```
Peach/
├── Core/
│   ├── Algorithm/
│   │   ├── NextRhythmComparisonStrategy.swift    # NEW protocol
│   │   └── AdaptiveRhythmComparisonStrategy.swift # NEW implementation
│   └── Training/
│       └── RhythmComparisonTrainingSettings.swift # NEW settings type
├── RhythmComparison/
│   └── RhythmComparison.swift                 # NEW value type

PeachTests/
├── Core/
│   └── Algorithm/
│       └── AdaptiveRhythmComparisonStrategyTests.swift # NEW
├── RhythmComparison/
│   └── RhythmComparisonTests.swift            # NEW
└── Mocks/
    └── MockNextRhythmComparisonStrategy.swift    # NEW
```

All paths align with existing conventions: algorithms in `Core/Algorithm/`, training settings in `Core/Training/`, feature types in feature directories.

### References

- [Source: Peach/Core/Algorithm/NextPitchComparisonStrategy.swift — protocol pattern to mirror]
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift — Kazez formula, narrowing/widening coefficients]
- [Source: Peach/Core/Training/PitchComparisonTrainingSettings.swift — session-specific settings pattern]
- [Source: Peach/Core/Profile/TrainingProfile.swift — `statistics(for:)` returns `StatisticalSummary?`, `mergedStatistics(for:)` default extension]
- [Source: Peach/Core/Profile/StatisticsKey.swift — `.rhythm(TrainingMode, TempoRange, RhythmDirection)` key structure]
- [Source: Peach/Core/Music/RhythmOffset.swift — signed Duration, `percentageOfSixteenthNote(at:)`]
- [Source: Peach/Core/Music/TempoBPM.swift — `sixteenthNoteDuration` computed property]
- [Source: Peach/Core/Music/TempoRange.swift — `range(for:)` lookup, `defaultRanges`]
- [Source: Peach/Core/Music/RhythmDirection.swift — `.early`/`.late`, `CaseIterable`]
- [Source: Peach/Core/Training/CompletedRhythmComparison.swift — result type with tempo, offset, isCorrect]
- [Source: Peach/Core/Profile/StatisticalSummary.swift — `.continuous(TrainingModeStatistics)` sum type]
- [Source: docs/planning-artifacts/architecture.md#NextRhythmComparisonStrategy — protocol and RhythmComparison definition]
- [Source: docs/planning-artifacts/epics.md#Story 48.1 — acceptance criteria]
- [Source: docs/implementation-artifacts/47-4-progresstimeline-extension-to-six-training-modes.md — previous story, StatisticsKey-based API]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
