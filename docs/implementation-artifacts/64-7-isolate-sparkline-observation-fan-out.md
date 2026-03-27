# Story 64.7: Isolate Sparkline Observation Fan-Out on Start Screen

Status: ready-for-dev

## Story

As a **user on the Start Screen**,
I want only the sparkline for the mode I just trained to update,
so that completing a rhythm training doesn't cause all six sparklines to re-render.

## Acceptance Criteria

1. **Given** the Start Screen renders 6 `ProgressSparklineView` instances **When** one training mode gains a new record **Then** only that mode's sparkline re-renders — the other 5 are unchanged.

2. **Given** `ProgressSparklineView` **When** rendering the sparkline path **Then** `buckets.map(\.mean)` is not called in the view body — the mapped array is precomputed or the Shape accepts buckets directly.

3. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Isolate sparkline observation (AC: #1)
  - [ ] 1.1 Read `StartScreen.swift` and `ProgressSparklineView.swift`
  - [ ] 1.2 The root issue: all 6 sparklines read `@Environment(\.progressTimeline)`, and `ProgressTimeline` is `@Observable`. Any mutation to the timeline (any mode) invalidates all 6 views
  - [ ] 1.3 Option A: Make each `ProgressSparklineView` read only the properties it needs (buckets, ewma, trend for its specific mode) and pass them as value-type parameters from StartScreen, so the sparkline doesn't observe the full timeline
  - [ ] 1.4 Option B: Keep the Environment read but wrap each sparkline in an `EquatableView` or use `.equatable()` with value-semantic inputs
  - [ ] 1.5 Choose the simpler option that achieves per-mode isolation

- [ ] Task 2: Eliminate `buckets.map(\.mean)` in body (AC: #2)
  - [ ] 2.1 If Option A is chosen (parameters), the parent computes `buckets.map(\.mean)` and passes `[Double]` as a parameter
  - [ ] 2.2 If the sparkline keeps the Environment read, extract the map to a computed value outside body or have `SparklinePath` accept `[TimeBucket]` and extract means internally (only once in `path(in:)`)

- [ ] Task 3: Run full test suite (AC: #3)

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
