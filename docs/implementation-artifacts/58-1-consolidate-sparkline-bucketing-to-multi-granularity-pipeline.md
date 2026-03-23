# Story 58.1: Consolidate Sparkline Bucketing to Multi-Granularity Pipeline

Status: done

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

- [x] Task 1: Update `buckets(for:)` to delegate to `allGranularityBuckets(for:)` (AC: #1)
  - [x] In `ProgressTimeline.swift:101-106`, change `buckets(for:)` body to call `allGranularityBuckets(for:)` directly
  - [x] Keep the public `buckets(for:)` method signature unchanged — `ProgressSparklineView` still calls it

- [x] Task 2: Delete `assignBuckets` (AC: #2)
  - [x] Remove `assignBuckets(_:now:sessionGap:)` at lines 142-182
  - [x] Remove the `recentThreshold` and `monthThreshold` constants (lines 59, 63) if they become unused — verify no other references first
  - [x] Keep `secondsPerDay` and `dayZoneDays` — they are used by `assignMultiGranularityBuckets` and `assignSubBuckets`

- [x] Task 3: Fix tests that depend on old bucketing behavior (AC: #4)
  - [x] Run full suite to identify failures
  - [x] Update assertions in `ProgressTimelineTests.swift` where `buckets(for:)` is called — the return values will now use calendar-snapped zone boundaries instead of age-relative thresholds
  - [x] The test at line 831 (`"existing buckets(for:) still returns identical results after adding allGranularityBuckets"`) must be updated or removed — it explicitly asserts the old behavior matches the new
  - [x] Pay special attention to session merging tests — the bug fix (comparing against `lastGroup.end` instead of `lastGroup.key`) changes merge behavior

- [x] Task 4: Update pre-existing findings catalog (AC: #5)
  - [x] In `docs/pre-existing-findings.md`, update ST-1 to CLOSED with reference to story 58.1
  - [x] Move it from "OPEN — Needs Story" to a "CLOSED" section, or remove entirely per catalog convention (check git history note at top of file — closed findings are removed)

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

Claude Opus 4.6

### Debug Log References

None — clean implementation with no blockers.

### Completion Notes List

- Wrote failing regression test `longSessionMergesCorrectly` exposing ST-1 bug (assignBuckets comparing against session start instead of last record timestamp)
- Rewired `buckets(for:)` to delegate to `allGranularityBuckets(for:)` — one-line body change
- Deleted `assignBuckets(_:now:sessionGap:)` method (41 lines) and unused `recentThreshold`/`monthThreshold` constants
- Updated `dayBucketsExtendedRange` test → `monthBucketsForOlderRecords` (10/20 days ago are now month zone under calendar-snapped boundaries)
- Replaced `existingBucketsAPIUnchanged` test with `bucketsForDelegatesToAllGranularity` verifying delegation equivalence
- Removed ST-1 from pre-existing findings catalog (closed findings are removed per convention)
- Full test suite: 1461 tests pass, zero regressions

### Change Log

- 2026-03-23: Implemented story 58.1 — consolidated sparkline bucketing to multi-granularity pipeline, deleted assignBuckets, closed ST-1

### File List

- Peach/Core/Profile/ProgressTimeline.swift (modified — rewired buckets(for:), deleted assignBuckets and unused constants)
- PeachTests/Core/Profile/ProgressTimelineTests.swift (modified — added regression test, updated 2 tests for calendar-snapped zones)
- docs/pre-existing-findings.md (modified — removed closed ST-1 entry)
- docs/implementation-artifacts/58-1-consolidate-sparkline-bucketing-to-multi-granularity-pipeline.md (modified — task checkboxes, dev agent record, status)
