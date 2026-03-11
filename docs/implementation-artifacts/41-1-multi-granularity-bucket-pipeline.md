# Story 41.1: Multi-Granularity Bucket Pipeline

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want `ProgressTimeline` to produce concatenated multi-granularity buckets and a layout calculator to compute zone geometry,
So that the scrollable chart has a clean, testable data source with all granularity zones in a single ordered array.

## Acceptance Criteria

1. **Given** `ProgressTimeline` with training data spanning multiple months, **When** `allGranularityBuckets(for:)` is called, **Then** it returns `[TimeBucket]` ordered chronologically with months for data >30 days, days for 1–30 days, and sessions for <24 hours — all concatenated left-to-right. Each bucket retains its `BucketSize` tag so the UI can distinguish zones.

2. **Given** the concatenated bucket array, **When** passed to `ChartLayoutCalculator`, **Then** it computes total chart width from bucket count × per-granularity point widths. It returns zone boundary indices marking where granularity transitions occur.

3. **Given** a `GranularityZoneConfig` protocol, **When** concrete conformances exist for `MonthlyZoneConfig`, `DailyZoneConfig`, `SessionZoneConfig`, **Then** each provides `pointWidth: CGFloat`, `backgroundTint: Color`, and `axisLabelFormatter: (Date) -> String`. Adding a new granularity (e.g., weekly) requires only a new conformance — no changes to existing code.

4. **Given** a user with only 1 day of training data, **When** `allGranularityBuckets(for:)` is called, **Then** it returns only session-granularity buckets (no empty month/day zones).

5. **Given** the existing `buckets(for:)` API, **When** the new method is added, **Then** the existing API continues to work unchanged (no breaking changes).

## Tasks / Subtasks

