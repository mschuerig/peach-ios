# Story 54.5: Data Model and Storage

Status: done

## Story

As a **developer**,
I want a `ContinuousRhythmMatchingRecord` SwiftData model and `TrainingDataStore` integration,
so that continuous rhythm matching trials are persisted and available for profile visualization and export.

## Acceptance Criteria

1. **Given** `ContinuousRhythmMatchingRecord` as a SwiftData `@Model`, **when** inspected, **then** it stores: `tempoBPM: Int`, `meanOffsetMs: Double`, `hitRate: Double`, `gapPositionBreakdownJSON: Data` (encoded JSON), `cycleCount: Int`, `timestamp: Date`.

2. **Given** `TrainingDataStore`, **when** it conforms to `ContinuousRhythmMatchingObserver`, **then** `continuousRhythmMatchingCompleted(_:)` converts the trial to a record and persists it.

3. **Given** `TrainingDataStore`, **when** CRUD methods are called, **then** `save`, `fetchAll`, and `deleteAll` operations work for `ContinuousRhythmMatchingRecord` following existing patterns.

4. **Given** `PerceptualProfile`, **when** it conforms to `ContinuousRhythmMatchingObserver`, **then** it updates rhythm statistics keyed by `TempoRange` using the signed mean offset computed from individual gap offsets, split by early/late direction.

5. **Given** `TrainingDisciplineConfig`, **when** a `.continuousRhythmMatching` discipline is registered, **then** it has appropriate display name, unit label, and optimal baseline.

6. **Given** `ProgressTimeline`, **when** extended for the new discipline, **then** it tracks trend data for continuous rhythm matching.

7. **Given** unit tests, **when** all data operations are tested, **then** save/fetch/delete, observer conversion, and profile update are verified.

## Tasks / Subtasks

