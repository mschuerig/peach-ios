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

## Tasks / Subtasks

- [ ] Task 1: Compute zone geometry from bucket data (AC: #1, #4)
  - [ ] 1.1 Write tests first: given multi-zone buckets and `ChartLayoutCalculator.zoneBoundaries(for:)`, verify zone boundary dates and bucket sizes are extracted correctly for rendering
  - [ ] 1.2 Write tests: given single-zone buckets, verify empty/single zone boundary means no separators rendered
  - [ ] 1.3 Create a static helper method on `ProgressChartView` that takes `[TimeBucket]` and returns zone rendering metadata (boundary dates, zone labels, zone tint colors) — only include separators when 2+ zones exist

- [ ] Task 2: Add zone background tints (AC: #1, #2)
  - [ ] 2.1 Map `BucketSize` to semantic `Color` in the UI layer (not in Core/) — e.g., `.month` → `Color(.systemBackground)`, `.day` → `Color(.secondarySystemBackground)`, `.session` → `Color(.systemBackground)` — alternating pattern for visual distinction
  - [ ] 2.2 Add `RectangleMark` entries in `chartContent` for each zone span, positioned behind data marks using `.foregroundStyle` with low opacity semantic colors
  - [ ] 2.3 Verify Dark Mode adaptation — semantic colors auto-adapt, no hardcoded values
  - [ ] 2.4 Verify stddev band visibility — the existing `AreaMark` stddev band uses `blue.opacity(0.15)` which is very subtle; zone background tints must not wash it out. Keep tint opacity low enough (≤ 0.05–0.08) or choose tint colors that contrast with the blue band. Visually verify in both Light and Dark Mode that the stddev band remains clearly distinguishable from the zone background

- [ ] Task 3: Add vertical divider lines at zone boundaries (AC: #1, #3)
  - [ ] 3.1 Add `RuleMark(x:)` at each zone boundary date — thin vertical line marking the transition
  - [ ] 3.2 Style with `StrokeStyle(lineWidth: 1)` and `.secondary` foreground — visible but not dominant

- [ ] Task 4: Add zone caption labels (AC: #1, #3)
  - [ ] 4.1 Add localized zone label strings: "Monthly"/"Monatlich", "Daily"/"Täglich", "Sessions"/"Sitzungen" via `bin/add-localization.py`
  - [ ] 4.2 Render zone labels as `.annotation(position: .top)` on the first data point of each zone, or as a `Text` overlay positioned at the zone start — use `.font(.caption2)` and `.foregroundStyle(.secondary)`
  - [ ] 4.3 Ensure labels appear in both scrollable and static chart modes

- [ ] Task 5: Handle single-zone edge case (AC: #4)
  - [ ] 5.1 Write test: given buckets all of the same `BucketSize`, verify no `RectangleMark` tints, no `RuleMark` dividers, and no zone labels are rendered (i.e., the helper returns empty zone separator data)
  - [ ] 5.2 Guard in the zone rendering logic: skip all zone separator rendering when `ChartLayoutCalculator.zoneBoundaries(for:)` returns a single boundary

- [ ] Task 6: Run full test suite
  - [ ] 6.1 Run `bin/test.sh` — all existing + new tests pass
  - [ ] 6.2 Run `bin/check-dependencies.sh` — no import rule violations

## Dev Notes

### Architecture & Key Decisions

**Zone separator rendering strategy:** Use Swift Charts' `RectangleMark` for background tints and `RuleMark(x:)` for vertical dividers, both rendered within the existing `chartContent` method. The key challenge is that `RectangleMark` needs x-range coordinates (start and end dates of each zone) — these come from the bucket array's `periodStart` dates at zone boundaries via `ChartLayoutCalculator.zoneBoundaries(for:)`.

**Background tint approach:** Since `GranularityZoneConfig` intentionally omits `backgroundTint` to avoid SwiftUI imports in Core/, the color mapping must live in the UI layer. Create a simple static dictionary or `switch` on `BucketSize` → `Color` in `ProgressChartView`. Use semantic system colors to auto-adapt for Dark Mode:
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
Apply at very low opacity (~0.05–0.08). The existing stddev band is `AreaMark` with `.foregroundStyle(.blue.opacity(0.15))` — an extremely subtle element. Zone tints must be faint enough that the band remains clearly visible on top. Test in both Light and Dark Mode: if the band blends into the zone background, reduce tint opacity further or adjust tint hue to avoid blue overlap.

**Vertical dividers:** `RuleMark(x: .value("Zone", boundaryDate))` with `.foregroundStyle(.secondary)` and `StrokeStyle(lineWidth: 1)`. Place after the `AreaMark`/`LineMark` so they render on top but before annotations.

**Zone labels:** There are two approaches — (a) use `RuleMark` or `PointMark` `.annotation(position: .top, alignment: .leading)` at the zone boundary, or (b) use a SwiftUI `.chartOverlay` with `GeometryProxy` to position `Text` labels. Approach (a) is simpler and keeps everything within the `Chart` DSL. Use the first `periodStart` date in each zone as the anchor for the annotation. Style: `.font(.caption2)`, `.foregroundStyle(.secondary)`.

**Data flow:** The zone separators consume the FULL bucket array (not the windowed slice) for zone boundary computation but render only within the visible window. Since `zoneBoundaries(for:)` returns indices, convert boundary indices to dates from the full bucket array, then let `RectangleMark`/`RuleMark` clipping handle visibility naturally within the scrollable chart.

**IMPORTANT: Full vs. windowed buckets for zone marks.** The windowed slice already clips to the visible range + buffer. Zone `RectangleMark` and `RuleMark` should be added to `chartContent` using zone boundaries computed from the FULL bucket array (for correct zone geometry), but only the zones that overlap with the visible slice need to be rendered. Compute zone boundaries once from the full array, then filter to those overlapping the visible window.

**WCAG 1.4.1 compliance:** Three information carriers for each zone transition: (1) background tint color change, (2) vertical divider line, (3) text label. This satisfies the "color is not the sole carrier" requirement.

### Existing Code to Understand

**`ProgressChartView.swift` (current, 268 lines):**
- `chartLayout(buckets:)` (line 76): Decides scrollable vs. static mode — zone separators must work in both.
- `chartContent(buckets:yDomain:)` (line 128): Renders `AreaMark` + `LineMark` + `RuleMark` + X-axis. Zone background tints, dividers, and labels should be added here.
- `scrollableChartBody(buckets:yDomain:)` (line 103): Passes `visibleSlice` to `chartContent` — zone boundaries must be computed from the FULL bucket array and passed down.
- `staticChartBody(buckets:yDomain:)` (line 124): Passes all buckets directly — zone boundaries computed from same array, simpler case.
- `zoneConfigs` (line 177): Static dictionary mapping `BucketSize` → `GranularityZoneConfig` — reuse for axis labels, extend with color mapping separately.

**`ChartLayoutCalculator.swift`:**
- `zoneBoundaries(for:)` — returns `[ZoneBoundary]` with `startIndex`, `endIndex`, `bucketSize`. This is the primary data source for zone rendering.

**`ZoneBoundary` struct:**
- `startIndex: Int`, `endIndex: Int`, `bucketSize: BucketSize` — index-based boundaries that need conversion to date-based boundaries for chart marks.

### Signature Changes

**`chartContent` needs zone boundary data.** Currently `chartContent(buckets:yDomain:)` receives only the windowed slice. It needs the zone boundaries (computed from full array) to render separators. Two options:
1. Pass zone boundaries as a parameter: `chartContent(buckets:yDomain:zoneBoundaries:allBuckets:)`
2. Compute within `chartLayout` and thread through

Option 1 is cleaner — the caller (`scrollableChartBody` or `staticChartBody`) computes zone boundaries from the full array and passes them in.

### Testing Patterns

Follow existing `ProgressChartViewTests` patterns:

**Static helper tests:**
1. Zone separator metadata: given 3-zone buckets (month + day + session), verify helper returns 2 boundary dates, 3 zone labels, and 3 tint colors
2. Single-zone: given all-day buckets, verify helper returns no separators (empty arrays)
3. Two-zone: given month + day buckets, verify 1 boundary, 2 labels
4. Zone label localization: verify zone label strings match expected keys

**Key test patterns:**
- Every `@Test` function must be `async`
- Behavioral descriptions: `@Test("returns no zone separators for single-zone buckets")`
- Use `#expect(value == expected)`
- Struct-based test suites, factory methods for fixtures

### File Placement

Modified files:
- `Peach/Profile/ProgressChartView.swift` — add zone background tints, divider lines, and caption labels in `chartContent`; add zone tint color mapping; thread zone boundary data through chart rendering methods

Updated test files:
- `PeachTests/Profile/ProgressChartViewTests.swift` — add tests for zone separator logic

Localization:
- `Peach/Localizable.xcstrings` — add "Monthly"/"Monatlich", "Daily"/"Täglich", "Sessions"/"Sitzungen" via `bin/add-localization.py`

### What NOT To Do

- Do NOT modify `ProgressTimeline.swift` — data layer is complete
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

### Project Structure Notes

- All chart view changes stay in `Peach/Profile/ProgressChartView.swift`
- `ProfileScreen.swift` should NOT need changes
- Core/ files are consumed read-only: `ChartLayoutCalculator`, `GranularityZoneConfig`, `ProgressTimeline`
- Run `bin/check-dependencies.sh` after implementation to verify import rules

### Previous Story Intelligence (41.2)

Key learnings from Story 41.2 implementation:
- `chartContent(buckets:yDomain:)` receives the windowed slice for scrollable mode. Zone boundary computation must use the FULL bucket array, not the windowed slice — otherwise zone boundaries shift during scrolling.
- `scrollPosition` is a `@State private var scrollPosition = Date()` bound to `.chartScrollPosition(x:)`. Zone marks exist in the same chart and will scroll naturally with the data.
- `bucketSizeByDate` dictionary is built for O(1) axis label lookups — similar pattern works for zone boundary date lookups.
- `ForEach` uses `id: \.periodStart` for stable SwiftUI identity — zone marks should use unique identifiers too.
- Y-domain is computed from ALL buckets to prevent axis shifting — zone tints should also span the full Y domain.
- Review found data windowing was initially dead code (C1 finding) — ensure zone separator rendering is actually connected and visible, not just computed.
- 1035 tests pass after 41.2.

### Git Intelligence

Recent commits follow `Implement story {id}: {description}` and `Review story {id}: {details}` pattern. Story 41.1 and 41.2 each had implementation + review commits.

### References

- [Source: docs/planning-artifacts/epics.md#Story 41.3] — Full acceptance criteria and technical hints
- [Source: docs/planning-artifacts/epics.md#Epic 41 Requirements] — FR4: Granularity zone separators (tint + dividers + labels), NFR1: WCAG 1.4.1
- [Source: docs/implementation-artifacts/41-2-scrollable-chart-with-fixed-y-axis.md] — Previous story: scrollable chart, data windowing, zone configs
- [Source: docs/implementation-artifacts/41-1-multi-granularity-bucket-pipeline.md] — ChartLayoutCalculator.zoneBoundaries, GranularityZoneConfig
- [Source: Peach/Profile/ProgressChartView.swift] — Current chart implementation (268 lines) to be extended
- [Source: Peach/Core/Profile/ChartLayoutCalculator.swift] — zoneBoundaries(for:) returns [ZoneBoundary]
- [Source: Peach/Core/Profile/GranularityZoneConfig.swift] — Zone configs (no backgroundTint by design)
- [Source: docs/project-context.md] — Coding conventions, Core/ import rules, testing rules, file placement

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
