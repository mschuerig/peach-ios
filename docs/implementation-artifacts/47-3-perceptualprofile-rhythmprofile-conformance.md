# Story 47.3: PerceptualProfile RhythmProfile Conformance

Status: done

## Story

As a **developer**,
I want `PerceptualProfile` to conform to `RhythmProfile`,
So that rhythm statistics are tracked per-tempo with asymmetric early/late tracking (FR86).

## Acceptance Criteria

1. **Given** `PerceptualProfile` conforms to `RhythmProfile`, **when** `updateRhythmComparison(tempo:offset:isCorrect:)` is called, **then** it updates per-(tempo, direction) statistics for rhythm comparison.

2. **Given** `PerceptualProfile` conforms to `RhythmProfile`, **when** `updateRhythmMatching(tempo:userOffset:)` is called, **then** it updates per-(tempo, direction) statistics for rhythm matching.

3. **Given** `rhythmStats(tempo:direction:)` is called, **when** data exists for the given tempo and direction, **then** it returns `RhythmTempoStats` with mean, stdDev, sampleCount, currentDifficulty.

4. **Given** `trainedTempos`, **when** accessed, **then** it returns all tempos that have any rhythm training data.

5. **Given** `rhythmOverallAccuracy`, **when** accessed with rhythm data, **then** it returns the combined overall accuracy for EWMA headline display (FR89).

6. **Given** `PerceptualProfile` on app startup, **when** rebuilt from stored records, **then** it loads `RhythmComparisonRecord` and `RhythmMatchingRecord` data alongside existing pitch data.

7. **Given** `resetRhythm()` is called, **when** executed, **then** all rhythm statistics are cleared while pitch statistics remain untouched.

## Tasks / Subtasks

