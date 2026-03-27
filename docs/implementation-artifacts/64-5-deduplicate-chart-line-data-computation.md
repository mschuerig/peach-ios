# Story 64.5: Deduplicate Chart Line Data Computation and Fix Unstable ForEach Identity

Status: review

## Story

As a **user viewing training charts**,
I want the progress chart and spectrogram to render efficiently,
so that scrolling is smooth and tapping a cell doesn't cause the entire grid to be recomputed.

## Acceptance Criteria

1. **Given** `ProgressChartView.chartContent()` **When** rendering the stddev band and EWMA line **Then** `lineDataWithSessionBridge()` is called once and the result is shared between both chart layers, not computed twice.

2. **Given** `ProgressChartView` ForEach loops for year labels, zone backgrounds, and zone accessibility **When** data changes (new bucket added) **Then** ForEach uses stable identifiers (not `\.offset` from `Array.enumerated()`), preventing full view teardown and recreation.

3. **Given** `RhythmSpectrogramView` **When** the user taps a cell (changing `selectedCell`) **Then** `SpectrogramData.compute()` is NOT called again — the computed data is cached and only recalculated when the underlying record count changes.

4. **Given** `RhythmSpectrogramView` ForEach loops for columns and labels **When** data changes **Then** ForEach uses stable identifiers, not enumeration offsets.

5. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Deduplicate `lineDataWithSessionBridge()` call (AC: #1)
  - [x] 1.1 In `chartContent()`, call `lineDataWithSessionBridge(for: buckets)` once and store in a local `let lineData`
  - [x] 1.2 Pass `lineData` to both `stddevBand()` and `ewmaLine()` as a parameter instead of having each call the function independently
  - [x] 1.3 Update the static method signatures to accept `[LinePoint]` instead of `[TimeBucket]`

- [x] Task 2: Fix unstable ForEach identity in `ProgressChartView` (AC: #2)
  - [x] 2.1 For `yearLabels`: add a stable `id` property to `YearLabel` (e.g., combining year + firstIndex) or make `YearLabel` Identifiable. Replace `ForEach(Array(...enumerated()), id: \.offset)` with `ForEach(yearLabels)`
  - [x] 2.2 For `separatorData.zones`: add a stable `id` property to `ZoneInfo` (e.g., combining bucketSize + startIndex) or make `ZoneInfo` Identifiable. Replace enumerated ForEach
  - [x] 2.3 For zone backgrounds in `zoneBackgrounds()`: same fix — use `ZoneInfo.id` instead of enumeration offset

- [x] Task 3: Cache `SpectrogramData.compute()` in `RhythmSpectrogramView` (AC: #3)
  - [x] 3.1 Add a `@State private var cachedData: SpectrogramData?`
  - [x] 3.3 Use `.task(id: progressTimeline.recordCount(for: mode))` to recompute only when record count changes, storing result in @State

- [x] Task 4: Fix unstable ForEach identity in `RhythmSpectrogramView` (AC: #4)
  - [x] 4.1 For `data.columns`: made `SpectrogramColumn` Identifiable using `date` (from `periodStart`). Added `index` property. Replaced all enumerated ForEach
  - [x] 4.2 For x-axis labels: use `data.columns` ForEach with `column.index` to look up bucket
  - [x] 4.3 For accessibility elements: same approach — use `column.index` instead of enumeration offset

- [x] Task 5: Run full test suite (AC: #5)

## Dev Agent Record

### Implementation Plan
- Task 1: Compute lineData once, pass to stddevBand/ewmaLine. Updated both ProgressChartView and ExportChartView.
- Task 2: Made YearLabel and ZoneInfo Identifiable with composite string IDs. Replaced 3 enumerated ForEach patterns.
- Task 3: Added @State cachedData with .task(id: recordCount) pattern. Falls back to inline compute for initial render.
- Task 4: Added `index` property to SpectrogramColumn, made it Identifiable via `date`. Replaced 3 enumerated ForEach patterns.
- Task 5: Full suite passes — 1529 tests, zero regressions.

### Completion Notes
All 5 ACs satisfied. Performance improvements: lineDataWithSessionBridge computed once instead of twice per chart render; SpectrogramData.compute() cached so cell taps don't trigger recomputation; all ForEach loops use stable identifiers preventing unnecessary view teardown.

## File List

- `Peach/Profile/ProgressChartView.swift` — deduplicated lineData, made YearLabel/ZoneInfo Identifiable, replaced enumerated ForEach
- `Peach/Profile/ExportChartView.swift` — updated stddevBand/ewmaLine calls to pass lineData
- `Peach/Profile/RhythmSpectrogramView.swift` — cached SpectrogramData, replaced enumerated ForEach with column.id
- `Peach/Core/Profile/SpectrogramData.swift` — added index property and Identifiable conformance to SpectrogramColumn

## Change Log

- 2026-03-28: Implemented story 64.5 — deduplicated chart line data computation, fixed unstable ForEach identity in both chart views, cached spectrogram data

## Dev Notes

### lineDataWithSessionBridge Duplication

In `ProgressChartView.chartContent()`, lines 156 and 157 call `stddevBand(buckets:)` and `ewmaLine(buckets:)`. Both static methods internally call `lineDataWithSessionBridge(for: buckets)`. This function:
1. Enumerates all buckets
2. Filters non-session buckets into LinePoint array
3. Computes weighted mean/variance of session buckets
4. Creates a bridge point

All of this happens twice per render. Fix: compute once, pass the result.

### Unstable ForEach Identity

`ForEach(Array(items.enumerated()), id: \.offset)` means that when a new item is prepended or an old one is removed, every subsequent item gets a new offset. SwiftUI sees all items as "new" and tears down/recreates all views. For chart zones and year labels, this causes unnecessary layout work.

### SpectrogramData.compute() Cost

`SpectrogramData.compute()` builds a 2D grid: for each tempo range × time bucket, it filters metrics, computes mean/stddev, and classifies accuracy. This runs every time `body` is evaluated, including when the user simply taps a cell (which only changes `@State selectedCell`). Caching eliminates this entirely for tap interactions.

### Source File Locations

| File | Path |
|------|------|
| ProgressChartView | `Peach/Profile/ProgressChartView.swift` |
| RhythmSpectrogramView | `Peach/Profile/RhythmSpectrogramView.swift` |
| SpectrogramData | `Peach/Core/Profile/SpectrogramData.swift` |

### References

- [Source: Peach/Profile/ProgressChartView.swift:269,280] — Duplicate lineDataWithSessionBridge calls
- [Source: Peach/Profile/ProgressChartView.swift:200,214,249] — Unstable ForEach identity
- [Source: Peach/Profile/RhythmSpectrogramView.swift:27] — SpectrogramData.compute() in body
- [Source: Peach/Profile/RhythmSpectrogramView.swift:58,69,89] — Unstable ForEach identity
