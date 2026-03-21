# Story 51.1: RhythmSpectrogramView

Status: ready-for-dev

## Story

As a **musician using Peach**,
I want a spectrogram-style chart showing my rhythm accuracy across time and tempo,
so that I can see how my timing precision evolves and identify which tempos need more practice.

## Acceptance Criteria

1. **Given** the `RhythmSpectrogramView` displayed with rhythm data, **when** rendered, **then** it shows a grid where X-axis is time progression (same bucketing as pitch charts via `ProgressTimeline`) and Y-axis is tempos actually trained at — no empty rows for untrained tempos (FR90).

2. **Given** cell coloring, **when** accuracy is computed for a cell, **then** green (precise, <=5%), yellow (moderate, 5-15%), red (erratic, >15%) thresholds are applied (UX-DR4). Thresholds are parameterized (not hardcoded literals).

3. **Given** cells with no training data, **when** displayed, **then** they are empty/transparent — grid background shows through (FR91).

4. **Given** the user taps a cell, **when** data exists for that tempo and time period, **then** an early/late breakdown detail is shown with split statistics: early mean/stdDev, late mean/stdDev, sample count (FR92, UX-DR4).

5. **Given** VoiceOver is active, **when** the spectrogram is navigated, **then** per-column summaries are announced (e.g., "March week 2: 120 BPM precise, 100 BPM moderate") (UX-DR11). Activating a column shows the detail overlay.

## Tasks / Subtasks

