# Story 38.6: Fix Trend Arrow — Stddev-Based Computation Including Wrong Answers

Status: ready

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want the trend arrow to reflect my actual performance including wrong answers,
So that I get honest feedback when my ear training is declining.

## Acceptance Criteria

1. **Given** a comparison training session, **When** the user answers incorrectly multiple times in a row (producing centOffset values outside 1 stddev of their running mean), **Then** the trend arrow shows declining (arrow.up.right, orange).

2. **Given** any training mode with 2+ records, **When** the latest answer's metric value is above `runningMean + runningStddev`, **Then** `trend(for:)` returns `.declining`.

3. **Given** any training mode with 2+ records, **When** the latest answer's metric value is between EWMA (inclusive) and `runningMean + runningStddev` (inclusive), **Then** `trend(for:)` returns `.stable`.

4. **Given** any training mode with 2+ records, **When** the latest answer's metric value is below the current EWMA, **Then** `trend(for:)` returns `.improving`.

5. **Given** any training mode with fewer than 2 records, **When** `trend(for:)` is called, **Then** it returns `nil`.

6. **Given** a pitch matching session, **When** the user's `abs(userCentError)` is above `runningMean + runningStddev`, **Then** the trend shows `.declining` — same algorithm as comparison mode.

7. **Given** comparison records including incorrect answers, **When** the timeline is rebuilt, **Then** incorrect answers contribute their `centOffset` as metric values (not filtered out).

## Tasks / Subtasks

