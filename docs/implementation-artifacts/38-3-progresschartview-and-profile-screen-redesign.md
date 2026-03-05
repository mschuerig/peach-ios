# Story 38.3: ProgressChartView and Profile Screen Redesign

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to see my training progress on the Profile Screen as one card per training mode with a timeline chart,
So that I can understand how my ear training is improving over time.

## Acceptance Criteria

1. **Given** the user navigates to the Profile Screen, **When** they have training data for one or more modes, **Then** they see one card per trained mode stacked vertically. Each card shows: headline EWMA value + stddev + trend indicator above the chart, and a chart with EWMA line, stddev band, and optimal baseline (dashed). Modes with no data are not shown.

2. **Given** the chart renders adaptive time buckets, **When** the user views it, **Then** recent time is shown in detail (per-session/per-day) and older time is compressed (per-week/per-month). Bucket labels show appropriate time formats ("2h ago", "Mon", "Mar 1", "Jan").

3. **Given** fewer than 20 records for a mode, **When** the card is displayed, **Then** it shows an encouraging cold-start message instead of a chart. For 0 records: "Start training to see your progress". For 1-19 records: "Keep going! X more sessions to see your trend".

4. **Given** the chart view, **When** it renders on iPhone and iPad in portrait and landscape, **Then** it adapts responsively using SwiftUI layout.

5. **Given** the chart view, **When** VoiceOver is active, **Then** all visual elements have accessibility descriptions.

6. **Given** the old profile views (`ThresholdTimelineView`, `SummaryStatisticsView`, `MatchingStatisticsView`) and old Core types (`ThresholdTimeline`, `TrendAnalyzer`), **When** the new card-based layout is complete, **Then** all old views and types are deleted, and all references are removed from the composition root, environment keys, observer arrays, resettables, and `TrainingDataTransferService`.

## Tasks / Subtasks