- [ ] Task 1: Design the spectrogram data model (AC: #1, #2, #3)
  - [ ] Create `SpectrogramCell` value type: `tempo: TempoBPM`, `timeBucketIndex: Int`, `meanAccuracy: Double?` (nil = no data), `earlyStats: (mean: Double, stdDev: Double, count: Int)?`, `lateStats: (mean: Double, stdDev: Double, count: Int)?`
  - [ ] Create `SpectrogramColumn` grouping cells by time bucket with a `date: Date` and `bucketSize: BucketSize`
  - [ ] Create `SpectrogramData` type with methods: `columns: [SpectrogramColumn]`, `trainedTempos: [TempoBPM]`, computed from `ProgressTimeline` + `RhythmProfile`
  - [ ] Define color threshold struct: `SpectrogramThresholds` with `preciseUpperBound: Double = 5.0`, `moderateUpperBound: Double = 15.0` (parameterized)
  - [ ] Write tests for `SpectrogramData` computation: correct tempo filtering, cell accuracy mapping, empty cell handling

- [ ] Task 2: Build `RhythmSpectrogramView` grid (AC: #1, #2, #3)
  - [ ] Create `Peach/Profile/RhythmSpectrogramView.swift`
  - [ ] Render as a SwiftUI `Grid` or `Canvas` — NOT `Charts` framework (this is a heat map, not a line chart)
  - [ ] X-axis: time columns from `ProgressTimeline` bucketing (reuse same `allGranularityBuckets` logic, but merge rhythm keys)
  - [ ] Y-axis: only tempos with data (from `RhythmProfile.trainedTempos`)
  - [ ] Cell color: `.green` / `.yellow` / `.red` from system colors based on thresholds; nil accuracy = transparent (`.clear`)
  - [ ] Square cells, sized to fit available width
  - [ ] Tempo labels on Y-axis (BPM values), time labels on X-axis (reuse `GranularityZoneConfig` formatting)

- [ ] Task 3: Implement tap-to-detail interaction (AC: #4)
  - [ ] Track `@State private var selectedCell: (tempo: TempoBPM, columnIndex: Int)?`
  - [ ] On cell tap, show a minimal popover/overlay with early/late breakdown: early mean, early stdDev, late mean, late stdDev, sample counts
  - [ ] Dismiss on tap elsewhere
  - [ ] Skip interaction for empty cells (no data)

- [ ] Task 4: VoiceOver accessibility (AC: #5)
  - [ ] Per-column accessibility element: summary of all tempos in that column (e.g., "March week 2: 120 BPM precise, 100 BPM moderate, 80 BPM no data")
  - [ ] Use `.accessibilityElement(children: .ignore)` on individual cells, group per column
  - [ ] Activating a column announces the detail (same data as tap overlay)
  - [ ] Localize all VoiceOver strings

- [ ] Task 5: Add German localizations
  - [ ] Run `bin/add-localization.swift` for new strings: threshold labels ("precise", "moderate", "erratic"), detail overlay labels, VoiceOver templates
  - [ ] Check `--missing` first

- [ ] Task 6: Run full test suite
  - [ ] `bin/test.sh` — all tests must pass

## Dev Notes

### This is a NEW component — not a ProgressChartView variant

The UX spec explicitly states: "New component — cannot reuse `ProgressChartView`." The existing `ProgressChartView` is a line chart using the `Charts` framework. The spectrogram is a 2D color grid (heat map). Build it from SwiftUI primitives (`Grid`, `Canvas`, or `LazyVGrid`), not Swift Charts.

### Data flow architecture

The spectrogram needs two data sources:

1. **`ProgressTimeline`** — provides time bucketing (same adaptive granularity: session/day/month). Call `allGranularityBuckets(for:)` for rhythm modes to get the X-axis columns. Since rhythm has multiple statistics keys (tempo range x direction), `ProgressTimeline` already merges them.

2. **`RhythmProfile`** (via `PerceptualProfile`) — provides per-tempo, per-direction stats via `rhythmStats(tempo:direction:)` returning `RhythmTempoStats` (mean, stdDev, sampleCount). Also provides `trainedTempos: [TempoBPM]` for the Y-axis rows.

**Challenge:** `ProgressTimeline` merges all rhythm keys into unified buckets (good for EWMA headline), but the spectrogram needs per-tempo breakdown within each time bucket. You'll need to either:
- Query `PerceptualProfile` directly for per-tempo data and align with timeline buckets
- Or extend `ProgressTimeline` to expose per-key bucket data

The simplest approach: use `ProgressTimeline` for time column boundaries only, then query `RhythmProfile` for per-tempo accuracy data filtered to each column's date range.

### Accuracy metric: percentage of sixteenth note

The "accuracy" values displayed in the spectrogram are `RhythmOffset.percentageOfSixteenthNote(at:)` — not raw milliseconds. This is what the thresholds (5%, 15%) apply to. The `RhythmProfile.rhythmStats(tempo:direction:)` returns `RhythmTempoStats` with mean/stdDev as `RhythmOffset` values, so call `.percentageOfSixteenthNote(at: tempo)` to get the percentage.

### Color thresholds (parameterized, UX-DR4)

```
precise:  meanAccuracy <= 5%   → .green
moderate: meanAccuracy 5-15%   → .yellow
erratic:  meanAccuracy > 15%   → .red
no data:  nil                  → .clear (transparent)
```

Use system colors (`.green`, `.yellow`, `.red`). Define thresholds in a `SpectrogramThresholds` struct so they can be tuned later without code archaeology.

### Tap-to-detail overlay (FR92)

Minimal overlay — not a full sheet. Show:
- Tempo (BPM)
- Time period (formatted date range)
- Early: mean %, stdDev %, count
- Late: mean %, stdDev %, count

Use `RhythmProfile.rhythmStats(tempo:direction:)` for `.early` and `.late` separately to populate this.

### Y-axis: only trained tempos

`RhythmProfile.trainedTempos` returns `[TempoBPM]` — the exact tempos the user has actually trained at. These are the Y-axis rows. Do NOT show all possible tempos (40-200 range). Sort ascending (lowest BPM at bottom).

### Existing infrastructure to reuse

| What | Where | How to use |
|------|-------|------------|
| Time bucketing | `ProgressTimeline.allGranularityBuckets(for:)` | X-axis column boundaries |
| Trained tempos | `RhythmProfile.trainedTempos` | Y-axis rows |
| Per-tempo stats | `RhythmProfile.rhythmStats(tempo:direction:)` | Cell data |
| Percentage calc | `RhythmOffset.percentageOfSixteenthNote(at:)` | Accuracy metric |
| Zone formatting | `GranularityZoneConfig` (Monthly/Daily/Session) | X-axis labels |
| Bucket sizes | `BucketSize` enum (`.session`, `.day`, `.month`) | Zone awareness |

### Environment dependencies

The view needs:
- `@Environment(\.progressTimeline) private var progressTimeline`
- `@Environment(\.rhythmProfile) private var rhythmProfile` — check if this `@Entry` already exists; if not, add it to `App/EnvironmentKeys.swift`

**CONFIRMED:** No `rhythmProfile` environment key exists yet. This story MUST:
1. Add `@Entry var rhythmProfile: RhythmProfile = PerceptualProfile()` to `App/EnvironmentKeys.swift`
2. Wire it in `PeachApp.swift` — pass the same `PerceptualProfile` instance that's already created (it conforms to `RhythmProfile`)

### What NOT to do

- Do NOT use the `Charts` framework — this is a color grid, not a chart
- Do NOT modify `ProgressChartView` — this is a separate component
- Do NOT modify `PerceptualProfile`, `RhythmProfile`, or `ProgressTimeline` — all infrastructure already exists
- Do NOT show empty tempo rows — only tempos in `trainedTempos`
- Do NOT hardcode color thresholds as bare literals — parameterize in a struct
- Do NOT add explicit `@MainActor` — redundant with default isolation
- Do NOT use `ObservableObject`/`@Published` — use `@Observable`

### Project Structure Notes

New files:
```
Peach/
└── Profile/
    └── RhythmSpectrogramView.swift    # NEW — spectrogram grid component
```

Test files:
```
PeachTests/
└── Profile/
    └── RhythmSpectrogramDataTests.swift  # NEW — data model tests
```

Modified files:
```
Peach/
├── App/
│   └── EnvironmentKeys.swift          # MODIFY — add @Entry for rhythmProfile
│   └── PeachApp.swift                 # MODIFY — wire rhythmProfile environment
└── Resources/
    └── Localizable.xcstrings          # German translations
```

### References

- [Source: docs/planning-artifacts/epics.md#Epic 51 Story 51.1 — acceptance criteria]
- [Source: docs/planning-artifacts/epics.md — FR89-FR92]
- [Source: docs/planning-artifacts/ux-design-specification.md:2030-2057 — Spectrogram Profile View spec]
- [Source: docs/planning-artifacts/architecture.md:2156-2170 — Spectrogram visualization architecture]
- [Source: Peach/Core/Profile/RhythmProfile.swift — rhythmStats, trainedTempos, rhythmOverallAccuracy]
- [Source: Peach/Core/Profile/ProgressTimeline.swift — allGranularityBuckets, time bucketing]
- [Source: Peach/Core/Music/RhythmOffset.swift — percentageOfSixteenthNote(at:)]
- [Source: Peach/Core/Music/TempoRange.swift — slow/medium/fast ranges]
- [Source: Peach/Core/Profile/GranularityZoneConfig.swift — zone label formatting]
- [Source: Peach/Profile/ProgressChartView.swift — card pattern, share button, accessibility patterns]
- [Source: Peach/Profile/ProfileScreen.swift — ForEach TrainingDiscipline iteration]
- [Source: docs/project-context.md — project rules and conventions]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