- [x] Task 1: Create `ContinuousRhythmMatchingRecord` (AC: #1)
  - [x] Create `Peach/Core/Data/ContinuousRhythmMatchingRecord.swift`
  - [x] SwiftData `@Model final class`
  - [x] Properties: `tempoBPM: Int`, `meanOffsetMs: Double`, `hitRate: Double`, `gapPositionBreakdownJSON: Data`, `cycleCount: Int`, `timestamp: Date`
  - [x] The `gapPositionBreakdownJSON` encodes per-position stats as JSON for storage flexibility
  - [x] Add to `ModelContainer` schema in `PeachApp.swift`
  - [x] Write tests in `PeachTests/Core/Data/ContinuousRhythmMatchingRecordTests.swift`

- [x] Task 2: Extend `TrainingDataStore` (AC: #2, #3)
  - [x] Add `save(_ record: ContinuousRhythmMatchingRecord) throws`
  - [x] Add `fetchAllContinuousRhythmMatchings() throws -> [ContinuousRhythmMatchingRecord]`
  - [x] Add `deleteAllContinuousRhythmMatchings() throws`
  - [x] Extend `replaceAllRecords(...)` to include `continuousRhythmMatchings` parameter
  - [x] Conform to `ContinuousRhythmMatchingObserver` — convert trial to record
  - [x] Write tests in `PeachTests/Core/Data/TrainingDataStoreTests.swift` (extend existing)

- [x] Task 3: Extend `PerceptualProfile` (AC: #4)
  - [x] Conform to `ContinuousRhythmMatchingObserver`
  - [x] `continuousRhythmMatchingCompleted(_:)` — update statistics using mean offset, keyed by `TempoRange` and direction of mean offset
  - [x] Use `StatisticsKey.rhythm(.continuousRhythmMatching, range, direction)`
  - [x] Write tests

- [x] Task 4: Register `TrainingDisciplineConfig` (AC: #5)
  - [x] Add `static let continuousRhythmMatching` to `TrainingDisciplineConfig`
  - [x] Display name: `"Fill the Gap – Rhythm"` (localized)
  - [x] Unit label: `"ms"`
  - [x] Optimal baseline: `20.0` (same as rhythm matching — ±20ms expert target)

- [x] Task 5: Extend `ProgressTimeline` (AC: #6)
  - [x] Add `.continuousRhythmMatching` case or configuration
  - [x] Conform to `ContinuousRhythmMatchingObserver` if needed for trend tracking

- [x] Task 6: Run full test suite
  - [x] `bin/test.sh` — all tests pass, no regressions (1571 passed)

## File List

### New Files
- `Peach/Core/Data/ContinuousRhythmMatchingRecord.swift` — SwiftData model + `PositionBreakdown` Codable struct
- `PeachTests/Core/Data/ContinuousRhythmMatchingRecordTests.swift` — Record model tests

### Modified Files
- `Peach/Core/Data/TrainingDataStore.swift` — CRUD methods, `deleteAll`/`replaceAllRecords` extensions, `ContinuousRhythmMatchingObserver` conformance
- `Peach/Core/Profile/PerceptualProfile.swift` — `ContinuousRhythmMatchingObserver` conformance
- `Peach/Core/Profile/TrainingDisciplineConfig.swift` — `.continuousRhythmMatching` config
- `Peach/Core/Profile/ProgressTimeline.swift` — `.continuousRhythmMatching` discipline case, config, slug, statisticsKeys
- `Peach/App/PeachApp.swift` — ModelContainer schema, observer wiring
- `Peach/App/MetricPointMapper.swift` — `feedContinuousRhythmMatchings` method
- `PeachTests/Core/Data/TrainingDataStoreTests.swift` — New continuous rhythm matching tests
- `PeachTests/Core/Profile/PerceptualProfileTests.swift` — Observer conformance tests
- `PeachTests/Helpers/PerceptualProfileTestHelpers.swift` — Added `.continuousRhythmMatching` to rhythm loops
- `PeachTests/Core/Data/TrainingDataStoreEdgeCaseTests.swift` — Added `ContinuousRhythmMatchingRecord.self` to ModelContainer
- `PeachTests/Core/Data/TrainingDataTransferServiceTests.swift` — Added `ContinuousRhythmMatchingRecord.self` to ModelContainer
- `PeachTests/Core/Data/TrainingDataImporterTests.swift` — Added `ContinuousRhythmMatchingRecord.self` to ModelContainer
- `PeachTests/Core/Data/TrainingDataExporterTests.swift` — Added `ContinuousRhythmMatchingRecord.self` to ModelContainer
- `PeachTests/Settings/TrainingDataImportActionTests.swift` — Added `ContinuousRhythmMatchingRecord.self` to ModelContainer
- `PeachTests/Settings/SettingsTests.swift` — Added `ContinuousRhythmMatchingRecord.self` to ModelContainer

## Change Log

- Created `ContinuousRhythmMatchingRecord` SwiftData model with `PositionBreakdown` JSON encoding
- Extended `TrainingDataStore` with CRUD, `deleteAll`/`replaceAllRecords`, and `ContinuousRhythmMatchingObserver` conformance
- Extended `PerceptualProfile` with `ContinuousRhythmMatchingObserver` — computes signed mean from raw offsets for correct early/late direction
- Registered `TrainingDisciplineConfig.continuousRhythmMatching` with 20ms optimal baseline
- Extended `ProgressTimeline` with `.continuousRhythmMatching` discipline
- Wired observers `[dataStore, profile]` in `PeachApp.createContinuousRhythmMatchingSession`
- Added `MetricPointMapper.feedContinuousRhythmMatchings` for profile rebuilds from storage
- Fixed 6 test files missing `ContinuousRhythmMatchingRecord.self` in ModelContainer schema

## Dev Agent Record

- **Key decision**: `PerceptualProfile` observer computes signed mean directly from raw `GapResult.offset.statisticalValue` rather than using `CompletedContinuousRhythmMatchingTrial.meanOffsetMs`, because the latter uses `absoluteMilliseconds` (always positive) which would always route to `.late` direction.
- **Boy Scout Rule**: Fixed all 6 test files that create their own ModelContainer to include the new model type, preventing crashes in `deleteAll`/`replaceAllRecords`.

## Dev Notes

### Gap position breakdown encoding

Store per-position stats as JSON in a `Data` column rather than separate columns. This avoids schema rigidity and handles the case where different trials train different positions:

```swift
struct PositionBreakdown: Codable {
    let position: Int  // raw StepPosition value
    let hitCount: Int
    let missCount: Int
    let meanOffsetMs: Double
}
```

### Profile statistics approach

The existing rhythm matching profile uses individual offsets per record. For continuous matching, each record represents an aggregate trial. The profile update should use `meanOffsetMs` as the statistical value, which is less granular but still captures the trend.

Alternative: store individual gap results as a separate array in the record. This would preserve per-gap granularity but increase storage. For v1, the aggregate approach is sufficient.

### What NOT to do

- Do NOT modify `RhythmMatchingRecord` — the continuous mode has its own record type
- Do NOT modify existing observer protocols — create a new one
- Do NOT add CSV export here — that's Story 54.8

### References

- [Source: Peach/Core/Data/RhythmMatchingRecord.swift — existing record pattern]
- [Source: Peach/Core/Data/TrainingDataStore.swift — CRUD and observer patterns]
- [Source: Peach/Core/Profile/PerceptualProfile.swift — profile update pattern]
- [Source: Peach/Core/Profile/TrainingDisciplineConfig.swift — discipline registration]
- [Source: Peach/Core/Profile/ProgressTimeline.swift — trend tracking]
- [Source: Peach/Core/Training/ContinuousRhythmMatchingObserver.swift — from Story 54.2]
- [Source: docs/project-context.md — project rules and conventions]
