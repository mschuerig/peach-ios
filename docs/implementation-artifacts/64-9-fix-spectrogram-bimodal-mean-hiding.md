# Story 64.9: Fix Spectrogram Combined Mean Hiding Bimodal Distributions

Status: ready-for-dev

## Story

As a **user viewing the rhythm spectrogram**,
I want accuracy metrics to reflect my actual timing patterns,
so that a tendency to alternate between early and late hits doesn't appear as perfect accuracy.

## Acceptance Criteria

1. **Given** a spectrogram cell has early hits averaging -50ms and late hits averaging +50ms **When** cell accuracy is computed **Then** the displayed value reflects the spread (e.g., uses mean of absolute offsets, not signed mean), so it does NOT show 0% (falsely perfect).

2. **Given** `SpectrogramData.combinedMeanPercent()` **When** computing cell accuracy from early and late metrics **Then** it uses the mean of absolute offset values (or RMS, or separate early/late display) rather than a signed mean that cancels out.

3. **Given** the detail overlay for a cell **When** shown **Then** it continues to display separate early/late statistics with signed values, so the user can see directional bias.

4. **Given** the full test suite **When** run **Then** all existing tests pass (with updated expected values where tests assert on combined accuracy).

## Tasks / Subtasks

- [ ] Task 1: Fix `combinedMeanPercent()` in `SpectrogramData` (AC: #1, #2)
  - [ ] 1.1 Read `SpectrogramData.swift` and locate `combinedMeanPercent()` or equivalent
  - [ ] 1.2 Change from signed mean to mean-of-absolute-offsets: `abs(earlyMs).average + abs(lateMs).average` combined, then convert to percent
  - [ ] 1.3 Alternative: use RMS (root mean square) which naturally handles sign cancellation — `sqrt(mean(x^2))`
  - [ ] 1.4 Choose whichever approach produces the most intuitive accuracy metric

- [ ] Task 2: Verify detail overlay still shows directional info (AC: #3)
  - [ ] 2.1 Read the overlay code — confirm it uses `cell.earlyStats` and `cell.lateStats` separately
  - [ ] 2.2 No changes needed if the overlay already shows early/late independently

- [ ] Task 3: Update tests (AC: #4)
  - [ ] 3.1 Update any `SpectrogramData` tests that assert on combined accuracy values
  - [ ] 3.2 Add test: equal-magnitude early/late hits produce a non-zero combined accuracy (the bug case)

- [ ] Task 4: Run full test suite (AC: #4)

## Dev Notes

### The Problem

`SpectrogramData` computes cell accuracy by averaging early and late offsets together:

```swift
let all = earlyMs + lateMs  // e.g., [-50, -45, +48, +52]
let mean = all.reduce(0.0, +) / Double(all.count)  // ≈ 1.25 (near zero!)
return msToPercent(mean, sixteenthMs: sixteenthMs)  // ≈ 1% — looks perfect
```

A user hitting consistently 50ms early and 50ms late has a combined mean near 0, appearing as near-perfect accuracy. The actual timing error is ~50ms in both directions.

### Fix: Mean of Absolute Values

```swift
let all = earlyMs.map(abs) + lateMs.map(abs)
let mean = all.reduce(0.0, +) / Double(all.count)  // ≈ 48.75 — accurate
```

This correctly reflects the magnitude of timing errors regardless of direction.

### Source File Locations

| File | Path |
|------|------|
| SpectrogramData | `Peach/Core/Profile/SpectrogramData.swift` |
| RhythmSpectrogramView | `Peach/Profile/RhythmSpectrogramView.swift` |

### References

- [Source: Peach/Core/Profile/SpectrogramData.swift] — combinedMeanPercent computation
- [Source: Peach/Profile/RhythmSpectrogramView.swift:140-148] — Detail overlay showing early/late separately