- [x] Task 1: Add rhythm internal storage to `PerceptualProfile` (AC: #1, #2, #3, #4)
  - [x] Add per-(TempoBPM, RhythmDirection) dictionary storage for rhythm statistics
  - [x] Each entry tracks: WelfordAccumulator, sample count, EWMA for difficulty

- [x] Task 2: Implement `RhythmProfile` conformance on `PerceptualProfile` (AC: #1, #2, #3, #4, #5)
  - [x] `updateRhythmComparison(tempo:offset:isCorrect:)` — skip incorrect answers (same pattern as pitch comparison), update per-(tempo, offset.direction) stats
  - [x] `updateRhythmMatching(tempo:userOffset:)` — always counts (same pattern as pitch matching), update per-(tempo, userOffset.direction) stats
  - [x] `rhythmStats(tempo:direction:)` — return `RhythmTempoStats` from stored per-(tempo, direction) data
  - [x] `trainedTempos` — collect distinct tempos from the dictionary
  - [x] `rhythmOverallAccuracy` — combined accuracy across all rhythm data
  - [x] `resetRhythm()` — clear rhythm dictionary, leave pitch modes untouched

- [x] Task 3: Extend Builder to accept rhythm data (AC: #6)
  - [x] Add rhythm point methods to `PerceptualProfile.Builder`
  - [x] Update `finalize(from:)` to rebuild rhythm storage from builder data

- [x] Task 4: Extend `MetricPointMapper` to feed rhythm records (AC: #6)
  - [x] Add `feedRhythmComparisons(_:into:)` to `MetricPointMapper`
  - [x] Add `feedRhythmMatchings(_:into:)` to `MetricPointMapper`
  - [x] Update `feedAllRecords(from:into:)` to include rhythm records

- [x] Task 5: Update `resetAll()` to also clear rhythm data (AC: #7)
  - [x] Ensure `resetAll()` clears both pitch modes and rhythm dictionary

- [x] Task 6: Add `RhythmComparisonObserver` and `RhythmMatchingObserver` conformance (AC: #1, #2)
  - [x] `rhythmComparisonCompleted(_:)` delegates to `updateRhythmComparison`
  - [x] `rhythmMatchingCompleted(_:)` delegates to `updateRhythmMatching`

- [x] Task 7: Write tests (AC: #1–#7)
  - [x] Test `updateRhythmComparison` updates per-(tempo, direction) stats
  - [x] Test incorrect rhythm comparison answers are skipped
  - [x] Test `updateRhythmMatching` always updates stats
  - [x] Test `rhythmStats` returns correct mean/stdDev/sampleCount
  - [x] Test `rhythmStats` for non-existent tempo returns zero stats
  - [x] Test `trainedTempos` returns correct set
  - [x] Test `rhythmOverallAccuracy` computes combined accuracy
  - [x] Test `resetRhythm` clears rhythm but preserves pitch
  - [x] Test `resetAll` clears everything including rhythm
  - [x] Test builder initialization with rhythm records rebuilds correctly
  - [x] Test observer conformance delegates correctly

- [x] Task 8: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions

## Dev Notes

### Rhythm indexing is fundamentally different from pitch indexing

Pitch modes use `TrainingMode` enum cases with `TrainingModeStatistics` (Welford + EWMA over `Cents`). Rhythm needs per-(tempo, direction) indexing — a different data shape entirely. Do NOT try to reuse `TrainingModeStatistics` or the `modes` dictionary for rhythm. Add a separate rhythm-specific dictionary.

### Rhythm storage design

The internal storage should be a dictionary keyed by `(TempoBPM, RhythmDirection)`. Since tuples aren't `Hashable`, use a small struct:

```swift
private struct RhythmKey: Hashable {
    let tempo: TempoBPM
    let direction: RhythmDirection
}
```

Each value tracks a `WelfordAccumulator<RhythmOffset>` (or raw Double-based accumulator). This gives per-(tempo, direction) mean, stdDev, sampleCount. For `currentDifficulty`, use the EWMA or latest value.

### RhythmOffset needs WelfordMeasurement conformance

`WelfordAccumulator` is generic over `WelfordMeasurement`. Currently only `Cents` conforms. `RhythmOffset` must also conform:

```swift
extension RhythmOffset: WelfordMeasurement {
    var statisticalValue: Double {
        duration / .milliseconds(1)  // milliseconds as Double
    }
    init(statisticalValue: Double) {
        self.init(duration: .milliseconds(statisticalValue))
    }
}
```

Use absolute magnitude for statistical tracking (same pattern as pitch where `abs(centOffset)` is stored) — the direction is captured by the dictionary key.

### Builder extension for rhythm

The Builder currently stores `[TrainingMode: [MetricPoint<Cents>]]`. For rhythm, add a parallel structure:

```swift
// In Builder:
fileprivate var rhythmPoints: [RhythmKey: [MetricPoint<RhythmOffset>]] = [:]

func addRhythmPoint(_ point: MetricPoint<RhythmOffset>, tempo: TempoBPM, direction: RhythmDirection, isCorrect: Bool = true) {
    guard isCorrect else { return }
    let key = RhythmKey(tempo: tempo, direction: direction)
    rhythmPoints[key, default: []].append(point)
}
```

### MetricPointMapper changes

`MetricPointMapper.feedAllRecords` must also feed rhythm records. Add two new static methods:

```swift
static func feedRhythmComparisons(_ records: [RhythmComparisonRecord], into builder: PerceptualProfile.Builder) {
    for record in records {
        let offset = RhythmOffset(duration: .milliseconds(record.offsetMs))
        let direction = offset.direction
        builder.addRhythmPoint(
            MetricPoint(timestamp: record.timestamp, value: RhythmOffset(duration: .milliseconds(abs(record.offsetMs)))),
            tempo: TempoBPM(record.tempoBPM),
            direction: direction,
            isCorrect: record.isCorrect
        )
    }
}

static func feedRhythmMatchings(_ records: [RhythmMatchingRecord], into builder: PerceptualProfile.Builder) {
    for record in records {
        let offset = RhythmOffset(duration: .milliseconds(record.userOffsetMs))
        let direction = offset.direction
        builder.addRhythmPoint(
            MetricPoint(timestamp: record.timestamp, value: RhythmOffset(duration: .milliseconds(abs(record.userOffsetMs)))),
            tempo: TempoBPM(record.tempoBPM),
            direction: direction
        )
    }
}
```

Update `feedAllRecords`:
```swift
static func feedAllRecords(from dataStore: TrainingDataStore, into builder: PerceptualProfile.Builder) throws {
    feedPitchComparisons(try dataStore.fetchAllPitchComparisons(), into: builder)
    feedPitchMatchings(try dataStore.fetchAllPitchMatchings(), into: builder)
    feedRhythmComparisons(try dataStore.fetchAllRhythmComparisons(), into: builder)
    feedRhythmMatchings(try dataStore.fetchAllRhythmMatchings(), into: builder)
}
```

### Observer conformance pattern

Follow the exact same pattern as existing pitch observer conformances:

```swift
extension PerceptualProfile: RhythmComparisonObserver {
    func rhythmComparisonCompleted(_ result: CompletedRhythmComparison) {
        guard result.isCorrect else { return }
        updateRhythmComparison(tempo: result.tempo, offset: result.offset, isCorrect: result.isCorrect)
    }
}

extension PerceptualProfile: RhythmMatchingObserver {
    func rhythmMatchingCompleted(_ result: CompletedRhythmMatching) {
        updateRhythmMatching(tempo: result.tempo, userOffset: result.userOffset)
    }
}
```

### rhythmOverallAccuracy design

Combined accuracy across all (tempo, direction) entries. Use weighted mean by sample count:

```swift
var rhythmOverallAccuracy: Double? {
    let allStats = rhythmStorage.values
    let totalCount = allStats.reduce(0) { $0 + $1.welford.count }
    guard totalCount > 0 else { return nil }
    let weightedSum = allStats.reduce(0.0) { $0 + $1.welford.mean * Double($1.welford.count) }
    return weightedSum / Double(totalCount)
}
```

This returns the overall mean offset in milliseconds. The caller (future FR89 headline) formats it.

### resetRhythm vs resetAll

- `resetRhythm()` clears only the rhythm dictionary — pitch `modes` untouched
- `resetAll()` must clear BOTH the pitch `modes` dictionary AND the rhythm dictionary

### What NOT to do

- Do NOT add rhythm cases to `TrainingMode` enum — that's story 47.4
- Do NOT modify `TrainingModeConfig` — rhythm mode configs are story 47.4
- Do NOT modify `ProgressTimeline` — that's story 47.4
- Do NOT wire `PerceptualProfile` as rhythm observer in `PeachApp.swift` — that happens when rhythm sessions exist (epic 48)
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT use `ObservableObject`, `@Published`, or Combine
- Do NOT import SwiftUI or UIKit in profile code
- Do NOT store `RhythmOffset` as raw `Double` in the profile — use the domain type

### File placement

- `RhythmProfile` conformance extension goes in `Peach/Core/Profile/PerceptualProfile.swift` — add MARK sections after the existing pitch observer extensions
- `RhythmOffset: WelfordMeasurement` conformance goes in `Peach/Core/Profile/WelfordAccumulator.swift` alongside the existing `Cents` conformance
- `MetricPointMapper` rhythm methods go in `Peach/App/MetricPointMapper.swift`
- Tests go in `PeachTests/Core/Profile/PerceptualProfileTests.swift`

### Project Structure Notes

- No new files needed — all changes extend existing files
- `PerceptualProfile.swift` gets a new private dictionary + `RhythmProfile` conformance extension + observer extensions
- `WelfordAccumulator.swift` gets `RhythmOffset: WelfordMeasurement`
- `MetricPointMapper.swift` gets rhythm record feeding methods
- Tests extend existing test suite

### References

- [Source: Peach/Core/Profile/PerceptualProfile.swift — current implementation with Builder, modes dictionary, pitch observer conformances]
- [Source: Peach/Core/Profile/RhythmProfile.swift — protocol definition and RhythmTempoStats]
- [Source: Peach/Core/Profile/WelfordAccumulator.swift — WelfordMeasurement protocol, WelfordAccumulator generic, Cents conformance]
- [Source: Peach/Core/Profile/TrainingModeStatistics.swift — per-mode stats with Welford + EWMA + trend]
- [Source: Peach/Core/Profile/MetricPoint.swift — timestamped measurement]
- [Source: Peach/App/MetricPointMapper.swift — record-to-metric-point mapping, feedAllRecords]
- [Source: Peach/Core/Music/RhythmOffset.swift — domain type wrapping Duration, .direction derives RhythmDirection]
- [Source: Peach/Core/Music/TempoBPM.swift — domain type, .value for raw Int]
- [Source: Peach/Core/Music/RhythmDirection.swift — enum early/late]
- [Source: Peach/Core/Training/RhythmComparisonObserver.swift — observer protocol]
- [Source: Peach/Core/Training/RhythmMatchingObserver.swift — observer protocol]
- [Source: Peach/Core/Training/CompletedRhythmComparison.swift — result type with TempoBPM, RhythmOffset, isCorrect, timestamp]
- [Source: Peach/Core/Training/CompletedRhythmMatching.swift — result type with TempoBPM, expectedOffset, userOffset, timestamp]
- [Source: Peach/Core/Data/RhythmComparisonRecord.swift — SwiftData model: tempoBPM Int, offsetMs Double, isCorrect Bool, timestamp Date]
- [Source: Peach/Core/Data/RhythmMatchingRecord.swift — SwiftData model: tempoBPM Int, userOffsetMs Double, timestamp Date]
- [Source: Peach/App/PeachApp.swift:186-194 — profile loading via builder + MetricPointMapper]
- [Source: docs/planning-artifacts/epics.md#Epic 47: Remember Every Beat]
- [Source: docs/planning-artifacts/architecture.md — RhythmProfile protocol, per-(tempo, direction) indexing]
- [Source: docs/project-context.md — project rules and conventions]
- [Source: docs/implementation-artifacts/47-2-trainingdatastore-rhythm-crud-and-observer-conformance.md — previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- **Design revision**: Split `RhythmProfile` into `RhythmComparisonProfile` + `RhythmMatchingProfile` (symmetric with pitch protocols)
- **Made `TrainingModeStatistics` generic** over `WelfordMeasurement` — rhythm uses the same statistics machinery as pitch (`TrainingModeStatistics<RhythmOffset>`)
- **Extracted `StatisticsConfig`** from `TrainingModeConfig` — decouples statistical parameters (EWMA halflife, session gap) from display config (which has `Cents`-typed baseline)
- Separate `rhythmComparisonModes` and `rhythmMatchingModes` dictionaries (consistent "modes" naming)
- Added `RhythmOffset: WelfordMeasurement` conformance
- Builder has separate `addRhythmComparisonPoint` and `addRhythmMatchingPoint`
- Extended `MetricPointMapper` with rhythm record feeding
- All observer conformances, reset, and builder finalization implemented
- 15 rhythm tests + full suite of 1207 tests pass

### Change Log

- 2026-03-20: Implemented story 47.3 with symmetric protocol design and generic TrainingModeStatistics
- 2026-03-21: Unified PerceptualProfile design — removed generics from MetricPoint/WelfordAccumulator/TrainingModeStatistics, introduced StatisticsKey + TempoRange, replaced 4 profile protocols with single TrainingProfile, single dictionary storage, single builder.addPoint

### File List

- Peach/Core/Profile/PerceptualProfile.swift (rewritten — unified storage, single update/query)
- Peach/Core/Profile/MetricPoint.swift (modified — non-generic, Double-based)
- Peach/Core/Profile/WelfordAccumulator.swift (modified — non-generic, sampleStdDev replaces typedMean/typedStdDev)
- Peach/Core/Profile/TrainingModeStatistics.swift (modified — non-generic)
- Peach/Core/Profile/TrainingModeConfig.swift (modified — optimalBaseline now Double, added rhythm configs)
- Peach/Core/Profile/ProgressTimeline.swift (modified — TrainingMode rhythm cases, MetricPoint non-generic)
- Peach/Core/Profile/StatisticsKey.swift (new)
- Peach/Core/Profile/TrainingProfile.swift (new — replaces 4 protocols)
- Peach/Core/Music/TempoRange.swift (new)
- Peach/Core/Profile/PitchComparisonProfile.swift (deleted)
- Peach/Core/Profile/PitchMatchingProfile.swift (deleted)
- Peach/Core/Profile/RhythmProfile.swift (deleted)
- Peach/App/MetricPointMapper.swift (modified — StatisticsKey-based)
- Peach/Profile/ProgressChartView.swift (modified — optimalBaseline.rawValue → optimalBaseline)
- Peach/Profile/ExportChartView.swift (modified — same)
- Peach/Core/Algorithm/NextPitchComparisonStrategy.swift (modified — TrainingProfile)
- Peach/Core/Algorithm/KazezNoteStrategy.swift (modified — TrainingProfile)
- Peach/PitchComparison/PitchComparisonSession.swift (modified — TrainingProfile)
- Peach/PitchMatching/PitchMatchingSession.swift (modified — TrainingProfile)
- PeachTests — multiple files updated for non-generic types, unified builder, MockTrainingProfile
- PeachTests/Core/Music/TempoRangeTests.swift (new)
- PeachTests/Core/Profile/StatisticsKeyTests.swift (new)
- PeachTests/Core/Profile/RhythmTempoStatsTests.swift (deleted)
- docs/implementation-artifacts/sprint-status.yaml (modified)
- docs/implementation-artifacts/47-3-perceptualprofile-rhythmprofile-conformance.md (modified)