- [ ] Task 1: Remove `trendChangeThreshold` from `TrainingModeConfig` (AC: #2-4)
  - [ ] 1.1 Remove `let trendChangeThreshold: Double` property from `TrainingModeConfig` struct
  - [ ] 1.2 Remove `trendChangeThreshold` value from all 4 static instances (`.unisonComparison`, `.intervalComparison`, `.unisonMatching`, `.intervalMatching`)
  - [ ] 1.3 Update `PeachTests/Core/Profile/TrainingModeConfigTests.swift` — remove any assertions referencing `trendChangeThreshold`

- [ ] Task 2: Add running stddev fields to `ModeState` (AC: #2-4)
  - [ ] 2.1 Add fields to `ModeState` struct: `var runningMean: Double = 0`, `var runningM2: Double = 0`
  - [ ] 2.2 Add computed property: `var runningStddev: Double? { recordCount >= 2 ? sqrt(runningM2 / Double(recordCount)) : nil }`
  - [ ] 2.3 Update `ModeState.addPoint` — after incrementing `recordCount`, apply Welford's update:
    ```swift
    let delta = point.value - runningMean
    runningMean += delta / Double(recordCount)
    let delta2 = point.value - runningMean
    runningM2 += delta * delta2
    ```
  - [ ] 2.4 Update `buildModeState` — compute running mean and M2 from all sorted metrics in a loop (replace `state.recordCount = sorted.count` with incremental accumulation)

- [ ] Task 3: Remove `isCorrect` filter from comparison metric extraction (AC: #1, #7)
  - [ ] 3.1 In `TrainingMode.extractMetrics` — change `.unisonComparison` filter from `$0.isCorrect && $0.interval == 0` to `$0.interval == 0`
  - [ ] 3.2 In `TrainingMode.extractMetrics` — change `.intervalComparison` filter from `$0.isCorrect && $0.interval != 0` to `$0.interval != 0`
  - [ ] 3.3 In `TrainingMode.metric(from completed: CompletedComparison)` — remove `guard completed.isCorrect else { return nil }`

- [ ] Task 4: Replace `recomputeTrend` with stddev-based algorithm (AC: #2, #3, #4, #5, #6)
  - [ ] 4.1 Replace the body of `ModeState.recomputeTrend(config:)` with:
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

- [ ] Task 5: Update and add tests (AC: #1-7)
  - [ ] 5.1 Invert `incorrectRecordsExcluded` test → rename to `incorrectRecordsIncludedInMetrics`, assert `totalRecords == 1`
  - [ ] 5.2 Update `unisonComparisonMetric` test — assert `totalRecords == 2` (both correct and incorrect contribute)
  - [ ] 5.3 Rewrite `improvingTrend` — records where latest value < EWMA and within 1 stddev → `.improving`
  - [ ] 5.4 Rewrite `decliningTrend` — records where latest value > runningMean + stddev → `.declining`
  - [ ] 5.5 Rewrite `stableTrend` — consistent records where latest is within 1 stddev and >= EWMA → `.stable`
  - [ ] 5.6 Add `decliningTrendFromWrongAnswers` — correct records at low centOffset, then wrong answer (high centOffset) via `comparisonCompleted` → `.declining`
  - [ ] 5.7 Add `pitchMatchingDecliningWhenOutsideStddev` — low-error records, then one high-error record → `.declining`
  - [ ] 5.8 Keep `noTrendWithSingleRecord` and `trendWithTwoRecords` unchanged
  - [ ] 5.9 Run full test suite: `bin/test.sh`

## Dev Notes

### Root Cause Analysis

The trend arrow bug has two contributing factors:

1. **Wrong answers are invisible to metrics.** `TrainingMode.extractMetrics` filters `$0.isCorrect` for comparison modes (line 40-41 of `ProgressTimeline.swift`). `TrainingMode.metric(from:)` has `guard completed.isCorrect else { return nil }` (line 56). Wrong answers never enter `allMetrics`.

2. **Half-split trend algorithm is insensitive.** Even if wrong answers were included, the current algorithm splits all metrics into earlier/later halves and compares means. This requires sustained change across many data points to shift — a few wrong answers wouldn't budge it.

### New Algorithm: Stddev + EWMA Thresholds

| Latest value vs... | Trend |
|---|---|
| `> runningMean + runningStddev` (outlier, worse than usual) | **Declining** |
| `>= ewma` (within normal range, above smoothed average) | **Stable** |
| `< ewma` (within normal range, below smoothed average) | **Improving** |

**Why this works:**
- Lower metric values = better (smaller cent offset = finer hearing)
- EWMA is time-weighted — captures "where you are now"
- Running stddev is unweighted — captures "what's normal for you overall"
- A wrong answer at a hard difficulty naturally has a large centOffset → pushes above stddev → declining

### Edge Cases

- **stddev = 0** (all values identical): `mean + 0 = mean`. Any value above mean → declining. Any below → improving. Value at mean depends on EWMA. This is correct — zero variance means any deviation is notable.
- **2 records**: Minimum for trend. Stddev is computed. Works but noisy — acceptable since the UI already shows nil for < 2 records.
- **EWMA vs running mean divergence**: After improvement, EWMA < running mean (recent data pulls it down). This makes "improving" easier to achieve, which is correct — rewarding recent good performance.

### Files to Modify

| File | Change |
|---|---|
| `Peach/Core/Profile/TrainingModeConfig.swift` | Remove `trendChangeThreshold` property and values |
| `Peach/Core/Profile/ProgressTimeline.swift` | Add running stddev to `ModeState`, remove `isCorrect` filters, replace `recomputeTrend` |
| `PeachTests/Core/Profile/ProgressTimelineTests.swift` | Invert/rewrite 5 tests, add 2 new tests |
| `PeachTests/Core/Profile/TrainingModeConfigTests.swift` | Remove `trendChangeThreshold` assertions |

### What NOT To Do

- Do NOT modify `TrainingStatsView.swift` or `ProgressSparklineView.swift` — they read from `ProgressTimeline` and render; the fix is in the data layer
- Do NOT modify `ComparisonScreen.swift` or `PitchMatchingScreen.swift` — trend display code is unchanged
- Do NOT add new fields to `TrainingModeConfig` — the stddev boundary replaces the configured threshold
- Do NOT change EWMA computation or bucket assignment — only trend algorithm changes
- Do NOT change `CompletedComparison` or `ComparisonRecord` models

### References

- Tech spec: `docs/implementation-artifacts/tech-spec-fix-trend-stddev.md`
- [Source: Peach/Core/Profile/ProgressTimeline.swift] — `ModeState`, `recomputeTrend`, `extractMetrics`, `metric(from:)`
- [Source: Peach/Core/Profile/TrainingModeConfig.swift] — `trendChangeThreshold` to remove
- [Source: PeachTests/Core/Profile/ProgressTimelineTests.swift] — Tests to update
