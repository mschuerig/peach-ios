# Story 41.3: Granularity Zone Separators

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user**,
I want to see clear visual boundaries between monthly, daily, and session-level zones on my chart,
so that I understand the time scale changes as I scroll through my history.

## Acceptance Criteria

1. **Given** a chart with multiple granularity zones, **When** the chart renders, **Then** each zone has a subtle background tint using semantic colors (`Color(.systemBackground)` vs `Color(.secondarySystemBackground)`), **And** a thin vertical divider line marks each zone boundary, **And** a small caption label at the top of each zone identifies it (e.g., "Monthly", "Daily", "Sessions" — localized DE+EN).

2. **Given** the zone separators, **When** viewed in Dark Mode, **Then** semantic colors adapt automatically with no hardcoded color values.

3. **Given** the zone separators, **When** evaluated for WCAG 1.4.1 compliance, **Then** color is not the sole information carrier — the vertical divider line and zone label text also communicate the transition (NFR1).

4. **Given** a chart with only one granularity zone (e.g., new user with sessions only), **When** the chart renders, **Then** no zone separators or labels are shown (nothing to separate).

5. **Given** the monthly zone contains data spanning multiple calendar years, **When** the chart renders, **Then** year boundary separators appear as vertical lines within the monthly zone, **And** year labels appear in a dedicated row below the X-axis labels flanking each year boundary.

6. **Given** a year boundary within 1 bucket index of a zone transition, **When** the chart renders, **Then** the year boundary separator is suppressed to avoid visual clutter (deduplication).

7. **Given** the multi-granularity bucket pipeline, **When** zone boundaries are computed, **Then** the session zone starts at midnight today (calendar day snap, not 24h rolling window), **And** the day zone covers the 7 calendar days before today, **And** the month zone covers everything older — with the last month's bucket truncated at the day zone start (e.g., if the day zone starts March 5, the March monthly bucket only contains data from March 1–4).

## Tasks / Subtasks

