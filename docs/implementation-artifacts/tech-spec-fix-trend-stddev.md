---
title: 'Fix trend arrow to reflect wrong answers using stddev-based computation'
slug: 'fix-trend-stddev'
created: '2026-03-05'
status: 'implementation-complete'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'SwiftUI', '@Observable', 'Swift Testing']
files_to_modify:
  - 'Peach/Core/Profile/ProgressTimeline.swift'
  - 'Peach/Core/Profile/TrainingModeConfig.swift'
  - 'PeachTests/Core/Profile/ProgressTimelineTests.swift'
  - 'PeachTests/Core/Profile/TrainingModeConfigTests.swift'
code_patterns:
  - '@Observable final class with private ModeState struct'
  - 'EWMA smoothing with configurable half-life'
  - 'ComparisonObserver/PitchMatchingObserver incremental updates'
  - 'Welford online algorithm for running variance'
test_patterns:
  - 'Swift Testing with @Test/@Suite/#expect'
  - 'Struct-based test suites with factory methods'
  - 'async test functions, no setUp/tearDown'
---

# Tech-Spec: Fix trend arrow to reflect wrong answers using stddev-based computation

**Created:** 2026-03-05

## Overview

### Problem Statement

The trend arrow in TrainingStatsView and ProgressSparklineView always shows "improving" (or remains stale) even when the user gives multiple wrong answers in a row. This is because `TrainingMode.extractMetrics` and `TrainingMode.metric(from:)` filter on `isCorrect` — wrong answers are never added to `allMetrics` and have zero effect on the trend computation.

The current `recomputeTrend` algorithm splits all (correct-only) metrics into earlier/later halves and compares their means. Since wrong answers are invisible, the trend never reflects declining performance.

### Solution

Replace the half-split trend algorithm with a per-answer stddev-based approach that applies to all training modes:

| Condition | Trend |
|---|---|
| Answer outside 1 stddev of running mean (worse than usual) | **Declining** |
| Answer inside 1 stddev but >= EWMA | **Stable** |
| Answer inside 1 stddev and < EWMA | **Improving** |

Key changes:
1. Include wrong comparison answers in metrics (their actual centOffset value)
2. Replace the earlier/later half-split trend algorithm with stddev + EWMA thresholds
3. Apply consistently across all training modes

### Scope

**In Scope:**
- Trend computation logic in `ProgressTimeline.recomputeTrend`
- Metric extraction to include wrong answers for comparison modes
- Remove dead `trendChangeThreshold` from `TrainingModeConfig`
- Unit tests for the new trend logic

**Out of Scope:**
- EWMA formula/half-life changes
- Bucket assignment or sparkline rendering
- Chart UI or color changes
- Profile screen redesign

## Context for Development

### Codebase Patterns

