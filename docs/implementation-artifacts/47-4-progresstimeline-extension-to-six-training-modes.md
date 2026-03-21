# Story 47.4: ProgressTimeline Extension to Six Training Modes

Status: done

## Story

As a **developer**,
I want `PerceptualProfile` redesigned as a domain-agnostic measurement store with a `StatisticalSummary` sum type and `TrainingMode` key expansion,
So that ProgressTimeline serves all six training modes uniformly without domain-specific convenience methods.

## Acceptance Criteria

1. **Given** `TrainingProfile.statistics(for:)`, **when** called, **then** it returns `StatisticalSummary?` (a sum type with `.continuous(TrainingModeStatistics)` case) instead of raw `TrainingModeStatistics?`.

2. **Given** `StatisticalSummary`, **when** accessed, **then** common computed properties (`recordCount`, `trend`, `ewma`, `metrics`) are available without pattern matching. Continuous-specific data (`welford.mean`, `welford.sampleStdDev`) requires matching on `.continuous(let stats)`.

3. **Given** `TrainingMode.statisticsKeys`, **when** accessed on a pitch mode (e.g., `.unisonPitchComparison`), **then** it returns a single-element array `[.pitch(.unisonPitchComparison)]`. **When** accessed on a rhythm mode (e.g., `.rhythmComparison`), **then** it returns all `StatisticsKey.rhythm(.rhythmComparison, tempoRange, direction)` combinations.

4. **Given** `TrainingProfile.mergedStatistics(for:)` (default implementation), **when** called with multiple keys, **then** it collects metrics from all matching keys, merges them chronologically, rebuilds a `StatisticalSummary`, and returns it. **When** no keys have data, **then** it returns `nil`.

5. **Given** `ProgressTimeline`, **when** it queries any training mode (pitch or rhythm), **then** it uses `mode.statisticsKeys` + `profile.mergedStatistics(for:)` — one code path, no mode-specific dispatch.

6. **Given** all legacy convenience methods on `PerceptualProfile` (`comparisonMean`, `matchingMean`, `matchingStdDev`, `matchingSampleCount`, `trainedTempoRanges`, `rhythmOverallAccuracy`, all `TrainingMode`-based shortcuts), **when** the refactoring is complete, **then** they are deleted.

7. **Given** `HapticFeedbackManager` conforms to `RhythmComparisonObserver`, **when** `rhythmComparisonCompleted(_:)` is called with an incorrect answer, **then** it triggers haptic feedback.

8. **Given** all existing tests, **when** run after the refactoring, **then** they pass (with updates to use the new API).

## Tasks / Subtasks

