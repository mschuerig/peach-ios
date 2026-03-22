# Story 54.5: Data Model and Storage

Status: backlog

## Story

As a **developer**,
I want a `ContinuousRhythmMatchingRecord` SwiftData model and `TrainingDataStore` integration,
so that continuous rhythm matching trials are persisted and available for profile visualization and export.

## Acceptance Criteria

1. **Given** `ContinuousRhythmMatchingRecord` as a SwiftData `@Model`, **when** inspected, **then** it stores: `tempoBPM: Int`, `meanOffsetMs: Double`, `hitRate: Double`, `gapPositionBreakdown: Data` (encoded JSON), `cycleCount: Int`, `timestamp: Date`.

2. **Given** `TrainingDataStore`, **when** it conforms to `ContinuousRhythmMatchingObserver`, **then** `continuousRhythmMatchingCompleted(_:)` converts the trial to a record and persists it.

3. **Given** `TrainingDataStore`, **when** CRUD methods are called, **then** `save`, `fetchAll`, and `deleteAll` operations work for `ContinuousRhythmMatchingRecord` following existing patterns.

4. **Given** `PerceptualProfile`, **when** it conforms to `ContinuousRhythmMatchingObserver`, **then** it updates rhythm statistics keyed by `TempoRange` using the trial's mean offset, split by early/late direction of the mean.

5. **Given** `TrainingDisciplineConfig`, **when** a `.continuousRhythmMatching` discipline is registered, **then** it has appropriate display name, unit label, and optimal baseline.

6. **Given** `ProgressTimeline`, **when** extended for the new discipline, **then** it tracks trend data for continuous rhythm matching.

7. **Given** unit tests, **when** all data operations are tested, **then** save/fetch/delete, observer conversion, and profile update are verified.

## Tasks / Subtasks

- [ ] Task 1: Create `ContinuousRhythmMatchingRecord` (AC: #1)
  - [ ] Create `Peach/Core/Data/ContinuousRhythmMatchingRecord.swift`
  - [ ] SwiftData `@Model final class`
  - [ ] Properties: `tempoBPM: Int`, `meanOffsetMs: Double`, `hitRate: Double`, `gapPositionBreakdownJSON: Data`, `cycleCount: Int`, `timestamp: Date`
  - [ ] The `gapPositionBreakdownJSON` encodes per-position stats as JSON for storage flexibility
  - [ ] Add to `ModelContainer` schema in `PeachApp.swift`
  - [ ] Write tests in `PeachTests/Core/Data/ContinuousRhythmMatchingRecordTests.swift`

- [ ] Task 2: Extend `TrainingDataStore` (AC: #2, #3)
  - [ ] Add `save(_ record: ContinuousRhythmMatchingRecord) throws`
  - [ ] Add `fetchAllContinuousRhythmMatchings() throws -> [ContinuousRhythmMatchingRecord]`
  - [ ] Add `deleteAllContinuousRhythmMatchings() throws`
  - [ ] Extend `replaceAllRecords(...)` to include `continuousRhythmMatchings` parameter
  - [ ] Conform to `ContinuousRhythmMatchingObserver` — convert trial to record
  - [ ] Write tests in `PeachTests/Core/Data/TrainingDataStoreTests.swift` (extend existing)

- [ ] Task 3: Extend `PerceptualProfile` (AC: #4)
  - [ ] Conform to `ContinuousRhythmMatchingObserver`
  - [ ] `continuousRhythmMatchingCompleted(_:)` — update statistics using mean offset, keyed by `TempoRange` and direction of mean offset
  - [ ] Use `StatisticsKey.rhythm(.continuousRhythmMatching, range, direction)`
  - [ ] Write tests

- [ ] Task 4: Register `TrainingDisciplineConfig` (AC: #5)
  - [ ] Add `static let continuousRhythmMatching` to `TrainingDisciplineConfig`
  - [ ] Display name: `"Fill the Gap – Rhythm"` (localized)
  - [ ] Unit label: `"ms"`
  - [ ] Optimal baseline: `20.0` (same as rhythm matching — ±20ms expert target)

- [ ] Task 5: Extend `ProgressTimeline` (AC: #6)
  - [ ] Add `.continuousRhythmMatching` case or configuration
  - [ ] Conform to `ContinuousRhythmMatchingObserver` if needed for trend tracking

- [ ] Task 6: Run full test suite
  - [ ] `bin/test.sh` — all tests pass, no regressions

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