- `ProgressTimeline` is `@Observable final class` with private `ModeState` struct
- `ModeState` tracks `allMetrics: [MetricPoint]`, `buckets: [TimeBucket]`, `ewma: Double?`, `computedTrend: Trend?`, `recordCount: Int`
- `recomputeTrend` is called after every `addPoint` (incremental) and during `rebuild` (bulk via `buildModeState`)
- `TrainingMode.extractMetrics` provides bulk metrics from `[ComparisonRecord]`/`[PitchMatchingRecord]`; `TrainingMode.metric(from:)` provides incremental metrics from observer callbacks
- For comparison modes, both currently filter `isCorrect` — wrong answers are discarded
- For pitch matching modes, all answers contribute `abs(userCentError)` — no `isCorrect` filter
- Welford's online algorithm is already used in `ModeState.updateBucket` for per-bucket stddev
- EWMA is computed per mode via `recomputeEWMA` using time-weighted exponential smoothing

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/Core/Profile/ProgressTimeline.swift:273` | `recomputeTrend` — the algorithm to replace |
| `Peach/Core/Profile/ProgressTimeline.swift:39-41` | `extractMetrics` — `isCorrect` filter for comparison modes |
| `Peach/Core/Profile/ProgressTimeline.swift:55-67` | `metric(from: CompletedComparison)` — `guard isCorrect` gate |
| `Peach/Core/Profile/ProgressTimeline.swift:209` | `ModeState` struct — add running stddev fields here |
| `Peach/Core/Profile/ProgressTimeline.swift:243` | `updateBucket` — existing Welford's algorithm to reference |
| `Peach/Core/Profile/TrainingModeConfig.swift:23` | `trendChangeThreshold` — field to remove |
| `PeachTests/Core/Profile/ProgressTimelineTests.swift:349` | `incorrectRecordsExcluded` test — must be inverted |
| `PeachTests/Core/Profile/ProgressTimelineTests.swift:381` | Trend tests section — must be rewritten |

### Technical Decisions

1. **Wrong comparison answers contribute their actual `centOffset`.** The user was tested at X cents and got it wrong, so their effective threshold is at least X cents. Wrong answers tend to have larger centOffset values (harder difficulties), so they naturally push metrics upward = worse. `extractMetrics` drops the `isCorrect` filter; `metric(from:)` drops the `guard completed.isCorrect` gate.

2. **Global running stddev on `ModeState` via Welford's algorithm.** Add `runningMean: Double` and `runningM2: Double` fields. Maintain incrementally in `addPoint` and compute in bulk in `buildModeState`. Computed property `runningStddev` derives `sqrt(runningM2 / recordCount)`. Same pattern as existing `updateBucket`.

3. **Trend evaluates `allMetrics.last` against running stddev and EWMA.** The new algorithm is: `value > runningMean + stddev` → declining; `value >= ewma` → stable; `value < ewma` → improving. This makes trend responsive to individual answers.

4. **Remove `trendChangeThreshold` from `TrainingModeConfig`.** Dead code after the algorithm change. Clean removal from struct definition and all 4 static instances.

5. **`CompletedComparison.isCorrect` is a computed property** — no model changes needed. The filter removal is purely in `TrainingMode`'s metric extraction methods.

6. **Minimum 2 records for trend** — unchanged. With 0-1 records, stddev is meaningless and `trend(for:)` returns `nil`.

## Implementation Plan

### Tasks

- [x] Task 1: Remove `trendChangeThreshold` from `TrainingModeConfig`
  - File: `Peach/Core/Profile/TrainingModeConfig.swift`
  - Action: Remove `let trendChangeThreshold: Double` property and its value from all 4 static instances (`.unisonComparison`, `.intervalComparison`, `.unisonMatching`, `.intervalMatching`)
  - File: `PeachTests/Core/Profile/TrainingModeConfigTests.swift`
  - Action: Remove any test assertions that reference `trendChangeThreshold`

- [x] Task 2: Add running stddev fields to `ModeState`
  - File: `Peach/Core/Profile/ProgressTimeline.swift`
  - Action in `ModeState` struct (line ~209):
    - Add fields: `var runningMean: Double = 0`, `var runningM2: Double = 0`
    - Add computed property: `var runningStddev: Double? { recordCount >= 2 ? sqrt(runningM2 / Double(recordCount)) : nil }`
  - Action in `ModeState.addPoint` (line ~216):
    - After incrementing `recordCount`, update running stats:
      ```
      let delta = point.value - runningMean
      runningMean += delta / Double(recordCount)
      let delta2 = point.value - runningMean
      runningM2 += delta * delta2
      ```
  - Action in `buildModeState` (line ~303):
    - After setting `state.allMetrics = sorted`, compute running mean and M2 from all metrics:
      ```
      for metric in sorted {
          state.recordCount += 1  // (move recordCount increment here)
          let delta = metric.value - state.runningMean
          state.runningMean += delta / Double(state.recordCount)
          let delta2 = metric.value - state.runningMean
          state.runningM2 += delta * delta2
      }
      ```
    - Remove the existing `state.recordCount = sorted.count` line (now accumulated in loop)

- [x] Task 3: Remove `isCorrect` filter from comparison metric extraction
  - File: `Peach/Core/Profile/ProgressTimeline.swift`
  - Action in `TrainingMode.extractMetrics` (line ~40-41):
    - Change `.unisonComparison` from `comparisonRecords.filter { $0.isCorrect && $0.interval == 0 }` to `comparisonRecords.filter { $0.interval == 0 }`
    - Change `.intervalComparison` from `comparisonRecords.filter { $0.isCorrect && $0.interval != 0 }` to `comparisonRecords.filter { $0.interval != 0 }`
  - Action in `TrainingMode.metric(from completed: CompletedComparison)` (line ~55-56):
    - Remove `guard completed.isCorrect else { return nil }`

- [x] Task 4: Replace `recomputeTrend` with stddev-based algorithm
  - File: `Peach/Core/Profile/ProgressTimeline.swift`
  - Action: Replace the body of `recomputeTrend(config:)` (line ~273) with:
    ```swift
    mutating func recomputeTrend(config: TrainingModeConfig) {
        guard recordCount >= 2,
              let stddev = runningStddev,
              let ewma = ewma,
              let latest = allMetrics.last else {
            computedTrend = nil
            return
        }

        let value = latest.value
        if value > runningMean + stddev {
            computedTrend = .declining
        } else if value >= ewma {
            computedTrend = .stable
        } else {
            computedTrend = .improving
        }
    }
    ```
  - Note: `config` parameter is now unused but kept for API compatibility with `addPoint` and `buildModeState` call sites. Alternatively, remove the parameter — both callers can be updated.

- [x] Task 5: Update and add tests
  - File: `PeachTests/Core/Profile/ProgressTimelineTests.swift`
  - Action — **Invert** `incorrectRecordsExcluded` (line ~349):
    - Rename to `incorrectRecordsIncludedInMetrics`
    - Assert `totalRecords == 1` (wrong answer now contributes a metric point)
  - Action — **Rewrite** `improvingTrend` (line ~384):
    - Create records where the latest value is below EWMA and within 1 stddev
    - Example: many records at 20.0 cents, then latest at 10.0 cents (below EWMA, within stddev)
    - Assert `trend == .improving`
  - Action — **Rewrite** `decliningTrend` (line ~399):
    - Create records where the latest value is outside 1 stddev above the mean
    - Example: many records at 10.0 cents with low variance, then latest at 50.0 cents
    - Assert `trend == .declining`
  - Action — **Rewrite** `stableTrend` (line ~414):
    - Create records where the latest value is within 1 stddev but >= EWMA
    - Example: consistent records at 15.0 cents, latest at 15.0 cents
    - Assert `trend == .stable`
  - Action — **Add** `decliningTrendFromWrongAnswers`:
    - Create a timeline with correct comparison records at low centOffset
    - Add a wrong comparison answer (high centOffset) incrementally via `comparisonCompleted`
    - Assert trend becomes `.declining`
  - Action — **Add** `pitchMatchingDecliningWhenOutsideStddev`:
    - Create pitch matching records with low error, then one with high error
    - Assert trend becomes `.declining`
  - Action — **Keep unchanged**: `noTrendWithSingleRecord`, `trendWithTwoRecords`
  - Action — **Update** `unisonComparisonMetric` (line ~87):
    - Remove comment "Only 1 correct record contributes to metric"
    - Assert `totalRecords == 2` (both correct and incorrect now contribute)

### Acceptance Criteria

1. **Given** a comparison training session, **When** the user answers incorrectly (producing a centOffset outside 1 stddev of their running mean), **Then** the trend arrow shows declining (arrow.up.right, orange).

2. **Given** any training mode with 2+ records, **When** the latest answer's metric value is above `runningMean + runningStddev`, **Then** `trend(for:)` returns `.declining`.

3. **Given** any training mode with 2+ records, **When** the latest answer's metric value is between EWMA (inclusive) and `runningMean + runningStddev` (inclusive), **Then** `trend(for:)` returns `.stable`.

4. **Given** any training mode with 2+ records, **When** the latest answer's metric value is below the current EWMA, **Then** `trend(for:)` returns `.improving`.

5. **Given** any training mode with fewer than 2 records, **When** `trend(for:)` is called, **Then** it returns `nil`.

6. **Given** a pitch matching session, **When** the user's `abs(userCentError)` is above `runningMean + runningStddev`, **Then** the trend shows `.declining` — same algorithm as comparison mode.

7. **Given** comparison records including incorrect answers, **When** the timeline is rebuilt, **Then** incorrect answers contribute their `centOffset` as metric values (not filtered out).

## Additional Context

### Dependencies

None — all changes are within existing files and patterns. No new files, no new imports.

### Testing Strategy

- **TDD workflow**: Write failing tests for the new stddev-based trend rules first, then implement
- **Update existing tests**: 6 tests need modification (`incorrectRecordsExcluded`, `unisonComparisonMetric`, `improvingTrend`, `decliningTrend`, `stableTrend`, plus any `TrainingModeConfig` tests referencing `trendChangeThreshold`)
- **Add new tests**: Wrong-answer declining scenario, pitch matching declining scenario
- **Test both paths**: Bulk `rebuild` and incremental `addPoint`/`comparisonCompleted`
- **Edge cases**: Exactly on stddev boundary (= stable, not declining), exactly at EWMA (= stable, not improving), 2 records (minimum for trend), uniform values (stddev = 0 → only improving or stable possible)
- **Run full suite**: `bin/test.sh` before commit

### Notes

- **Edge case: stddev = 0** (all values identical). When stddev is 0, `runningMean + 0 = runningMean`. If the latest value equals the mean (and EWMA ≈ mean), the result is stable. Any value above the mean is declining. Any value below is improving. This is correct behavior — with zero variance, any deviation is significant.
- **EWMA vs running mean**: EWMA is time-weighted (recent data matters more via half-life), running mean is unweighted. A user who improved recently will have EWMA < running mean, making it easier to show "improving" (latest < EWMA). This is intentional — it rewards recent improvement.
- **Metric semantics**: Lower values = better (smaller cent offset = finer hearing). "Outside 1 stddev" means above `mean + stddev` only (one-tailed), not below, because lower values are always good.
