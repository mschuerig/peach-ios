# Profile Chart Review — Tufte Principles & Kill-List

**Date:** 2026-05-25
**Scope:** Profile/Start screen data visualizations
**Method:** Critique against Tufte's *Visual Display of Quantitative Information* principles and the Tufte skill kill-list. Critique only — no code changed.

## Files Reviewed

- `Peach/Profile/ProgressChartView.swift` — progress line chart (EWMA over time)
- `Peach/Profile/ChartData+ChartContent.swift` — shared `ChartContent` layer builders
- `Peach/Profile/RhythmSpectrogramView.swift` — accuracy heatmap (tempo × time)
- `Peach/Start/ProgressSparklineView.swift` — inline trend sparkline
- Supporting: `Peach/Core/Profile/ChartData.swift` (domain/axis computation)

## Summary Verdict

The progress line chart is fundamentally sound — single accent hue, zero-based meaningful baseline, uncertainty band, range-spanning domain. Its weakness is **scaffolding overload**: five layers of non-data-ink competing with a thin blue line (Tufte principle 7, "1+1=3").

The spectrogram contains the one outright **kill-list violation**: a green→yellow→orange→red rainbow scale applied to ordinal data, with non-monotonic luminance that makes the *middle* level visually dominant.

The sparkline's trend-based coloring **inverts emphasis** — it grays out the declining (worst) case and highlights the flat case.

---

## Kill-List Violations (fix first)

### [KILL] Rainbow scale on ordinal data — spectrogram
**Issue:** Accuracy is purely ordinal (excellent > precise > moderate > loose > erratic), but the color ramp is multi-hue green→yellow→orange→red. This is the textbook kill-list anti-pattern ("Rainbow/jet scale for ordered data"). Worse, luminance is **non-monotonic**: `.yellow` (the middle level) is the brightest of all five swatches, so the median accuracy visually "pops" as if it were an extreme. The green↔red endpoints also fail for deuteranopia (~8% of men).
**Reference:** Kill-list — "Rainbow/jet scale for ordered data"; "Red + green only". Principle 9 (smallest effective difference).
**Location:** `RhythmSpectrogramView.swift:255–265` — `extension SpectrogramAccuracyLevel { var color: Color }`
**Modifier/Fix:** Rewrite the `var color` switch as a **sequential single-hue** ramp — fix one hue and step brightness/saturation monotonically across the five levels, e.g. `Color(hue: 0.34, saturation: s, brightness: b)` with `s`/`b` advancing in one direction. A monotonic luminance gradient also resolves the colorblind endpoint problem.

### [KILL] Drop shadow on detail overlay — spectrogram
**Issue:** Drop shadow adds ink and encodes nothing. The `.regularMaterial` background already separates the overlay from the grid. Note the equivalent annotation in `ProgressChartView` (`ProgressChartView.swift:243–244`) uses bare material with no shadow — this is inconsistent.
**Reference:** Kill-list — "Drop shadows".
**Location:** `RhythmSpectrogramView.swift:166` — `.shadow(radius: 2)` in `detailOverlay`
**Modifier/Fix:** Delete `.shadow(radius: 2)`.

### [KILL] Discrete-swatch legend separated from data — spectrogram
**Issue:** The legend is five discrete color chips placed below the grid. For an *ordered* scale, disconnected tiles obscure the continuum and force the eye away from the data to decode color.
**Reference:** Kill-list — "Legend placed away from data". Principle 10 (word-data integration).
**Location:** `RhythmSpectrogramView.swift:174–193` — `legend` / `legendItem`
**Modifier/Fix:** Replace the five `legendItem(...)` calls with a single continuous gradient strip labelled only at the ends ("erratic … excellent"). Once the scale is sequential (see first finding), the strip reads as the ordering it encodes. A key is acceptable for a heatmap — but make it one ordered key, not five disconnected tiles.

---

## Worth Changing (scaffolding & emphasis)

### [HIGH] Sparkline coloring inverts emphasis
**Issue:** Stroke color is driven by trend: improving = `.green`, stable = `.orange`, declining = `.secondary` (faded gray). So a **declining** trend — the thing a learner most needs to notice — renders at the *lowest* emphasis, while a flat trend gets attention-grabbing orange. The trend is also already encoded by the symbol in `ProgressChartView.headlineRow` (`ProgressChartView.swift:80–84`), so tinting the whole stroke is a redundant third encoding.
**Reference:** Principle 9 (smallest effective difference); kill-list — "Color as decoration only".
**Location:** `ProgressSparklineView.swift:44–51` (`sparklineColor`); applied at `:22–24` (`.stroke(...)`).
**Modifier/Fix:** Stroke the path in one neutral color (`.secondary` or `.primary`) at line 23. If direction must be signaled, mark only the **last point** with a colored dot rather than tinting the entire line (Tufte sparklines are single-hue with an optional highlighted endpoint). At minimum, fix the palette so emphasis tracks importance — do not gray out declines.

### [HIGH] Redundant zone delineation — progress chart
**Issue:** Granularity zones (month/day/session) are separated **twice**: faint background rect tints *and* divider rule marks. Two encodings of one boundary.
**Reference:** Principle 4 (erase redundant data-ink).
**Location:** Invoked at `ProgressChartView.swift:132–133`; builders at `ChartData+ChartContent.swift:9–19` (`zoneBackgrounds`) and `:21–27` (`zoneDividers`, currently `.secondary`, lineWidth 1).
**Modifier/Fix:** Keep the quieter background tints; either remove the `ChartData.zoneDividers(...)` layer from the `Chart` body or drop its weight to `.tertiary` / `lineWidth: 0.5`. Don't pay for both.

