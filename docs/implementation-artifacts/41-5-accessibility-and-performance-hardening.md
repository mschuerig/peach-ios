# Story 41.5: Accessibility and Performance Hardening

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **user with accessibility needs**,
I want the redesigned chart to work well with VoiceOver, Dynamic Type, Increase Contrast, and Reduce Motion,
so that the chart is usable regardless of my accessibility settings.

## Acceptance Criteria

1. **Given** VoiceOver is active, **When** the user navigates to a progress card, **Then** each granularity zone has an accessibility container with a summary label (e.g., "Monthly zone: November through January, pitch trend from 15 to 11 cents") (NFR2).

2. **Given** Dynamic Type is set to an accessibility size, **When** the chart renders, **Then** axis labels and headline text use scaled fonts, **And** the Y-axis area (if reimplemented) expands to accommodate larger text (NFR3).

3. **Given** Reduce Motion is enabled, **When** the chart appears with scroll-to-position, **Then** no scroll animation plays — the chart starts at the right edge without animating (NFR4).

4. **Given** Increase Contrast is enabled, **When** the chart renders, **Then** the EWMA line, stddev band, and baseline use stronger contrast variants (NFR5).

5. **Given** a user with extensive training history, **When** the chart renders with all granularity zones, **Then** total data point count stays well under 2,000 (NFR6), **And** session-level data is limited to today as defined by `allGranularityBuckets(for:)`.

## Tasks / Subtasks