- [x] Task 1: Create `ProgressChartView` (AC: #1, #2, #3, #4, #5)
  - [x] 1.1 Create `Peach/Profile/ProgressChartView.swift` — a single parameterized view taking `TrainingMode`
  - [x] 1.2 Read `TrainingModeConfig` for the given mode to get displayName, unitLabel, optimalBaseline
  - [x] 1.3 Query `ProgressTimeline` via environment for `state(for:)`, `buckets(for:)`, `currentEWMA(for:)`, `trend(for:)`
  - [x] 1.4 Render headline row: current EWMA value (large), "+/-" stddev (smaller), trend arrow + label
  - [x] 1.5 Render chart using Apple Charts: `LineMark` for EWMA line, `AreaMark` for stddev band, `RuleMark` for optimal baseline (dashed)
  - [x] 1.6 Compute X-axis positions from `TimeBucket.periodStart`; format labels per bucket size (session: "2h ago", day: "Mon", week: "Mar 1", month: "Jan")
  - [x] 1.7 Handle cold-start states: `.noData` shows nothing; `.coldStart(recordsNeeded:)` shows "Keep going! X more sessions..."
  - [x] 1.8 Add VoiceOver accessibility labels for headline values, chart summary, and trend indicator
  - [x] 1.9 Support responsive layout via `@Environment(\.horizontalSizeClass)` (chart height adapts)

- [x] Task 2: Redesign `ProfileScreen` to card-based layout (AC: #1, #3, #4)
  - [x] 2.1 Replace contents of `ProfileScreen.swift` with a `ScrollView` iterating over `TrainingMode.allCases`
  - [x] 2.2 For each mode, check `progressTimeline.state(for: mode)` — skip `.noData` modes entirely
  - [x] 2.3 Render one `ProgressChartView` card per mode with visual card styling (rounded rect, padding)
  - [x] 2.4 Remove all references to `ThresholdTimelineView`, `SummaryStatisticsView`, `MatchingStatisticsView`
  - [x] 2.5 Remove `@Environment(\.perceptualProfile)`, `@Environment(\.thresholdTimeline)`, `@Environment(\.trendAnalyzer)` — use only `@Environment(\.progressTimeline)`
  - [x] 2.6 Update accessibility summary for the screen

- [x] Task 3: Delete old views and Core types (AC: #6)
  - [x] 3.1 Delete `Peach/Profile/ThresholdTimelineView.swift`
  - [x] 3.2 Delete `Peach/Profile/SummaryStatisticsView.swift`
  - [x] 3.3 Delete `Peach/Profile/MatchingStatisticsView.swift`
  - [x] 3.4 Delete `Peach/Core/Profile/ThresholdTimeline.swift`
  - [x] 3.5 Delete `Peach/Core/Profile/TrendAnalyzer.swift`
  - [x] 3.6 Delete `PeachTests/Core/Profile/ThresholdTimelineTests.swift`
  - [x] 3.7 Delete `PeachTests/Profile/TrendAnalyzerTests.swift`

- [x] Task 4: Unwire old types from composition root and services (AC: #6)
  - [x] 4.1 `Peach/App/EnvironmentKeys.swift`: Remove `@Entry var trendAnalyzer` and `@Entry var thresholdTimeline`
  - [x] 4.2 `Peach/App/PeachApp.swift`: Remove `trendAnalyzer` and `thresholdTimeline` — remove `@State` properties, remove from `init`, remove from `makeComparisonSession` parameters, remove from observers array, remove from resettables array, remove `.environment()` modifiers
  - [x] 4.3 `Peach/Core/Data/TrainingDataTransferService.swift`: Remove `trendAnalyzer` and `thresholdTimeline` properties, init parameters, and `.rebuild()` calls. Replace with `progressTimeline` — add as dependency, call `progressTimeline.rebuild(comparisonRecords:pitchMatchingRecords:)` after import
  - [x] 4.4 `Peach/Core/Training/ComparisonObserver.swift`: Cleaned up doc comments referencing old types
  - [x] 4.5 Update `TrainingDataTransferService.preview()` to use `ProgressTimeline()` instead of old types
  - [x] 4.6 Update all test files referencing old types; also deleted `SummaryStatisticsTests.swift` and `MatchingStatisticsViewTests.swift` as they tested deleted views

- [x] Task 5: Add localization and write tests (AC: #1, #3, #5)
  - [x] 5.1 Add English+German localization for 9 new UI strings (cold-start messages, trend labels, accessibility) via `bin/add-localization.py`
  - [x] 5.2 Write `PeachTests/Profile/ProgressChartViewTests.swift` — 12 tests for static helper methods (formatting, accessibility text, cold-start message, trend symbols, bucket labels)
  - [x] 5.3 Update `PeachTests/Profile/ProfileScreenLayoutTests.swift` for new card-based layout

- [x] Task 6: Verify full test suite passes
  - [x] 6.1 Run `bin/test.sh` — all 933 tests pass (dropped from 1008 due to deleted test files for removed types)

## Dev Notes

### Architecture & Design Decisions

**Single parameterized view:** `ProgressChartView` takes a `ProgressTimeline.TrainingMode` and reads everything it needs from `ProgressTimeline` (via environment) and `TrainingModeConfig` (static lookup). No mode-specific subviews.

**Data flow:** `@Environment(\.progressTimeline)` is the sole data source. The view calls:
- `progressTimeline.state(for: mode)` — determines cold-start vs. active display
- `progressTimeline.buckets(for: mode)` — provides `[TimeBucket]` for chart X/Y data
- `progressTimeline.currentEWMA(for: mode)` — headline number
- `progressTimeline.trend(for: mode)` — trend indicator (improving/stable/declining, nil if < 100 records)

**ProgressTimeline.TimeBucket fields:**
```swift
struct TimeBucket {
    let periodStart: Date
    let periodEnd: Date
    let bucketSize: BucketSize  // .session, .day, .week, .month
    let mean: Double            // Y-axis for EWMA line
    let stddev: Double          // stddev band height
    let recordCount: Int
}
```

**TrainingModeConfig static lookup:**
```swift
let config = TrainingModeConfig.config(for: mode)
// config.displayName, config.unitLabel, config.optimalBaseline
```

**Apple Charts usage (import Charts in Profile/ only):**
```swift
Chart {
    // Stddev band — AreaMark
    ForEach(buckets) { bucket in
        AreaMark(
            x: .value("Time", bucket.periodStart),
            yStart: .value("Low", bucket.mean - bucket.stddev),
            yEnd: .value("High", bucket.mean + bucket.stddev)
        )
        .foregroundStyle(.blue.opacity(0.15))
    }
    // EWMA line — LineMark
    ForEach(buckets) { bucket in
        LineMark(
            x: .value("Time", bucket.periodStart),
            y: .value("EWMA", bucket.mean)
        )
        .foregroundStyle(.blue)
    }
    // Optimal baseline — RuleMark
    RuleMark(y: .value("Baseline", config.optimalBaseline))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
        .foregroundStyle(.green.opacity(0.6))
}
```

**Trend indicators (SF Symbols):**
- Improving: `arrow.down.right` (lower cents = better) + green tint
- Stable: `arrow.right` + secondary color
- Declining: `arrow.up.right` + orange tint
- Note: "improving" means threshold is *decreasing* (user can detect smaller differences)

**Bucket label formatting by size:**
- `.session` → RelativeDateTimeFormatter short style ("2h ago")
- `.day` → "EEE" weekday abbreviation ("Mon")
- `.week` → "MMM d" ("Mar 1")
- `.month` → "MMM" ("Jan")

### Removal of Old Types — Full Blast Radius

**Files to delete (7):**
- `Peach/Profile/ThresholdTimelineView.swift`
- `Peach/Profile/SummaryStatisticsView.swift`
- `Peach/Profile/MatchingStatisticsView.swift`
- `Peach/Core/Profile/ThresholdTimeline.swift`
- `Peach/Core/Profile/TrendAnalyzer.swift`
- `PeachTests/Core/Profile/ThresholdTimelineTests.swift`
- `PeachTests/Profile/TrendAnalyzerTests.swift`

**Files to modify (references to remove):**
| File | What to remove/change |
|---|---|
| `Peach/App/EnvironmentKeys.swift` | Remove `@Entry var trendAnalyzer` and `@Entry var thresholdTimeline` |
| `Peach/App/PeachApp.swift` | Remove `@State private var trendAnalyzer/thresholdTimeline`, init code, `makeComparisonSession` params, observer array entries, resettables entries, `.environment()` modifiers |
| `Peach/Core/Data/TrainingDataTransferService.swift` | Replace `trendAnalyzer`/`thresholdTimeline` with `progressTimeline`. After import, call `progressTimeline.rebuild(comparisonRecords: allComparisons, pitchMatchingRecords: allPitchMatchings)` |
| `Peach/Profile/ProfileScreen.swift` | Rewrite to card-based layout using `ProgressTimeline` |
| `PeachTests/Core/Data/TrainingDataTransferServiceTests.swift` | Update factory to use `ProgressTimeline()` instead of old types |
| `PeachTests/Settings/SettingsTests.swift` | Remove `ThresholdTimeline`/`TrendAnalyzer` references |
| `PeachTests/Settings/TrainingDataImportActionTests.swift` | Update to use `ProgressTimeline` |
| `PeachTests/Comparison/ComparisonSessionResetTests.swift` | Remove old observer references if present |
| `PeachTests/Core/Training/ResettableTests.swift` | Remove `ThresholdTimeline`/`TrendAnalyzer` from resettable list tests |
| `PeachTests/Profile/ProfileScreenLayoutTests.swift` | Update for new card-based layout |

### ProgressTimeline.rebuild() Method

`ProgressTimeline` already has a `rebuild()` method (it resets internal state and reprocesses all records). The `TrainingDataTransferService` needs to call it after import, passing both comparison and pitch matching records. Check exact method signature in `ProgressTimeline.swift` — it may be `rebuild(comparisonRecords:pitchMatchingRecords:)` or similar. If no public rebuild method exists for both record types, the service can call `reset()` then feed records through the init path.

### Existing Code Patterns to Follow

**Card styling pattern** (used in Start Screen):
```swift
.padding()
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
```

**Environment access pattern:**
```swift
@Environment(\.progressTimeline) private var progressTimeline
```

**Trend symbol pattern** (from existing `SummaryStatisticsView`):
```swift
static func trendSymbol(_ trend: Trend) -> String {
    switch trend {
    case .improving: return "arrow.down.right"
    case .stable: return "arrow.right"
    case .declining: return "arrow.up.right"
    }
}
```

**Chart accessibility pattern:**
```swift
.accessibilityLabel("Progress chart for \(config.displayName)")
.accessibilityValue("Current: \(ewma) \(config.unitLabel), trend: \(trendLabel)")
```

### Cold Start Display Logic

```swift
switch progressTimeline.state(for: mode) {
case .noData:
    // Skip this card entirely (don't show in ProfileScreen)
case .coldStart(let recordsNeeded):
    // Show card with encouraging message instead of chart
    Text("Keep going! \(recordsNeeded) more sessions to see your trend")
case .active:
    // Show full chart with headline stats
}
```

### What NOT To Do

- Do NOT keep `ThresholdTimeline`, `TrendAnalyzer`, or any old profile views — they are fully replaced.
- Do NOT import `Charts` in any `Core/` file — chart rendering stays in `Profile/`.
- Do NOT create separate view files per training mode — use one parameterized `ProgressChartView`.
- Do NOT add `@testable import` in tests — test through public interfaces.
- Do NOT use `ObservableObject`/`@Published` or `@EnvironmentObject` — use `@Observable` and `@Environment` with `@Entry`.
- Do NOT create a protocol for `ProgressChartView` — YAGNI.
- Do NOT implement focus+context tap interaction — that's story 38.4.
- Do NOT add sparklines to Start Screen — that's story 38.5.
- Do NOT modify `PerceptualProfile`, `PianoKeyboardView`, or `PianoKeyboardLayout` — they remain.

### Project Structure Notes

- New file: `Peach/Profile/ProgressChartView.swift`
- New test file: `PeachTests/Profile/ProgressChartViewTests.swift`
- Modified: `Peach/Profile/ProfileScreen.swift` (rewritten to card-based layout)
- Modified: `Peach/App/EnvironmentKeys.swift` (remove 2 entries)
- Modified: `Peach/App/PeachApp.swift` (remove old wiring)
- Modified: `Peach/Core/Data/TrainingDataTransferService.swift` (swap old types for progressTimeline)
- Modified: 6 test files (update references)
- Deleted: 7 files (3 old views, 2 old Core types, 2 old test files)
- `PianoKeyboardView.swift` stays — it's used by other features or may be used later

### References

- [Source: docs/implementation-artifacts/38-1-brainstorm-and-design-profile-visualization.md] — Approved UX concept: card layout, headline stats, chart elements, cold start stages, bucket label formats
- [Source: docs/implementation-artifacts/38-2-progresstimeline-core-ewma-adaptive-buckets-and-trainingmodeconfig.md] — ProgressTimeline API, TrainingModeConfig params, composition root wiring
- [Source: docs/planning-artifacts/epics.md#Epic 38] — Story acceptance criteria and technical hints
- [Source: Peach/Profile/ProfileScreen.swift] — Current profile screen (to be rewritten)
- [Source: Peach/Profile/ThresholdTimelineView.swift] — Existing Apple Charts usage patterns (LineMark, AreaMark, RuleMark, ChartProxy)
- [Source: Peach/Profile/SummaryStatisticsView.swift] — Trend symbol mapping, stats formatting, accessibility helpers
- [Source: Peach/Profile/MatchingStatisticsView.swift] — Matching stats formatting (to be absorbed into card)
- [Source: Peach/Core/Profile/ProgressTimeline.swift] — Public API: state(for:), buckets(for:), currentEWMA(for:), trend(for:), TrainingMode enum, TimeBucket struct
- [Source: Peach/Core/Profile/TrainingModeConfig.swift] — displayName, unitLabel, optimalBaseline, config(for:) static method
- [Source: Peach/Core/Profile/ThresholdTimeline.swift] — To be deleted (replaced by ProgressTimeline)
- [Source: Peach/Core/Profile/TrendAnalyzer.swift] — To be deleted (absorbed into ProgressTimeline)
- [Source: Peach/Core/Data/TrainingDataTransferService.swift] — Uses trendAnalyzer.rebuild() and thresholdTimeline.rebuild() — must be updated
- [Source: Peach/App/PeachApp.swift] — Composition root: observer arrays, resettables, environment injection
- [Source: Peach/App/EnvironmentKeys.swift] — @Entry definitions to clean up
- [Source: docs/project-context.md] — Coding conventions, architecture rules, testing rules, localization workflow

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Moved `Trend` enum from `TrendAnalyzer.swift` to `ProgressTimeline.swift` since `ProgressTimeline` already used it
- Made `ProgressTimeline.rebuild(comparisonRecords:pitchMatchingRecords:)` internal (was private) so `TrainingDataTransferService` can call it after import
- Deleted `SummaryStatisticsTests.swift` and `MatchingStatisticsViewTests.swift` (not listed in story) because they tested the deleted `SummaryStatisticsView` and `MatchingStatisticsView`

### Completion Notes List

- Created `ProgressChartView` as a single parameterized view using Apple Charts (LineMark, AreaMark, RuleMark)
- Redesigned `ProfileScreen` to card-based ScrollView layout using `ProgressTimeline` as sole data source
- Deleted 9 files total (7 source + 2 extra test files for deleted views)
- Updated composition root: removed `TrendAnalyzer` and `ThresholdTimeline` from observers, resettables, environment
- Updated `TrainingDataTransferService` to use `ProgressTimeline` for post-import rebuild
- Updated 6 test files to reference `ProgressTimeline` instead of old types
- Added 9 German translations for new UI strings
- All 933 tests pass, all dependency rules pass

### File List

New files:
- `Peach/Profile/ProgressChartView.swift`
- `PeachTests/Profile/ProgressChartViewTests.swift`

Modified files:
- `Peach/Profile/ProfileScreen.swift`
- `Peach/App/EnvironmentKeys.swift`
- `Peach/App/PeachApp.swift`
- `Peach/Core/Data/TrainingDataTransferService.swift`
- `Peach/Core/Profile/ProgressTimeline.swift`
- `Peach/Core/Training/ComparisonObserver.swift`
- `Peach/Localizable.xcstrings`
- `PeachTests/Core/Data/TrainingDataTransferServiceTests.swift`
- `PeachTests/Settings/SettingsTests.swift`
- `PeachTests/Settings/TrainingDataImportActionTests.swift`
- `PeachTests/Comparison/ComparisonSessionResetTests.swift`
- `PeachTests/Core/Training/ResettableTests.swift`
- `PeachTests/Profile/ProfileScreenLayoutTests.swift`
- `docs/implementation-artifacts/sprint-status.yaml`

Deleted files:
- `Peach/Profile/ThresholdTimelineView.swift`
- `Peach/Profile/SummaryStatisticsView.swift`
- `Peach/Profile/MatchingStatisticsView.swift`
- `Peach/Core/Profile/ThresholdTimeline.swift`
- `Peach/Core/Profile/TrendAnalyzer.swift`
- `PeachTests/Core/Profile/ThresholdTimelineTests.swift`
- `PeachTests/Profile/TrendAnalyzerTests.swift`
- `PeachTests/Profile/SummaryStatisticsTests.swift`
- `PeachTests/Profile/MatchingStatisticsViewTests.swift`

## Change Log

- 2026-03-05: Implemented story 38.3 — Created ProgressChartView with Apple Charts, redesigned ProfileScreen to card-based layout, deleted old profile views and types (ThresholdTimeline, TrendAnalyzer, ThresholdTimelineView, SummaryStatisticsView, MatchingStatisticsView), unwired old types from composition root and services, added German translations, 933 tests passing