### [MEDIUM] Unmanaged default Y-axis gridlines — progress chart
**Issue:** `.chartXAxis` is customized but `.chartYAxis` is not, so Swift Charts draws its **default** horizontal gridlines on top of the zone tints, X gridlines, baseline, and year labels. Apple's defaults are light, but stacked they contribute to the "1+1=3" clutter.
**Reference:** Principle 3 (erase non-data-ink); principle 7 (layering & separation).
**Location:** `ProgressChartView.swift:156–174` customizes X only; no `.chartYAxis` block exists.
**Modifier/Fix:** Add `.chartYAxis { AxisMarks { AxisGridLine().foregroundStyle(.quaternary); AxisValueLabel() } }` to fade/thin Y gridlines, or reduce their count.

### [MEDIUM] Baseline reference line too loud — progress chart
**Issue:** The optimal baseline is drawn `.green` (opacity 0.6/0.9), dashed. Green ("good") pulls the eye to scaffolding rather than data. A target line is reference-ink, not data-ink, and should recede. Additionally, the baseline (`:140`) and the selection indicator (`:147`) use the **identical** `dash: [5, 3]`, making two dashed lines confusable.
**Reference:** Principle 9 (smallest effective difference); principle 7.
**Location:** `ProgressChartView.swift:139–141` (baseline `RuleMark`); `:146–147` (selection `RuleMark`).
**Modifier/Fix:** Change baseline `.foregroundStyle(.green...)` → `.foregroundStyle(.secondary)`. Differentiate the dash patterns (e.g. baseline `[2,2]`, selection solid-thin) so the two rules read distinctly.

---

## Polish (do if cheap; verify in-app)

### [LOW] Unit possibly stated three times — progress chart
**Issue:** `.chartYAxisLabel(config.unitLabel)` labels the axis in cents, while the headline value already renders the unit (`formatEWMA`, `:73`) and Y tick labels carry magnitude. Three statements of the same unit.
**Reference:** Principle 4 (erase redundant data-ink).
**Location:** `ProgressChartView.swift:155`.
**Modifier/Fix:** Consider dropping `.chartYAxisLabel` if the headline + tick values make the unit obvious. Verify legibility in-app first.

### [LOW] Per-cell borders — spectrogram
**Issue:** Every cell carries a border, i.e. gridline-ink on every datum. At 0.5pt / 0.1 opacity it is already subtle and aids cell discrimination, so this is a judgment call.
**Reference:** Principle 3 (erase non-data-ink).
**Location:** `RhythmSpectrogramView.swift:128` — `.border(Color.primary.opacity(0.1), width: 0.5)`.
**Modifier/Fix:** Once the color scale is a clean luminance gradient, try removing the border and relying on color edges; keep only if cells become hard to separate.

---

## Already Correct — Leave Alone

These follow Tufte; resist "improving" them:

- **Zero-based `yDomain`** on a meaningful-zero metric (pitch error in cents) — no lie factor. `ChartData.swift:81–86`.
- **Uncertainty band** drawn as an `AreaMark` under the line. `ChartData+ChartContent.swift:29–38`.
- **Single accent hue** — EWMA line, session dots, and stddev band all blue. `ChartData+ChartContent.swift:36 / :46 / :57`.
- **Raw + smoothed data both shown** — `PointMark` sessions plus the smoothed `LineMark` (principle 8, micro/macro). `ChartData+ChartContent.swift:40–61`.
- **Range-spanning X domain** (`-0.5...totalExtent`) — fills the data's actual extent. `ProgressChartView.swift:153`.
- **Headline number beside the chart** — word-data integration (principle 10). `ProgressChartView.swift:65–98`.
- **Self-normalizing sparkline range** — correct for a shape-not-magnitude sparkline; the adjacent number carries magnitude. `ProgressSparklineView.swift:64–85`, `:27–30`.
- **Empty spectrogram cells render `.clear`** — missing data is not falsely encoded. `RhythmSpectrogramView.swift:216–219`.

---

## Priority Order

| # | Finding | File | Severity |
|---|---------|------|----------|
| 1 | Rainbow scale → sequential single-hue | `RhythmSpectrogramView.swift:255–265` | KILL |
| 2 | Sparkline stops graying-out declines | `ProgressSparklineView.swift:44–51` | HIGH |
| 3 | Drop `.shadow(radius: 2)` | `RhythmSpectrogramView.swift:166` | KILL |
| 4 | Collapse double zone delineation | `ChartData+ChartContent.swift:21–27` | HIGH |
| 5 | Fade Y gridlines / manage `.chartYAxis` | `ProgressChartView.swift:156–174` | MEDIUM |
| 6 | Recede + differentiate baseline line | `ProgressChartView.swift:139–141` | MEDIUM |
| 7 | Legend → ordered gradient strip | `RhythmSpectrogramView.swift:174–193` | KILL |
| 8 | Unit-label redundancy | `ProgressChartView.swift:155` | LOW |
| 9 | Per-cell borders | `RhythmSpectrogramView.swift:128` | LOW |