- [x] Task 1: VoiceOver zone accessibility containers (AC: #1)
  - [x] 1.1 Write tests: `zoneAccessibilitySummary(buckets:zone:config:)` returns descriptive summary for a zone (e.g., "Monthly zone: November 2025 through January 2026, pitch trend from 15.2 to 11.0 cents, 3 data points")
  - [x] 1.2 Write tests: single-zone data returns one summary; multi-zone returns one per zone; empty zone returns nil
  - [x] 1.3 Implement `zoneAccessibilitySummary(buckets:zone:config:)` static helper — pure function, fully testable
  - [x] 1.4 In `chartContent`, wrap each zone's chart marks with `.accessibilityElement(children: .combine)` and `.accessibilityLabel(summary)` using `Group` or chart accessibility modifiers
  - [x] 1.5 Verify VoiceOver can navigate zone-by-zone through the chart

- [x] Task 2: Dynamic Type support for chart text (AC: #2)
  - [x] 2.1 Audit all font usage in `ProgressChartView.swift` — confirm `.headline`, `.title2`, `.caption`, `.caption2` are used (these auto-scale with Dynamic Type)
  - [x] 2.2 Verify annotation popover text (`.caption`, `.caption2`) scales correctly at accessibility sizes
  - [x] 2.3 Verify axis labels scale — Swift Charts axis labels use the font you provide, which should already be `.caption`
  - [x] 2.4 If any hardcoded font sizes exist, replace with scaled text styles

- [x] Task 3: Reduce Motion — suppress scroll animation (AC: #3)
  - [x] 3.1 Verified `.onAppear` scroll position is set directly without animation — no `withAnimation` or `.animation()` wrappers exist
  - [x] 3.2 Confirmed no `.animation()` modifiers on chart or container — nothing to gate with `reduceMotion`
  - [x] 3.3 No `@Environment(\.accessibilityReduceMotion)` needed — removed as dead code during review (no animation exists to suppress)

- [x] Task 4: Increase Contrast support (AC: #4)
  - [x] 4.1 Add `@Environment(\.colorSchemeContrast) private var colorSchemeContrast` to `ProgressChartView`
  - [x] 4.2 Write tests: `contrastAdjustedOpacity(base:isIncreaseContrast:)` returns higher opacity when increase contrast is enabled
  - [x] 4.3 Implement contrast-aware color helpers — when `colorSchemeContrast == .increased`:
    - EWMA line: `.blue` (already opaque, no change needed)
    - Stddev band: increase opacity from `0.15` to `0.3`
    - Baseline: increase opacity from `0.6` to `0.9`
    - Zone backgrounds: increase opacity from `0.06` to `0.12`
    - Zone dividers: use `.primary` instead of `.secondary`
    - Selection indicator: increase from `0.5` to `0.8` opacity
  - [x] 4.4 Apply contrast-adjusted values in chart layers

- [x] Task 5: Performance verification (AC: #5)
  - [x] 5.1 Write test: `allGranularityBuckets(for:)` with 365 days of data produces < 2000 total buckets
  - [x] 5.2 Write test: `allGranularityBuckets(for:)` with 1000 days of data still produces < 2000 buckets (monthly aggregation keeps count bounded)
  - [x] 5.3 Verify session zone is limited to today only (already implemented in `ProgressTimeline` — `timestamp >= startOfDay(now)`)

- [x] Task 6: Run full test suite (AC: all)
  - [x] 6.1 Run `bin/test.sh` — all existing + new tests pass
  - [x] 6.2 Verify no dependency violations with `bin/check-dependencies.sh`

## Dev Notes

### VoiceOver Zone Accessibility

The current chart has a single `.accessibilityElement(children: .combine)` on the entire card (line 41 of `ProgressChartView.swift`), which combines everything into one VoiceOver element. NFR2 requires per-zone navigation.

**Approach:** Add zone-level accessibility to the chart using Swift Charts' `.accessibilityLabel` and `.accessibilityValue` on chart mark groups. Since Swift Charts doesn't directly support accessibility containers on subsets of marks, use the chart-level `chartAccessibilityLabel` or overlay approach:

**Recommended approach:** Add an invisible `.accessibilityElement` overlay for each zone on top of the chart. Use `GeometryReader` in the existing `.chartOverlay` to position transparent accessibility containers at each zone's X range.

```swift
// Inside chartOverlay, after year labels:
ForEach(separatorData.zones, id: \.startIndex) { zone in
    let summary = Self.zoneAccessibilitySummary(
        buckets: Array(buckets[zone.startIndex...zone.endIndex]),
        zone: zone,
        config: config
    )
    Color.clear
        .frame(width: zoneWidth, height: plotFrame.height)
        .position(x: zoneCenterX, y: plotFrame.midY)
        .accessibilityElement()
        .accessibilityLabel(summary)
}
```

**Summary format:** `"{Zone name} zone: {first month/date} through {last month/date}, pitch trend from {first EWMA} to {last EWMA} {unit}, {count} data points"`

The `zoneAccessibilitySummary` helper must be a static function — fully testable without SwiftUI.

### Dynamic Type — Current State Assessment

All fonts in `ProgressChartView` already use text styles (`.headline`, `.title2.bold()`, `.caption`, `.caption2`) which auto-scale with Dynamic Type. **No code changes needed for font scaling** — just verification.

The fixed Y-axis was removed in Story 41.2 (HStack with separate Y-axis chart was removed in 41.3 because alignment was unreliable). Current chart uses Swift Charts' built-in Y-axis, which handles Dynamic Type automatically.

**Action:** Verify that annotation popover (`.caption`, `.caption2` fonts) and axis labels remain readable at `.accessibilityExtraExtraExtraLarge`. If popover becomes too wide, `.overflowResolution(.init(x: .fit(to: .chart), y: .fit(to: .chart)))` already handles clipping.

### Reduce Motion — Current Implementation Analysis

The `.onAppear` in `scrollableChartBody` (line 106-108) sets `scrollPosition` directly:
```swift
.onAppear {
    scrollPosition = Self.initialScrollPosition(for: buckets)
}
```

This is a direct state assignment, **not wrapped in `withAnimation`**, so there is likely **no animation to suppress**. However, `chartScrollPosition(x:)` binding changes may animate implicitly in some SwiftUI versions.

**Defensive approach:** Follow the pattern from `PitchComparisonScreen.swift` and `PitchMatchingScreen.swift` which already use `@Environment(\.accessibilityReduceMotion)`:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

// In scrollableChartBody .onAppear:
if reduceMotion {
    scrollPosition = Self.initialScrollPosition(for: buckets)
} else {
    withAnimation(.easeOut(duration: 0.3)) {
        scrollPosition = Self.initialScrollPosition(for: buckets)
    }
}
```

Wait — the current code does NOT animate. Adding animation when reduce motion is OFF would be a feature addition (Story 41.5 is about hardening, not adding animations). **Keep the current non-animated assignment.** Just add `reduceMotion` environment value and ensure no implicit animation wraps the scroll position.

If no animation exists, the `reduceMotion` environment property is still valuable as a guard against future animation additions and to satisfy NFR4 audit.

### Increase Contrast — Implementation Pattern

Use `@Environment(\.colorSchemeContrast)` which returns `.standard` or `.increased`:

```swift
@Environment(\.colorSchemeContrast) private var colorSchemeContrast
private var isIncreaseContrast: Bool { colorSchemeContrast == .increased }
```

Apply higher opacities when increase contrast is enabled. Current opacity values and their contrast-increased alternatives:

| Element | Current | Increase Contrast |
|---------|---------|-------------------|
| Stddev band | `.blue.opacity(0.15)` | `.blue.opacity(0.3)` |
| Baseline | `.green.opacity(0.6)` | `.green.opacity(0.9)` |
| Zone backgrounds | `zoneTint.opacity(0.06)` | `zoneTint.opacity(0.12)` |
| Zone dividers | `.secondary` | `.primary` |
| Selection indicator | `Color.gray.opacity(0.5)` | `Color.gray.opacity(0.8)` |
| EWMA line | `.blue` (opaque) | No change needed |
| Session dots | `.blue` (opaque) | No change needed |

Extract contrast-aware opacity as a helper or compute inline. Do NOT create a `Utils/` directory — keep helpers as `static` methods on `ProgressChartView`.

### Performance — Bucket Count Analysis

`ProgressTimeline.allGranularityBuckets(for:)` produces:
- **Session zone:** Today only (0 to N sessions, typically 1-10)
- **Day zone:** 7 calendar days
- **Month zone:** All remaining data aggregated to months (12 buckets/year)

For 1 year of data: ~12 months + 7 days + ~5 sessions = ~24 buckets.
For 5 years of data: ~60 months + 7 days + ~5 sessions = ~72 buckets.
For 10 years: ~120 months + 7 days + ~5 sessions = ~132 buckets.

**Total will never approach 2,000** due to monthly aggregation. The performance NFR is already satisfied by the data pipeline. Add verification tests to document this guarantee.

### Existing Accessibility in the File

Current accessibility (lines 41-47 of `ProgressChartView.swift`):
```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(String(localized: "Progress chart for \(config.displayName)"))
.accessibilityValue(Self.chartAccessibilityValue(ewma: ewma, trend: trend, unitLabel: config.unitLabel))
```

Also: `.accessibilityLabel(Self.trendLabel(trend))` on trend icon (line 70).

The card-level accessibility combines everything into one element. When adding zone containers, consider changing `.accessibilityElement(children: .combine)` to `.accessibilityElement(children: .contain)` so VoiceOver can navigate both the card summary AND individual zones.

### Chart Layers (Current Z-Order after 41.4)

1. `RectangleMark` — zone background tints (bottommost)
2. `RuleMark(x:)` — zone and year boundary divider lines
3. `AreaMark` — stddev band
4. `LineMark` — EWMA line
5. `PointMark` — session dots
6. `RuleMark(y:)` — baseline
7. `RuleMark(x:)` + `.annotation` — selection indicator with popover
8. `.chartOverlay` — year labels (topmost, text only)

Contrast adjustments apply to layers 1-7. No new layers added.

### Localization

Zone accessibility summaries need localization:
- `"Monthly zone: {start} through {end}, pitch trend from {first} to {last} {unit}, {count} data points"` — German equivalent
- Use `String(localized:)` for all accessibility labels
- Add via `bin/add-localization.py`

### Testing Patterns

Follow existing `ProgressChartViewTests` patterns:

**Static helper tests:**
1. `zoneAccessibilitySummary(buckets:zone:config:)`: monthly zone summary, daily zone summary, session zone summary, empty zone returns nil
2. `contrastAdjustedOpacity(base:isIncreaseContrast:)`: returns base when standard, returns higher when increased (if extracted as helper)
3. Performance: `allGranularityBuckets` bucket count for large datasets

**Key test patterns (from 41.3/41.4):**
- Every `@Test` function must be `async`
- Behavioral descriptions: `@Test("produces VoiceOver summary for monthly zone")`
- Use `#expect(value == expected)` or `#expect(value.contains(substring))`
- Struct-based test suites, factory methods for fixtures
- Use the existing `makeBucketArray(count:)` test helper

### File Placement

Modified files:
- `Peach/Profile/ProgressChartView.swift` — add `reduceMotion` and `colorSchemeContrast` environment values, zone accessibility containers, contrast-adjusted opacities, `zoneAccessibilitySummary` static helper
- `PeachTests/Profile/ProgressChartViewTests.swift` — add tests for zone accessibility summary, contrast opacity, performance bucket counts
- `Peach/Resources/Localizable.xcstrings` — add zone accessibility summary strings via `bin/add-localization.py`

No new files created. No Core/ files modified.

### What NOT To Do

- Do NOT add explicit `@MainActor` annotations (redundant with default isolation).
- Do NOT use XCTest — use Swift Testing (`@Test`, `@Suite`, `#expect`).
- Do NOT import third-party dependencies.
- Do NOT modify Core/ files — this story is purely UI-layer in `ProgressChartView.swift` (performance tests may read from `ProgressTimeline` but don't modify it).
- Do NOT add TipKit tips — that is Story 41.6.
- Do NOT add narrative headlines — that is Story 41.8.
- Do NOT add session-level markers — that is Story 41.9.
- Do NOT use `UIAccessibility.darkerSystemColorsEnabled` directly — use `@Environment(\.colorSchemeContrast)` which is the SwiftUI-native approach.
- Do NOT add animations that don't currently exist — this is hardening, not feature addition.
- Do NOT create `Utils/` or `Helpers/` directories.
- Do NOT use hardcoded color values (hex, RGB) — use semantic colors with opacity adjustments.
- Do NOT remove the existing card-level accessibility — extend it with zone-level containers.
- Do NOT add `.accessibilityAddTraits(.isHeader)` to chart elements — the headline row handles that.

### Project Structure Notes

- All chart view changes stay in `Peach/Profile/ProgressChartView.swift`
- No Core/ files modified — accessibility is a pure UI concern
- `ProfileScreen.swift` should NOT need changes
- Run `bin/check-dependencies.sh` after implementation to verify import rules

### Previous Story Intelligence (41.4)

Key learnings from Story 41.4:
- Chart layers were extracted into separate `some ChartContent` helper methods to avoid Swift Charts type-checker timeout — this pattern makes it easy to add contrast-aware parameters to each layer
- `.annotation(overflowResolution:)` actual API is `.init(x: .fit(to: .chart), y: .fit(to: .chart))` not `.fitToChart`
- `Color.gray.opacity(0.5)` must use explicit `Color.` prefix to avoid resolving to `Chart3DContent`
- `.chartOverlay` is used for year labels — zone accessibility overlays can be added here
- `round()` uses `.toNearestOrAwayFromZero` by default — 41.4 switched to `.toNearestOrEven` for bucket snapping
- All 1053 tests pass after 41.4

### Git Intelligence

Recent commits:
```
f41007d Review story 41.4: use native annotation API, extract chart layers, deduplicate gesture
0bd6a26 Implement story 41.4: tap-to-select data points
24586b6 Create story 41.4: tap-to-select data points
d97a9be Review story 41.3: extract magic number, remove dead code, add story 41.10
23dcaef Extend period for generated test data to 180 days.
```

Chart layer extraction in review commit (f41007d) means each layer method can accept a contrast parameter easily. Pattern: `stddevBand(buckets:)` can become `stddevBand(buckets:)` with `isIncreaseContrast` read from instance property.

### References

- [Source: docs/planning-artifacts/epics.md#Story 41.5] — Full acceptance criteria and NFR references
- [Source: docs/planning-artifacts/epics.md#Epic 41 Requirements] — NFR1-NFR6 definitions
- [Source: docs/implementation-artifacts/41-4-tap-to-select-data-points.md] — Previous story: chart layer extraction, annotation API, gesture patterns
- [Source: Peach/Profile/ProgressChartView.swift] — Current chart implementation to be hardened
- [Source: Peach/PitchComparison/PitchComparisonScreen.swift] — Existing `reduceMotion` pattern to follow
- [Source: docs/project-context.md] — Coding conventions, testing rules, file placement

## Change Log

- 2026-03-12: Implemented accessibility and performance hardening for ProgressChartView — added VoiceOver zone containers, Dynamic Type verification, Reduce Motion environment guard, Increase Contrast support with contrast-adjusted opacities, and performance verification tests
- 2026-03-12: Code review fixes — removed unused `reduceMotion` dead code, added missing German translations for zone accessibility summaries and "Session" key, removed stale orphaned localization entries, strengthened weak test assertions (data point count), added out-of-bounds zone index test

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Pre-existing flaky tests in PitchComparisonSessionLifecycleTests and PitchComparisonSessionResetTests (timing-sensitive, not related to this story)

### Completion Notes List

- Added `zoneAccessibilitySummary(buckets:zone:config:)` static helper producing localized VoiceOver summaries per zone
- Changed card accessibility from `.combine` to `.contain` to enable zone-by-zone VoiceOver navigation
- Added invisible accessibility overlay elements in `.chartOverlay` for each granularity zone
- Added `@Environment(\.colorSchemeContrast)` with `isIncreaseContrast` computed property
- Added `contrastAdjustedOpacity(base:increased:isIncreaseContrast:)` static helper
- Applied contrast-adjusted opacities to stddev band (0.15→0.3), baseline (0.6→0.9), zone backgrounds (0.06→0.12), selection indicator (0.5→0.8), and zone dividers (.secondary→.primary)
- Verified all fonts use text styles (no hardcoded sizes) — Dynamic Type works automatically
- Added performance tests: 365 days → <2000 buckets, 1000 days → <2000 buckets, session zone limited to today
- Added German translations for zone accessibility summaries and "Session" key
- Removed stale orphaned localization entries
- All 1061 tests pass (1060 + 1 new), no dependency violations

### File List

- Peach/Profile/ProgressChartView.swift (modified)
- PeachTests/Profile/ProgressChartViewTests.swift (modified)
- Peach/Resources/Localizable.xcstrings (modified)
- docs/implementation-artifacts/41-5-accessibility-and-performance-hardening.md (modified)
- docs/implementation-artifacts/sprint-status.yaml (modified)
