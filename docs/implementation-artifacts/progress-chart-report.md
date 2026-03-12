# Progress Chart: Design & Implementation Report

## 1. Purpose

The progress chart answers one question: **"Am I getting better?"** across three time horizons. A user training pitch detection over months should see their long-term trajectory (monthly averages), recent consistency (daily averages for the past week), and today's performance (individual session dots). Small improvements in the 1–5 cent range must be visually discernible — the chart is useless if everything looks flat.

## 2. Design Decisions

### 2.1 Three-Zone Layout

The chart uses **non-linear time compression**: three granularity zones occupy a single horizontal axis, each with equal spacing per data point regardless of actual time span.

```
 25 ┤
    │
 20 ┤          ╭──╮
    │     ╭────╯  ╰───╮        ╭──╮
 15 ┤─────╯            ╰───────╯  ╰──╮    ●
    │                                  ╰─●──●─ ● ●
 10 ┤                                     ●
    │
  5 ┤
    │
  0 ┼──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──
    Okt Nov Dez Jan Feb Mär  │ Mo Di Mi Do Fr Sa So│
    2025────────────────2026  │         Day zone    │Session
              Month zone     │                     │ zone
```

**Zone rules:**
- **Month zone** (leftmost): Everything older than 7 days. Monthly averages, connected line + stddev band. X-axis labels: month abbreviations (e.g. "Okt", "Nov"). Second label row: year labels flanking year boundaries.
- **Day zone** (middle): Previous 7 days. Daily averages, connected line + stddev band. X-axis labels: weekday abbreviations (e.g. "Mo", "Di").
- **Session zone** (rightmost): Today's sessions. Disconnected dots (no line). No X-axis labels.

**Why index-based, not date-based X-axis:** A date-based axis would compress months into tiny slivers while sessions sprawl. By assigning each bucket an integer index and using `Double` as the X-axis type, every data point gets equal visual weight. This is the single most important design decision — it makes the chart readable.

### 2.2 Zone Separators

Full-height vertical lines mark granularity transitions. Within the monthly zone, additional separator lines mark year boundaries. Year labels sit in a dedicated row below the X-axis labels, flanking each year boundary.

**Deduplication rule:** When a year boundary falls within 1 index of a zone transition, the year-boundary separator is suppressed to avoid visual clutter.

### 2.3 Dynamic Y-Axis

The Y-axis adapts to the data. The ceiling is the smallest "nice" value from `[1, 2, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100]` that exceeds `max(10, rawMax * 1.2)`. This prevents wasted vertical space (the original implementation jumped from 20 to 50, wasting half the chart for data that peaked at 25).

### 2.4 Visual Elements

| Element | Month zone | Day zone | Session zone |
|---------|-----------|----------|-------------|
| Line | Connected (LineMark) | Connected (LineMark) | None |
| Dots | None | None | PointMark |
| Stddev band | AreaMark, blue 15% | AreaMark, blue 15% | None |
| Background | systemBackground 6% | secondarySystemBackground 6% | systemBackground 6% |
| Baseline | Dashed green line (optimal threshold) spanning all zones |

### 2.5 Scrolling

The chart scrolls horizontally when bucket count exceeds 12. Visible domain is 12 buckets. Initial position: rightmost (most recent data). Implemented via `.chartScrollableAxes(.horizontal)` with `@State scrollPosition: Double`.

### 2.6 German Abbreviations

`DateFormatter` with "MMM" and "EEE" produces trailing dots in German ("Dez.", "Fr."). These are stripped in `formatAxisLabel` — the chart uses "Dez", "Fr" etc.


## 3. Architecture

```
┌─────────────────────────────────────────────────┐
│              ProgressChartView                   │
│  (SwiftUI + Charts, UI layer only)              │
│                                                  │
│  - zoneSeparatorData(for:)   → zones + dividers │
│  - yearLabels(for:)          → year label data  │
│  - yDomain(for:)             → Y-axis range     │
│  - formatAxisLabel(_:size:)  → strip dots       │
└────────┬────────────────────────┬───────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌─────────────────────────┐
│ ChartLayout-    │    │ GranularityZoneConfig    │
│ Calculator      │    │ (protocol + 3 configs)   │
│ .zoneBoundaries │    │ MonthlyZoneConfig        │
│   (for:)        │    │ DailyZoneConfig          │
│ (Core/)         │    │ SessionZoneConfig        │
│                 │    │ (Core/, no SwiftUI)       │
└────────┬────────┘    └──────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│           ProgressTimeline                       │
│  (Observable, data pipeline)                     │
│                                                  │
│  - allGranularityBuckets(for:) → [TimeBucket]   │
│  - assignMultiGranularityBuckets(...)            │
│    age < 24h  → .session                         │
│    age < 7d   → .day                             │
│    age >= 7d  → .month                           │
│  - EWMA smoothing, trend detection              │
└─────────────────────────────────────────────────┘
```