- [x] Task 1: Add `allGranularityBuckets(for:)` to `ProgressTimeline` (AC: #1, #4, #5)
  - [x] 1.1 Write tests first in `PeachTests/Core/Profile/ProgressTimelineTests.swift` — multi-month data produces month+day+session concatenation; single-day data produces only sessions; empty data returns empty array; boundary dates (exactly 24h, exactly 30d) are assigned correctly
  - [x] 1.2 Implement `allGranularityBuckets(for:)` in `ProgressTimeline.swift` — new public method that regroups `allMetrics` into age-based granularity zones concatenated chronologically. Do NOT modify `buckets(for:)` or `assignBuckets`
  - [x] 1.3 Verify existing `buckets(for:)` tests still pass unchanged

- [x] Task 2: Create `GranularityZoneConfig` protocol and conformances (AC: #3)
  - [x] 2.1 Write tests first in `PeachTests/Core/Profile/GranularityZoneConfigTests.swift` — each config returns expected pointWidth, backgroundTint, and axis labels formatted correctly for sample dates
  - [x] 2.2 Create `Peach/Core/Profile/GranularityZoneConfig.swift` — protocol definition + `MonthlyZoneConfig`, `DailyZoneConfig`, `SessionZoneConfig` conformances
  - [x] 2.3 Resolve the `Color` import issue: `GranularityZoneConfig` lives in Core/ which must not import SwiftUI. Use a `struct GranularityTint` wrapper with semantic named colors (e.g., `.primary`, `.secondary`) that the UI layer maps to SwiftUI `Color` values. OR define the protocol in Core/ without `backgroundTint` and extend with a computed property in the Profile/ UI layer

- [x] Task 3: Create `ChartLayoutCalculator` (AC: #2)
  - [x] 3.1 Write tests first in `PeachTests/Core/Profile/ChartLayoutCalculatorTests.swift` — total width computation, zone boundary indices for various bucket arrays, single-zone case returns no boundaries, empty array returns zero width
  - [x] 3.2 Create `Peach/Core/Profile/ChartLayoutCalculator.swift` — pure enum with static methods: `totalWidth(for:configs:)`, `zoneBoundaries(for:)`. No UI dependencies

- [x] Task 4: Run full test suite
  - [x] 4.1 Run `bin/test.sh` — all existing + new tests pass

## Dev Notes

### Architecture & Key Decisions

**New method, not a modification:** `allGranularityBuckets(for:)` is a new public method on `ProgressTimeline`. The existing `buckets(for:)` continues to work exactly as before — it uses adaptive bucketing based on data age relative to `now`. The new method instead produces a concatenated multi-granularity array where all three granularity levels coexist in one timeline.

**Bucketing logic for `allGranularityBuckets`:** The new method groups the same `allMetrics` data but with a different bucketing strategy:
- Data older than 30 days → `.month` buckets (using `Calendar.dateInterval(of: .month)`)
- Data 1–30 days old → `.day` buckets (using `Calendar.startOfDay`)
- Data <24 hours old → `.session` buckets (using `sessionGap` from `TrainingModeConfig`)
- All concatenated left-to-right chronologically in a single `[TimeBucket]` array

This is conceptually similar to `assignBuckets` (lines 339–399 in `ProgressTimeline.swift`) but removes the `.week` granularity (per epic spec — weekly is omitted for simplicity) and concatenates all zones rather than choosing one per data point.

**No `.week` bucket size in the new method:** The epic spec explicitly omits weekly granularity ("Start without — add later if monthly→daily feels too abrupt"). The existing `BucketSize.week` case remains for backward compatibility with `buckets(for:)` and `subBuckets(for:expanding:)`.

**`GranularityZoneConfig` and Core/ import rules:** Core/ files must NOT import SwiftUI (enforced by `bin/check-dependencies.sh`). Two approaches:
1. **Preferred:** Define the protocol in Core/ with `pointWidth: CGFloat` (CoreGraphics, allowed) and `axisLabelFormatter: (Date) -> String`. Omit `backgroundTint` from the Core/ protocol. Add a UI-layer extension or lookup that maps `BucketSize` → `Color` in the Profile/ feature directory.
2. **Alternative:** Use a custom `struct GranularityTint` with named semantic slots that the UI layer resolves.

CGFloat is from CoreGraphics (Foundation re-exports it), so `pointWidth: CGFloat` is safe in Core/.

**`ChartLayoutCalculator` as pure static enum:** Following the project pattern of using enums with static methods for stateless utilities (like `SF2PresetParser`). Input: `[TimeBucket]` + zone configs. Output: total width (`CGFloat`), zone boundaries (`[ZoneBoundary]` with `startIndex`, `endIndex`, `bucketSize`).

### Existing Code to Understand

**`ProgressTimeline.assignBuckets` (line 339):** Current adaptive bucketing — assigns each metric to a single granularity based on age. The new `allGranularityBuckets` uses the same age thresholds (`recentThreshold`, `weekThreshold`, `monthThreshold`) but skips `.week` and concatenates all zones.

**`ProgressTimeline.ModeState.allMetrics` (line 227):** Sorted `[MetricPoint]` array with timestamp and value. This is the data source for the new method. Access it via `modeData[mode]?.allMetrics`.

**`ProgressTimeline.buildModeState` (line 317):** Shows the pattern for creating buckets from sorted metrics — sort, iterate, group, compute mean/stddev.

**`TrainingModeConfig.sessionGap` (line 22):** `.seconds(1800)` (30 minutes). Used to determine when two consecutive records belong to the same session.

**Age thresholds (lines 129–136):**
- `recentThreshold = 24 * 3600` (24 hours → session)
- `weekThreshold = 7 * 86400` (7 days — NOT used in new method)
- `monthThreshold = 30 * 86400` (30 days → month vs day boundary)

### Testing Patterns

Follow the existing `ProgressTimelineTests` patterns:
- Use `makePitchComparisonRecord(centOffset:hoursAgo:)` and `makePitchMatchingRecord(userCentError:hoursAgo:)` factory methods
- Use `now.addingTimeInterval(-hours * 3600)` for timestamps at specific ages
- For multi-month data: `now.addingTimeInterval(-days * 86400)` with days > 30
- Test struct uses `private let now = Date()` as reference
- Every `@Test` function must be `async`
- Behavioral descriptions: `@Test("multi-month data produces month, day, and session zones")`

**Key test scenarios for `allGranularityBuckets`:**
1. Data spanning 60+ days → should have `.month` + `.day` + `.session` zones
2. Data from 5–10 days ago + today → `.day` + `.session` zones only (no `.month`)
3. Data only from last 12 hours → `.session` zone only
4. Empty mode → empty array
5. Boundary: record exactly 30 days old → `.month` zone
6. Boundary: record exactly 24 hours old → `.day` zone (not `.session`)
7. Session merging: two records 10 minutes apart (<30 min gap) → one `.session` bucket
8. Verify all buckets sorted chronologically
9. Verify each bucket retains correct `BucketSize` tag
10. Verify `buckets(for:)` still returns identical results (regression)

**Key test scenarios for `ChartLayoutCalculator`:**
1. Mixed zone array → correct total width (sum of bucket count × per-zone pointWidth)
2. Zone boundaries at correct indices
3. Single zone → no boundaries, just total width
4. Empty array → zero width, no boundaries

**Key test scenarios for `GranularityZoneConfig`:**
1. `MonthlyZoneConfig.axisLabelFormatter` → "Jan", "Feb", etc.
2. `DailyZoneConfig.axisLabelFormatter` → "Mon", "Tue", etc.
3. `SessionZoneConfig.axisLabelFormatter` → relative time string
4. Each config returns expected `pointWidth`

### File Placement

New files:
- `Peach/Core/Profile/GranularityZoneConfig.swift` — protocol + conformances (no SwiftUI)
- `Peach/Core/Profile/ChartLayoutCalculator.swift` — pure static enum
- `PeachTests/Core/Profile/GranularityZoneConfigTests.swift`
- `PeachTests/Core/Profile/ChartLayoutCalculatorTests.swift`

Modified files:
- `Peach/Core/Profile/ProgressTimeline.swift` — add `allGranularityBuckets(for:)` method
- `PeachTests/Core/Profile/ProgressTimelineTests.swift` — add tests for new method

### What NOT To Do

- Do NOT modify `buckets(for:)`, `assignBuckets`, or `subBuckets(for:expanding:)` — they must remain unchanged
- Do NOT add `import SwiftUI` or `import Charts` in any Core/ file
- Do NOT create a `Utils/` or `Helpers/` directory
- Do NOT add `.week` buckets to `allGranularityBuckets` — weekly is intentionally omitted per epic spec
- Do NOT create `@Observable` classes for the calculator or zone configs — they are pure value types / static utilities
- Do NOT use `ObservableObject`, `@Published`, `Combine`, or `@EnvironmentObject`
- Do NOT add explicit `@MainActor` annotations (redundant with default isolation)
- Do NOT use XCTest — use Swift Testing (`@Test`, `@Suite`, `#expect`)
- Do NOT import third-party dependencies
- Do NOT modify `ProgressChartView.swift` — chart UI changes are Story 41.2
- Do NOT implement scrollable chart, tap-to-select, TipKit, or narrative headlines — those are Stories 41.2–41.8

### Project Structure Notes

- All new Core/ files go in `Peach/Core/Profile/` alongside existing `ProgressTimeline.swift` and `TrainingModeConfig.swift`
- All new test files go in `PeachTests/Core/Profile/` alongside existing `ProgressTimelineTests.swift`
- No cross-feature coupling — this story is entirely within Core/Profile
- Run `bin/check-dependencies.sh` after implementation to verify import rules

### References

- [Source: docs/planning-artifacts/epics.md#Story 41.1] — Full acceptance criteria and technical hints
- [Source: docs/planning-artifacts/research/technical-profile-screen-chart-ux-research-2026-03-11.md] — Multi-granularity timeline design, protocol-based zone configs, performance constraints
- [Source: docs/implementation-artifacts/38-3-progresschartview-and-profile-screen-redesign.md] — Previous profile chart implementation, ProgressTimeline API usage patterns
- [Source: Peach/Core/Profile/ProgressTimeline.swift] — Current implementation: `assignBuckets` (line 339), `ModeState.allMetrics` (line 227), age thresholds (lines 129–136)
- [Source: Peach/Core/Profile/TrainingModeConfig.swift] — `sessionGap`, `optimalBaseline`, per-mode configs
- [Source: Peach/Profile/ProgressChartView.swift] — Current chart view consuming `buckets(for:)` API
- [Source: docs/project-context.md] — Coding conventions, Core/ import rules, testing rules, file placement

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (claude-opus-4-6)

### Debug Log References

- Initial GranularityZoneConfig axis label tests failed due to locale-dependent formatting (simulator uses German locale). Fixed by making tests locale-aware instead of hardcoding English abbreviations.

### Completion Notes List

- Implemented `allGranularityBuckets(for:)` on `ProgressTimeline` — new public method producing concatenated multi-granularity `[TimeBucket]` array (month → day → session, no weekly). Existing `buckets(for:)` API unchanged.
- Created `GranularityZoneConfig` protocol in Core/ with `pointWidth: CGFloat` and `axisLabelFormatter: (Date) -> String`. Three conformances: `MonthlyZoneConfig` (30pt), `DailyZoneConfig` (40pt), `SessionZoneConfig` (50pt). `backgroundTint` intentionally omitted from Core/ to avoid SwiftUI import — UI layer maps `BucketSize` → `Color` separately.
- Created `ChartLayoutCalculator` as pure static enum with `totalWidth(for:configs:)` and `zoneBoundaries(for:)`. Returns `[ZoneBoundary]` with `startIndex`, `endIndex`, `bucketSize`.
- All 1027 tests pass (1010 existing + 17 new). No regressions. `bin/check-dependencies.sh` passes.

### Change Log

- 2026-03-11: Implemented story 41.1 — multi-granularity bucket pipeline with GranularityZoneConfig protocol and ChartLayoutCalculator

### File List

New files:
- Peach/Core/Profile/GranularityZoneConfig.swift
- Peach/Core/Profile/ChartLayoutCalculator.swift
- PeachTests/Core/Profile/GranularityZoneConfigTests.swift
- PeachTests/Core/Profile/ChartLayoutCalculatorTests.swift

Modified files:
- Peach/Core/Profile/ProgressTimeline.swift
- PeachTests/Core/Profile/ProgressTimelineTests.swift
- docs/implementation-artifacts/sprint-status.yaml
- docs/implementation-artifacts/41-1-multi-granularity-bucket-pipeline.md
