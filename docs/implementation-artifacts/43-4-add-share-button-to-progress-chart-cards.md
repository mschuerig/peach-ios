# Story 43.4: Add Share Button to Progress Chart Cards

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to share a progress chart image from the Profile Screen,
So that I can show my training progress to others.

## Acceptance Criteria

1. **Given** a `ProgressChartView` card on the Profile Screen
   **When** it is displayed for a training mode with data
   **Then** a share button (SF Symbol `square.and.arrow.up`) appears in the headline row, trailing after the trend arrow

2. **Given** the share button
   **When** it is displayed
   **Then** it is sized to match the headline text (not oversized — it's a secondary action)
   **And** it scales with Dynamic Type alongside the headline row

3. **Given** the user taps the share button
   **When** the chart has data
   **Then** the system share sheet appears with the rendered chart image (from story 43.3)
   **And** the image filename includes the training mode and a minute-precision timestamp

4. **Given** VoiceOver is active
   **When** the share button is focused
   **Then** VoiceOver reads "Share [mode display name] chart" (e.g., "Share Pitch Comparison chart")

5. **Given** the share button in the rendered export image
   **When** the chart is rendered for sharing (story 43.3)
   **Then** the share button is not visible in the exported image

## Tasks / Subtasks

- [x] Task 1: Add share image URL state and rendering task to `ProgressChartView` (AC: #3)
  - [x] Add `@State private var shareImageURL: URL?` to `ProgressChartView`
  - [x] Add `.task(id:)` modifier on `activeCard` keyed on `progressTimeline.currentEWMA(for: mode)` that calls `ChartImageRenderer.render(mode:progressTimeline:)` and stores the result in `shareImageURL`

- [x] Task 2: Add share button to headline row (AC: #1, #2, #3, #4)
  - [x] Add a `ShareLink(item:preview:)` after the trend icon in `headlineRow`, conditionally shown when `shareImageURL` is non-nil
  - [x] Use `Image(systemName: "square.and.arrow.up")` as the label
  - [x] Use `.font(.body)` and `.foregroundStyle(.secondary)` so the button matches headline scale without dominating
  - [x] Set `SharePreview` with the mode's `displayName` and the share image
  - [x] Add `.accessibilityLabel(String(localized: "Share \(config.displayName) chart"))` to the `ShareLink`

- [x] Task 3: Add localization strings (AC: #4)
  - [x] Add "Share %@ chart" localization key for the accessibility label (English + German)
  - [x] Use `bin/add-localization.swift` for the German translation

- [x] Task 4: Verify export image exclusion (AC: #5)
  - [x] Confirm `ExportChartView` does NOT include a share button (already the case from story 43.3 — no code change needed, just verify)

- [x] Task 5: Write tests (AC: #1–#5)
  - [x] Test that `headlineRow` signature or structure accommodates the share button parameter
  - [x] Test accessibility label format for all four training modes

- [x] Task 6: Run full test suite and verify no regressions

## Dev Notes

### Design Decisions

**ShareLink over Button + ActivityViewController:** `ShareLink` is the idiomatic SwiftUI approach for sharing. It handles share sheet presentation automatically and works with `Transferable` types. The SettingsScreen already uses this pattern for CSV export (see `Peach/Settings/SettingsScreen.swift:262`). Using a URL as the `Transferable` item is the same pattern used there.

**Pre-rendering via `.task(id:)` over on-demand rendering:** `ShareLink` requires the shareable item at init time — it can't defer rendering to tap time. Pre-rendering the image when the card appears (and re-rendering when EWMA changes) is the only clean approach. The `.task(id: progressTimeline.currentEWMA(for: mode))` pattern re-renders only when the data actually changes, which happens only when the user navigates away to train and returns.

**Secondary styling for the button:** The share button is a secondary action — the chart itself is the primary content. Using `.font(.body)` and `.foregroundStyle(.secondary)` keeps it visually subordinate to the headline EWMA value. It naturally scales with Dynamic Type because `@ScaledMetric` and font metrics handle this.

### Implementation Pattern

The `headlineRow` in `ProgressChartView` currently ends with the trend icon. The share button goes after it:

```swift
// Current: Text(displayName) — Spacer — EWMA — StdDev — TrendIcon
// New:     Text(displayName) — Spacer — EWMA — StdDev — TrendIcon — ShareButton

if let shareURL = shareImageURL {
    ShareLink(
        item: shareURL,
        preview: SharePreview(config.displayName)
    ) {
        Image(systemName: "square.and.arrow.up")
            .font(.body)
            .foregroundStyle(.secondary)
    }
    .accessibilityLabel(String(localized: "Share \(config.displayName) chart"))
}
```

The `shareImageURL` is populated via `.task(id:)`:

```swift
.task(id: progressTimeline.currentEWMA(for: mode)) {
    shareImageURL = ChartImageRenderer.render(
        mode: mode,
        progressTimeline: progressTimeline
    )
}
```

### `headlineRow` Method Signature Change

The current `headlineRow(ewma:stddev:trend:)` is a private method. The share button needs `shareImageURL` which is `@State` — it's already accessible within the struct. The method signature does NOT need to change; the share button can reference `self.shareImageURL` directly inside the method body.

### AC #5: Export Image Exclusion

`ExportChartView` (from story 43.3) has its own `headlineRow` method that does NOT include a `ShareLink`. This AC is already satisfied by the existing architecture — `ExportChartView` is a completely separate view from `ProgressChartView`. No code change needed; just verify this during implementation.

### What NOT to Do

- Do NOT modify `ExportChartView.swift` — it already excludes the share button
- Do NOT modify `ChartImageRenderer.swift` — it already handles rendering
- Do NOT add a custom share sheet or `UIActivityViewController` — use `ShareLink`
- Do NOT render the image synchronously in the view body — use `.task(id:)` for async pre-rendering
- Do NOT add `import UIKit` — `ShareLink` is pure SwiftUI
- Do NOT create a new service or observable — this is pure view-layer state (`@State`)
- Do NOT add explicit `@MainActor` — default isolation handles this
- Do NOT use `ObservableObject` or `@Published` — forbidden by project rules
- Do NOT use Combine

### Project Structure Notes

- `Peach/Profile/ProgressChartView.swift` (modified — add `@State shareImageURL`, `.task(id:)`, `ShareLink` in headline row)
- No new files needed
- No Core/ modifications needed
- No new `@Environment` keys needed

### Key Source Files to Read Before Implementing

- `Peach/Profile/ProgressChartView.swift` — the view being modified; `headlineRow` method at line 57, `activeCard` at line 33
- `Peach/Profile/ChartImageRenderer.swift` — `render(mode:progressTimeline:)` returns `URL?`; already implemented in story 43.3
- `Peach/Profile/ExportChartView.swift` — verify it does NOT have a share button (AC #5)
- `Peach/Settings/SettingsScreen.swift:259-271` — reference pattern for `ShareLink(item: url, preview:)`
- `Peach/Core/Profile/ProgressTimeline.swift` — `currentEWMA(for:)` returns `Double?`; used as `.task(id:)` key

### References

- [Source: docs/planning-artifacts/epics.md — Epic 43, Story 43.4, lines 4352–4381]
- [Source: docs/implementation-artifacts/43-3-render-progress-chart-as-shareable-image.md — ChartImageRenderer.render() API, ExportChartView architecture]
- [Source: Peach/Profile/ProgressChartView.swift — headlineRow, activeCard, chart layers]
- [Source: Peach/Profile/ChartImageRenderer.swift — render(mode:progressTimeline:) -> URL?]
- [Source: Peach/Profile/ExportChartView.swift — Separate view without share button]
- [Source: Peach/Settings/SettingsScreen.swift:262 — ShareLink pattern reference]
- [Source: docs/project-context.md — SwiftUI rules, @State, no UIKit in views, accessibility, localization]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Added `@State private var shareImageURL: URL?` to `ProgressChartView`
- Added `.task(id: progressTimeline.currentEWMA(for: mode))` modifier on `activeCard` to pre-render chart image via `ChartImageRenderer.render()`
- Added `ShareLink` after the trend icon in `headlineRow`, conditionally shown when `shareImageURL` is non-nil
- Used `.font(.body)` and `.foregroundStyle(.secondary)` for secondary visual weight
- Added accessibility label `"Share \(config.displayName) chart"` to `ShareLink`
- Added German localization `"%@ Chart teilen"` via `bin/add-localization.swift`
- Verified `ExportChartView` does NOT include a share button (AC #5 satisfied by separate view architecture)
- Added parameterized test verifying accessibility label format for all four training modes
- All 1079 tests pass with no regressions

### Change Log

- 2026-03-16: Implemented share button on progress chart cards (story 43.4)

### File List

- Peach/Profile/ProgressChartView.swift (modified — added @State shareImageURL, .task(id:), ShareLink in headlineRow)
- Peach/Resources/Localizable.xcstrings (modified — added "Share %@ chart" key with German translation)
- PeachTests/Profile/ProgressChartViewTests.swift (modified — added share accessibility label test)
- docs/implementation-artifacts/43-4-add-share-button-to-progress-chart-cards.md (modified — status, tasks, dev agent record)
- docs/implementation-artifacts/sprint-status.yaml (modified — story status updated)