The Core/ layer has no SwiftUI imports. Color mapping (`BucketSize` → `Color`) lives in `ProgressChartView`. The `GranularityZoneConfig` protocol provides `pointWidth` and `formatAxisLabel` — originally intended for variable-width layout but now used only for label formatting (the index-based X-axis makes `pointWidth` irrelevant for the current chart).


## 4. Problems Encountered and Their Solutions

### 4.1 SOLVED: Day Zone Showing Too Many Days

**Problem:** The day zone showed up to 29 days instead of exactly 7.
**Root cause:** `assignMultiGranularityBuckets` used `monthThreshold` (30 days) as the upper bound for day-zone assignment. Everything between 1 and 30 days old became a day bucket.
**Fix:** Added `dayThreshold = 7 * 86400`. Data between 7–30 days now falls into monthly buckets.

### 4.2 SOLVED: Y-Axis Wasted Space

**Problem:** `niceAxisMax(30)` returned 50, wasting 40% of the chart height.
**Root cause:** `tickCandidates` jumped from 20 to 50 with no intermediate values.
**Fix:** Added finer candidates: `[1, 2, 5, 10, 15, 20, 25, 30, 40, 50, 75, 100]`.

### 4.3 SOLVED: Trailing Dots on German Abbreviations

**Problem:** "Fr.", "Dez." look cluttered on axis labels.
**Fix:** `formatAxisLabel` strips trailing ".".

### 4.4 SOLVED: Session Zone Had Labels

**Problem:** Session buckets showed time labels on the X-axis, cluttering the rightmost zone.
**Fix:** Filtered session buckets out of `AxisMarks` values.

### 4.5 SOLVED: Adjacent Duplicate Separators

**Problem:** A year boundary 1 month from a zone transition produced two separator lines very close together.
**Fix:** Deduplication logic: year boundaries within 1 index of a zone transition are suppressed.

### 4.6 SOLVED: Zone Background Tints in Dark Mode

**Problem:** Hardcoded colors broke Dark Mode.
**Fix:** Semantic colors: `Color(.systemBackground)` and `Color(.secondarySystemBackground)` at 6% opacity.

### 4.7 UNSOLVED: Separator Lines Extend Through X-Axis Labels

**Problem:** Zone separator lines are drawn via `chartOverlay`, which renders on top of the entire chart including the axis label area. The separators cut through X-axis labels.

**Why it's hard:** Swift Charts provides no API to query the exact pixel boundaries of the plot area vs. the axis label area. The current code uses a magic number offset (`plotFrame.maxY + 28`) to estimate where the label area ends, but this is fragile — it depends on font size, Dynamic Type setting, label count, and platform.

```
 Desired:                        Actual:
 ┌──────────┐──────────┐        ┌──────────┐──────────┐
 │  month   ││  day    │        │  month   ││  day    │
 │  data    ││  data   │        │  data    ││  data   │
 ├──────────┤├─────────┤        │──────────┤├─────────│
   Okt Nov  │  Mo Di            │ Okt Nov  ││ Mo Di   │
   2025     │                   │ 2025     ││         │
                                           ↑↑
                                   Lines go through labels
```

**Attempted approaches:**
1. `RuleMark(x:)` inside the Chart — clips correctly to plot area but *cannot extend below* the axis labels into the year-label row.
2. `chartOverlay` with `GeometryReader` — knows scroll position and can extend below, but draws on top of everything including labels.
3. Sibling `VStack` view below the chart — cannot access scroll position, so separator positions would be wrong on scroll.

### 4.8 UNSOLVED: Year Labels Overlap

**Problem:** When two consecutive years occupy adjacent bucket indices (e.g., Dec 2025 at index 5, Jan 2026 at index 6), their year labels ("2025" and "2026") overlap because they're positioned at indices only ~30pt apart.

**Why it's hard:** Year labels are positioned via `chartOverlay` using `proxy.position(forX:)`. With dense data, adjacent indices map to positions closer together than the label text width. There's no layout negotiation — `chartOverlay` positions are absolute, not flow-based.


## 5. The Core Tension: chartOverlay vs. RuleMark

This is the fundamental architectural problem. The chart has three rendering layers, and no single Swift Charts mechanism handles all three correctly:

| Need | RuleMark (inside Chart) | chartOverlay | Sibling View |
|------|------------------------|--------------|--------------|
| Clips to plot area | Yes | No | N/A |
| Extends below axis | No | Yes | Yes |
| Knows scroll position | Yes (automatic) | Yes (via proxy) | No |
| Respects label layout | Yes | No | N/A |

**Zone separators need all four properties.** They must:
1. Align with data points (requires scroll awareness)
2. Not obstruct axis labels (requires clipping or layout awareness)
3. Extend into the year-label row (requires extending below plot area)

No single rendering approach satisfies all three.


## 6. Trade-Offs

### 6.1 Extending Separators Below the Axis vs. Clean Label Rendering

**Design wish:** Separator lines extend from the top of the chart all the way down through the year-label row, visually connecting zones across both label rows.
**Implementation reality:** Any line that extends below the plot area (via `chartOverlay`) also covers the X-axis labels. Swift Charts provides no Z-ordering control or "draw behind labels" API.