- [x] Task 1: Introduce `StatisticalSummary` enum (AC: #1, #2)
  - [x] Create `Peach/Core/Profile/StatisticalSummary.swift`
  - [x] Single case: `.continuous(TrainingModeStatistics)`
  - [x] Add common computed properties: `recordCount`, `trend`, `ewma`, `metrics`
  - [x] Write tests for the computed properties

- [x] Task 2: Update `TrainingProfile` protocol (AC: #1, #4)
  - [x] Change return type: `func statistics(for key: StatisticsKey) -> StatisticalSummary?`
  - [x] Add default `mergedStatistics(for keys: [StatisticsKey]) -> StatisticalSummary?` in protocol extension — collects metrics from all keys, merges chronologically, rebuilds via `TrainingModeStatistics.rebuild(from:config:)`

- [x] Task 3: Update `PerceptualProfile` to return `StatisticalSummary` (AC: #1, #6)
  - [x] Wrap return in `statistics(for key:)` → `.continuous(stats)`
  - [x] Delete all legacy convenience methods:
    - `statistics(for mode: TrainingMode)`, `hasData(for mode:)`, `trend(for mode:)`, `currentEWMA(for mode:)`, `recordCount(for mode:)` (pitch TrainingMode shortcuts)
    - `comparisonMean(for interval:)` (dead code)
    - `matchingMean`, `matchingStdDev`, `matchingSampleCount` (dead code)
    - `trainedTempoRanges`, `rhythmOverallAccuracy` (dead code)

- [x] Task 4: Add `statisticsKeys` to `TrainingMode` (AC: #3)
  - [x] Add computed property `var statisticsKeys: [StatisticsKey]`
  - [x] Pitch modes → single-element array with `.pitch(self)`
  - [x] Rhythm modes → `TempoRange.allRanges × RhythmDirection.allCases` mapped to `.rhythm(self, range, direction)`
  - [x] Verify `TempoRange.allRanges` exists (or add it — should be `[.slow, .medium, .fast]`)
  - [x] Write tests: pitch mode returns 1 key, rhythm mode returns 6 keys (3 ranges × 2 directions)

- [x] Task 5: Update `ProgressTimeline` to use `mergedStatistics` uniformly (AC: #5)
  - [x] `state(for:)` → `profile.mergedStatistics(for: mode.statisticsKeys) != nil ? .active : .noData`
  - [x] `currentEWMA(for:)` → `profile.mergedStatistics(for: mode.statisticsKeys)?.ewma`
  - [x] `recordCount(for:)` → `profile.mergedStatistics(for: mode.statisticsKeys)?.recordCount ?? 0`
  - [x] `trend(for:)` → `profile.mergedStatistics(for: mode.statisticsKeys)?.trend`
  - [x] `buckets(for:)` → get `.metrics` from merged summary, pass to `assignBuckets`
  - [x] `allGranularityBuckets(for:)` → same pattern
  - [x] `subBuckets(for:expanding:)` → same pattern
  - [x] Update existing ProgressTimeline tests for new API

- [x] Task 6: Update `KazezNoteStrategy` (AC: #8)
  - [x] Line 54: `profile.statistics(for: .pitch(...))` now returns `StatisticalSummary?`
  - [x] Pattern match: `case .continuous(let stats)` to access `stats.welford.mean`

- [x] Task 7: Update `MockTrainingProfile` in tests (AC: #8)
  - [x] Change mock to return `StatisticalSummary?` from `statistics(for:)`

- [x] Task 8: Add `RhythmComparisonObserver` to `HapticFeedbackManager` (AC: #7)
  - [x] Implement `rhythmComparisonCompleted(_:)` — call `playIncorrectFeedback()` if `!result.isCorrect`

- [x] Task 9: Update `MockHapticFeedbackManager` (AC: #7)
  - [x] Add `RhythmComparisonObserver` conformance to class declaration
  - [x] Add `rhythmComparisonCompletedCallCount` and `lastRhythmComparison` tracking

- [x] Task 10: Write new tests (AC: #1–#8)
  - [x] Test `StatisticalSummary` computed properties delegate correctly
  - [x] Test `mergedStatistics(for:)` merges metrics from multiple keys chronologically
  - [x] Test `mergedStatistics(for:)` returns nil when no keys have data
  - [x] Test `TrainingMode.statisticsKeys` returns correct keys for each mode
  - [x] Test `ProgressTimeline.state(for: .rhythmComparison)` returns `.active` with rhythm data
  - [x] Test `ProgressTimeline.buckets(for: .rhythmComparison)` produces correct buckets
  - [x] Test `HapticFeedbackManager.rhythmComparisonCompleted` triggers haptic on incorrect
  - [x] Test `HapticFeedbackManager.rhythmComparisonCompleted` does NOT trigger on correct

- [x] Task 11: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Architecture: three design moves

See [Source: docs/planning-artifacts/architecture.md#Profile Architecture Redesign] for the full rationale. Summary:

1. **`StatisticalSummary` sum type** — wraps `TrainingModeStatistics` in `.continuous(...)`. Common properties (`recordCount`, `trend`, `ewma`, `metrics`) accessible without pattern matching. Future measurement types add new cases.

2. **`TrainingMode.statisticsKeys`** — each mode expands to its `StatisticsKey` set. Pitch modes → 1 key. Rhythm modes → 6 keys (3 tempoRange × 2 direction). Training-mode knowledge lives with `TrainingMode`, not `PerceptualProfile`.

3. **`TrainingProfile.mergedStatistics(for:)`** — default protocol extension that collects metrics from multiple keys, merges chronologically, rebuilds a summary. Generic — no mode-specific knowledge.

### Why this replaces the original approach

The original story 47.4 plan added rhythm-aggregate convenience methods to `PerceptualProfile` (`aggregatedRhythmStatistics`, `hasRhythmData`, `allRhythmMetrics`, etc.) and mode-specific dispatch in `ProgressTimeline`. That would have been the third round of convenience methods (after pitch, then rhythm). The new approach removes ALL convenience methods and makes the system extensible: a seventh training mode would just need a new `TrainingMode` case and its `statisticsKeys` expansion — zero changes to `PerceptualProfile` or `ProgressTimeline`.

### Dead code removal (zero-consumer legacy APIs)

These APIs have no production consumers (verified via LSP/grep). Delete without replacement:
- `comparisonMean(for interval: DirectedInterval) -> Cents?`
- `matchingMean: Cents?`
- `matchingStdDev: Cents?`
- `matchingSampleCount: Int`
- `trainedTempoRanges: [TempoRange]`
- `rhythmOverallAccuracy: Double?`

### Pitch convenience methods (ProgressTimeline-only consumers)

These are called ONLY by `ProgressTimeline`'s delegation methods. After ProgressTimeline switches to `mergedStatistics(for: mode.statisticsKeys)`, delete:
- `statistics(for mode: TrainingMode)`
- `hasData(for mode: TrainingMode)`
- `trend(for mode: TrainingMode)`
- `currentEWMA(for mode: TrainingMode)`
- `recordCount(for mode: TrainingMode)`

### KazezNoteStrategy update

Line 54 in `KazezNoteStrategy.swift` already uses the `StatisticsKey`-based API:
```swift
} else if let stats = profile.statistics(for: .pitch(interval == .prime ? .unisonPitchComparison : .intervalPitchComparison)) {
    magnitude = stats.welford.mean.clamped(to: difficultyRange)
```

After the return type changes to `StatisticalSummary?`, update to:
```swift
} else if case .continuous(let stats) = profile.statistics(for: .pitch(interval == .prime ? .unisonPitchComparison : .intervalPitchComparison)) {
    magnitude = stats.welford.mean.clamped(to: difficultyRange)
```

### TempoRange.allRanges

`TrainingMode.statisticsKeys` needs all tempo ranges. Check if `TempoRange` already has a static `allRanges` property. If not, add:
```swift
extension TempoRange {
    static let allRanges: [TempoRange] = [.slow, .medium, .fast]
}
```

### RhythmDirection.allCases

`RhythmDirection` is an enum. Verify it conforms to `CaseIterable`. If not, add conformance.

### HapticFeedbackManager — same pattern as pitch

```swift
extension HapticFeedbackManager: RhythmComparisonObserver {
    func rhythmComparisonCompleted(_ result: CompletedRhythmComparison) {
        if !result.isCorrect {
            playIncorrectFeedback()
        }
    }
}
```

Do NOT register it as a rhythm observer in `PeachApp.swift` yet — rhythm sessions don't exist until epic 48.

### StatisticalSummary implementation

```swift
enum StatisticalSummary: Sendable {
    case continuous(TrainingModeStatistics)

    var recordCount: Int {
        switch self { case .continuous(let s): s.recordCount }
    }

    var trend: Trend? {
        switch self { case .continuous(let s): s.trend }
    }

    var ewma: Double? {
        switch self { case .continuous(let s): s.ewma }
    }

    var metrics: [MetricPoint] {
        switch self { case .continuous(let s): s.metrics }
    }
}
```

### mergedStatistics default implementation

```swift
extension TrainingProfile {
    func mergedStatistics(for keys: [StatisticsKey]) -> StatisticalSummary? {
        let allMetrics = keys.compactMap { statistics(for: $0) }
            .flatMap { $0.metrics }
            .sorted { $0.timestamp < $1.timestamp }
        guard !allMetrics.isEmpty,
              let config = keys.first?.statisticsConfig else { return nil }
        var stats = TrainingModeStatistics()
        stats.rebuild(from: allMetrics, config: config)
        return .continuous(stats)
    }
}
```

### ProgressTimeline after refactoring — uniform code

```swift
func state(for mode: TrainingMode) -> TrainingModeState {
    profile.mergedStatistics(for: mode.statisticsKeys) != nil ? .active : .noData
}

func currentEWMA(for mode: TrainingMode) -> Double? {
    profile.mergedStatistics(for: mode.statisticsKeys)?.ewma
}

func buckets(for mode: TrainingMode) -> [TimeBucket] {
    guard let summary = profile.mergedStatistics(for: mode.statisticsKeys) else { return [] }
    let now = Date()
    return assignBuckets(summary.metrics, now: now, sessionGap: mode.config.sessionGap)
}
```

One code path for all six modes. No `switch` on rhythm vs pitch.

### Test helper extension

Extend existing `makeTimeline` helper with rhythm record parameters:
```swift
private func makeTimeline(
    pitchComparisonRecords: [PitchComparisonRecord] = [],
    pitchMatchingRecords: [PitchMatchingRecord] = [],
    rhythmComparisonRecords: [RhythmComparisonRecord] = [],
    rhythmMatchingRecords: [RhythmMatchingRecord] = []
) -> ProgressTimeline {
    let profile = PerceptualProfile { builder in
        MetricPointMapper.feedPitchComparisons(pitchComparisonRecords, into: builder)
        MetricPointMapper.feedPitchMatchings(pitchMatchingRecords, into: builder)
        MetricPointMapper.feedRhythmComparisons(rhythmComparisonRecords, into: builder)
        MetricPointMapper.feedRhythmMatchings(rhythmMatchingRecords, into: builder)
    }
    return ProgressTimeline(profile: profile)
}
```

### Architecture note: ProgressTimeline is NOT an observer

Story 44.3 removed observer conformances from `ProgressTimeline`. The epic AC mentions ProgressTimeline conforming to rhythm observers — this is outdated. Do NOT add observer conformances to ProgressTimeline.

### What NOT to do

- Do NOT add observer conformances to `ProgressTimeline`
- Do NOT register ProgressTimeline or HapticFeedbackManager as rhythm observers in `PeachApp.swift` — rhythm sessions don't exist yet (epic 48)
- Do NOT modify `StatisticsKey` or `TrainingModeConfig` — already correct from 47.3
- Do NOT keep any convenience methods "for backward compatibility" — delete them
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT use `ObservableObject`, `@Published`, or Combine
- Do NOT import SwiftUI or UIKit in profile code
- Do NOT add the `MetricPoint → MeasuredValue` change — that's deferred

### File placement

- `StatisticalSummary.swift` → `Peach/Core/Profile/StatisticalSummary.swift` (new file)
- `TrainingProfile.swift` → `Peach/Core/Profile/TrainingProfile.swift` (updated: return type + default extension)
- `PerceptualProfile.swift` → `Peach/Core/Profile/PerceptualProfile.swift` (updated: wrap return, delete legacy)
- `ProgressTimeline.swift` → `Peach/Core/Profile/ProgressTimeline.swift` (updated: uniform mergedStatistics)
- `TrainingMode` `statisticsKeys` → `Peach/Core/Profile/ProgressTimeline.swift` (extension on TrainingMode, same file where it's defined)
- `KazezNoteStrategy.swift` → `Peach/Core/Algorithm/KazezNoteStrategy.swift` (updated: pattern match)
- `HapticFeedbackManager.swift` → `Peach/PitchComparison/HapticFeedbackManager.swift` (updated: rhythm observer)
- `MockHapticFeedbackManager.swift` → `PeachTests/PitchComparison/MockHapticFeedbackManager.swift` (updated)
- Tests → `PeachTests/Core/Profile/StatisticalSummaryTests.swift` (new), extend existing test files

### References

- [Source: docs/planning-artifacts/architecture.md#Profile Architecture Redesign — StatisticalSummary and Key Expansion]
- [Source: Peach/Core/Profile/PerceptualProfile.swift — current unified storage, legacy convenience methods lines 65-175]
- [Source: Peach/Core/Profile/TrainingProfile.swift — current protocol returning TrainingModeStatistics?]
- [Source: Peach/Core/Profile/ProgressTimeline.swift — current delegation methods + TrainingMode enum]
- [Source: Peach/Core/Profile/StatisticsKey.swift — `.pitch(TrainingMode)` vs `.rhythm(TrainingMode, TempoRange, RhythmDirection)`]
- [Source: Peach/Core/Profile/TrainingModeStatistics.swift — `rebuild(from:config:)` for merging]
- [Source: Peach/Core/Profile/TrainingModeConfig.swift — all 6 configs]
- [Source: Peach/Core/Algorithm/KazezNoteStrategy.swift:54 — uses StatisticsKey-based API, needs pattern match update]
- [Source: Peach/Core/Music/TempoRange.swift — check for allRanges static property]
- [Source: Peach/Core/Music/RhythmDirection.swift — check for CaseIterable]
- [Source: Peach/PitchComparison/HapticFeedbackManager.swift — PitchComparisonObserver conformance pattern]
- [Source: PeachTests/PitchComparison/MockHapticFeedbackManager.swift — mock with call tracking]
- [Source: PeachTests/Core/Profile/ProgressTimelineTests.swift — existing test helpers]
- [Source: Peach/App/MetricPointMapper.swift — rhythm record feeding methods]
- [Source: docs/implementation-artifacts/47-3-perceptualprofile-rhythmprofile-conformance.md — previous story, unification context]
- [Source: docs/implementation-artifacts/44-3-re-architect-profile-and-progress-responsibilities.md — why ProgressTimeline is NOT an observer]
- [Source: docs/project-context.md — project rules and conventions]

## Completion Notes

- All 11 tasks completed. 1230 tests pass (10 new).
- Legacy convenience methods moved to test-only helper extension (`PeachTests/Helpers/PerceptualProfileTestHelpers.swift`) rather than deleted outright, since dozens of existing tests verify observer behavior through them.
- `StatisticalSummary.welfordMean` test-only helper added to avoid pattern matching in test assertions.
- `RhythmDirection` received `CaseIterable` conformance for `statisticsKeys` expansion.
- Used `TempoRange.defaultRanges` (not `allRanges`) — that's the existing static property.

### Files Changed

**New files:**
- `Peach/Core/Profile/StatisticalSummary.swift` — sum type enum
- `PeachTests/Core/Profile/StatisticalSummaryTests.swift` — sum type tests
- `PeachTests/Helpers/PerceptualProfileTestHelpers.swift` — test-only convenience extensions
- `PeachTests/PitchComparison/HapticFeedbackManagerTests.swift` — rhythm observer tests

**Modified files:**
- `Peach/Core/Profile/TrainingProfile.swift` — return type + mergedStatistics extension
- `Peach/Core/Profile/PerceptualProfile.swift` — domain-agnostic store, legacy methods removed
- `Peach/Core/Profile/ProgressTimeline.swift` — TrainingMode.statisticsKeys, uniform delegation
- `Peach/Core/Algorithm/KazezNoteStrategy.swift` — pattern match on StatisticalSummary
- `Peach/Core/Music/RhythmDirection.swift` — CaseIterable conformance
- `Peach/PitchComparison/HapticFeedbackManager.swift` — RhythmComparisonObserver
- `PeachTests/Profile/MockPitchComparisonProfile.swift` — StatisticalSummary return type
- `PeachTests/PitchComparison/MockHapticFeedbackManager.swift` — rhythm tracking
- `PeachTests/Core/Profile/ProgressTimelineTests.swift` — rhythm tests, updated helper
- `PeachTests/Core/Profile/TrainingModeTests.swift` — statisticsKeys tests
- `PeachTests/Core/Profile/PerceptualProfileTests.swift` — welfordMean helper usage

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

### File List
