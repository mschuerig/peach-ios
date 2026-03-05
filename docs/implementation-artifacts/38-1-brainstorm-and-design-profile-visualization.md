# Story 38.1: Brainstorm and Design Profile Visualization

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the **product team**,
We want to explore visualization concepts through interactive brainstorming,
So that we design a profile visualization that is encouraging, actionable, and understandable without music theory prerequisites.

## Acceptance Criteria

1. **Given** an interactive brainstorming session with the developer, **When** visualization concepts are explored, **Then** the following design goals are addressed:
   - **Encouragement:** Users see their progress and feel motivated to continue
   - **Weak spot identification:** Users see where further training would give the most improvement
   - **Understandability:** The visualization makes sense without music theory background

2. **Given** the brainstorming output, **When** concepts are evaluated, **Then** at least 3 distinct visualization approaches are considered (e.g., heatmaps, progress arcs, radar charts, before/after comparisons, difficulty curves, achievement milestones)

3. **Given** a selected concept, **When** it is documented, **Then** a UX concept is produced with enough detail for implementation (layout sketches, data mapping, interaction patterns) **And** the concept is approved by the developer before implementation begins

## Brainstorming Outcome

### Approaches Considered

**Approach 1: Progress Timeline with Adaptive Buckets (Selected)**
- Time-bucket chart with EWMA line and stddev band per training mode
- Buckets grow larger going back in time (hours -> days -> weeks -> months)
- Focus+context interaction: tap a bucket to expand into finer granularity
- Single parameterized view iterating over training modes
- Strengths: Directly shows progress, intuitive time model, encourages by showing improvement
- Weaknesses: Requires new data pipeline, more complex interaction than current chart

**Approach 2: Dashboard Cards with Trend Sparklines**
- Large "current ability" number as hero element per mode
- Small sparkline showing trend direction, historical detail only on expand
- Strengths: Simplest to understand, mobile-friendly, highly encouraging
- Weaknesses: Less detail, limited history exploration

**Approach 3: Before/After Comparison View**
- "Your first week" vs "your last week" side by side with visual diff
- Milestone achievements ("You improved by 40% this month!")
- Strengths: Maximally encouraging, very clear narrative
- Weaknesses: No continuous progress view, gamification can feel patronizing

**Decision:** Approach 1 as primary visualization, incorporating Approach 2's headline statistics (EWMA number + trend arrow) above each chart.

## Approved UX Concept: Progress Timeline Visualization

### Design Philosophy

Focus on **progress over time** rather than profile over training range. For each training mode, show how close the user comes to optimal performance and how reliable they are at it. Recent data shown in more detail, older data compressed.

### Profile Screen Layout

One **Training Mode Card** per mode the user has trained, stacked vertically:

```
+-------------------------------------------+
|  Pitch Discrimination (Unison)            |
|                                           |
|   8.2 cents  +/-2.1    v improving        |  <- EWMA headline
|   ----------------------------------------|
|   [chart: EWMA line + stddev band         |
|    over adaptive time buckets]            |
|   ----------------------------------------|
|   Jan    Feb    Mar 1   Mar 3  Today      |  <- bucket labels
|                                           |
+-------------------------------------------+
|  Pitch Matching (Unison)                  |
|   ...same parameterized layout...         |
+-------------------------------------------+
```

Only show cards for modes with training data. No empty cards.

### Headline Statistics (per card)

- **Current EWMA value** -- large, prominent (e.g., "8.2 cents")
- **Standard deviation** -- smaller, beside it (e.g., "+/-2.1")
- **Trend indicator** -- SF Symbol arrow + word (improving / stable / declining)

### Chart Elements

1. **EWMA line** -- primary stroke showing smoothed performance over time
2. **Standard deviation band** -- shaded area around the line showing reliability
3. **Optimal baseline** -- dashed horizontal line at configurable target
4. **Bucket boundaries** -- subtle vertical dividers between time periods

### Adaptive Time Buckets

| Time Range       | Bucket Size  | Label Format             |
|------------------|-------------|--------------------------|
| Last 24 hours    | Per session | "2h ago", "5h ago"       |
| Last 7 days      | Per day     | "Mon", "Tue", ...        |
| Last 30 days     | Per week    | "Mar 1", "Feb 22"        |
| Beyond 30 days   | Per month   | "Jan", "Dec", ...        |

### Focus+Context Interaction (Magnifying Lens)

- **Tap** a bucket region to expand it into finer granularity (month -> weeks, week -> days)
- **Tap again** or tap elsewhere to collapse back
- Surrounding buckets compress proportionally to maintain chart width
- Smooth animation for expand/collapse transitions

### Statistics: EWMA with Time Discounting

