# Hotfix: Tune Kazez Convergence Coefficient and Filter Unrefined Neighbors

Status: done

## Motivation

After implementing weighted effective difficulty (neighbor-based bootstrapping) and Kazez convergence formulas, manual testing on device shows the algorithm still cannot reach the 3–10 cent range within 10 comparisons on a cold start. After ~100 correct answers, difficulty remains above 20 cents. The root causes are: (1) the Kazez narrowing coefficient (0.05) is too conservative for multi-note convergence, and (2) unrefined notes at 100 cents anchor neighbor-weighted averages upward.

This hotfix addresses both issues documented in `future-work.md` under "Weighted Effective Difficulty: Convergence Still Too Slow".

## Story

As a **musician using Peach**,
I want the adaptive algorithm to converge to my pitch discrimination threshold within ~10 comparisons on a cold start,
So that training immediately targets my actual skill level instead of lingering at easy intervals.

## Acceptance Criteria

1. **Given** `AdaptiveNoteStrategy`, **When** a correct answer is recorded, **Then** difficulty narrows using coefficient `0.08` (not `0.05`): `N = P × [1 - (0.08 × √P)]`

2. **Given** the weighted effective difficulty calculation, **When** collecting neighbor notes for bootstrapping, **Then** only neighbors whose `currentDifficulty != DifficultyParameters.defaultDifficulty` are included (in addition to `sampleCount > 0`)

3. **Given** a single note trained from 100 cents with 5 consecutive correct answers, **When** using coefficient 0.08, **Then** difficulty reaches below 10 cents: 100 → 20 → 12.8 → 9.1 → 6.9 → 5.5

4. **Given** all existing tests (updated where needed), **When** the full test suite is run, **Then** all tests pass with zero regressions

5. **Given** the incorrect-answer coefficient, **When** an incorrect answer is recorded, **Then** the widening formula remains unchanged: `N = P × [1 + (0.09 × √P)]`

## Tasks / Subtasks

- [x] Task 1: Increase Kazez correct-answer coefficient from 0.05 to 0.08
  - [x] Change `0.05` to `0.08` in `determineCentDifference()` (line 215 of AdaptiveNoteStrategy.swift)
  - [x] Update doc comment on `determineCentDifference()` to reflect new coefficient
  - [x] Verify incorrect-answer coefficient (0.09) is NOT changed

- [x] Task 2: Filter unrefined neighbors in `weightedEffectiveDifficulty()`
  - [x] Add `&& stats.currentDifficulty != DifficultyParameters.defaultDifficulty` guard to left-neighbor loop (line 256)
  - [x] Add `&& stats.currentDifficulty != DifficultyParameters.defaultDifficulty` guard to right-neighbor loop (line 267)

- [x] Task 3: Update existing tests for new coefficient
  - [x] Update `regionalDifficultyNarrowsOnCorrect`: expected value 50.0 → 20.0 (100 × (1 - 0.08 × √100) = 100 × 0.2 = 20.0)
  - [x] Update `difficultyNarrowsAcrossJumps`: expected value 50.0 → 20.0
  - [x] Verify `kazezConvergenceFromDefault` still passes (converges faster with 0.08)
  - [x] Verify `regionalDifficultyWidensOnIncorrect` is unaffected (0.09 unchanged)
  - [x] Verify `regionalDifficultyRespectsBounds` still passes
  - [x] Review `weightedDifficultyKernelNarrowing` — neighbor condition change may affect test setup; update if needed
  - [x] Review `weightedDifficultyNeighborsOnly` — neighbor must have non-default difficulty to be included; verify test setup sets difficulty explicitly

- [x] Task 4: Run full test suite and verify no regressions

## Dev Notes

### Change 1: Kazez Coefficient (Surgical)

File: `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift`, line 215

Current:
```swift
? max(p * (1.0 - 0.05 * p.squareRoot()),
```

New:
```swift
? max(p * (1.0 - 0.08 * p.squareRoot()),
```

**Why 0.08?** With a 48-note range (36–84), comparisons spread across many notes. Each note gets ~2 of 100 comparisons. At 0.05, a single correct answer from 100 cents gives 50.0 — too slow for neighbor bootstrapping to cascade. At 0.08, a single correct answer from 100 cents gives 20.0. This makes early-trained notes converge faster, so new notes inherit much lower starting points via weighted bootstrapping.

**Convergence comparison (single note, all correct):**

