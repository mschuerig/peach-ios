# Story 38.2: ProgressTimeline Core — EWMA, Adaptive Buckets, and TrainingModeConfig

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want a core data pipeline that computes EWMA statistics over adaptive time buckets per training mode,
So that the profile visualization has a clean, testable, configurable data source.

## Acceptance Criteria

1. **Given** a `TrainingModeConfig` struct, **When** it is initialized for any training mode, **Then** it centralizes all tuneable parameters: display name, unit label, optimal baseline, EWMA halflife, cold start thresholds, and bucket boundaries. No magic numbers exist outside this configuration type.

2. **Given** a set of `ComparisonRecord` entries for unison discrimination, **When** `ProgressTimeline` processes them, **Then** it groups records into adaptive time buckets (per-session for last 24h, per-day for last 7d, per-week for last 30d, per-month beyond), computes EWMA with the configured halflife (default 7 days), computes standard deviation per bucket, and discrimination mode uses `centOffset` on correct answers only as its metric.

3. **Given** a set of `PitchMatchingRecord` entries, **When** `ProgressTimeline` processes them, **Then** matching mode uses `abs(userCentError)` as its metric, and the same EWMA and bucketing logic applies (parameterized, not duplicated).

4. **Given** `ProgressTimeline` is `@Observable`, **When** a new training record is added via observer protocol, **Then** it updates incrementally without re-scanning all records.

5. **Given** fewer than 20 records for a training mode, **When** `ProgressTimeline` is queried, **Then** it reports cold-start state (no trend computation, limited display data).

## Tasks / Subtasks

