# Story 51.2: RhythmProfileCardView and Profile Screen Integration

Status: review

## Story

As a **musician using Peach**,
I want a rhythm profile card on the Profile Screen showing my overall rhythm accuracy and the spectrogram,
so that I can track my rhythm training progress alongside my pitch progress.

## Acceptance Criteria

1. **Given** the `RhythmProfileCardView` displayed with rhythm data, **when** rendered, **then** it shows a headline with "Rhythm" label, EWMA of the most recent time bucket's combined accuracy, a trend arrow, and a share button (FR89, UX-DR5). The spectrogram view appears below the headline.

2. **Given** no rhythm training data, **when** the card is displayed, **then** it shows dashes ("—") for the EWMA value, no trend arrow, and placeholder text encouraging the user to start training (UX-DR5).

3. **Given** the Profile Screen, **when** updated, **then** it includes `RhythmProfileCardView` for rhythm disciplines alongside existing pitch `ProgressChartView` cards.

4. **Given** landscape or iPad layout, **when** the Profile Screen is displayed, **then** the rhythm card adapts appropriately (same `.regularMaterial` card pattern).

## Tasks / Subtasks

- [x] Task 1: Create `RhythmProfileCardView` (AC: #1, #2)
  - [x] Create `Peach/Profile/RhythmProfileCardView.swift`
  - [x] Headline row: "Rhythm" label + EWMA value (ms) + ±stddev + trend arrow + share button
  - [x] Embed `RhythmSpectrogramView` below headline (pass same `mode`)
  - [x] Empty state: dashes for EWMA, placeholder text, no spectrogram
  - [x] Share button: render card to image via `ChartImageRenderer` pattern
  - [x] Match `.regularMaterial` card background with rounded corners (12pt)

- [x] Task 2: Update `ProfileScreen` to use `RhythmProfileCardView` for rhythm modes (AC: #3, #4)
  - [x] In `ForEach(TrainingDiscipline.allCases)`, branch on rhythm modes to render `RhythmProfileCardView` instead of `ProgressChartView`
  - [x] Ensure both rhythm disciplines (`.rhythmOffsetDetection`, `.rhythmMatching`) each get their own card
  - [x] Maintain existing pitch card rendering (no changes to `ProgressChartView`)

- [x] Task 3: Adapt `RhythmSpectrogramView` for embedding (AC: #1)
  - [x] Remove the outer `.padding()` and `.background(.regularMaterial)` card chrome from `RhythmSpectrogramView` — that wrapper is now `RhythmProfileCardView`'s responsibility
  - [x] Remove the simple "Timing Accuracy" headline — the card provides the full headline
  - [x] Keep state handling: when `.noData`, return `EmptyView()` (card handles its own empty state separately)
  - [x] Ensure the spectrogram grid + legend still render correctly when embedded

- [x] Task 4: Format EWMA and stddev for rhythm (ms units) (AC: #1, #2)
  - [x] EWMA format: value in ms with 1 decimal, e.g., "12.3 ms" — do NOT use `Cents().formatted()` (that's pitch-specific)
  - [x] StdDev format: "±4.1 ms"
  - [x] Empty state: "— ms" with no stddev or trend

- [x] Task 5: Add German localizations (AC: all)
  - [x] Use `bin/add-localization.swift --missing` to check for missing keys
  - [x] Add translations for new strings: "Rhythm", empty state placeholder text, share label, accessibility labels

- [x] Task 6: Run full test suite
  - [x] `bin/test.sh` — zero regressions

## Dev Notes

### Card structure mirrors `ProgressChartView` exactly

Follow the same visual and structural pattern as `ProgressChartView` (Peach/Profile/ProgressChartView.swift):

```
VStack(alignment: .leading, spacing: 12) {
    headlineRow(ewma:stddev:trend:)   // HStack: title, Spacer, stats, trend, share
    spectrogramContent                 // Embedded RhythmSpectrogramView
}
.padding()
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
```

The headline row HStack layout:
1. `Text("Rhythm").font(.headline)` — or use `config.displayName` for per-mode names
2. `Spacer()`
3. EWMA value `.font(.title2.bold())` + stddev `.font(.caption).foregroundStyle(.secondary)`
4. Trend arrow `Image(systemName:)` via `TrainingStatsView.trendSymbol/trendColor/trendLabel`
5. `ShareLink` with chart image URL (conditional on availability)

### EWMA and trend come from `ProgressTimeline`

All statistical data is already computed. Use:
- `progressTimeline.state(for: mode)` → `.noData` or `.active`
- `progressTimeline.currentEWMA(for: mode)` → `Double?` (value in ms for rhythm)
- `progressTimeline.trend(for: mode)` → `Trend?`
- `progressTimeline.allGranularityBuckets(for: mode)` → `[TimeBucket]` (last bucket's stddev for display)

### EWMA format: milliseconds, NOT cents

`ProgressChartView.formatEWMA` uses `Cents(value).formatted()` — that's pitch-specific. For rhythm cards, format as milliseconds:
```swift
static func formatRhythmEWMA(_ value: Double) -> String {
    "\(String(format: "%.1f", value)) ms"
}
static func formatRhythmStdDev(_ value: Double) -> String {
    "±\(String(format: "%.1f", value)) ms"
}
```

### Refactoring `RhythmSpectrogramView` — remove card chrome

`RhythmSpectrogramView` currently wraps itself in `.padding()` and `.background(.regularMaterial)` card chrome. Since `RhythmProfileCardView` now provides this wrapper, extract the card chrome OUT of `RhythmSpectrogramView`. The spectrogram becomes a pure content component.

**Before (current):** `RhythmSpectrogramView` = card chrome + headline + grid + legend
**After:** `RhythmSpectrogramView` = grid + legend only (no card chrome, no headline)

The `.noData` → `EmptyView()` case in `RhythmSpectrogramView` should remain — it's a defensive guard. The parent `RhythmProfileCardView` handles its own empty state display (with dashes/placeholder).

### Empty state (UX-DR5)

When `progressTimeline.state(for: mode) == .noData`:
- Headline shows `Text("Rhythm").font(.headline)`, then `Text("—").font(.title2.bold())`
- No trend arrow, no share button
- Below headline: `Text(String(localized: "Start rhythm training to build your profile")).foregroundStyle(.secondary)`
- Still wrapped in card chrome (`.regularMaterial` background)

**Note:** Current pitch cards use `EmptyView()` for no-data and the card is completely hidden. The UX-DR5 spec explicitly requires showing the rhythm card with placeholder content when no data exists. This is a **departure from the pitch card pattern**.

### Share button: reuse `ChartImageRenderer` pattern

`ProgressChartView` renders a share image via:
```swift
@State private var shareImageURL: URL?

.task(id: progressTimeline.recordCount(for: mode)) {
    shareImageURL = ChartImageRenderer.render(mode: mode, progressTimeline: progressTimeline)
}
```

The spectrogram is not a `Charts` chart, so `ChartImageRenderer.render` (which uses `ExportChartView`) won't work directly for the spectrogram. Options:
1. **Use `ImageRenderer` directly** on the `RhythmProfileCardView` content (headline + spectrogram) — simplest approach
2. Create a dedicated export view for spectrogram

Use option 1: `ImageRenderer(content: exportContent)` where `exportContent` is a snapshot of the card's visible content (headline + spectrogram + legend).

### ProfileScreen branching

Current `ProfileScreen.body`:
```swift
ForEach(TrainingDiscipline.allCases, id: \.self) { mode in
    let state = progressTimeline.state(for: mode)
    if state != .noData {
        ProgressChartView(mode: mode)
    }
}
```

Change to:
```swift
ForEach(TrainingDiscipline.allCases, id: \.self) { mode in
    switch mode {
    case .rhythmOffsetDetection, .rhythmMatching:
        RhythmProfileCardView(mode: mode)  // Shows empty state internally
    default:
        let state = progressTimeline.state(for: mode)
        if state != .noData {
            ProgressChartView(mode: mode)
        }
    }
}
```

Rhythm cards render unconditionally (they handle their own empty state with placeholder text per UX-DR5). Pitch cards remain hidden when no data exists.

### Accessibility

- Card: `.accessibilityElement(children: .contain)` + `.accessibilityLabel("Rhythm profile for \(config.displayName)")`
- EWMA value: `.accessibilityLabel("Current average \(ewma) milliseconds")`
- Trend: reuse `TrainingStatsView.trendLabel` ("Improving" / "Stable" / "Declining")
- Share: `.accessibilityLabel("Share \(config.displayName) chart")`
- Empty state: `.accessibilityLabel("No rhythm training data. Start training to build your profile.")`

### What NOT to do

- Do NOT use `Cents().formatted()` for rhythm values — use milliseconds
- Do NOT add explicit `@MainActor` — redundant with default isolation
- Do NOT use `ObservableObject`/`@Published` — use `@Observable` (already done in `ProgressTimeline`)
- Do NOT modify `PerceptualProfile`, `ProgressTimeline`, or `SpectrogramData` — all infrastructure exists
- Do NOT create a new environment key — `@Environment(\.progressTimeline)` and `@Environment(\.perceptualProfile)` already provide everything needed
- Do NOT import `Charts` — the spectrogram is pure SwiftUI, not a Swift Charts component

### Existing infrastructure to reuse

| What | Where | How to use |
|------|-------|------------|
| EWMA / trend | `ProgressTimeline.currentEWMA(for:)`, `.trend(for:)` | Headline stats |
| State check | `ProgressTimeline.state(for:)` | Empty state branching |
| Time buckets | `ProgressTimeline.allGranularityBuckets(for:)` | Stddev from last bucket |
| Record count | `ProgressTimeline.recordCount(for:)` | Share image `.task(id:)` |
| Spectrogram grid | `RhythmSpectrogramView` | Embedded below headline |
| Trend symbols | `TrainingStatsView.trendSymbol/trendColor/trendLabel` | Arrow in headline |
| Card chrome | `.regularMaterial`, rounded corners 12pt | Card background |
| Share rendering | `ImageRenderer` (SwiftUI built-in) | Share image |
| Config names | `TrainingDisciplineConfig.displayName` | "Hear & Compare – Rhythm" |

### Project Structure Notes

New files:
```
Peach/
└── Profile/
    └── RhythmProfileCardView.swift    # NEW — rhythm card wrapping spectrogram
```

Modified files:
```
Peach/
└── Profile/
    ├── ProfileScreen.swift            # MODIFY — branch rhythm modes to RhythmProfileCardView
    └── RhythmSpectrogramView.swift    # MODIFY — remove card chrome & headline (now provided by parent)
Peach/
└── Resources/
    └── Localizable.xcstrings          # German translations
```

### References

- [Source: docs/planning-artifacts/epics.md#Epic 51 Story 51.2 — acceptance criteria]
- [Source: docs/planning-artifacts/epics.md — FR89]
- [Source: docs/planning-artifacts/ux-design-specification.md:2059-2071 — Rhythm Profile Card spec]
- [Source: docs/planning-artifacts/ux-design-specification.md:264-265 — UX-DR5 definition]
- [Source: Peach/Profile/ProgressChartView.swift — headline pattern, share button, card chrome]
- [Source: Peach/Profile/RhythmSpectrogramView.swift — spectrogram grid to embed]
- [Source: Peach/Profile/ProfileScreen.swift — ForEach TrainingDiscipline iteration]
- [Source: Peach/Profile/ChartImageRenderer.swift — share image rendering pattern]
- [Source: Peach/Core/Profile/ProgressTimeline.swift — currentEWMA, trend, state, allGranularityBuckets]
- [Source: Peach/Core/Profile/TrainingDisciplineConfig.swift — rhythm config: displayName, unitLabel, optimalBaseline]
- [Source: docs/implementation-artifacts/51-1-rhythm-spectrogram-view.md — previous story learnings]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Created `RhythmProfileCardView` mirroring `ProgressChartView` structure: headline row with config.displayName, EWMA (ms), stddev, trend arrow, and share button; embedded `RhythmSpectrogramView` below
- Empty state shows "—" dash with placeholder text per UX-DR5 (departure from pitch cards which use `EmptyView()`)
- Adapted `RhythmSpectrogramView` to be a pure content component: removed `.padding()`, `.background(.regularMaterial)` card chrome, and "Timing Accuracy" headline; retained `.noData → EmptyView()` guard
- ms formatting via `formatRhythmEWMA`/`formatRhythmStdDev` static methods (not `Cents().formatted()`)
- Share image rendered via `ImageRenderer` on a private `RhythmProfileCardExportView` (spectrogram is not a Charts chart, so `ChartImageRenderer.render` doesn't apply)
- `ProfileScreen` branches on `.rhythmOffsetDetection`/`.rhythmMatching` to render `RhythmProfileCardView`; rhythm cards render unconditionally (handle own empty state); pitch cards unchanged
- Added German translations for 2 new localization keys
- All 1380 tests pass, zero regressions

### File List

- Peach/Profile/RhythmProfileCardView.swift (NEW)
- Peach/Profile/RhythmSpectrogramView.swift (MODIFIED)
- Peach/Profile/ProfileScreen.swift (MODIFIED)
- Peach/Resources/Localizable.xcstrings (MODIFIED)
- docs/implementation-artifacts/51-2-rhythm-profile-card-and-profile-screen-integration.md (MODIFIED)
- docs/implementation-artifacts/sprint-status.yaml (MODIFIED)

### Change Log

- 2026-03-21: Implemented story 51.2 — RhythmProfileCardView and Profile Screen Integration
