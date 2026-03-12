# Story 41.6: TipKit Help Overlay System

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **first-time user**,
I want guided explanations of each chart element to appear one at a time,
so that I understand what the EWMA line, stddev band, baseline, and granularity zones mean without needing external documentation.

## Acceptance Criteria

1. **Given** the user views a progress card for the first time, **When** the card appears, **Then** an inline tip card displays above the chart: "This chart shows how your pitch perception is developing over time" (FR6).

2. **Given** the user dismisses the first tip, **When** the next profile visit occurs, **Then** the next tip in the ordered sequence appears (EWMA line -> stddev band -> baseline -> granularity zones), **And** tips are managed via `TipGroup(.ordered)` so only one displays at a time (FR6).

3. **Given** a tip is dismissed, **When** the user revisits the profile later, **Then** TipKit's built-in persistence ensures dismissed tips do not reappear, **And** display frequency is configured to avoid tip fatigue (FR6).

4. **Given** VoiceOver is active, **When** a tip is displayed, **Then** the tip content is accessible and announced appropriately (NFR2).

## Tasks / Subtasks

- [ ] Task 1: Configure TipKit in PeachApp (AC: #1, #2, #3)
  - [ ] 1.1 Add `import TipKit` to `PeachApp.swift`
  - [ ] 1.2 Add `Tips.configure()` in the app's `init()` or `.task` modifier — use default configuration (TipKit handles persistence automatically)
  - [ ] 1.3 Verify TipKit initializes without errors on app launch

- [ ] Task 2: Define chart tip structs (AC: #1, #2)
  - [ ] 2.1 Create `Peach/Profile/ChartTips.swift` with five tip structs conforming to `Tip`:
    - `ChartOverviewTip` — "This chart shows how your pitch perception is developing over time"
    - `EWMALineTip` — explains the blue trend line
    - `StdDevBandTip` — explains the blue shaded band (variability)
    - `BaselineTip` — explains the green dashed baseline
    - `GranularityZoneTip` — explains monthly/daily/session zones
  - [ ] 2.2 Each tip provides `title` and `message` as `Text` computed properties
  - [ ] 2.3 Group all five in a `TipGroup(.ordered)` so they display sequentially

- [ ] Task 3: Integrate inline overview tip into ProgressChartView (AC: #1, #3)
  - [ ] 3.1 Add `TipView` for `ChartOverviewTip` between the headline row and the chart in `activeCard`
  - [ ] 3.2 TipView should be inline (not popover) — it displays above the chart within the card
  - [ ] 3.3 Verify the tip appears on first card render and does not reappear after dismissal

- [ ] Task 4: Integrate popover tips for chart elements (AC: #2)
  - [ ] 4.1 Add `.popoverTip()` for `EWMALineTip` on or near the EWMA line area (e.g., on the chart container or a transparent overlay element anchored to the chart area)
  - [ ] 4.2 Add `.popoverTip()` for `StdDevBandTip` similarly anchored
  - [ ] 4.3 Add `.popoverTip()` for `BaselineTip` similarly anchored
  - [ ] 4.4 Add `.popoverTip()` for `GranularityZoneTip` similarly anchored
  - [ ] 4.5 Verify tips appear one at a time in order after the previous is dismissed

- [ ] Task 5: Localize all tip content (AC: #1, #2, #4)
  - [ ] 5.1 Add English + German translations for all five tip titles via `bin/add-localization.py`
  - [ ] 5.2 Add English + German translations for all five tip messages via `bin/add-localization.py`

- [ ] Task 6: VoiceOver verification (AC: #4)
  - [ ] 6.1 Verify TipView inline tip is announced by VoiceOver (TipKit handles this by default)
  - [ ] 6.2 Verify popover tips are announced when they appear

- [ ] Task 7: Run full test suite (AC: all)
  - [ ] 7.1 Run `bin/test.sh` — all existing + new tests pass
  - [ ] 7.2 Verify no dependency violations with `bin/check-dependencies.sh`

## Dev Notes

### TipKit API Overview (iOS 18+ / TipGroup)

TipKit is a first-party Apple framework (`import TipKit`). Key APIs:

**Tip protocol:**
```swift
struct ChartOverviewTip: Tip {
    var title: Text {
        Text("Your Progress Chart")
    }
    var message: Text? {
        Text("This chart shows how your pitch perception is developing over time")
    }
}
```

**TipGroup(.ordered):**
```swift
// iOS 18+ API — ensures tips appear sequentially
@State private var tipGroup = TipGroup(.ordered) {
    ChartOverviewTip()
    EWMALineTip()
    StdDevBandTip()
    BaselineTip()
    GranularityZoneTip()
}
```

With `TipGroup(.ordered)`, a tip can only display after all preceding tips have been invalidated (dismissed). This is exactly what FR6 requires — one tip at a time in sequence.

**Display methods:**
- **Inline:** `TipView(tip)` — renders as a card within the view hierarchy. Best for the overview tip above the chart.
- **Popover:** `.popoverTip(tip)` — presents as a popover pointing at the modified view. Best for element-specific tips (EWMA, stddev, baseline, zones).

**Configuration in PeachApp:**
```swift
import TipKit

@main
struct PeachApp: App {
    init() {
        try? Tips.configure()
    }
    // ...
}
```

`Tips.configure()` initializes TipKit's persistent data store. It handles persistence automatically — dismissed tips remain dismissed across app launches. No need for custom data store paths or options for this use case.

### TipGroup Integration Pattern

The `TipGroup` must be owned by the view that displays the tips. Since `ProgressChartView` renders the card, it should own the `TipGroup` as `@State`:

```swift
struct ProgressChartView: View {
    @State private var tipGroup = TipGroup(.ordered) {
        ChartOverviewTip()
        EWMALineTip()
        StdDevBandTip()
        BaselineTip()
        GranularityZoneTip()
    }
    // ...
}
```

**Important:** Each `ProgressChartView` instance (one per TrainingMode) will have its own `TipGroup`. Since TipKit's persistence is per-Tip-type (not per-instance), dismissing "ChartOverviewTip" in one card dismisses it for all cards. This is the desired behavior — the user doesn't need the same explanation repeated across four cards.

### Inline Tip Placement

The `ChartOverviewTip` (first in sequence) should display as an inline `TipView` between the headline row and the chart:

```swift
private var activeCard: some View {
    let buckets = progressTimeline.allGranularityBuckets(for: mode)
    // ...
    return VStack(alignment: .leading, spacing: 12) {
        headlineRow(ewma: ewma, stddev: stddev, trend: trend)
        TipView(tipGroup.currentTip as? ChartOverviewTip ?? ChartOverviewTip())
        chartLayout(buckets: buckets)
            .frame(height: chartHeight)
    }
    // ...
}
```

**Alternative (simpler):** Use `tipGroup.currentTip` and conditionally show `TipView` only when the current tip is the overview tip, and use `.popoverTip()` for the remaining element-specific tips.

A cleaner pattern:
```swift
// Show inline TipView for overview tip only
if let currentTip = tipGroup.currentTip {
    TipView(currentTip)
}
```

This displays whatever the current tip is as an inline card. Since all tips are ordered, only one shows at a time. However, the epics file specifies inline for the overview and popover for element tips. The developer should evaluate which approach feels better — all inline may be simpler and less intrusive than popovers on chart elements.

**Developer decision:** The epics hint at both inline and popover. Since chart elements are inside a `Chart` view (which makes `.popoverTip()` anchoring tricky), consider making ALL tips inline `TipView` cards above the chart. This is simpler, avoids fighting Swift Charts' layout, and still achieves the sequential teaching goal. If the user explicitly prefers popover tips for element explanations, a transparent overlay approach (similar to zone accessibility containers in 41.5) could serve as an anchor.

### Popover Anchoring Challenge

Swift Charts marks (`LineMark`, `AreaMark`, etc.) are not SwiftUI views — they are chart content. You **cannot** directly attach `.popoverTip()` to a `LineMark`. Options:

1. **All inline approach:** Show all tips as `TipView` above the chart. Simpler, reliable, no anchoring issues.
2. **Transparent overlay anchors:** Use the existing `.chartOverlay` to place invisible `Color.clear` views at strategic positions (e.g., center of chart for EWMA tip, bottom for baseline tip) and attach `.popoverTip()` to those.
3. **Separate anchor views outside the chart:** Place small invisible anchor views around the chart for each element type.

**Recommendation:** Start with the all-inline approach (option 1). If the user wants popover behavior for element tips, option 2 can be implemented in a follow-up.

### Tips.configure() Placement

Add to `PeachApp.swift` `init()`:
```swift
init() {
    // ... existing initialization ...
    try? Tips.configure()
}
```

The `try?` is standard practice — configuration failures are non-fatal (tips just won't show, which is acceptable degradation).

### Display Frequency

The epics mention configuring display frequency to avoid tip fatigue. TipKit tips have display rules:
```swift
struct EWMALineTip: Tip {
    var title: Text { Text("Trend Line") }
    var message: Text? { Text("The blue line shows your smoothed progress over time") }

    var rules: [Rule] {
        // No custom rules needed — TipGroup(.ordered) handles sequencing
        // Tips only show once (built-in persistence)
    }
}
```

Since `TipGroup(.ordered)` handles sequencing and TipKit's built-in persistence prevents re-display of dismissed tips, no additional display frequency configuration is needed for the MVP. The "?" button in Story 41.7 will handle tip replay.

### Tip Content (English)

| Tip | Title | Message |
|-----|-------|---------|
| ChartOverviewTip | "Your Progress Chart" | "This chart shows how your pitch perception is developing over time" |
| EWMALineTip | "Trend Line" | "The blue line shows your smoothed average — it filters out random ups and downs to reveal your real progress" |
| StdDevBandTip | "Variability Band" | "The shaded area around the line shows how consistent you are — a narrower band means more reliable results" |
| BaselineTip | "Target Baseline" | "The green dashed line is your goal — as the trend line approaches it, your ear is getting sharper" |
| GranularityZoneTip | "Time Zones" | "The chart groups your data by time: months on the left, recent days in the middle, and today's sessions on the right" |

### Localization (German)

| Tip | Title (DE) | Message (DE) |
|-----|-----------|-------------|
| ChartOverviewTip | "Dein Fortschrittsdiagramm" | "Dieses Diagramm zeigt, wie sich deine Tonwahrnehmung im Laufe der Zeit entwickelt" |
| EWMALineTip | "Trendlinie" | "Die blaue Linie zeigt deinen geglatteten Durchschnitt — sie filtert zufallige Schwankungen heraus, um deinen echten Fortschritt zu zeigen" |
| StdDevBandTip | "Schwankungsband" | "Der schattierte Bereich um die Linie zeigt, wie bestandig du bist — ein schmaleres Band bedeutet zuverlassigere Ergebnisse" |
| BaselineTip | "Zielwert" | "Die grun gestrichelte Linie ist dein Ziel — wenn sich die Trendlinie ihr nahert, wird dein Gehor scharfer" |
| GranularityZoneTip | "Zeitbereiche" | "Das Diagramm gruppiert deine Daten nach Zeit: Monate links, die letzten Tage in der Mitte und die heutigen Sitzungen rechts" |

Use `bin/add-localization.py` to add all translations. Note: TipKit uses `LocalizedStringResource` — tips defined with `Text("...")` are automatically localizable through String Catalogs.

### Testing Considerations

**TipKit is difficult to unit test directly** — `Tip`, `TipGroup`, and `TipView` rely on the TipKit runtime and persistent data store. Unit testing tip logic is impractical without Apple providing a test configuration.

**What to test:**
- Existing tests must continue to pass — `ProgressChartView` static helpers are unaffected
- Tip content strings can be verified manually through the localization catalog
- Integration testing: verify tips appear on first launch and sequence correctly (manual QA)

**What NOT to write tests for:**
- Do NOT try to unit test `TipGroup` behavior or `TipView` rendering
- Do NOT mock TipKit internals
- Do NOT add test helper methods for tip state management

The primary verification is:
1. All 1061+ existing tests still pass
2. No dependency violations (`bin/check-dependencies.sh`)
3. Manual verification that tips display correctly

### Previous Story Intelligence (41.5)

Key learnings from Story 41.5:
- `ProgressChartView` was hardened with accessibility features — `@Environment(\.colorSchemeContrast)`, zone accessibility containers in `.chartOverlay`
- Chart layers are extracted into separate `some ChartContent` helper methods (from 41.4 review)
- The `activeCard` VStack is the main container — new `TipView` goes inside this VStack
- `.chartOverlay` already has zone accessibility containers and year labels — do NOT modify these for tips
- German translations added via `bin/add-localization.py` — follow the same pattern
- All 1061 tests pass after 41.5

### Git Intelligence

Recent commits:
```
ab2c706 Review story 41.5: add missing German translations, remove dead code, strengthen tests
247a9e6 Implement story 41.5: accessibility and performance hardening
4b2f1e7 Create story 41.5: accessibility and performance hardening
f41007d Review story 41.4: use native annotation API, extract chart layers, deduplicate gesture
0bd6a26 Implement story 41.4: tap-to-select data points
```

The chart has been progressively enhanced through stories 41.1-41.5. Each layer is cleanly extracted. Adding TipKit is purely additive — no existing chart logic changes.

### What NOT To Do

- Do NOT add explicit `@MainActor` annotations (redundant with default isolation).
- Do NOT use XCTest — use Swift Testing (`@Test`, `@Suite`, `#expect`) if any tests are added.
- Do NOT import third-party dependencies.
- Do NOT modify Core/ files — TipKit tips are UI-layer code in `Profile/`.
- Do NOT try to unit test TipKit behavior (no testable surface).
- Do NOT add a "?" help button — that is Story 41.7.
- Do NOT add narrative headlines — that is Story 41.8.
- Do NOT add session-level markers — that is Story 41.9.
- Do NOT create `Utils/` or `Helpers/` directories.
- Do NOT modify existing chart layers — tips are additive overlay/inline elements.
- Do NOT use `ObservableObject` / `@Published` — use `@State` for `TipGroup`.
- Do NOT fight Swift Charts for popover anchoring — prefer inline `TipView` if popovers on chart marks prove impractical.
- Do NOT add `Tips.resetDatastore()` — that belongs to Story 41.7 ("?" button).
- Do NOT add custom `Tips.ConfigurationOption` for display frequency — TipGroup ordering + built-in persistence is sufficient.

### Project Structure Notes

- New file: `Peach/Profile/ChartTips.swift` — all five tip struct definitions and the tip group
- Modified: `Peach/Profile/ProgressChartView.swift` — add `TipView` in `activeCard`, `@State` for `TipGroup`
- Modified: `Peach/App/PeachApp.swift` — add `import TipKit` and `Tips.configure()` in init
- Modified: `Peach/Resources/Localizable.xcstrings` — add tip title and message translations
- No Core/ files modified
- No new test files needed (TipKit is not unit-testable)
- Run `bin/check-dependencies.sh` after implementation to verify import rules

### References

- [Source: docs/planning-artifacts/epics.md#Story 41.6] — Full acceptance criteria and technical hints
- [Source: docs/planning-artifacts/epics.md#Epic 41 Requirements] — FR6 definition
- [Source: docs/implementation-artifacts/41-5-accessibility-and-performance-hardening.md] — Previous story: accessibility hardening, chart layer structure
- [Source: Peach/Profile/ProgressChartView.swift] — Current chart implementation to integrate tips into
- [Source: Peach/Profile/ProfileScreen.swift] — Container rendering ProgressChartView per TrainingMode
- [Source: Peach/App/PeachApp.swift] — Composition root for Tips.configure()
- [Source: docs/project-context.md] — Coding conventions, testing rules, file placement
- [Source: Apple TipKit Documentation](https://developer.apple.com/documentation/tipkit/) — TipKit API reference
- [Source: Apple TipGroup Documentation](https://developer.apple.com/documentation/tipkit/tipgroup) — TipGroup ordered priority
- [Source: WWDC24 - Customize feature discovery with TipKit](https://developer.apple.com/videos/play/wwdc2024/10070/) — TipGroup introduction

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
