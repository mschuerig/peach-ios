# Story 64.7: Isolate Sparkline Observation Fan-Out on Start Screen

Status: done

## Story

As a **user on the Start Screen**,
I want only the sparkline for the mode I just trained to update,
so that completing a rhythm training doesn't cause all six sparklines to re-render.

## Acceptance Criteria

1. **Given** the Start Screen renders 6 `ProgressSparklineView` instances **When** one training mode gains a new record **Then** only that mode's sparkline re-renders — the other 5 are unchanged.

2. **Given** `ProgressSparklineView` **When** rendering the sparkline path **Then** `buckets.map(\.mean)` is not called in the view body — the mapped array is precomputed or the Shape accepts buckets directly.

3. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Isolate sparkline observation (AC: #1)
  - [x] 1.1 Read `StartScreen.swift` and `ProgressSparklineView.swift`
  - [x] 1.2 The root issue: all 6 sparklines read `@Environment(\.progressTimeline)`, and `ProgressTimeline` is `@Observable`. Any mutation to the timeline (any mode) invalidates all 6 views
  - [x] 1.3 Option A: Make each `ProgressSparklineView` read only the properties it needs (buckets, ewma, trend for its specific mode) and pass them as value-type parameters from StartScreen, so the sparkline doesn't observe the full timeline
  - [x] 1.4 Option B: Keep the Environment read but wrap each sparkline in an `EquatableView` or use `.equatable()` with value-semantic inputs
  - [x] 1.5 Choose the simpler option that achieves per-mode isolation

- [x] Task 2: Eliminate `buckets.map(\.mean)` in body (AC: #2)
  - [x] 2.1 If Option A is chosen (parameters), the parent computes `buckets.map(\.mean)` and passes `[Double]` as a parameter
  - [x] 2.2 If the sparkline keeps the Environment read, extract the map to a computed value outside body or have `SparklinePath` accept `[TimeBucket]` and extract means internally (only once in `path(in:)`)

- [x] Task 3: Run full test suite (AC: #3)

## Dev Notes

### Current Fan-Out

`StartScreen` renders 6 `ProgressSparklineView(mode:)` instances. Each reads `@Environment(\.progressTimeline)` and calls three methods on it:
- `progressTimeline.buckets(for: mode)`
- `progressTimeline.currentEWMA(for: mode)`
- `progressTimeline.trend(for: mode)`

Because `ProgressTimeline` is `@Observable`, any property mutation (even for a different mode) triggers re-evaluation of all 6 sparklines. With 3 method calls each, that's 18 calls when only 3 are needed.

### Recommended Approach

Pass precomputed values from `StartScreen`:

```swift
ProgressSparklineView(
    modeName: mode.config.displayName,
    bucketMeans: progressTimeline.buckets(for: mode).map(\.mean),
    ewma: progressTimeline.currentEWMA(for: mode),
    trend: progressTimeline.trend(for: mode),
    unitLabel: mode.config.unitLabel
)
```

This way, `ProgressSparklineView` is a pure view with no Environment dependencies and only re-renders when its value-type inputs change. The `StartScreen` still observes `progressTimeline`, but each sparkline is a leaf that doesn't propagate unnecessary invalidation.

### Source File Locations

| File | Path |
|------|------|
| StartScreen | `Peach/Start/StartScreen.swift` |
| ProgressSparklineView | `Peach/Start/ProgressSparklineView.swift` |

### References

- [Source: Peach/Start/ProgressSparklineView.swift:7,19-21,25] — Environment read and body computation
- [Source: Peach/Start/StartScreen.swift] — 6 sparkline instances

## Dev Agent Record

### Implementation Plan

Option A chosen: pass precomputed value-type parameters from `StartScreen` to `ProgressSparklineView`. This is simpler and more effective than `EquatableView` (Option B) because it eliminates the `@Environment` dependency entirely, making `ProgressSparklineView` a pure leaf view with zero observation overhead.

### Debug Log

No issues encountered.

### Completion Notes

- Refactored `ProgressSparklineView` from environment-dependent to pure value-type parameters: `state`, `bucketMeans`, `ewma`, `trend`, `modeName`, `unitLabel`
- Removed `@Environment(\.progressTimeline)` from `ProgressSparklineView` — it no longer observes `ProgressTimeline` directly
- `StartScreen` now reads `@Environment(\.progressTimeline)` and passes precomputed values to each sparkline
- `buckets.map(\.mean)` is now computed in `StartScreen.trainingCard()`, not in the sparkline view body
- Added two new tests verifying the value-type parameter initializer works for both `.active` and `.noData` states
- Boy Scout: Fixed 5 flaky stddev tests in `ProgressTimelineTests` (same midnight boundary issue as TF-1) — updated pre-existing findings catalog

## File List

- `Peach/Start/ProgressSparklineView.swift` — removed `@Environment`, replaced `mode` parameter with value-type parameters
- `Peach/Start/StartScreen.swift` — added `@Environment(\.progressTimeline)`, pass precomputed values to sparkline
- `PeachTests/Start/ProgressSparklineViewTests.swift` — added value-type initializer tests
- `PeachTests/Core/Profile/ProgressTimelineTests.swift` — fixed 5 flaky stddev tests (midnight boundary)
- `docs/pre-existing-findings.md` — updated TF-1 to cover stddev test fixes
- `docs/implementation-artifacts/sprint-status.yaml` — status updated

## Change Log

- 2026-03-28: Implemented story 64.7 — isolated sparkline observation fan-out via value-type parameters (Option A). Fixed 5 pre-existing flaky stddev tests (TF-1 extension).
