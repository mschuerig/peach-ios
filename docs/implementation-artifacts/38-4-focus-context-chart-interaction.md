# Story 38.4: Focus+Context Chart Interaction

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to tap a time region on my progress chart to see more detail,
So that I can explore specific periods of my training history.

## Acceptance Criteria

1. **Given** the progress chart on the Profile Screen, **When** the user taps a time bucket region, **Then** that bucket expands into finer granularity (month -> weeks, week -> days) **And** surrounding buckets compress proportionally to maintain chart width **And** the expansion animates smoothly.

2. **Given** an expanded bucket region, **When** the user taps it again or taps a different region, **Then** the expanded region collapses back to its original bucket size **And** the collapse animates smoothly.

3. **Given** the focus+context interaction, **When** used with VoiceOver, **Then** the interaction is accessible (tap targets have labels, expanded state is announced).

## Tasks / Subtasks

- [ ] Task 1: Add sub-bucket query API to `ProgressTimeline` (AC: #1)
  - [ ] 1.1 In `ModeState`, replace `allValues: [Double]` with `allMetrics: [MetricPoint]` (retaining `timestamp: Date` alongside `value: Double`); derive `[Double]` for trend computation via `allMetrics.map(\.value)`
  - [ ] 1.2 Add `func subBuckets(for mode: TrainingMode, expanding bucket: TimeBucket) -> [TimeBucket]` — filters `allMetrics` to `bucket.periodStart..<bucket.periodEnd`, then groups at one `BucketSize` level finer (`.month` -> `.week`, `.week` -> `.day`, `.day` -> `.session` using `TrainingModeConfig.sessionGap`)
  - [ ] 1.3 Return empty array for `.session` buckets (finest granularity, cannot expand)
  - [ ] 1.4 Write tests for `subBuckets(for:expanding:)` covering all `BucketSize` granularity transitions

- [ ] Task 2: Add expansion state to `ProgressChartView` (AC: #1, #2)
  - [ ] 2.1 Add `@State private var expandedBucketIndex: Int?` to track which bucket (if any) is currently expanded
  - [ ] 2.2 Compute `displayBuckets: [TimeBucket]` from the original buckets: if an index is expanded, replace that single bucket with its sub-buckets from `ProgressTimeline.subBuckets(for:expanding:)`; keep all other buckets unchanged
  - [ ] 2.3 Animate the bucket transition with `.animation(.easeInOut(duration: 0.3), value: expandedBucketIndex)`

- [ ] Task 3: Add tap gesture to chart (AC: #1, #2)
  - [ ] 3.1 Add `.chartOverlay` with `GeometryReader` + `ChartProxy` to detect taps
  - [ ] 3.2 On tap: use `chart.value(atX: location.x)` to find the tapped `Date`, then find the nearest bucket by `periodStart`
  - [ ] 3.3 If tapped bucket is already expanded -> collapse (set `expandedBucketIndex = nil`)
  - [ ] 3.4 If tapped bucket is a different bucket -> expand it (replace previous expansion)
  - [ ] 3.5 If tapped bucket is `.session` granularity -> no-op (cannot expand further)

- [ ] Task 4: Accessibility for expanded state (AC: #3)
  - [ ] 4.1 Update chart accessibility label to announce when a region is expanded: "Expanded view of [bucket label]"
  - [ ] 4.2 Add accessibility action "Collapse expanded region" when a bucket is expanded
  - [ ] 4.3 Add localization strings for expanded state announcements (English + German)

- [ ] Task 5: Write tests (AC: #1, #2, #3)
  - [ ] 5.1 `ProgressTimelineTests`: test `subBuckets` returns finer granularity for month/week/day buckets
  - [ ] 5.2 `ProgressTimelineTests`: test `subBuckets` returns empty for session buckets (finest level)
  - [ ] 5.3 `ProgressTimelineTests`: test sub-bucket metrics are consistent (sum of sub-bucket recordCounts equals parent bucket recordCount)
  - [ ] 5.4 `ProgressChartViewTests`: test `displayBuckets` computation with no expansion, with one expanded bucket, and with toggle behavior (expand -> collapse)

- [ ] Task 6: Verify full test suite passes
  - [ ] 6.1 Run `bin/test.sh` -- all tests pass

## Dev Notes

### Architecture & Design Decisions

**Core change: ProgressTimeline needs to store raw metric points with timestamps.** Currently `ModeState.allValues` stores only `[Double]` (values without timestamps). To support sub-bucket queries, the sorted `MetricPoint` array (`timestamp: Date`, `value: Double`) must be retained in `ModeState`. This is a minimal change -- replace `allValues: [Double]` with `allMetrics: [MetricPoint]` and derive the `[Double]` array from it for trend computation. Note: `MetricPoint.value` stays `Double` (not `Cents`) -- this matches the existing `TimeBucket.mean`/`TimeBucket.stddev` types and the `TrainingMode.extractMetrics()` return type throughout `ProgressTimeline`.

**Sub-bucket query is a pure computation on stored metrics.** The `subBuckets(for:expanding:)` method filters `allMetrics` to the bucket's `periodStart..<periodEnd` range, then re-buckets using `BucketSize` one level finer. The `assignSubBuckets` helper reuses the same grouping logic as `assignBuckets` but parameterized by parent `BucketSize` instead of age-relative thresholds. Session grouping uses `TrainingModeConfig.sessionGap` (`Duration` type, converted via `.timeIntervalSeconds`).

**Expansion state lives in the view, not the model.** `ProgressTimeline` is the data source; which bucket is visually expanded is purely UI state. Use `@State private var expandedBucketIndex: Int?` in `ProgressChartView`.

### ProgressTimeline Changes (Core/Profile/ProgressTimeline.swift)

**Step 1: Replace `allValues` with `allMetrics`**

```swift
// In ModeState, change:
var allValues: [Double] = []
// To:
var allMetrics: [MetricPoint] = []

// Derive allValues where needed for trend:
let allValues = allMetrics.map(\.value)
```

Update `addPoint` to append the full `MetricPoint` instead of just `point.value`. Update `buildModeState` similarly.

**Step 2: Make `MetricPoint` accessible**

`MetricPoint` is currently `private` inside `ProgressTimeline`. Either:
- Keep it private and use `(timestamp: Date, value: Double)` tuples in the public API, or
- Promote to internal (simpler, since single-module app)

Recommendation: Keep `MetricPoint` private. The `subBuckets` method takes a `TimeBucket` and returns `[TimeBucket]` -- the metric points never leak.

**Step 3: Add subBuckets method**

```swift
func subBuckets(for mode: TrainingMode, expanding bucket: TimeBucket) -> [TimeBucket] {
    guard bucket.bucketSize != .session else { return [] }
    guard let data = modeData[mode] else { return [] }

    let metrics = data.allMetrics.filter {
        $0.timestamp >= bucket.periodStart && $0.timestamp < bucket.periodEnd
    }
    guard !metrics.isEmpty else { return [] }

    let sessionGap = mode.config.sessionGap.timeIntervalSeconds
    return assignSubBuckets(metrics, parentSize: bucket.bucketSize, sessionGap: sessionGap)
}
```

The `assignSubBuckets` method works like `assignBuckets` but maps `BucketSize` to child granularity:
- `.month` parent -> group by `.week` (using `Calendar.dateInterval(of: .weekOfYear)`)
- `.week` parent -> group by `.day` (using `Calendar.startOfDay(for:)`)
- `.day` parent -> group by `.session` (using `TrainingModeConfig.sessionGap: Duration`)

### ProgressChartView Changes (Profile/ProgressChartView.swift)

**Add expansion state and computed display buckets:**

```swift
@State private var expandedBucketIndex: Int?

private func displayBuckets(from baseBuckets: [TimeBucket]) -> [TimeBucket] {
    guard let expandedIndex = expandedBucketIndex,
          expandedIndex < baseBuckets.count else {
        return baseBuckets
    }
    let expandedBucket = baseBuckets[expandedIndex]
    let subs = progressTimeline.subBuckets(for: mode, expanding: expandedBucket)
    guard !subs.isEmpty else { return baseBuckets }

    var result = baseBuckets
    result.replaceSubrange(expandedIndex...expandedIndex, with: subs)
    return result
}
```

**Add chart overlay for tap detection:**

```swift
.chartOverlay { chart in
    GeometryReader { geo in
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleChartTap(location: location, chart: chart, geo: geo, baseBuckets: buckets)
            }
    }
}
```

**Tap handler finds nearest bucket:**

```swift
private func handleChartTap(
    location: CGPoint,
    chart: ChartProxy,
    geo: GeometryProxy,
    baseBuckets: [TimeBucket]
) {
    guard let tappedDate: Date = chart.value(atX: location.x) else { return }

    // Find nearest bucket in the BASE buckets (not display buckets)
    guard let nearestIndex = baseBuckets.enumerated().min(by: {
        abs($0.element.periodStart.timeIntervalSince(tappedDate)) <
        abs($1.element.periodStart.timeIntervalSince(tappedDate))
    })?.offset else { return }

    let bucket = baseBuckets[nearestIndex]

    withAnimation(.easeInOut(duration: 0.3)) {
        if expandedBucketIndex == nearestIndex {
            expandedBucketIndex = nil  // Collapse
        } else if bucket.bucketSize != .session {
            expandedBucketIndex = nearestIndex  // Expand
        }
    }
}
```

**Important: Animation with `withAnimation` wrapping the state change.** SwiftUI Charts animates mark transitions automatically when the data changes -- the key is that `displayBuckets` is a computed property that changes when `expandedBucketIndex` changes.

### Bucket Label Formatting for Sub-Buckets

The existing `bucketLabel(for:size:relativeTo:)` already handles all four `BucketSize` cases. Sub-buckets created at finer granularity will automatically get appropriate labels because their `bucketSize` matches the finer level.

### Existing Code Patterns to Follow

**Chart overlay pattern** (from Apple Charts documentation -- this is the standard approach):
```swift
.chartOverlay { proxy in
    GeometryReader { geo in
        Rectangle().fill(.clear).contentShape(Rectangle())
            .onTapGesture { location in
                if let date: Date = proxy.value(atX: location.x) { ... }
            }
    }
}
```

**Card styling pattern** (already used in ProgressChartView):
```swift
.padding()
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
```

**Environment access pattern:**
```swift
@Environment(\.progressTimeline) private var progressTimeline
```

### What NOT To Do

- Do NOT store expansion state in `ProgressTimeline` -- it's purely UI state
- Do NOT create a new view file for the expanded chart -- modify `ProgressChartView` in place
- Do NOT add drag/pan gestures -- only tap to expand/collapse per the UX spec
- Do NOT modify `ProfileScreen.swift` -- all changes are within `ProgressChartView` and `ProgressTimeline`
- Do NOT add sparklines to Start Screen -- that's story 38.5
- Do NOT use `ObservableObject`/`@Published` or `@EnvironmentObject`
- Do NOT import `Charts` in any `Core/` file
- Do NOT add `@testable import` in tests
- Do NOT create separate sub-bucket view types -- one parameterized chart handles everything
- Do NOT use `@MainActor` explicitly -- default isolation handles it
- Do NOT change the EWMA computation or headline statistics -- only the chart's visual bucket display changes during expansion
- Do NOT cache sub-buckets in `ProgressTimeline` -- compute on demand (small data, fast computation)

### Testing Strategy

**ProgressTimeline sub-bucket tests** (add to existing `PeachTests/Core/Profile/ProgressTimelineTests.swift`):
- Create a timeline with records spanning months, verify `subBuckets` for a month bucket returns week-level buckets
- Verify `subBuckets` for a week bucket returns day-level buckets
- Verify `subBuckets` for a day bucket returns session-level buckets
- Verify `subBuckets` for a session bucket returns empty array
- Verify record counts are consistent between parent and sub-buckets

**ProgressChartView display bucket tests** (add to `PeachTests/Profile/ProgressChartViewTests.swift`):
- Test `displayBuckets` static helper with nil expansion returns original buckets
- Test `displayBuckets` with expanded index replaces one bucket with sub-buckets
- Cannot easily test gesture handling in unit tests -- rely on manual testing for tap interaction

### Project Structure Notes

- Modified: `Peach/Core/Profile/ProgressTimeline.swift` (store full MetricPoint, add subBuckets API, add assignSubBuckets helper)
- Modified: `Peach/Profile/ProgressChartView.swift` (expansion state, displayBuckets computation, chart overlay gesture, accessibility updates)
- Modified: `Peach/Resources/Localizable.xcstrings` (new accessibility strings for expansion state)
- Modified: `PeachTests/Core/Profile/ProgressTimelineTests.swift` (sub-bucket tests)
- Modified: `PeachTests/Profile/ProgressChartViewTests.swift` (display bucket computation tests)
- No new files created
- No files deleted

### References

- [Source: docs/implementation-artifacts/38-1-brainstorm-and-design-profile-visualization.md#Focus+Context Interaction] -- Approved UX spec: tap to expand buckets, tap again to collapse, smooth animation
- [Source: docs/implementation-artifacts/38-3-progresschartview-and-profile-screen-redesign.md] -- Previous story: ProgressChartView implementation, chart rendering patterns, data flow
- [Source: Peach/Core/Profile/ProgressTimeline.swift] -- Current API: state(for:), buckets(for:), currentEWMA(for:), trend(for:); ModeState stores allValues without timestamps; assignBuckets contains the bucketing logic to reuse
- [Source: Peach/Profile/ProgressChartView.swift] -- Current chart: LineMark + AreaMark + RuleMark, no gesture overlay, no expansion state
- [Source: Peach/Core/Profile/TrainingModeConfig.swift] -- sessionGap (1800s), coldStartThreshold (20), config(for:) static method
- [Source: docs/project-context.md] -- @Observable not ObservableObject, @Environment with @Entry, Core/ has no SwiftUI imports, Swift Testing only

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
