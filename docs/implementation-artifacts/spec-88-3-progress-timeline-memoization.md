---
title: 'Story 88.3: Cache progress snapshots via a reusable view wrapper'
type: 'refactor'
created: '2026-07-17'
status: 'done'
baseline_commit: '641343c9'
review_loop_iteration: 0
context: ['docs/implementation-artifacts/epic-88-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Every `ProgressTimeline` read (`state`, `currentEWMA`, `recordCount`, `trend`, `buckets`) funnels through `mergedStatistics`, which re-fetches each key, flat-maps all metric points, sorts, and rebuilds a full `TrainingDisciplineStatistics` (Welford + EWMA + trend) over an **unbounded** lifetime history. A single card body does 4–5 of these identical merges for one mode; `ProgressChartView` repeats it **per scroll frame**. This is code-reading finding 12.

**Approach:** Give the profile a cheap `dataGeneration` counter (bumped on every mutation) and give `ProgressTimeline` one pure `snapshot(for:) -> DisciplineProgress` that computes all display values in a single merge. Cache it in the view layer with **one reusable wrapper** — `CachedProgress` — that holds the `@State` + `.task(id: dataGeneration)` once; each card wraps its content in it and receives a plain `DisciplineProgress`. Same values, recomputed only when the base data changes, no per-card caching boilerplate.

## Boundaries & Constraints

**Always:**
- Observable behaviour unchanged: `snapshot(for: mode)` fields equal the current per-method reads (`state`, `allGranularityBuckets`, `currentEWMA`, `trend`, `recordCount`) for every mode and state.
- `ProgressTimeline` stays a **pure, stateless** presentation layer — it gains `snapshot(for:)` and holds no cache. The granular methods stay for single-value consumers.
- The cache lives in the view layer, written **once** in `CachedProgress`: `content(cached ?? timeline.snapshot(for: mode))` with `.task(id: profile.dataGeneration) { cached = timeline.snapshot(for: mode) }`. The `?? snapshot` inline fallback makes the first render synchronous (no empty-frame flash), mirroring `RhythmSpectrogramView`'s `cachedData ?? compute()`.
- Reactivity rides on `dataGeneration`, an observation-tracked stored property on `PerceptualProfile`, bumped by exactly the three mutators that change `statisticsStore`: `update`, `resetAll`, `finalize` (the latter covers `init(build:)` and `replaceAll`). A per-trial `update`, a `resetAll`, or an import must re-fire every mounted `CachedProgress`'s `.task` — including the macOS case where the Settings window resets/imports while the Profile view is visible in the main window.
- Cards become prop-driven: `ProgressChartView`, `RhythmProfileCardView`, and the Start sparkline receive a `DisciplineProgress` for their render path instead of reading the timeline per value.
- Buckets stay live: `snapshot` recomputes bucketing with `Date()` at snapshot time (i.e. at the last data change). One accepted delta — an idle chart left open across a day/session boundary with no new data re-zones on the next data change / re-appearance, not continuously. Harmless, documented.
- Closes code-reading finding 12. No PF entry is dissolved.

**Ask First:**
- Caching the training screens' `trend(for:)` reads (e.g. across `PitchMatchingScreen` slider-drag frames). Out of scope below; renegotiate if wanted.

**Never:**
- No cache on `ProgressTimeline` or any injected singleton — the memo is the view-layer `CachedProgress` `@State`.
- No snapshot frozen at view-open — it must react to `dataGeneration` (macOS cross-window reset/import).
- No change to bucketing math, `StatisticalSummary`, `TrainingDisciplineStatistics`, Welford, EWMA, or trend logic; `snapshot` is a pure regrouping of existing reads.
- No fix for the O(n)-per-trial `add_point` re-bucketing (finding 16) — this shape does not make it free; leave `TrainingDisciplineStatistics.addPoint` untouched.
- The three training screens stay live single `trend(for:)` reads — do not wrap them in `CachedProgress`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Repeated reads, no mutation | A card re-renders (scroll, tap) | `.task` id (`dataGeneration`) unchanged → `CachedProgress` does NOT recompute; content reads cached `@State`; zero merges per scroll frame | N/A |
| Record ingested | `profile.update(...)` | `dataGeneration` bumps → mounted `.task`s re-fire → snapshot recomputed with the new record | N/A |
| Reset / import | `resetAll()` / `replaceAll` (incl. macOS Settings window while Profile visible) | `dataGeneration` bumps → visible cards refresh | N/A |
| First render | Card appears, `cached == nil` | Inline `?? snapshot(for:)` computes synchronously; `.task` then populates the cache; no empty flash | N/A |
| Cold start / noData | Empty profile, generation 0 | `snapshot` reports `state == .noData`, nil ewma/trend, empty buckets, `recordCount == 0`; card renders `EmptyView`; no crash | N/A |
| One-shot export | `ExportChartView` via `ImageRenderer` | Uses inline `let progress = snapshot(for:)` (single merge), no `CachedProgress`/`.task` (renderer runs off the view tree) | N/A |

</frozen-after-approval>

## Code Map

- `Peach/Core/Profile/PerceptualProfile.swift` -- add tracked `private(set) var dataGeneration = 0`; bump in `update`(67), `resetAll`(60), `finalize`(73)
- `Peach/Core/Profile/ProgressTimeline.swift` -- add `struct DisciplineProgress { state; buckets; ewma; trend; recordCount }` + pure `snapshot(for:)` (one `mergedStatistics` call); keep the six granular methods
- `Peach/App/CachedProgress.swift` (new) -- reusable wrapper: `@Environment` timeline + profile, `@State cached`, `content(cached ?? timeline.snapshot(for: mode))`, `.task(id: profile.dataGeneration)`. Lives in `App/` beside other shared view components (no cross-feature coupling)
- `Peach/App/Training/TrainingDisciplineUI.swift:47` -- default `profileCard` wraps `ProgressChartView` in `CachedProgress`
- `Peach/Training/ContinuousRhythmMatching/Discipline/ContinuousRhythmMatchingDiscipline.swift:37` and `Peach/Training/TimingOffsetDetection/Discipline/TimingOffsetDetectionDiscipline.swift:42` -- rhythm `profileCard` wraps `RhythmProfileCardView` in `CachedProgress`
- `Peach/Profile/ProgressChartView.swift` -- take `progress: DisciplineProgress` for the render path (state/buckets/ewma/trend, :22/:35/:36/:37); keep `@Environment(\.progressTimeline)` only for the cold paths — the share-image `.task`(:55, migrate its id `recordCount(for:)` → `dataGeneration`) and the tap-to-expand `subBuckets`
- `Peach/Training/ContinuousRhythmMatching/Profile/RhythmProfileCardView.swift` -- take `progress`; feed its two sub-structs and the nested spectrogram from it
- `Peach/Profile/RhythmSpectrogramView.swift` -- receive `buckets` from `progress` (drop the inline `allGranularityBuckets` at :28); keep its separate `SpectrogramData` `@State` cache but migrate its `.task(id:)` from `recordCount(for:)`(:41) to `dataGeneration`
- `Peach/Start/StartScreen.swift:132` -- `trainingCard` wraps `ProgressSparklineView` in `CachedProgress`, feeding it from `progress` (sparkline already takes pure params — unchanged)
- `Peach/Profile/ExportChartView.swift:17` -- single inline `let progress = progressTimeline.snapshot(for: mode)`; derive headline + chart from it (no wrapper — `ImageRenderer`)
- `Peach/Profile/ProfileScreen.swift:51` -- accessibility summary reads `state(for:)` per discipline (cold); leave live
- `PeachTests/Core/Profile/PerceptualProfileTests.swift` / `ProgressTimelineTests.swift` -- `dataGeneration` + `snapshot` equivalence tests
- `docs/planning-artifacts/architecture.md` (merge block 2607–2630) / `docs/project-context.md` (~264) -- document the counter, pure `snapshot`, and the `CachedProgress` view-layer cache

## Tasks & Acceptance

**Execution:**
- [x] `Peach/Core/Profile/PerceptualProfile.swift` -- add `private(set) var dataGeneration = 0`; increment at the end of `update`, `resetAll`, `finalize` -- the O(1) observation-tracked change signal `CachedProgress` keys off
- [x] `Peach/Core/Profile/ProgressTimeline.swift` -- add `struct DisciplineProgress` and pure `func snapshot(for:) -> DisciplineProgress` doing exactly one `mergedStatistics` call; keep granular methods for single-value callers
- [x] `Peach/App/CachedProgress.swift` -- new reusable wrapper view (the sole cache site); `content: (DisciplineProgress) -> some View`, `@State cached`, inline `?? snapshot` fallback, `.task(id: profile.dataGeneration)`
- [x] `Peach/App/Training/TrainingDisciplineUI.swift` + the two rhythm `Discipline` files -- wrap each `profileCard` body in `CachedProgress(mode: id) { ProgressChartView(progress: $0) }` / `{ RhythmProfileCardView(progress: $0) }`
- [x] `Peach/Profile/ProgressChartView.swift` -- accept `progress`; drive state/buckets/ewma/trend from it; keep timeline env for the share-image `.task` (migrate id to `dataGeneration`) and `subBuckets`
- [x] `Peach/Training/ContinuousRhythmMatching/Profile/RhythmProfileCardView.swift` -- accept `progress`; feed sub-views and the spectrogram
- [x] `Peach/Profile/RhythmSpectrogramView.swift` -- take `buckets` from `progress`; migrate the `SpectrogramData` `.task(id:)` to `dataGeneration`
- [x] `Peach/Start/StartScreen.swift` -- wrap the sparkline in `CachedProgress`, feeding from `progress`
- [x] `Peach/Profile/ExportChartView.swift` -- single inline `snapshot(for:)`
- [x] `PeachTests/Core/Profile/PerceptualProfileTests.swift` -- `dataGeneration` strictly increases on `update`, `resetAll`, `replaceAll`/`init(build:)`; unchanged with no mutation and unchanged by a `statistics(for:)` read
- [x] `PeachTests/Core/Profile/ProgressTimelineTests.swift` -- for pitch (1-key) and rhythm (multi-key) modes, `snapshot(for:)` fields equal the granular `state`/`allGranularityBuckets`/`currentEWMA`/`trend`/`recordCount`; cold-start snapshot reports noData/nil/empty
- [x] `docs/planning-artifacts/architecture.md` + `docs/project-context.md` -- document: profile `dataGeneration` counter; `ProgressTimeline.snapshot(for:)` stays pure; cards are prop-driven and cached once via the `CachedProgress` wrapper keyed on `dataGeneration`

**Acceptance Criteria:**
- Given any mode and state, when `snapshot(for:)` is called, then each field equals the value the corresponding granular method returns today (behaviour-preserving regrouping)
- Given any record ingestion, reset, or import, when it commits, then `dataGeneration` strictly increases; given no mutation, then it is stable across arbitrarily many reads
- Given a card wrapped in `CachedProgress`, when it re-renders without a data change (scroll, tap, layout), then no merge runs; when `dataGeneration` changes, then it recomputes and reflects the new data — including a macOS Settings-window reset/import while the Profile view is visible
- Given the app builds and the full suite passes on both platforms, then `archlint` and `check-dependencies` stay clean

## Spec Change Log

Review patches (2026-07-18): step-04 adversarial review found `RhythmSpectrogramView` lagged one data generation (its `.task(id: dataGeneration)` captured the `buckets` **prop**, which trails the counter). The post-workflow `/code-review high` sweep then flagged that the `?? / .task` caching idiom duplicates its `compute()` call and undercaches. Both are resolved by replacing the `.task`-based caching with a small synchronous view-local memo primitive, `Memoized<Value>` (`App/Memoized.swift`): `CachedProgress` and the rhythm card's `SpectrogramData` each hold a `@State Memoized` keyed on `dataGeneration`. Synchronous compute means no first-frame flash, no cross-generation lag (a dependent memo recomputes in the same render pass), no duplicated `compute()` call site, and one recompute per data change (not per share-image toggle or cell tap). `RhythmSpectrogramView` is now a pure view of `SpectrogramData`. Other sweep findings dispositioned: buckets time-zone-at-snapshot delta (accepted in Boundaries), granular `ProgressTimeline` methods "dead in production" (kept — they are the unit-tested contract of the bucketing/stats engine, 100+ test refs), `DisciplineProgress.recordCount` (kept for snapshot cohesion), `PitchMatchingSession.inTuneTargetFrequency` (rejected — not in this diff, false premise), view-cache not unit-testable (documented trade).

## Design Notes

The wrapper is the whole idea — the `@State` + `.task` caching is written once and applied by wrapping, so no card repeats it:

```swift
struct CachedProgress<Content: View>: View {
    let mode: TrainingDisciplineID
    @ViewBuilder let content: (DisciplineProgress) -> Content
    @Environment(\.progressTimeline) private var timeline
    @Environment(\.perceptualProfile) private var profile
    @State private var cached: DisciplineProgress?
    var body: some View {
        content(cached ?? timeline.snapshot(for: mode))         // inline first render — no flash
            .task(id: profile.dataGeneration) {                 // recompute ONLY on data change
                cached = timeline.snapshot(for: mode)
            }
    }
}
```

Scope edges: `ExportChartView` renders once via `ImageRenderer` (off the view tree, where `.task` wouldn't run) → inline `snapshot`. `RhythmSpectrogramView` keeps its own `SpectrogramData` cache — a genuinely separate, heavier derivation on top of buckets, not duplicated snapshot caching — but its `.task` id migrates onto the cheaper `dataGeneration` (today it keys on `recordCount(for:)`, which runs a full merge every render just to compute the id). `ProgressChartView` stays partly timeline-coupled for two cold paths only: the share-image `.task` and the per-tap `subBuckets` expand. Training screens read a single `trend(for:)` that changes every trial while visible, so caching would save nothing — they stay live.

Verification honesty: the caching is a SwiftUI view mechanism (no view-test harness in this project), so it is not directly unit-tested. Its correctness reduces to two unit-tested guarantees plus review: `snapshot == granular reads` (values) and `dataGeneration` bumps iff data mutates (invalidation), with the `.task(id: dataGeneration)` keying verified by reading the diff. This is a conscious trade for the view-layer locality: the alternative (memoizing inside `ProgressTimeline`) would have made the "repeated reads hit the cache" assertion directly unit-testable via a computation counter, which the epic sketch suggested; the view-layer wrapper cannot offer that seam.

## Verification

**Commands:**
- `bin/test.sh && bin/test.sh -p mac` -- expected: full suite green on both platforms (never in parallel)
- `bin/build.sh && bin/build.sh -p mac` -- expected: no errors/warnings
- `archlint Peach/` and `bin/check-dependencies.sh` -- expected: clean

**Manual checks (if no CLI):**
- Not an audio change; no listening test. Confirm the Profile/Start progress display still updates after completing a training trial (return and see the new point), and — on macOS — that resetting training data in the Settings window refreshes a Profile view open in the main window (reactivity via `dataGeneration` intact).

## Suggested Review Order

**The mechanism — change signal, pure snapshot, reusable cache**

- Entry point: the synchronous view-local memo primitive — recompute only when `generation` changes, no flash, no lag
  [`Memoized.swift:13`](../../Peach/App/Memoized.swift#L13)

- The reusable cache wrapper — one `Memoized` keyed on `dataGeneration`, applied by wrapping each card's content
  [`CachedProgress.swift:20`](../../Peach/App/CachedProgress.swift#L20)

- The O(1) change signal every cache keys off; bumped in `update`/`resetAll`/`finalize`
  [`PerceptualProfile.swift:12`](../../Peach/Core/Profile/PerceptualProfile.swift#L12)

- All display values from a single merge; `ProgressTimeline` stays pure/stateless
  [`ProgressTimeline.swift:108`](../../Peach/Core/Profile/ProgressTimeline.swift#L108)

- The value type cards receive
  [`ProgressTimeline.swift:68`](../../Peach/Core/Profile/ProgressTimeline.swift#L68)

**Wiring — wrap once at each card build site**

- Default profile card wrapped in `CachedProgress`
  [`TrainingDisciplineUI.swift:47`](../../Peach/App/Training/TrainingDisciplineUI.swift#L47)

- Start grid card wrapped; sparkline fed from the snapshot
  [`StartScreen.swift:134`](../../Peach/Start/StartScreen.swift#L134)

**Prop-driven cards**

- Chart reads the snapshot; keeps timeline only for the cold share-image task
  [`ProgressChartView.swift:6`](../../Peach/Profile/ProgressChartView.swift#L6)

- Spectrogram data memoized here (once per data change), passed down — no lag, no per-tap recompute
  [`RhythmProfileCardView.swift:33`](../../Peach/Training/ContinuousRhythmMatching/Profile/RhythmProfileCardView.swift#L33)

- Now a pure view of `SpectrogramData`
  [`RhythmSpectrogramView.swift:5`](../../Peach/Profile/RhythmSpectrogramView.swift#L5)

**Tests (peripherals)**

- `dataGeneration` bumps on every mutator, stable across reads
  [`PerceptualProfileTests.swift:54`](../../PeachTests/Core/Profile/PerceptualProfileTests.swift#L54)

- `snapshot` equals the granular reads (pitch single-key + rhythm multi-key) + cold start
  [`ProgressTimelineTests.swift:1083`](../../PeachTests/Core/Profile/ProgressTimelineTests.swift#L1083)
