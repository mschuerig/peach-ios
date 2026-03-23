# Story 58.1: Consolidate Sparkline Bucketing to Multi-Granularity Pipeline

Status: ready-for-dev

## Story

As a **user viewing the Start Screen sparkline**,
I want the sparkline to use the same bucketing pipeline as the Profile chart,
So that session grouping is correct and there is only one code path to maintain.

## Acceptance Criteria

1. **`buckets(for:)` delegates to multi-granularity pipeline** — `ProgressTimeline.buckets(for:)` calls `allGranularityBuckets(for:)` instead of `assignBuckets`.

2. **`assignBuckets` deleted** — The private method `assignBuckets(_:now:sessionGap:)` has zero callers and is removed entirely.

3. **Sparkline renders correctly** — The Start Screen sparkline renders using multi-granularity buckets. Visual behavior may differ slightly due to finer bucketing (calendar-snapped zones vs age-relative) — this is acceptable and expected.

4. **Zero regressions** — Full test suite passes.

5. **Finding closed** — `docs/pre-existing-findings.md` entry ST-1 is updated to CLOSED with a reference to this story.

## Tasks / Subtasks

- [ ] Task 1: Update `buckets(for:)` to delegate to `allGranularityBuckets(for:)` (AC: #1)
  - [ ] In `ProgressTimeline.swift:101-106`, change `buckets(for:)` body to call `allGranularityBuckets(for:)` directly
  - [ ] Keep the public `buckets(for:)` method signature unchanged — `ProgressSparklineView` still calls it

- [ ] Task 2: Delete `assignBuckets` (AC: #2)
  - [ ] Remove `assignBuckets(_:now:sessionGap:)` at lines 142-182
  - [ ] Remove the `recentThreshold` and `monthThreshold` constants (lines 59, 63) if they become unused — verify no other references first
  - [ ] Keep `secondsPerDay` and `dayZoneDays` — they are used by `assignMultiGranularityBuckets` and `assignSubBuckets`

- [ ] Task 3: Fix tests that depend on old bucketing behavior (AC: #4)
  - [ ] Run full suite to identify failures
  - [ ] Update assertions in `ProgressTimelineTests.swift` where `buckets(for:)` is called — the return values will now use calendar-snapped zone boundaries instead of age-relative thresholds
  - [ ] The test at line 831 (`"existing buckets(for:) still returns identical results after adding allGranularityBuckets"`) must be updated or removed — it explicitly asserts the old behavior matches the new
  - [ ] Pay special attention to session merging tests — the bug fix (comparing against `lastGroup.end` instead of `lastGroup.key`) changes merge behavior

- [ ] Task 4: Update pre-existing findings catalog (AC: #5)
  - [ ] In `docs/pre-existing-findings.md`, update ST-1 to CLOSED with reference to story 58.1
  - [ ] Move it from "OPEN — Needs Story" to a "CLOSED" section, or remove entirely per catalog convention (check git history note at top of file — closed findings are removed)

## Dev Notes

### The Bug (ST-1)

`assignBuckets` at line 154 compares session gap against `lastGroup.key` (session **start**), not `lastGroup.end` (last record timestamp). This means long sessions incorrectly split into multiple buckets. `assignMultiGranularityBuckets` at line 209 correctly uses `lastGroup.end`. After consolidation, the sparkline automatically gets the fix.

### Key Behavioral Change

`assignBuckets` used age-relative thresholds:
- `< 24h` → session buckets
- `24h–30d` → day buckets
- `> 30d` → month buckets

`assignMultiGranularityBuckets` uses calendar-snapped zones:
- `>= startOfDay(now)` → session zone (today from midnight)
- Previous 7 calendar days → day zone
- Everything older → month zone

The sparkline only maps `buckets.map(\.mean)` into a 60×24pt path, so the change in zone boundaries is invisible to the user — the shape plots whatever buckets exist.

### Files to Modify

| File | Change |
|------|--------|
| `Peach/Core/Profile/ProgressTimeline.swift` | Rewire `buckets(for:)`, delete `assignBuckets`, remove unused constants |
| `PeachTests/Core/Profile/ProgressTimelineTests.swift` | Update/remove tests that assert old bucketing behavior |
| `docs/pre-existing-findings.md` | Close ST-1 |

### Files That Must NOT Change

- `Peach/Start/ProgressSparklineView.swift` — calls `buckets(for:)` which keeps its signature
- `Peach/Profile/ProgressChartView.swift` — calls `allGranularityBuckets(for:)`, unaffected
- `Peach/Profile/ExportChartView.swift` — calls `allGranularityBuckets(for:)`, unaffected

### Testing Strategy

1. Write a failing test first that exposes the session-merging bug in the old `buckets(for:)` — records spaced such that `lastGroup.key` comparison splits them but `lastGroup.end` comparison merges them
2. Rewire `buckets(for:)` → test passes
3. Delete `assignBuckets` → compilation confirms zero callers
4. Update remaining tests — new zone boundaries change expected bucket counts/sizes
5. Run full suite

### Project Structure Notes

- All changes stay within existing files — no new files needed
- `ProgressTimeline.swift` is in `Core/Profile/` (correct location)
- No dependency direction changes

### References

- [Source: docs/pre-existing-findings.md#ST-1] — Bug description and provenance
- [Source: docs/planning-artifacts/epics.md#Epic 58, Story 58.1] — Acceptance criteria
- [Source: Peach/Core/Profile/ProgressTimeline.swift:101-182] — `buckets(for:)` and `assignBuckets` implementation
- [Source: Peach/Core/Profile/ProgressTimeline.swift:116-122] — `allGranularityBuckets(for:)` (correct implementation)
- [Source: Peach/Start/ProgressSparklineView.swift:19] — Sparkline's call to `buckets(for:)`
- [Source: PeachTests/Core/Profile/ProgressTimelineTests.swift:831] — Compatibility test that needs updating

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
