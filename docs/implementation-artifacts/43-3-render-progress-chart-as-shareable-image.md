# Story 43.3: Render Progress Chart as Shareable Image

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer**,
I want a view that renders a progress chart card as a static image suitable for sharing,
So that the chart image rendering is testable and decoupled from the share interaction.

## Acceptance Criteria

1. **Given** a training mode with data
   **When** the export chart view is rendered
   **Then** it includes: the headline row (mode display name, current EWMA value, stddev, trend arrow), the full chart visualization (EWMA line, stddev band, session dots, baseline, zone backgrounds), a localized timestamp, and a small "Peach" attribution text

2. **Given** the localized timestamp
   **When** rendered in German locale
   **Then** it shows a locale-appropriate format (e.g., "15. Marz 2026, 14:32")
   **And** in English locale it shows the English format (e.g., "March 15, 2026, 2:32 PM")
   **And** it uses standard `Date.FormatStyle` with locale-aware formatting

3. **Given** the export chart view
   **When** compared to the live `ProgressChartView`
   **Then** it excludes: the share button, interactive elements (selection indicator, tap gesture), tip views, and navigation chrome

4. **Given** SwiftUI `ImageRenderer`
   **When** it renders the export chart view
   **Then** it produces a raster image at `@2x` or device scale
   **And** the background is a solid fill (not transparent) so the image looks complete outside the app

5. **Given** the rendered image filename
   **When** it is generated
   **Then** it follows the pattern `peach-{mode-slug}-{YYYY-MM-DD-HHmm}.png` where the mode slug is derived from the training mode (e.g., `pitch-comparison`, `pitch-matching`, `interval-comparison`, `interval-matching`)

## Tasks / Subtasks