**Trade-off:** Either (a) separators stop at the plot area boundary (clean but less visually connected), or (b) separators extend through labels (connected but messy).

### 6.2 Year Labels at Exact Positions vs. Readable Labels

**Design wish:** Year labels positioned precisely at the first and last bucket of each calendar year.
**Implementation reality:** When years are adjacent (Dec → Jan), the labels overlap because they're wider than the inter-bucket spacing.

**Trade-off:** Either (a) position labels exactly but accept overlap in edge cases, (b) use collision-avoidance logic (complex, brittle), or (c) use a single centered label per year-span (loses the "flanking" design).

### 6.3 Index-Based X-Axis vs. Swift Charts' Built-in Date Axis

**Design wish:** Equal visual weight per data point regardless of time span.
**Trade-off gained:** Non-linear time compression works perfectly — months get the same width as days. **Trade-off lost:** All of Swift Charts' built-in date axis intelligence (automatic label density, tick placement, etc.) is unavailable. We must manually compute every label position, tick mark, and separator.

### 6.4 Three-Zone Chart vs. Three Separate Charts

**Design wish:** A single continuous chart showing all three time horizons.
**Implementation reality:** Mixing granularities on one axis is the root cause of nearly every rendering problem. Three separate mini-charts would each have uniform granularity and no separator issues.
**Trade-off:** Visual continuity and "one glance" overview vs. implementation simplicity.


## 7. Options for Making Progress

### Option A: Minimal Separators (RuleMark Only)

Use `RuleMark(x:)` inside the Chart for separator lines. They clip naturally to the plot area. **Do not extend lines below the axis.** Rely on background tints to distinguish zones visually. Place year labels in a separate `HStack` or `Text` below the chart — statically computed, not scroll-aware (only relevant for the leftmost, non-scrollable month zone).

**Pros:** Clean, no magic numbers, no label overlap with lines.
**Cons:** Separators don't connect through to year labels. Year labels may drift on scroll (but month zone is typically far left and scrolls off-screen naturally, so this may be acceptable).

**Effort:** Small. Mostly removing the `chartOverlay` code and replacing with `RuleMark`.

### Option B: Hybrid Approach

Use `RuleMark(x:)` for separator lines in the plot area. Use a *separate* `chartOverlay` layer for year labels only (no lines). Accept that year labels may not perfectly align with separator lines during scroll but position them at the overlay level.

**Pros:** Clean separator lines in plot area. Year labels are approximately positioned.
**Cons:** Slight visual disconnect between where the separator line ends and where the year label sits. Still has the year-label overlap problem.

**Effort:** Medium. Need to carefully coordinate two rendering mechanisms.

### Option C: Custom Canvas Rendering

Replace the `chartOverlay` with a `Canvas` view rendered as an underlay behind the chart's axis labels. The `Canvas` can draw lines at precise positions (using the chart proxy for scroll-aware coordinates) and clip them to any rectangle.

**Pros:** Full control over every pixel. Can draw lines that stop exactly at the label boundary.
**Cons:** `Canvas` in a `chartOverlay` has the same stacking problem. As a background/underlay, it can't access the chart proxy. Requires passing coordinates between views via `PreferenceKey`, which adds significant complexity.

**Effort:** Large. Essentially re-implementing chart overlay from scratch.

### Option D: Three Separate Charts

Replace the single multi-zone chart with three horizontally adjacent mini-charts, each handling one granularity. A shared Y-axis on the left. Separator lines are simply the borders between charts.

**Pros:** Eliminates every rendering problem: no cross-zone separators needed, no label conflicts, no year-label overlap. Each chart is a vanilla Swift Charts instance with uniform data. Scrolling only needed in the month chart.
**Cons:** Fundamentally different layout. Aligning Y-axes across three independent charts requires manual coordination (shared `yDomain`). The connected line cannot cross from day zone into month zone — visual continuity is lost. The "single continuous chart" design intent is abandoned.

**Effort:** Large (rewrite), but the result would be significantly simpler to maintain.

### Option E: Accept Imperfections and Ship

Keep the current `chartOverlay` approach. Accept that:
- Separator lines extend through axis labels (faint enough to be tolerable)
- Year labels may overlap in edge cases (rare — requires data spanning a year boundary within the visible window)

Polish: reduce separator line opacity, increase year-label font weight slightly to stand out over separator lines.

**Pros:** No rewrite. Ship what exists, iterate later.
**Cons:** Known visual artifacts remain. May not meet the design standard.

**Effort:** Minimal.

### Recommendation

**Option A** is the pragmatic choice. `RuleMark` inside the chart is the correct tool for vertical lines that respect the plot area. Dropping the requirement that separators extend into the year-label row eliminates the entire `chartOverlay` complexity for lines. Year labels can be handled separately — either as a static row below (for the common case where the month zone is scrolled off-screen) or via a constrained `chartOverlay` that only draws text, not lines.

The key insight: **the background tints already distinguish zones**. Separator lines are reinforcement, not the primary signal. Making them stop at the plot area boundary is not a significant visual loss.