- **Algorithm:** Exponentially Weighted Moving Average (EWMA)
- **Halflife:** 7 days (configurable) -- last week ~50% weight, two weeks ago ~25%
- **Aggregation level:** Per-session or per-day (not per individual record)
- **Discrimination metric:** `centOffset` on correct answers only (incorrect answers indicate difficulty was too hard, not user's threshold)
- **Matching metric:** `abs(userCentError)`

### Optimal Baselines (Configurable)

| Training Mode                  | Baseline | Meaning                     |
|-------------------------------|----------|-----------------------------|
| Unison discrimination          | 8 cents  | Good listener               |
| Interval discrimination        | 12 cents | Harder task, wider baseline  |
| Unison matching                | 5 cents  | Good pitch matching          |
| Interval matching              | 8 cents  | Harder task                  |

These are starting points. All baselines must be easily configurable for future tuning.

### Cold Start Stages

| Records  | Display                                          |
|----------|--------------------------------------------------|
| 0        | "Start training to see your progress"            |
| 1-19     | "Keep going! X more sessions to see your trend"  |
| 20-99    | Chart shown, no trend indicator yet              |
| 100+     | Full visualization with trend                    |

### Cross-Screen Presentations

**Start Screen sparkline:**
- Tiny EWMA line only (no axes, labels, or band)
- Tinted: green if improving, amber if stable, subtle gray if declining
- Current value as small text beside it: "8.2c"
- One sparkline per training mode with data

**Training Screen text:**
- Single line: "Current accuracy: 8.2 cents (improving)"
- Derived from same EWMA computation

### Aggregate Across Modes

Not recommended. Pitch discrimination and pitch matching are distinct auditory-motor skills. A user can be excellent at discrimination but poor at matching. An aggregate would obscure this and mislead users about where to focus training.

## Tasks / Subtasks

- [x] Task 1: Inventory available profile data (AC: #1, #2)
  - [x] 1.1 Document all data fields from `PerceptualProfile`
  - [x] 1.2 Document matching statistics
  - [x] 1.3 Document timeline data
  - [x] 1.4 Document current vs. available data
- [x] Task 2: Brainstorm at least 3 visualization approaches (AC: #2)
  - [x] 2.1 Describe each approach with strengths/weaknesses
  - [x] 2.2 Evaluate against design goals
  - [x] 2.3 Consider cold-start experience
  - [x] 2.4 Consider data-rich experience
- [x] Task 3: Select preferred concept with developer (AC: #3)
  - [x] 3.1 Present trade-offs and recommendation
  - [x] 3.2 Get developer approval -- **Approach 1 approved**
- [x] Task 4: Document UX concept for implementation (AC: #3)
  - [x] 4.1 Layout description
  - [x] 4.2 Data mapping (EWMA, stddev, per-mode metrics)
  - [x] 4.3 Interaction patterns (tap-to-expand focus+context)
  - [x] 4.4 Cold-start and empty-state handling
  - [x] 4.5 Accessibility (VoiceOver for all elements -- implementation detail)
  - [x] 4.6 Output document produced (this story file)

## Dev Notes

### Implementation Architecture (for 38.2+ stories)

**Configurability requirement:** All tuneable parameters (baselines, EWMA halflife, cold start thresholds, bucket boundaries) must be centralized in a configuration type, not scattered as magic numbers. This enables easy future tuning based on real user data.

**Parameterized visualization:** A single `ProgressChartView` renders all training modes. Each mode provides its configuration via a protocol:

```swift
protocol TrainingModeMetrics {
    var displayName: String { get }
    var unitLabel: String { get }
    var optimalBaseline: Double { get }
    var ewmaHalflifeDays: Double { get }
    func extractMetric(from records: ...) -> [MetricDataPoint]
}
```

**Data pipeline:** `Records -> Group by session/day -> Compute per-period stats -> Apply EWMA -> Feed to chart view`

**New Core type:** A `ProgressTimeline` in `Core/Profile/` replaces or supplements the existing `ThresholdTimeline`. It should:
- Group records by adaptive time buckets
- Compute EWMA with configurable halflife
- Be `@Observable` and update incrementally via observer protocols
- Conform to a protocol so the same chart view works for both discrimination and matching

**Existing code to deprecate/replace:** `ThresholdTimeline`, `TrendAnalyzer`, `ThresholdTimelineView`, `SummaryStatisticsView`, `MatchingStatisticsView` -- all designed for the old per-note approach. Plan replacement in implementation stories.

### Project Structure Notes

- New visualization views: `peach/Profile/ProgressChartView.swift` (parameterized)
- New core type: `peach/Core/Profile/ProgressTimeline.swift`
- Configuration: `peach/Core/Profile/TrainingModeConfig.swift` or similar
- Existing `ProfileScreen.swift` will be refactored to use new card-based layout
- Environment injection via `@Environment` with `@Entry` macro

### References

- [Source: docs/planning-artifacts/epics.md#Epic 38] -- Epic definition and story acceptance criteria
- [Source: peach/Profile/ProfileScreen.swift] -- Current profile screen (to be redesigned)
- [Source: peach/Profile/ThresholdTimelineView.swift] -- Existing Apple Charts usage (pattern reference)
- [Source: peach/Profile/SummaryStatisticsView.swift] -- Current summary stats (to be replaced)
- [Source: peach/Profile/MatchingStatisticsView.swift] -- Current matching stats (to be replaced)
- [Source: peach/Core/Profile/PerceptualProfile.swift] -- Profile data model (128 MIDI notes, Welford's algorithm)
- [Source: peach/Core/Profile/ThresholdTimeline.swift] -- Current timeline (to be replaced by ProgressTimeline)
- [Source: peach/Core/Profile/TrendAnalyzer.swift] -- Current trend analysis (to be absorbed into ProgressTimeline)
- [Source: peach/Core/Data/ComparisonRecord.swift] -- Discrimination record model (centOffset, isCorrect, interval, tuningSystem)
- [Source: peach/Core/Data/PitchMatchingRecord.swift] -- Matching record model (userCentError, interval, tuningSystem)
- [Source: docs/project-context.md] -- Coding conventions, architecture rules, naming patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

### Completion Notes List

- Brainstorming conducted via party-mode with Sally (UX), Adam (Music Domain), Winston (Architect)
- 3 approaches evaluated; Approach 1 (Progress Timeline with Adaptive Buckets) selected
- Developer approved concept with note: all parameters must be easily configurable for future tuning
- Implementation stories (38.2+) to be defined based on this UX concept

### File List