- [x] Task 1: Implement `TrainingModeConfig` (AC: #1)
  - [x] 1.1 Create `peach/Core/Profile/TrainingModeConfig.swift` with struct holding all tuneable parameters
  - [x] 1.2 Define four static configurations: unisonDiscrimination, intervalDiscrimination, unisonMatching, intervalMatching
  - [x] 1.3 Write tests for all four configurations and parameter access

- [x] Task 2: Implement adaptive time bucket grouping (AC: #2, #3)
  - [x] 2.1 Define `TimeBucket` struct (periodStart, periodEnd, bucketSize enum)
  - [x] 2.2 Implement bucket boundary computation: per-session (<24h), per-day (<7d), per-week (<30d), per-month (beyond)
  - [x] 2.3 Write tests for bucket assignment across all time ranges

- [x] Task 3: Implement EWMA computation (AC: #2, #3)
  - [x] 3.1 Implement EWMA with configurable halflife (alpha = exp(-ln(2) * dt / halflife))
  - [x] 3.2 Implement per-bucket standard deviation
  - [x] 3.3 Write tests for EWMA correctness with known input/output pairs
  - [x] 3.4 Write tests for stddev computation

- [x] Task 4: Implement `ProgressTimeline` class (AC: #2, #3, #4, #5)
  - [x] 4.1 Create `peach/Core/Profile/ProgressTimeline.swift` as `@Observable final class`
  - [x] 4.2 Initialize from `[ComparisonRecord]` and `[PitchMatchingRecord]` at startup
  - [x] 4.3 Implement metric extraction: `centOffset` (correct only) for discrimination, `abs(userCentError)` for matching
  - [x] 4.4 Implement cold-start detection (< 20 records per mode)
  - [x] 4.5 Implement trend computation (improving/stable/declining) for modes with 100+ records
  - [x] 4.6 Conform to `ComparisonObserver` for incremental discrimination updates
  - [x] 4.7 Conform to `PitchMatchingObserver` for incremental matching updates
  - [x] 4.8 Conform to `Resettable` for data reset support

- [x] Task 5: Wire into composition root (AC: #4)
  - [x] 5.1 Add `@Entry var progressTimeline` to `EnvironmentKeys.swift`
  - [x] 5.2 Initialize `ProgressTimeline` in `PeachApp.swift` from fetched records
  - [x] 5.3 Add to `ComparisonSession` observers array and `PitchMatchingSession` observers array
  - [x] 5.4 Add to resettables array

## Dev Notes

### Architecture & Design Decisions

**This story creates the data pipeline only.** No UI changes. `ThresholdTimeline` and `TrendAnalyzer` remain in place — they will be removed in story 38.3 when the Profile Screen is redesigned.

**`ProgressTimeline` is a single class serving all four training modes.** It holds per-mode state internally, keyed by a mode identifier. Each mode's behavior is parameterized by `TrainingModeConfig` — no mode-specific subclasses or protocol conformers needed.

**EWMA formula:** For each new bucket value `x` at time `t`, with previous EWMA at time `t_prev`:
```
alpha = 1 - exp(-ln(2) * (t - t_prev) / halflifeDays)
ewma_new = alpha * x + (1 - alpha) * ewma_prev
```
This is time-weighted EWMA where the halflife is in days. When `dt == halflife`, alpha = 0.5 (50% weight to new vs. old).

**Adaptive bucket boundaries are relative to `Date.now`**, not to the data range. Recompute buckets on each full rebuild (startup or reset). During incremental updates, a new record always falls into the most recent bucket — just update that bucket's stats and recompute EWMA for it.

**Four training modes determined by (interval, trainingType):**
- Unison discrimination: `interval == 0` on `ComparisonRecord`
- Interval discrimination: `interval != 0` on `ComparisonRecord`
- Unison matching: `interval == 0` on `PitchMatchingRecord`
- Interval matching: `interval != 0` on `PitchMatchingRecord`

### Metric Extraction Rules

- **Discrimination metric:** `abs(centOffset)` from `ComparisonRecord`, but **only where `isCorrect == true`**. Incorrect answers mean the difficulty was too high, not the user's threshold.
- **Matching metric:** `abs(userCentError)` from `PitchMatchingRecord`. All records count.
- Via `CompletedComparison`: use `completed.comparison.targetNote.offset.magnitude` for cent value, `completed.isCorrect` for filtering.
- Via `CompletedPitchMatching`: use `abs(result.userCentError)` for cent value.

### Existing Code Patterns to Follow

**Observer pattern (from `ThresholdTimeline`):**
```swift
extension ProgressTimeline: ComparisonObserver {
    func comparisonCompleted(_ completed: CompletedComparison) {
        // Extract metric, determine mode, update incrementally
    }
}
extension ProgressTimeline: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        // Extract metric, determine mode, update incrementally
    }
}
```

**Initialization pattern (from `PeachApp.swift`):**
```swift
let progressTimeline = ProgressTimeline(
    comparisonRecords: comparisonRecords,
    pitchMatchingRecords: pitchMatchingRecords
)
```
Then add to observers arrays:
```swift
let comparisonObservers: [ComparisonObserver] = [dataStore, profile, hapticManager, trendAnalyzer, thresholdTimeline, progressTimeline]
let pitchMatchingObservers: [PitchMatchingObserver] = [dataStore, profile, progressTimeline]
```

**Environment key pattern (from `EnvironmentKeys.swift`):**
```swift
@Entry var progressTimeline = ProgressTimeline()
```

### TrainingModeConfig Parameters

| Parameter | Unison Disc. | Interval Disc. | Unison Match. | Interval Match. |
|---|---|---|---|---|
| optimalBaseline | 8.0 cents | 12.0 cents | 5.0 cents | 8.0 cents |
| ewmaHalflifeDays | 7.0 | 7.0 | 7.0 | 7.0 |
| coldStartThreshold | 20 | 20 | 20 | 20 |
| trendThreshold | 100 | 100 | 100 | 100 |
| unitLabel | "cents" | "cents" | "cents" | "cents" |

### Cold Start Stages

| Records | State | Trend Available |
|---|---|---|
| 0 | `.noData` | No |
| 1-19 | `.coldStart(recordsNeeded:)` | No |
| 20-99 | `.active` | No |
| 100+ | `.active` | Yes (improving/stable/declining) |

### Bucket Assignment Algorithm

```
let age = Date.now.timeIntervalSince(record.timestamp)
if age < 24 * 3600:       → per-session bucket (group by session proximity, e.g., 30-min gap)
elif age < 7 * 86400:     → per-day bucket (Calendar.current.startOfDay)
elif age < 30 * 86400:    → per-week bucket (Calendar.current.dateInterval(of: .weekOfYear))
else:                      → per-month bucket (Calendar.current.dateInterval(of: .month))
```

"Per-session" means grouping records with timestamps within 30 minutes of each other into one bucket (a training session is typically 5-15 minutes).

### Dependencies & Constraints

- **No `import SwiftUI`** — this is a `Core/Profile/` file. Framework-free.
- **No `import Charts`** — chart rendering is story 38.3.
- **No `import SwiftData`** — data comes through `TrainingDataStore` at startup and observers during training.
- **`@Observable` is from `Observation` framework** — imported via Foundation, no explicit import needed.
- **Value types for data structures** — `TrainingModeConfig`, `TimeBucket`, bucket data points are all structs.
- **`ProgressTimeline` is a `final class`** — needed for `@Observable` and reference semantics.

### What NOT To Do

- Do NOT remove `ThresholdTimeline` or `TrendAnalyzer` yet — story 38.3 handles deprecation when Profile Screen is redesigned.
- Do NOT add UI code — this is data pipeline only.
- Do NOT use Combine (`PassthroughSubject`, `sink`).
- Do NOT create a protocol for `ProgressTimeline` yet — YAGNI until needed.
- Do NOT duplicate EWMA/bucket logic per mode — parameterize via `TrainingModeConfig`.
- Do NOT use `@testable import` — test through the class's interface.

### Project Structure Notes

- New file: `peach/Core/Profile/TrainingModeConfig.swift`
- New file: `peach/Core/Profile/ProgressTimeline.swift`
- Modified: `peach/App/EnvironmentKeys.swift` (add `@Entry var progressTimeline`)
- Modified: `peach/App/PeachApp.swift` (initialize and wire `ProgressTimeline`)
- New test file: `PeachTests/Core/Profile/TrainingModeConfigTests.swift`
- New test file: `PeachTests/Core/Profile/ProgressTimelineTests.swift`
- Alignment: follows existing `Core/Profile/` directory structure (alongside `PerceptualProfile.swift`, `ThresholdTimeline.swift`, `TrendAnalyzer.swift`)

### References

- [Source: docs/implementation-artifacts/38-1-brainstorm-and-design-profile-visualization.md] — Approved UX concept with EWMA algorithm, adaptive buckets, baselines, cold start stages
- [Source: docs/planning-artifacts/epics.md#Epic 38] — Story acceptance criteria and technical hints
- [Source: peach/Core/Profile/ThresholdTimeline.swift] — Existing timeline pattern (observer, rebuild, reset, aggregation)
- [Source: peach/Core/Profile/TrendAnalyzer.swift] — Existing trend pattern (split-half comparison, minimumRecordCount, Resettable)
- [Source: peach/Core/Profile/PerceptualProfile.swift] — Observer conformance pattern, Welford's algorithm reference
- [Source: peach/Core/Data/ComparisonRecord.swift] — Fields: centOffset, isCorrect, interval, timestamp
- [Source: peach/Core/Data/PitchMatchingRecord.swift] — Fields: userCentError, interval, timestamp
- [Source: peach/Core/Training/ComparisonObserver.swift] — `comparisonCompleted(_ completed: CompletedComparison)`
- [Source: peach/Core/Training/PitchMatchingObserver.swift] — `pitchMatchingCompleted(_ result: CompletedPitchMatching)`
- [Source: peach/App/PeachApp.swift] — Composition root wiring pattern
- [Source: peach/App/EnvironmentKeys.swift] — `@Entry` environment key pattern
- [Source: docs/project-context.md] — Coding conventions, architecture rules, testing rules

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no debugging issues.

### Completion Notes List

- Implemented `TrainingModeConfig` struct with four static configurations centralizing all tuneable parameters (AC #1)
- Implemented `ProgressTimeline` as `@Observable final class` with adaptive time bucketing: per-session (<24h, 30-min gap), per-day (<7d), per-week (<30d), per-month (beyond) (AC #2, #3)
- EWMA computation uses time-weighted formula with configurable halflife (default 7 days); standard deviation computed per bucket (AC #2, #3)
- Discrimination metric: `abs(centOffset)` on correct answers only; matching metric: `abs(userCentError)` on all records (AC #2, #3)
- Incremental updates via `ComparisonObserver` and `PitchMatchingObserver` conformances — no full rescan needed (AC #4)
- Cold-start detection: `.noData` (0 records), `.coldStart(recordsNeeded:)` (1-19), `.active` (20+); trend available at 100+ records (AC #5)
- `Resettable` conformance for data reset support
- Wired into composition root: environment key, PeachApp initialization, observer arrays, resettables array
- 25 new tests (5 TrainingModeConfig + 20 ProgressTimeline), all 995 tests pass, dependency rules clean

### Change Log

- 2026-03-05: Implemented story 38.2 — ProgressTimeline core data pipeline with EWMA, adaptive buckets, TrainingModeConfig, and composition root wiring

### File List

- Peach/Core/Profile/TrainingModeConfig.swift (new)
- Peach/Core/Profile/ProgressTimeline.swift (new)
- Peach/App/EnvironmentKeys.swift (modified — added `@Entry var progressTimeline`)
- Peach/App/PeachApp.swift (modified — initialize, wire observers, resettables, environment)
- PeachTests/Core/Profile/TrainingModeConfigTests.swift (new)
- PeachTests/Core/Profile/ProgressTimelineTests.swift (new)