- [x] Task 1: Add `slug` computed property to `TrainingMode` (AC: #5)
  - [x] Add `var slug: String` to `TrainingMode` returning kebab-case identifiers: `"pitch-comparison"`, `"interval-comparison"`, `"pitch-matching"`, `"interval-matching"`
  - [x] Add tests for all four slug values

- [x] Task 2: Create `ExportChartView` in `Peach/Profile/` (AC: #1, #2, #3)
  - [x] Create `Peach/Profile/ExportChartView.swift` — a SwiftUI view that renders a single training mode's chart card for image export
  - [x] Include headline row: mode `displayName`, formatted EWMA, formatted stddev, trend icon — reuse `ProgressChartView`'s static helpers (`formatEWMA`, `formatStdDev`, `trendSymbol`, `trendColor`)
  - [x] Include chart content: zone backgrounds, zone dividers, stddev band, EWMA line, session dots, baseline — reuse chart layer methods from `ProgressChartView` where possible via extraction or direct re-implementation
  - [x] Chart must be **non-scrollable** (static full-width) with **no** selection indicator, tap gesture, `chartScrollableAxes`, or `chartScrollPosition`
  - [x] Include a localized timestamp row below the chart using `Date.FormatStyle` (`.dateTime.day().month(.wide).year().hour().minute()`)
  - [x] Include a small "Peach" attribution text (secondary style, trailing alignment)
  - [x] Use a fixed size appropriate for sharing (e.g., 390pt width, chart height matching `ProgressChartView`'s compact height of 180pt)
  - [x] Set a solid background fill (`.background(Color(.systemBackground))`) so the image is not transparent

- [x] Task 3: Create `ChartImageRenderer` enum in `Peach/Profile/` (AC: #4, #5)
  - [x] Create `Peach/Profile/ChartImageRenderer.swift` — a stateless enum with a `static func render(mode:progressTimeline:) -> URL?` method
  - [x] Use SwiftUI `ImageRenderer` to render `ExportChartView` to a `CGImage`
  - [x] Set `renderer.scale` to `2.0` (for @2x output)
  - [x] Convert `CGImage` to PNG data via `UIImage(cgImage:).pngData()`
  - [x] Write PNG data to a temp file using `FileManager.default.temporaryDirectory`
  - [x] Generate filename using `exportFileName(for:mode:)` static method following pattern `peach-{slug}-{yyyy-MM-dd-HHmm}.png` with `en_US_POSIX` locale for the timestamp (consistent with `TrainingDataTransferService.exportFileName`)
  - [x] Return the temp file URL on success, `nil` on failure

- [x] Task 4: Add localization strings (AC: #2)
  - [x] Add "Peach" attribution string (if it needs localization — it's a brand name, so it may not)
  - [x] Ensure timestamp formatting uses `Date.FormatStyle` which is auto-localized

- [x] Task 5: Write tests (AC: #1–#5)
  - [x] Test `TrainingMode.slug` returns correct kebab-case values for all four modes
  - [x] Test `ChartImageRenderer.exportFileName(for:mode:)` produces correct pattern for each mode
  - [x] Test `ChartImageRenderer.exportFileName` uses `en_US_POSIX` locale (timestamp doesn't change with device locale)
  - [x] Test `ExportChartView` renders without crashing (snapshot test with mock `ProgressTimeline`)

- [x] Task 6: Run full test suite and verify no regressions

## Dev Notes

### Design Decisions

**ExportChartView vs. modifying ProgressChartView:** Creating a separate `ExportChartView` is cleaner than adding export-mode conditionals to `ProgressChartView`. The export view has fundamentally different requirements: no interactivity, no scrolling, fixed size, solid background, extra metadata (timestamp, attribution). A separate view avoids polluting the interactive chart with export concerns.

**ChartImageRenderer as stateless enum:** Following the project pattern of `ChartLayoutCalculator` (stateless enum with static methods). No service instance needed — rendering is a pure operation that takes inputs and produces a file URL.

**Chart content reuse strategy:** `ProgressChartView`'s chart layers (zone backgrounds, stddev band, EWMA line, session dots, baseline) and static helpers (`formatEWMA`, `formatStdDev`, `trendSymbol`, `trendColor`, `zoneSeparatorData`, `yearLabels`, `lineDataWithSessionBridge`, `yDomain`) are already `static` methods. `ExportChartView` can call these directly via `ProgressChartView.formatEWMA(...)` etc. The chart layer instance methods (`zoneBackgrounds`, `stddevBand`, `ewmaLine`, `sessionDots`) read from `@Environment` and use instance state — the export view will re-implement the chart `Chart { ... }` body using the same static data methods but without interactive layers.

**Fixed width of 390pt:** Matches iPhone screen width for a clean share image. The chart will not scroll — all buckets are shown in full width. This means the export chart shows ALL data, not just the visible window.

**@2x scale:** Ensures crisp images on modern displays without over-inflating file size. `ImageRenderer.scale = 2.0` is explicit rather than relying on device scale (which may be @3x on Pro devices, producing unnecessarily large images).

### What the Export Chart Includes

From `ProgressChartView.activeCard`:
- Headline row: `config.displayName`, `formatEWMA(ewma)`, `formatStdDev(stddev)`, trend icon
- Chart content layers: zone backgrounds, zone dividers, stddev band, EWMA line, session dots, baseline rule mark
- Y-axis label (`config.unitLabel`)
- X-axis labels (formatted per bucket size)
- Year labels overlay

Added for export:
- Localized timestamp: `Date.now.formatted(.dateTime.day().month(.wide).year().hour().minute())`
- "Peach" attribution text (small, secondary, trailing)

### What the Export Chart Excludes

From `ProgressChartView`:
- `@State selectedBucketIndex` and selection indicator `RuleMark`
- `annotationView(for:)` popup
- `selectionTapGesture` / `chartGesture`
- `chartScrollableAxes(.horizontal)` / `chartScrollPosition` / `chartXVisibleDomain`
- `.onChange(of: scrollPosition)` and `.onAppear { scrollPosition = ... }`
- Zone accessibility containers (not needed in a static image)
- `@Environment(\.horizontalSizeClass)` responsiveness (export uses fixed size)
- `@Environment(\.colorSchemeContrast)` — export always uses base contrast values

From `ProfileScreen`:
- TipKit tips
- Navigation bar / toolbar
- Help sheet

### Filename Generation

Pattern: `peach-{mode-slug}-{YYYY-MM-DD-HHmm}.png`

Examples:
- `peach-pitch-comparison-2026-03-15-1432.png`
- `peach-interval-matching-2026-03-15-1432.png`

`TrainingMode.slug` mapping:
- `.unisonPitchComparison` → `"pitch-comparison"`
- `.intervalPitchComparison` → `"interval-comparison"`
- `.unisonMatching` → `"pitch-matching"`
- `.intervalMatching` → `"interval-matching"`

The timestamp uses `DateFormatter` with `en_US_POSIX` locale (same pattern as `TrainingDataTransferService.exportFileName`), ensuring filenames are machine-readable regardless of device locale.

### Key Source Files to Read Before Implementing

- `Peach/Profile/ProgressChartView.swift` — the live chart; reuse static helpers, replicate chart layers
- `Peach/Core/Profile/ProgressTimeline.swift` — `TrainingMode` enum (add `slug`), `TimeBucket`, `BucketSize`, public API for buckets/EWMA/trend
- `Peach/Core/Profile/TrainingModeConfig.swift` — `displayName`, `optimalBaseline`, `unitLabel`
- `Peach/Core/Data/TrainingDataTransferService.swift` — `exportFileName(for:)` pattern to follow for filename generation
- `Peach/Core/Profile/ChartLayoutCalculator.swift` — `zoneBoundaries(for:)` used by zone separator data
- `Peach/Core/Profile/GranularityZoneConfig.swift` — `formatAxisLabel` for axis labels
- `Peach/App/TrainingStatsView.swift` — `trendSymbol`, `trendLabel`, `trendColor` shared helpers

### What NOT to Do

- Do NOT modify `ProgressChartView.swift` — story 43.4 will add a share button there; this story only creates the export view and renderer
- Do NOT add the share button or `ShareLink` — that's story 43.4
- Do NOT add `import UIKit` to `Core/` files — `UIImage` usage is only in `ChartImageRenderer` which lives in `Peach/Profile/` (a feature directory, not Core)
- Do NOT use `@EnvironmentObject` or `ObservableObject` — pass `ProgressTimeline` as a parameter to `ExportChartView`, not via `@Environment`, since `ImageRenderer` renders views outside the normal environment hierarchy
- Do NOT create a service class — `ChartImageRenderer` is a stateless `enum` with static methods
- Do NOT make the chart scrollable in the export — show all buckets at once in a static layout
- Do NOT use `nonisolated` or explicit `@MainActor` — default isolation handles this
- Do NOT add Combine, `PassthroughSubject`, or `sink`
- Do NOT persist the rendered image — it's a transient temp file

### Project Structure Notes

- `Peach/Profile/ExportChartView.swift` — NEW file, view-layer concern (uses SwiftUI + Charts)
- `Peach/Profile/ChartImageRenderer.swift` — NEW file, view-layer concern (uses `ImageRenderer` + `UIImage`)
- `TrainingMode.slug` added to `Peach/Core/Profile/ProgressTimeline.swift` — pure computed property, no framework imports needed
- Tests mirror source: `PeachTests/Profile/ExportChartViewTests.swift`, `PeachTests/Profile/ChartImageRendererTests.swift`, `PeachTests/Core/Profile/TrainingModeTests.swift` (or extend `ProgressTimelineTests`)
- No cross-feature coupling: export views only depend on `Core/Profile/` types
- No new `@Environment` keys needed — `ExportChartView` receives `ProgressTimeline` as an `init` parameter

### ImageRenderer Usage Pattern

```swift
enum ChartImageRenderer {
    static func render(mode: TrainingMode, progressTimeline: ProgressTimeline) -> URL? {
        let view = ExportChartView(mode: mode, progressTimeline: progressTimeline)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        guard let pngData = uiImage.pngData() else { return nil }
        let fileName = exportFileName(for: Date(), mode: mode)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pngData.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func exportFileName(for date: Date = Date(), mode: TrainingMode) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)
        return "peach-\(mode.slug)-\(timestamp).png"
    }
}
```

### ExportChartView Environment Consideration

`ImageRenderer` renders a view **outside** the SwiftUI environment hierarchy. This means `@Environment` values are not available. Therefore, `ExportChartView` must receive `ProgressTimeline` as an explicit `init` parameter (not via `@Environment(\.progressTimeline)`). Similarly, it should not depend on `horizontalSizeClass` or `colorSchemeContrast` — use hardcoded values for the export context (compact size class equivalent, standard contrast).

### References

- [Source: docs/planning-artifacts/epics.md — Epic 43, Story 43.3, lines 4321–4351]
- [Source: docs/implementation-artifacts/43-2-replace-file-exporter-with-sharelink-in-settings.md — Previous story: temp file URL pattern, ShareLink integration]
- [Source: Peach/Profile/ProgressChartView.swift — Live chart implementation, static helpers, chart layers]
- [Source: Peach/Core/Profile/ProgressTimeline.swift — TrainingMode enum, TimeBucket, ProgressTimeline API]
- [Source: Peach/Core/Profile/TrainingModeConfig.swift — displayName, unitLabel, optimalBaseline]
- [Source: Peach/Core/Data/TrainingDataTransferService.swift — exportFileName pattern with en_US_POSIX DateFormatter]
- [Source: Peach/Core/Profile/ChartLayoutCalculator.swift — zoneBoundaries(for:)]
- [Source: Peach/Core/Profile/GranularityZoneConfig.swift — GranularityZoneConfig protocol, axis label formatting]
- [Source: Peach/App/TrainingStatsView.swift — trendSymbol, trendLabel, trendColor shared helpers]
- [Source: docs/project-context.md — Swift 6.2, SwiftUI, zero third-party deps, testing rules, naming conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Test target needed `import SwiftUI` for `ImageRenderer` to be in scope

### Completion Notes List

- Task 1: Added `TrainingMode.slug` computed property with kebab-case identifiers for all four modes. 4 tests in new `TrainingModeTests.swift`.
- Task 2: Created `ExportChartView` — static (non-scrollable) chart card view for image export. Reuses all `ProgressChartView` static helpers (`formatEWMA`, `formatStdDev`, `trendSymbol`, `trendColor`, `yDomain`, `zoneSeparatorData`, `yearLabels`, `lineDataWithSessionBridge`, `formatAxisLabel`). Receives `ProgressTimeline` as init parameter (no `@Environment`). Uses hardcoded base contrast values. Includes headline row, full chart layers, localized timestamp, and "Peach" attribution.
- Task 3: Created `ChartImageRenderer` stateless enum with `render(mode:progressTimeline:date:) -> URL?` and `exportFileName(for:mode:) -> String`. Uses `ImageRenderer` at @2x scale, writes PNG to temp directory.
- Task 4: "Peach" is a brand name — no localization needed. Timestamp uses `Date.FormatStyle` which is auto-localized.
- Task 5: 12 tests total — 4 slug tests, 5 filename tests, 3 rendering tests (including full render-to-file integration test).
- Task 6: Full test suite passes — 1075 tests, 0 failures.

### Change Log

- 2026-03-16: Implemented story 43.3 — ExportChartView, ChartImageRenderer, TrainingMode.slug, and comprehensive tests
- 2026-03-16: Code review — eliminated chart layer duplication (ExportChartView now calls ProgressChartView static methods), added error logging to ChartImageRenderer, made DateFormatter timezone explicit

### File List

- Peach/Core/Profile/ProgressTimeline.swift (modified — added `TrainingMode.slug`)
- Peach/Profile/ExportChartView.swift (new)
- Peach/Profile/ChartImageRenderer.swift (new)
- Peach/Profile/ProgressChartView.swift (modified — chart layer methods promoted to static for reuse)
- PeachTests/Core/Profile/TrainingModeTests.swift (new)
- PeachTests/Profile/ChartImageRendererTests.swift (new)
- PeachTests/Profile/ExportChartViewTests.swift (new)
- docs/implementation-artifacts/sprint-status.yaml (modified)
- docs/implementation-artifacts/43-3-render-progress-chart-as-shareable-image.md (modified)