- [ ] Task 0: Fix calendar-snapped zone boundaries in ProgressTimeline (AC: #7)
  - [ ] 0.1 Write tests first: given metrics spanning months, days, and today — verify `assignMultiGranularityBuckets` assigns session zone from midnight today (not 24h rolling), day zone as the 7 calendar days before today, and month zone for everything older
  - [ ] 0.2 Write tests: given metrics in the current month that fall within the day zone's range — verify the last monthly bucket is truncated at the day zone start date (e.g., March data split: March 1–4 in month zone, March 5–11 in day zone)
  - [ ] 0.3 Write tests: given a new user with only today's data — verify only session buckets are produced (no empty day or month zones)
  - [ ] 0.4 Refactor `assignMultiGranularityBuckets` to use calendar-based boundaries instead of age-based thresholds:
    - `sessionStart = Calendar.current.startOfDay(for: now)` (midnight today)
    - `dayStart = Calendar.current.date(byAdding: .day, value: -7, to: sessionStart)!` (midnight 7 days ago)
    - Classify: `timestamp >= sessionStart` → `.session`, `timestamp >= dayStart` → `.day`, else → `.month`
  - [ ] 0.5 Ensure month buckets whose calendar month overlaps the day zone are truncated: only include metrics with `timestamp < dayStart` in the monthly bucket. The monthly bucket's `periodEnd` should be `min(monthInterval.end, dayStart)`.
  - [ ] 0.6 The `dayThreshold` constant added during the previous attempt is superseded by this calendar-based approach — remove it if no longer needed, or repurpose it. The `recentThreshold` constant (24h) is also superseded.
  - [ ] 0.7 Update the doc comment on `allGranularityBuckets(for:)` to reflect calendar-based boundaries

- [ ] Task 1: Zone separator metadata computation (AC: #1, #4, #5, #6)
  - [ ] 1.1 Write tests first: given 3-zone buckets (month + day + session), verify `zoneSeparatorData(for:)` returns 3 zones with correct bucket size, tint color, start/end indices, and 2 divider indices
  - [ ] 1.2 Write tests: given single-zone buckets, verify empty zones and empty divider indices
  - [ ] 1.3 Write tests: given 2-zone buckets (month + day), verify 2 zones and 1 divider index
  - [ ] 1.4 Write tests: given monthly buckets spanning 2 calendar years, verify year boundary index appears in dividers
  - [ ] 1.5 Write tests: given a year boundary within 1 index of a zone transition, verify deduplication (year boundary suppressed)
  - [ ] 1.6 Implement `zoneSeparatorData(for:)` static method on `ProgressChartView` returning `ZoneSeparatorData` (zones: `[ZoneInfo]`, dividerIndices: `[Int]`). Uses `ChartLayoutCalculator.zoneBoundaries(for:)`. Includes year boundary detection and deduplication logic.
  - [ ] 1.7 Implement `yearLabels(for:)` static method returning `[YearLabel]` — flanking labels at first and last bucket index of each calendar year span within monthly zones

- [ ] Task 2: Zone background tints via RectangleMark (AC: #1, #2)
  - [ ] 2.1 Add `zoneTint(for:)` mapping `BucketSize` → semantic `Color`: `.month` → `Color(.systemBackground)`, `.day` → `Color(.secondarySystemBackground)`, `.session` → `Color(.systemBackground)`. Alternating pattern for visual distinction.
  - [ ] 2.2 Add `RectangleMark` entries in `Chart` block for each zone span using index-based coordinates: `xStart: Double(zone.startIndex) - 0.5`, `xEnd: Double(zone.endIndex) + 0.5`, full Y domain. Rendered FIRST (behind data marks).
  - [ ] 2.3 Apply `.foregroundStyle(zone.tint.opacity(0.06))` — faint enough that the stddev band (`blue.opacity(0.15)`) remains clearly visible in both Light and Dark Mode

- [ ] Task 3: Vertical divider lines via RuleMark inside Chart (AC: #1, #3, #5)
  - [ ] 3.1 Add `RuleMark(x: .value("Div", Double(idx) - 0.5))` inside the `Chart` block for each divider index from `zoneSeparatorData`. This renders within the plot area and clips naturally at the axis boundary — no chartOverlay needed.
  - [ ] 3.2 Style with `.foregroundStyle(.secondary)` and `.lineStyle(StrokeStyle(lineWidth: 1))` — visible but not dominant
  - [ ] 3.3 Place divider RuleMarks after RectangleMark tints but before data marks (AreaMark, LineMark, PointMark) so dividers appear behind data

- [ ] Task 4: Zone caption labels (AC: #1, #3)
  - [ ] 4.1 Add localized zone label strings: "Monthly"/"Monatlich", "Daily"/"Täglich", "Sessions"/"Sitzungen" via `bin/add-localization.py`
  - [ ] 4.2 Render zone labels using `.chartOverlay` with `GeometryReader` — position `Text` at the horizontal center of each zone, vertically at the top of the plot area. Style: `.font(.caption2)`, `.foregroundStyle(.secondary)`.
  - [ ] 4.3 Ensure labels appear in both scrollable and static chart modes

- [ ] Task 5: Year labels below X-axis (AC: #5)
  - [ ] 5.1 Write tests: given monthly buckets spanning 2025-2026, verify `yearLabels(for:)` returns flanking labels at first and last index of each year span
  - [ ] 5.2 Write tests: given monthly buckets within a single year, verify a single pair of flanking labels
  - [ ] 5.3 Render year labels via `.chartOverlay` — text-only, no lines. Position in a row below the X-axis labels using `proxy.position(forX:)`. Use `.font(.caption2)`, `.foregroundStyle(.secondary)`.
  - [ ] 5.4 Add bottom padding to chart frame to accommodate year label row (only when year labels exist)

- [ ] Task 6: Run full test suite
  - [ ] 6.1 Run `bin/test.sh` — all existing + new tests pass
  - [ ] 6.2 Run `bin/check-dependencies.sh` — no import rule violations

## Dev Notes

### Visual Design Target

**Three-zone layout with index-based X-axis (equal spacing per data point):**

```
 25 ┤
    │
 20 ┤          ╭──╮
    │     ╭────╯  ╰───╮        ╭──╮          ╭──╮
 15 ┤─────╯           ╰────────╯  ╰──────────╯  ╰──╮               ●
    │                                                     ●   ●
 10 ┤                                                 ●
    │
  5 ┤
    │
  0 ┼──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬────────────────
    Okt Nov Dez Jan Feb Mär │  Fr Sa So Mo Di Mi Do │
    2025   2025| 2026  2026 │
```

**Separator lines clip to the plot area (RuleMark behavior):**

```
 Correct (RuleMark):             Wrong (chartOverlay):
 ┌──────────┐──────────┐        ┌──────────┐──────────┐
 │  month   │   day    │        │  month   ││  day    │
 │  data    │   data   │        │  data    ││  data   │
 ├──────────├──────────┘        │──────────┤├─────────│
   Okt Nov    Mo Di               Okt Nov  ││ Mo Di   │
      2025                        2025     ││         │
                                           ↑↑
                                   Lines go through labels
```

Separator lines MUST use `RuleMark(x:)` inside the `Chart` block. They clip naturally at the plot area boundary. Do NOT use `chartOverlay` for lines — it draws on top of axis labels.

### Zone Boundary Model (Calendar-Snapped)

The zone boundaries snap to calendar days, not rolling hour windows:

```
                     dayStart              sessionStart           now
                     (midnight,            (midnight              │
                      7 days ago)           today)                ▼
 ◄── Month zone ────►│◄── Day zone (7d) ──►│◄── Session zone ───►│
 ...Oct Nov Dec Jan  ││ Fr Sa So Mo Di Mi Do│  session1 session2  │
                     ││                     │                     │
 monthly buckets     ││ daily buckets       │ session buckets     │
 (last month         ││                     │                     │
  truncated here)    ││                     │                     │
```

**Key rules:**
- **Session zone**: `timestamp >= startOfDay(now)` — today's sessions from midnight
- **Day zone**: `timestamp >= startOfDay(now) - 7 days` AND `timestamp < startOfDay(now)` — previous 7 calendar days
- **Month zone**: `timestamp < startOfDay(now) - 7 days` — everything older, monthly buckets
- **Month truncation**: The last monthly bucket's `periodEnd` is `min(monthInterval.end, dayStart)`. If March starts on the 1st but the day zone starts on the 5th, the March monthly bucket only contains March 1–4 data.

This replaces the age-based thresholds (`recentThreshold = 24h`, `dayThreshold = 7 * 86400`) in `assignMultiGranularityBuckets`. The change lives in `ProgressTimeline.swift`.

### Critical Context: Previous Failed Attempt

This story failed once. A comprehensive analysis is documented in `docs/implementation-artifacts/progress-chart-report.md`. Read sections 4–7 of that document for detailed problem descriptions and trade-off analysis. The key lessons:

1. **The X-axis is index-based (`Double`), not date-based.** Each bucket gets an integer index; the chart uses `Double` as X plottable. This is the single most important design decision — it gives every data point equal visual weight regardless of time span. All zone geometry (RectangleMark, RuleMark, labels) must use `Double` index coordinates, not `Date`.

2. **`chartOverlay` draws on top of everything — including axis labels.** Separator lines drawn via `chartOverlay` cut through X-axis labels. No Swift Charts API exists to draw between the plot area and the label area.

3. **`RuleMark(x:)` inside `Chart` clips correctly to the plot area** but cannot extend below the axis. This is the correct tool for separator lines — accept that they stop at the plot area boundary.

4. **Background tints already distinguish zones.** Separator lines are reinforcement, not the primary signal. Making them stop at the plot area boundary is not a significant visual loss.

5. **The fixed Y-axis (HStack from 41.2) was removed** because reliable alignment across the two Chart instances couldn't be achieved. The Y-axis now renders inline on the single chart. Do not attempt to restore it.

6. **Year label overlap is a known edge case** when adjacent years have few monthly buckets. Accept approximate positioning for now.

### Architecture: The Core Tension — chartOverlay vs. RuleMark

```
| Need                       | RuleMark (inside Chart) | chartOverlay      |
|----------------------------|------------------------|-------------------|
| Clips to plot area         | Yes                    | No                |
| Extends below axis         | No                     | Yes               |
| Knows scroll position      | Yes (automatic)        | Yes (via proxy)   |
| Respects label layout      | Yes                    | No                |
```

**Resolution (Option A from report):** Use `RuleMark(x:)` inside the `Chart` for all separator lines. They clip to the plot area — separator lines do not extend into the year-label row. Use `chartOverlay` for text elements only (zone labels, year labels) — text is small and doesn't overlap axis labels problematically.

### Rendering Layers (Z-Order within Chart block)

1. `RectangleMark` — zone background tints (bottommost)
2. `RuleMark(x:)` — zone and year boundary divider lines
3. `AreaMark` — stddev band
4. `LineMark` — EWMA line
5. `PointMark` — session dots
6. `RuleMark(y:)` — baseline
7. `chartOverlay` — zone caption labels, year labels (topmost, text only)

### Index-Based Coordinates

Zone boundaries use bucket array indices, not dates:
```swift
// Zone tint: half-index offset so tint spans from center-of-gap to center-of-gap
RectangleMark(
    xStart: .value("ZS", Double(zone.startIndex) - 0.5),
    xEnd: .value("ZE", Double(zone.endIndex) + 0.5),
    yStart: .value("Y0", yDomain.lowerBound),
    yEnd: .value("Y1", yDomain.upperBound)
)

// Divider line: sits at the gap between zones
RuleMark(x: .value("Div", Double(dividerIndex) - 0.5))
```

### Zone Tint Color Mapping (UI Layer)

```swift
private static func zoneTint(for bucketSize: BucketSize) -> Color {
    switch bucketSize {
    case .month: Color(.systemBackground)
    case .day: Color(.secondarySystemBackground)
    case .session: Color(.systemBackground)
    case .week: Color(.systemBackground) // unused but exhaustive
    }
}
```

At 6% opacity. Semantic colors auto-adapt for Dark Mode.

### Year Boundary Detection

Within monthly zone buckets, compare adjacent `periodStart` years. When year changes, add divider at that bucket index. Deduplicate: suppress year boundaries within 1 index of a zone transition to avoid double lines.

### Year Labels

Flanking labels: for each contiguous year span in the monthly zone, place the year string at the first and last bucket index of that span. Positioned via `chartOverlay` using `proxy.position(forX:)` in a row below the X-axis labels. Add `bottomPadding` to the chart frame when year labels exist.

Known limitation: adjacent years with few buckets may overlap. Accept this for now.

### Existing Code to Understand

**`ProgressChartView.swift` (current, after 41.2 + reverted 41.3 = back to 41.2 baseline):**
- `chartView(buckets:)` — main chart rendering. Currently renders AreaMark + LineMark + PointMark + baseline RuleMark. Zone separator code must be added here.
- `scrollPosition: Double` — index-based scroll state (not Date)
- `visibleBucketCount = 12` — scroll domain length
- `yDomain(for:)` — computes Y axis range from all buckets
- `formatAxisLabel(_:size:)` — X-axis labels with trailing-dot stripping for German
- `zoneConfigs` — `[BucketSize: any GranularityZoneConfig]` dictionary (month/day/session)
- `chartXScale(domain: -0.5...Double(buckets.count) - 0.5)` — the X domain includes half-index padding

**`ChartLayoutCalculator.zoneBoundaries(for:)`** — returns `[ZoneBoundary]` with `startIndex`, `endIndex`, `bucketSize`. Primary data source for zone rendering.

### Signature Changes

`chartView(buckets:)` already receives the full bucket array. Zone separator data can be computed inline via the static `zoneSeparatorData(for:)` helper — no signature changes needed.

### Testing Patterns

Follow existing `ProgressChartViewTests` patterns:

**Static helper tests:**
1. `zoneSeparatorData(for:)`: 3-zone, 2-zone, 1-zone, empty bucket scenarios — verify zone count, divider indices, tint colors
2. Year boundary detection: monthly buckets spanning year boundary → divider at correct index
3. Year boundary deduplication: year boundary adjacent to zone transition → suppressed
4. `yearLabels(for:)`: multi-year monthly buckets → flanking labels at correct indices

**Key test patterns:**
- Every `@Test` function must be `async`
- Behavioral descriptions: `@Test("returns no zone separators for single-zone buckets")`
- Use `#expect(value == expected)`
- Struct-based test suites, factory methods for fixtures

### File Placement

Modified files:
- `Peach/Profile/ProgressChartView.swift` — add zone background tints, divider RuleMarks, zone caption labels, year labels, and all supporting static helpers
- `PeachTests/Profile/ProgressChartViewTests.swift` — add tests for zone separator and year label logic
- `Peach/Resources/Localizable.xcstrings` — add "Monthly"/"Monatlich", "Daily"/"Täglich", "Sessions"/"Sitzungen" via `bin/add-localization.py`

Modified Core files:
- `Peach/Core/Profile/ProgressTimeline.swift` — refactor `assignMultiGranularityBuckets` from age-based thresholds to calendar-snapped zone boundaries (Task 0)
- `PeachTests/Core/Profile/ProgressTimelineTests.swift` — add tests for calendar-snapped zone boundaries and month truncation

### What NOT To Do

- Do NOT use `chartOverlay` for separator LINES — use `RuleMark(x:)` inside the `Chart` block. `chartOverlay` is only for TEXT (zone labels, year labels). This was the core mistake of the first attempt. See `progress-chart-report.md` section 5.
- Do NOT attempt to extend separator lines below the X-axis into the year-label row — this requires `chartOverlay` which draws over axis labels. Accept that `RuleMark` clips to the plot area.
- Do NOT restore the fixed Y-axis HStack from 41.2 — it was removed because alignment was unreliable. Y-axis renders inline on the chart.
- Do NOT use age-based thresholds (rolling hours) for zone boundaries — use calendar-day-snapped boundaries. See "Zone Boundary Model" section above.
- Do NOT modify `ChartLayoutCalculator.swift` or `GranularityZoneConfig.swift` — consume them as-is
- Do NOT add `import SwiftUI` or `import Charts` in any Core/ file
- Do NOT add `backgroundTint` property to `GranularityZoneConfig` — Core/ must stay SwiftUI-free
- Do NOT add tap-to-select data points — that is Story 41.4
- Do NOT add TipKit tips — that is Story 41.6
- Do NOT add narrative headlines — that is Story 41.8
- Do NOT add session-level markers — that is Story 41.9
- Do NOT use hardcoded color values (hex, RGB) — use semantic `Color(.systemBackground)` etc.
- Do NOT use `.chartOverlay` with `.onTapGesture` — scroll+tap conflict on iOS 18
- Do NOT add explicit `@MainActor` annotations (redundant with default isolation)
- Do NOT use XCTest — use Swift Testing (`@Test`, `@Suite`, `#expect`)
- Do NOT import third-party dependencies
- Do NOT use `ObservableObject`, `@Published`, or Combine
- Do NOT create `Utils/` or `Helpers/` directories
- Do NOT use hardcoded magic-number Y offsets for separator positioning — the previous attempt used `plotFrame.maxY + 28` which was fragile

### Project Structure Notes

- All chart view changes stay in `Peach/Profile/ProgressChartView.swift`
- `ProfileScreen.swift` should NOT need changes
- `ProgressTimeline.swift` is modified in Task 0 (calendar-snapped zone boundaries)
- `ChartLayoutCalculator.swift` and `GranularityZoneConfig.swift` are consumed read-only
- Run `bin/check-dependencies.sh` after implementation to verify import rules

### Previous Story Intelligence (41.2)

Key learnings from Story 41.2 implementation:
- `scrollPosition` is `@State private var scrollPosition: Double = .infinity` — index-based, not Date. Set to rightmost position on `.onAppear`.
- `chartXScale(domain: -0.5...Double(buckets.count) - 0.5)` — the X domain includes half-index padding for visual balance
- `ForEach` uses `id: \.offset` or `id: \.periodStart` for stable identity — zone marks should use unique identifiers too
- Y-domain is computed from ALL buckets to prevent axis shifting — zone tints should also span the full Y domain
- Review found data windowing was initially dead code (C1 finding) — ensure zone separator rendering is actually connected and visible, not just computed
- The fixed Y-axis HStack was abandoned during 41.3 attempt because alignment was unreliable. The chart is now a single `Chart` with inline Y-axis.
- 1035 tests pass after 41.2 review fixes.

### Previous Attempt Intelligence (41.3 Failed)

Critical learnings from the failed 41.3 implementation (see `progress-chart-report.md`):
- `RectangleMark` zone tints work correctly with index-based coordinates — keep this approach
- `zoneSeparatorData(for:)` computation logic is sound — keep the algorithm
- `yearLabels(for:)` flanking logic is sound — keep the algorithm
- Year boundary deduplication logic works — keep it
- Zone caption labels via `chartOverlay` Text work — keep for TEXT only
- The FAILURE was using `chartOverlay` Path drawing for separator LINES — this draws on top of axis labels. Replace with `RuleMark(x:)` inside the Chart.
- `ProgressTimeline.assignMultiGranularityBuckets` had a real bug: day zone used `monthThreshold` (30 days) instead of a 7-day boundary. A partial fix (`dayThreshold = 7 * 86400`) is in the working tree, but the real fix is calendar-snapped boundaries (Task 0 in this story). The working tree diff should be discarded in favor of the proper calendar-based implementation.

### Git Intelligence

Recent commits follow `Implement story {id}: {description}` and `Review story {id}: {details}` pattern. The 41.3 implementation commit exists but the changes need to be reworked per this updated story.

### References

- [Source: docs/implementation-artifacts/progress-chart-report.md] — Comprehensive design and implementation report with problem analysis and trade-offs
- [Source: docs/planning-artifacts/epics.md#Story 41.3] — Full acceptance criteria and technical hints
- [Source: docs/planning-artifacts/epics.md#Epic 41 Requirements] — FR4: Granularity zone separators, NFR1: WCAG 1.4.1
- [Source: docs/implementation-artifacts/41-2-scrollable-chart-with-fixed-y-axis.md] — Previous story: scrollable chart, data windowing, zone configs
- [Source: docs/implementation-artifacts/41-1-multi-granularity-bucket-pipeline.md] — ChartLayoutCalculator.zoneBoundaries, GranularityZoneConfig
- [Source: Peach/Profile/ProgressChartView.swift] — Current chart implementation to be extended
- [Source: Peach/Core/Profile/ChartLayoutCalculator.swift] — zoneBoundaries(for:) returns [ZoneBoundary]
- [Source: Peach/Core/Profile/GranularityZoneConfig.swift] — Zone configs (no backgroundTint by design)
- [Source: docs/project-context.md] — Coding conventions, Core/ import rules, testing rules, file placement

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
