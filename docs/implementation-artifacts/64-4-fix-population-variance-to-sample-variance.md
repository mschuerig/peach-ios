# Story 64.4: Fix Population Variance to Sample Variance

Status: review

## Story

As a **user reviewing my training progress**,
I want standard deviation calculations to use the correct statistical formula,
so that my reported variability is accurate rather than systematically understated.

## Acceptance Criteria

1. **Given** `ProgressTimeline.makeBucket()` computes variance **When** a bucket has N > 1 data points **Then** variance is computed as `sum((x - mean)^2) / (N - 1)` (Bessel's correction, sample variance), not `/ N` (population variance).

2. **Given** `SpectrogramData` computes per-cell variance **When** a cell has N > 1 metrics **Then** the same sample variance formula is used.

3. **Given** a bucket or cell with exactly 2 data points **When** stddev is computed **Then** the result equals the correct sample stddev (which is ~41% larger than the previous population stddev for N=2).

4. **Given** the full test suite **When** run **Then** all existing tests pass (with updated expected values where tests assert on stddev).

## Tasks / Subtasks

- [x] Task 1: Fix `ProgressTimeline` variance calculation (AC: #1, #3)
  - [x] 1.1 Read `ProgressTimeline.swift` and locate `makeBucket()` or equivalent where variance is computed with `/ Double(points.count)`
  - [x] 1.2 Change to `/ Double(points.count - 1)` for N > 1 cases
  - [x] 1.3 Keep the N <= 1 case as stddev = 0

- [x] Task 2: Fix `SpectrogramData` variance calculation (AC: #2, #3)
  - [x] 2.1 Read `SpectrogramData.swift` and locate per-cell variance computation
  - [x] 2.2 Apply the same Bessel's correction

- [x] Task 3: Update tests with corrected expected values (AC: #4)
  - [x] 3.1 Search for tests that assert on stddev or variance values from ProgressTimeline or SpectrogramData
  - [x] 3.2 No existing tests asserted on specific stddev values (only zero/non-zero checks). Added 3 new tests for ProgressTimeline and 1 for SpectrogramData verifying sample variance.

- [x] Task 4: Run full test suite (AC: #4)

## Dev Notes

### Impact

Both `ProgressTimeline.makeBucket()` and `SpectrogramData` divide by N (population variance) instead of N-1 (sample variance). For small buckets:
- N=2: reported stddev is 70.7% of true sample stddev
- N=3: reported stddev is 81.6% of true sample stddev
- N=10: reported stddev is 94.9% of true sample stddev

Since training buckets often contain 2-5 sessions, the understatement is significant. Users appear more consistent than they are.

### Note on WelfordAccumulator

`WelfordAccumulator` already provides both `sampleStdDev` (N-1) and `populationStdDev` (N). The `TrainingDisciplineStatistics` uses Welford for its own stats and those are correct. The issue is only in the ad-hoc variance calculations in `ProgressTimeline` and `SpectrogramData` where raw metric arrays are bucketed.

### Source File Locations

| File | Path |
|------|------|
| ProgressTimeline | `Peach/Core/Profile/ProgressTimeline.swift` |
| SpectrogramData | `Peach/Core/Profile/SpectrogramData.swift` |

### References

- [Source: Peach/Core/Profile/ProgressTimeline.swift] — makeBucket variance
- [Source: Peach/Core/Profile/SpectrogramData.swift] — cell variance
- [Source: Peach/Core/Profile/WelfordAccumulator.swift] — correct Bessel's correction reference

## Dev Agent Record

### Implementation Plan

Applied Bessel's correction (N-1 divisor) to both ad-hoc variance calculations, matching what WelfordAccumulator already does correctly.

### Debug Log

- RED: Added 3 ProgressTimeline tests (sample variance N=3, N=2, N=1) and 1 SpectrogramData test — all failed as expected
- GREEN: Changed `/ Double(points.count)` → `/ Double(points.count - 1)` in both files — all tests pass
- No existing tests needed value updates (existing tests only checked zero/non-zero)

### Completion Notes

- Fixed `ProgressTimeline.makeBucket()` line 213: `/ Double(points.count)` → `/ Double(points.count - 1)`
- Fixed `SpectrogramData.computeStats()` line 187: `/ Double(values.count)` → `/ Double(values.count - 1)`
- Added 4 new tests verifying correct sample variance with known values
- Full suite: 1529 tests pass, zero regressions

## File List

- `Peach/Core/Profile/ProgressTimeline.swift` — modified (Bessel's correction)
- `Peach/Core/Profile/SpectrogramData.swift` — modified (Bessel's correction)
- `PeachTests/Core/Profile/ProgressTimelineTests.swift` — modified (3 new tests)
- `PeachTests/Core/Profile/SpectrogramDataTests.swift` — modified (1 new test)
- `docs/implementation-artifacts/64-4-fix-population-variance-to-sample-variance.md` — modified (status/tasks)
- `docs/implementation-artifacts/sprint-status.yaml` — modified (status)

## Change Log

- Fixed population variance to sample variance in ProgressTimeline and SpectrogramData (2026-03-27)