| Step | 0.05 coeff | 0.08 coeff |
|------|-----------|-----------|
| 0    | 100.0     | 100.0     |
| 1    | 50.0      | 20.0      |
| 2    | 32.3      | 12.8      |
| 3    | 22.8      | 9.1       |
| 4    | 16.9      | 6.9       |
| 5    | 13.0      | 5.5       |

### Change 2: Neighbor Filtering (Surgical)

File: `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift`, lines 256 and 267

Current (left-neighbor loop):
```swift
if stats.sampleCount > 0 {
```

New:
```swift
if stats.sampleCount > 0
    && stats.currentDifficulty != DifficultyParameters.defaultDifficulty {
```

Same change for the right-neighbor loop.

**Why?** The first note in every session gets `profile.update()` (sampleCount becomes 1) but never gets Kazez-refined (nil `lastComparison`). Its `currentDifficulty` stays at 100.0 (the default). The neighbor search currently includes any note with `sampleCount > 0`, so this 100-cent anchor pulls up weighted averages for all nearby untrained notes. By also requiring `currentDifficulty != defaultDifficulty`, only Kazez-refined notes contribute to bootstrapping.

**Note:** The current-note check at line 246-247 already has this dual condition. This change makes the neighbor loops consistent.

### Test Impact Analysis

- `regionalDifficultyNarrowsOnCorrect`: Tests Kazez narrowing from 100. Comment says "100 × (1 - 0.05 × √100) = 50.0". With 0.08: "100 × (1 - 0.08 × √100) = 20.0". Update expected value and comment.
- `difficultyNarrowsAcrossJumps`: Same formula, same update needed.
- `kazezConvergenceFromDefault`: Asserts < 10.0 after 10 correct answers. With 0.08, converges much faster — will still pass.
- `regionalDifficultyWidensOnIncorrect`: Uses 0.09 coefficient (unchanged). No update needed.
- `weightedDifficultyKernelNarrowing`: Test trains notes with `profile.update()` AND `profile.setDifficulty()`. Since `setDifficulty` sets `currentDifficulty` to 50.0 (not 100.0), the `!= defaultDifficulty` guard passes. Should still work — verify.
- `weightedDifficultyNeighborsOnly`: Trains note 59 with `update()` then `setDifficulty(note: 59, difficulty: 40.0)`. Since 40.0 != 100.0, neighbor filter passes. Should still work.

### References

- `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift` — target file
- `PeachTests/Core/Algorithm/AdaptiveNoteStrategyTests.swift` — tests to update
- `docs/implementation-artifacts/future-work.md` — source issue: "Weighted Effective Difficulty: Convergence Still Too Slow"

## Dev Agent Record

### Implementation Plan

Surgical two-change implementation: (1) coefficient bump in `determineCentDifference()`, (2) neighbor filter guard in `weightedEffectiveDifficulty()`. Both changes are single-line edits. Test updates for new expected values using approximate comparison (floating-point precision).

### Completion Notes

- Changed Kazez correct-answer coefficient from 0.05 to 0.08 in `determineCentDifference()` (line 215)
- Updated doc comment to reflect new coefficient value
- Verified incorrect-answer coefficient (0.09) unchanged
- Added `&& stats.currentDifficulty != DifficultyParameters.defaultDifficulty` guard to both left-neighbor (line 258) and right-neighbor (line 270) loops in `weightedEffectiveDifficulty()`
- Updated `regionalDifficultyNarrowsOnCorrect` test: expected 50.0 → 20.0 with approximate comparison
- Updated `difficultyNarrowsAcrossJumps` test: expected 50.0 → 20.0 with approximate comparison
- Both tests required `abs(diff - 20.0) < 0.01` instead of exact equality due to floating-point precision (0.08 × 10.0 = 0.7999... not 0.8)
- Verified all other tests unaffected: `kazezConvergenceFromDefault`, `regionalDifficultyWidensOnIncorrect`, `regionalDifficultyRespectsBounds`, `weightedDifficultyKernelNarrowing`, `weightedDifficultyNeighborsOnly` all pass without changes
- Full test suite: 172 tests, all passing, zero regressions

## File List

- Peach/Core/Algorithm/AdaptiveNoteStrategy.swift (modified)
- PeachTests/Core/Algorithm/AdaptiveNoteStrategyTests.swift (modified)
- docs/implementation-artifacts/hotfix-tune-kazez-convergence.md (modified)
- docs/implementation-artifacts/sprint-status.yaml (modified)
- docs/implementation-artifacts/future-work.md (modified)

## Change Log

- 2026-02-17: Story created from future-work.md item "Weighted Effective Difficulty: Convergence Still Too Slow"
- 2026-02-17: Implementation complete — all 4 tasks done, all 172 tests passing
