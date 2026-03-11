# Story 41.2: Scrollable Chart with Fixed Y-Axis

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to scroll horizontally through my training history with the Y-axis always visible,
so that I can explore my full progress timeline without losing context for what the numbers mean.

## Acceptance Criteria

1. **Given** the Profile Screen with a progress card, **When** the chart renders, **Then** it displays as an HStack with a fixed-width non-scrolling Y-axis on the left and a horizontally scrollable chart body on the right, **And** both share the same Y domain (`chartYScale(domain:)`) so vertical scales match.

2. **Given** the scrollable chart, **When** it first appears, **Then** it is pinned to the right edge (most recent data) via `.chartScrollPosition(initialX:)`.

3. **Given** the scrollable chart with many months of data, **When** the user scrolls left, **Then** older data (monthly buckets) becomes visible, **And** scrolling is smooth with no frame drops on supported devices.

4. **Given** the data for the visible viewport, **When** the chart renders, **Then** only the visible data slice plus a small buffer is passed to the chart (data windowing), **And** this mitigates the known iOS 18 redraw loop with synchronized scroll positions.

5. **Given** the fixed Y-axis, **When** the chart is scrolled, **Then** the Y-axis remains stationary and aligned with the scrollable chart body.

## Tasks / Subtasks

- [ ] Task 1: Switch data source to multi-granularity buckets (AC: #1)
  - [ ] 1.1 In `ProgressChartView`, replace `progressTimeline.buckets(for: mode)` with `progressTimeline.allGranularityBuckets(for: mode)` for the chart body
  - [ ] 1.2 Remove or gate the `chartExpansionEnabled` flag and `displayBuckets` expansion logic — this story replaces that interaction model entirely
  - [ ] 1.3 Remove `@State private var expandedBucketIndex: Int?` — no longer needed

- [ ] Task 2: Implement HStack layout with fixed Y-axis + scrollable chart (AC: #1, #5)
  - [ ] 2.1 Write tests first: static layout helper tests for Y-domain computation — given buckets with known min/max means and stddevs, verify computed Y domain range
  - [ ] 2.2 Split current `chart(buckets:)` into two sibling views inside an `HStack`:
    - Left: Fixed-width Y-axis column (narrow `Chart` with `.chartXAxis(.hidden)` or a plain `VStack` of labels)
    - Right: Horizontally scrollable chart body (main `Chart` with `.chartYAxis(.hidden)`)
  - [ ] 2.3 Both views must share the same Y domain via `.chartYScale(domain: yMin...yMax)` — compute `yMin` and `yMax` from bucket data (min of `mean - stddev` clamped to 0, max of `mean + stddev`)
  - [ ] 2.4 Fixed Y-axis must show the `config.unitLabel` and tick marks matching the scrollable chart

- [ ] Task 3: Add horizontal scrolling with right-edge pinning (AC: #2, #3)
  - [ ] 3.1 Add `.chartScrollableAxes(.horizontal)` to the scrollable chart body
  - [ ] 3.2 Add `.chartXVisibleDomain(length:)` to control how many data points are visible at once — use `ChartLayoutCalculator.totalWidth` to determine if scrolling is needed, and set a reasonable visible domain (e.g., ~10-15 bucket widths)
  - [ ] 3.3 Add `.chartScrollPosition(initialX:)` set to the latest bucket's `periodStart` date to pin the right edge on load
  - [ ] 3.4 Use total chart width from `ChartLayoutCalculator.totalWidth(for:configs:)` with the zone config dictionary to size the scrollable content

- [ ] Task 4: Implement data windowing for performance (AC: #4)
  - [ ] 4.1 Write tests first: given a large bucket array and a visible range, verify windowed slice returns correct subset with buffer
  - [ ] 4.2 Track the current scroll position via `@State` bound to `.chartScrollPosition`
  - [ ] 4.3 Compute visible data window: filter buckets to those within the visible X domain + a buffer of ~5 extra buckets on each side
  - [ ] 4.4 Pass only the windowed slice to the `Chart` to avoid iOS 18 redraw loop with large datasets

- [ ] Task 5: Update X-axis labels for multi-granularity (AC: #1)
  - [ ] 5.1 Replace current `bucketLabel` X-axis formatting with `GranularityZoneConfig.formatAxisLabel` — each bucket's label is formatted according to its `BucketSize` using the matching zone config's `formatAxisLabel(_:)` method
  - [ ] 5.2 Build zone config lookup dictionary: `[BucketSize: any GranularityZoneConfig]` mapping `.month` to `MonthlyZoneConfig()`, `.day` to `DailyZoneConfig()`, `.session` to `SessionZoneConfig()`

- [ ] Task 6: Preserve existing chart marks and headline (AC: #1)
  - [ ] 6.1 Keep `AreaMark` (stddev band), `LineMark` (EWMA), `RuleMark` (baseline) — same visual rendering, just inside the scrollable chart body
  - [ ] 6.2 Keep headline row (`headlineRow`) unchanged — still shows mode name, EWMA, stddev, trend arrow
  - [ ] 6.3 Retain existing accessibility labels and value descriptions

- [ ] Task 7: Run full test suite
  - [ ] 7.1 Run `bin/test.sh` — all existing + new tests pass
  - [ ] 7.2 Run `bin/check-dependencies.sh` — no import rule violations

## Dev Notes

### Architecture & Key Decisions

**HStack layout pattern (fixed Y-axis + scrollable body):** This is the established community workaround for Swift Charts — no built-in "sticky Y-axis" modifier exists. The pattern is:
```swift
HStack(spacing: 0) {
    // Fixed Y-axis (non-scrolling)
    Chart { /* minimal marks for Y-axis rendering */ }
        .chartXAxis(.hidden)
        .chartYScale(domain: yMin...yMax)
        .frame(width: yAxisWidth)

    // Scrollable chart body
    Chart { /* actual data marks */ }
        .chartYAxis(.hidden)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDomainLength)
        .chartScrollPosition(initialX: latestDate)
        .chartYScale(domain: yMin...yMax)
}
```

**Data source switch:** The current `ProgressChartView` uses `progressTimeline.buckets(for: mode)` which returns adaptive single-granularity buckets. Story 41.2 switches to `progressTimeline.allGranularityBuckets(for: mode)` which returns the concatenated multi-granularity array (month + day + session) created in Story 41.1. The old `buckets(for:)` API remains available but is no longer used by the chart.

**Chart expansion removal:** The `chartExpansionEnabled` flag, `displayBuckets` static method, and `expandedBucketIndex` state variable are dead code from the previous drill-down UX experiment. This story's scrollable multi-granularity chart replaces that concept entirely. Remove them.

**Y-domain synchronization:** Both the fixed Y-axis and scrollable body must use the same `.chartYScale(domain: yMin...yMax)`. Compute these from ALL buckets (not just visible ones) so the Y-axis doesn't shift during scrolling. `yMin = max(0, min of (mean - stddev))`, `yMax = max of (mean + stddev)`, with padding.

**Data windowing for iOS 18 redraw bug:** When two synchronized `Chart` views share scroll state, iOS 18 has a known redraw loop with large datasets. Mitigate by passing only the visible slice + buffer to the scrollable `Chart`. This means: track scroll position → compute which bucket indices are visible → slice the array with ~5 extra on each side → pass that slice to the `Chart`.

**`.chartScrollPosition(initialX:)`:** Set to the `periodStart` date of the last bucket to pin the chart to the most recent data on load. The user scrolls left to see older data.

**Zone configs dictionary:** Build once and reuse:
```swift
private static let zoneConfigs: [BucketSize: any GranularityZoneConfig] = [
    .month: MonthlyZoneConfig(),
    .day: DailyZoneConfig(),
    .session: SessionZoneConfig()
]
```
Note: `.week` is intentionally absent — `allGranularityBuckets` never produces weekly buckets.

**`.chartXVisibleDomain(length:)`:** This modifier takes a `length` in X-axis units. Since the X-axis is `Date`, the length is a `TimeInterval`. Calculate an appropriate visible domain that shows ~10-15 data points. This may need to be adaptive based on total bucket count — if the user has fewer than 15 buckets total, no scrolling is needed.

### Existing Code to Understand

**`ProgressChartView.swift` (current, 207 lines):**
- `activeCard` (line 32): Constructs card with headline + chart. Currently calls `buckets(for:)` — will switch to `allGranularityBuckets(for:)`.
- `chart(buckets:)` (line 91): Renders `AreaMark` + `LineMark` + `RuleMark`. This method needs to be split into fixed Y-axis + scrollable body.
- `headlineRow` (line 66): Shows mode name, EWMA, stddev, trend. Unchanged in this story.
- `bucketLabel(for:size:relativeTo:)` (line 163): Current X-axis label formatter — will be replaced by `GranularityZoneConfig.formatAxisLabel`.
- `displayBuckets` (line 136): Drill-down expansion logic — remove in this story.
- `chartExpansionEnabled` (line 10): Dead flag — remove.
- `expandedBucketIndex` (line 15): Dead state — remove.

**`ProgressTimeline.swift` key APIs:**
- `allGranularityBuckets(for:)` — returns `[TimeBucket]` with concatenated month + day + session zones (Story 41.1 output)
- `currentEWMA(for:)` — returns `Double?`, current EWMA value
- `trend(for:)` — returns `Trend?` (.improving/.stable/.declining)
- `state(for:)` — returns `.noData` or `.active`

**`ChartLayoutCalculator` APIs:**
- `totalWidth(for:configs:)` — total chart width from bucket count x point widths
- `zoneBoundaries(for:)` — `[ZoneBoundary]` with `startIndex`, `endIndex`, `bucketSize`

**`GranularityZoneConfig` conformances:**
- `MonthlyZoneConfig`: 30pt width, "MMM" date format (e.g., "Jan")
- `DailyZoneConfig`: 40pt width, "EEE" format (e.g., "Mon")
- `SessionZoneConfig`: 50pt width, short time format (e.g., "14:30")

**`TimeBucket` struct:**
- `periodStart: Date`, `periodEnd: Date`, `bucketSize: BucketSize`, `mean: Double`, `stddev: Double`, `recordCount: Int`

**`TrainingModeConfig` properties used:**
- `config.displayName` — headline label
- `config.unitLabel` — Y-axis label (e.g., "cents")
- `config.optimalBaseline` — `Cents` value for baseline `RuleMark`

### Testing Patterns

Follow existing `ProgressChartView` and `ProgressTimeline` test patterns:

**Static helper tests (unit-testable without SwiftUI views):**
1. Y-domain computation: given buckets with known mean/stddev, verify `yMin` and `yMax` are correct
2. Data windowing: given 50 buckets and visible range indices 30-40, verify windowed slice returns indices 25-45 (with buffer)
3. Data windowing edge cases: visible range at start (no left buffer), visible range at end (no right buffer), fewer buckets than buffer size
4. Zone config dictionary: verify all expected `BucketSize` cases are mapped

**Key test patterns from project:**
- Every `@Test` function must be `async`
- Behavioral descriptions: `@Test("computes Y domain from bucket min/max")`
- Use `#expect(value == expected)` with exact assertions
- Test structs, not classes
- Factory methods for test fixtures
- No XCTest, no setUp/tearDown

### File Placement

Modified files:
- `Peach/Profile/ProgressChartView.swift` — major rework: split into fixed Y-axis + scrollable body, switch data source, add scroll position management, add data windowing

New test files (if static helpers are extracted):
- `PeachTests/Profile/ProgressChartViewTests.swift` — tests for Y-domain computation, data windowing logic

### What NOT To Do

- Do NOT modify `ProgressTimeline.swift` — the data layer is complete from Story 41.1
- Do NOT modify `ChartLayoutCalculator.swift` or `GranularityZoneConfig.swift` — use them as-is
- Do NOT add `import SwiftUI` or `import Charts` in any Core/ file
- Do NOT add zone separators (background tints, vertical dividers, zone labels) — that is Story 41.3
- Do NOT add tap-to-select data points — that is Story 41.4
- Do NOT add TipKit tips — that is Story 41.6
- Do NOT add narrative headlines — that is Story 41.8
- Do NOT add session-level markers — that is Story 41.9
- Do NOT use `.chartOverlay` with `.onTapGesture` — this causes scroll+tap conflict on iOS 18+; tap interaction comes in Story 41.4 using `.chartGesture` with `SpatialTapGesture`
- Do NOT add explicit `@MainActor` annotations (redundant with default isolation)
- Do NOT use XCTest — use Swift Testing (`@Test`, `@Suite`, `#expect`)
- Do NOT import third-party dependencies
- Do NOT use `ObservableObject`, `@Published`, or Combine
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT use `.week` in the zone configs dictionary — weekly buckets are intentionally omitted from `allGranularityBuckets`

### Project Structure Notes

- All chart view changes stay in `Peach/Profile/ProgressChartView.swift`
- `ProfileScreen.swift` should NOT need changes — it just renders `ProgressChartView(mode:)` for each active mode
- Core/ files from Story 41.1 are consumed read-only: `ChartLayoutCalculator`, `GranularityZoneConfig`, `ProgressTimeline`
- Run `bin/check-dependencies.sh` after implementation to verify import rules

### Previous Story Intelligence (41.1)

Key learnings from Story 41.1 implementation:
- `GranularityZoneConfig` protocol lives in Core/ with `pointWidth: CGFloat` and `formatAxisLabel(_:)` method. `backgroundTint` was intentionally omitted from Core/ to avoid SwiftUI import. **The UI layer must map `BucketSize` to `Color` separately** — do this in Story 41.3, not here.
- `ChartLayoutCalculator` is a pure static enum. `totalWidth(for:configs:)` takes `[BucketSize: any GranularityZoneConfig]` dictionary. `zoneBoundaries(for:)` returns `[ZoneBoundary]`.
- DateFormatters in zone configs are cached as `static let` — no performance concern with repeated `formatAxisLabel` calls.
- Code review found that `allGranularityBuckets` hardcodes `Date()` instead of accepting a parameter (L6 low-priority finding). Be aware that the "now" reference is fixed at call time.
- 1027 tests passed after Story 41.1. No regressions expected from UI-only changes in this story.

### Git Intelligence

Recent commit pattern: `Implement story {id}: {description}` for implementation, `Review story {id}: {details}` for review fixes. The 41.1 implementation and review were done in two separate commits.

### References

- [Source: docs/planning-artifacts/epics.md#Story 41.2] — Full acceptance criteria and dependencies
- [Source: docs/planning-artifacts/research/technical-profile-screen-chart-ux-research-2026-03-11.md] — HStack Y-axis pattern, chartScrollPosition, data windowing, iOS 18 scroll+tap workaround, performance constraints
- [Source: docs/implementation-artifacts/41-1-multi-granularity-bucket-pipeline.md] — Previous story: allGranularityBuckets API, ChartLayoutCalculator, GranularityZoneConfig
- [Source: Peach/Profile/ProgressChartView.swift] — Current chart implementation (207 lines) to be reworked
- [Source: Peach/Profile/ProfileScreen.swift] — Parent view consuming ProgressChartView (unchanged)
- [Source: Peach/Core/Profile/ProgressTimeline.swift] — Data source: allGranularityBuckets(for:), currentEWMA(for:), trend(for:)
- [Source: Peach/Core/Profile/ChartLayoutCalculator.swift] — Layout utilities: totalWidth, zoneBoundaries
- [Source: Peach/Core/Profile/GranularityZoneConfig.swift] — Zone configs: MonthlyZoneConfig(30pt), DailyZoneConfig(40pt), SessionZoneConfig(50pt)
- [Source: docs/project-context.md] — Coding conventions, Core/ import rules, testing rules, file placement

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
