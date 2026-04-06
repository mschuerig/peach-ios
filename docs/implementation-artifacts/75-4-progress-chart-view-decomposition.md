# Story 75.4: ProgressChartView Decomposition

Status: ready-for-dev

## Story

As a **developer working on chart visualization**,
I want `ProgressChartView` split into focused types,
so that data preparation, rendering, and interaction are separate concerns.

## Background

The walkthrough (Layer 6) identified `ProgressChartView` as the largest file in the codebase at 629 lines. It mixes at least 6 responsibilities: chart data preparation (positions, zones, line bridge), chart rendering (7 layers), axis formatting, scroll/selection interaction, accessibility, and export coordination. The `lineDataWithSessionBridge()` method performs a weighted mean/variance computation — a statistical calculation that belongs in the data layer, not the view.

Additionally, `ProgressTimeline.assignMultiGranularityBuckets` (Layer 4 observation #4) is a dense 55-line method handling three zone logic paths that would benefit from extraction.

**Walkthrough sources:** Layer 6 observation #2; Layer 4 observation #4.

## Acceptance Criteria

1. **Given** a new `ChartData` struct **When** constructed from profile/timeline data **Then** it contains all pre-computed chart data: bucket positions, zone boundaries, line data (including session bridge), year boundaries, stddev bands.
2. **Given** `lineDataWithSessionBridge()` **When** inspected **Then** its weighted mean/variance computation lives on `ChartData` or `ProgressTimeline`, not in the view file.
3. **Given** `ProgressChartView` **When** inspected **Then** it renders from a `ChartData` instance without computing positions, zones, or line data itself. Its static helper methods are replaced by `ChartData` properties or methods.
4. **Given** `ExportChartView` **When** inspected **Then** it constructs a `ChartData` and renders from it, instead of independently calling the same static methods that `ProgressChartView` formerly used.
5. **Given** `ProgressTimeline.assignMultiGranularityBuckets` **When** inspected **Then** its three zone logic paths (session, day, month) are extracted into zone-specific methods.
6. **Given** the resulting `ProgressChartView` file **When** measured **Then** it is significantly smaller than 629 lines, with each extracted type under ~200 lines.
7. **Given** both platforms **When** built and tested **Then** all tests pass, charts render identically, and share/export produces identical images.

## Tasks / Subtasks

- [ ] Task 1: Extract ChartData struct (AC: #1, #2)
  - [ ] Define `ChartData` with properties for: bucket positions, zone boundaries, line data points, session bridge data, year boundaries, stddev band data
  - [ ] Move `lineDataWithSessionBridge()` computation into `ChartData` (or `ProgressTimeline`)
  - [ ] Move position/zone/boundary computation from static helpers into `ChartData.init()` or factory

- [ ] Task 2: Refactor ProgressChartView to render from ChartData (AC: #3, #6)
  - [ ] Replace static method calls with reads from `ChartData` properties
  - [ ] Keep rendering (the 7 Chart layers), axis formatting, scroll/selection, and accessibility in the view
  - [ ] Consider further splits if the view is still large (e.g., axis formatting or accessibility into extensions)

- [ ] Task 3: Refactor ExportChartView (AC: #4)
  - [ ] Construct `ChartData` and pass it to the chart rendering, removing duplicated static method calls

- [ ] Task 4: Extract ProgressTimeline zone methods (AC: #5)
  - [ ] Extract session zone bucketing from `assignMultiGranularityBuckets`
  - [ ] Extract day zone bucketing
  - [ ] Extract month zone bucketing
  - [ ] `assignMultiGranularityBuckets` becomes a coordinator that calls the three zone methods

- [ ] Task 5: Verify visual and functional identity (AC: #7)
  - [ ] `bin/test.sh && bin/test.sh -p mac`
  - [ ] Manual check: chart renders identically in both regular and export/share views
  - [ ] Verify scrolling, selection, annotations, year labels, contrast accessibility

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| New: `Peach/Profile/ChartData.swift` | Pre-computed chart data model |
| `Peach/Profile/ProgressChartView.swift` (629 lines) | Slim down to rendering only |
| `Peach/Profile/ExportChartView.swift` (139 lines) | Use ChartData instead of static method calls |
| `Peach/Core/Profile/ProgressTimeline.swift` (268 lines) | Extract zone-specific bucketing methods |

### The Six Responsibilities to Separate

1. **Chart data preparation** — positions, zones, line bridge, year boundaries → `ChartData`
2. **Chart rendering** — 7-layer `Chart` body → stays in `ProgressChartView`
3. **Axis formatting and domain configuration** → stays in view (or extension)
4. **Scroll/selection interaction** → stays in view
5. **Accessibility** (contrast, VoiceOver) → stays in view (or extension)
6. **Share/export coordination** → stays in view (delegates to `ChartData` for data)

### lineDataWithSessionBridge() — The Statistical Computation

This method computes a weighted average of session data points to extend the EWMA trend line from the last day bucket into the session zone. It uses `WelfordAccumulator` for variance. This is a data computation, not a rendering concern — it should live in `ChartData.init()` or as a `ProgressTimeline` method.

### Contrast Accessibility

All opacity values have `contrastAdjustedOpacity` variants. These should stay near the rendering code, not move to `ChartData`. `ChartData` is pure data; accessibility is a rendering concern.

### What NOT to Change

- Do not change the 7-layer chart rendering order or visual appearance
- Do not change the scrolling behavior or selection interaction
- Do not change `ChartImageRenderer` — it just wraps `ImageRenderer`

### References

- [Source: docs/walkthrough/6-screens-and-navigation.md — observation #2]
- [Source: docs/walkthrough/4-data-and-profiles.md — observation #4]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
