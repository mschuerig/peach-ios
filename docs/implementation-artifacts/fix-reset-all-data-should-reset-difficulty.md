# Story: Fix Reset All Data Should Reset Difficulty

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a musician using Peach,
I want "Reset All Training Data" to fully reset the Kazez convergence chain and all difficulty state,
so that training after a reset starts fresh at cold-start difficulty (100 cents) with no residual convergence state.

## Acceptance Criteria

1. **Given** the user has trained and the Kazez convergence chain has narrowed difficulty below 100 cents,
   **When** the user taps "Reset All Training Data" in Settings and confirms,
   **Then** all per-note `currentDifficulty` values in `PerceptualProfile` are reset to `100.0` (the cold-start default).

2. **Given** the user has reset all training data,
   **When** the user starts a new training session,
   **Then** the first comparison uses exactly 100 cents (cold-start difficulty), not any previously converged difficulty.

3. **Given** the `TrainingSession` has a non-nil `lastCompletedComparison` from a prior training run,
   **When** "Reset All Training Data" is executed,
   **Then** the `TrainingSession`'s convergence-related state (`lastCompletedComparison`) is cleared so the next session enters cold-start mode.

4. **Given** the user resets data and immediately starts training without restarting the app,
   **When** the Kazez formula runs for the first comparison,
   **Then** it enters the bootstrap path (`lastComparison == nil`) and `weightedEffectiveDifficulty()` returns the default 100.0 (no trained neighbors exist).

5. **Given** the existing reset behavior for ComparisonRecords, PerceptualProfile stats, and TrendAnalyzer,
   **When** the convergence chain reset is added,
   **Then** it is atomic with the existing reset — either all state is cleared or none is (error path preserves consistency).

6. **Given** the fix is implemented,
   **When** the full test suite is run,
   **Then** all existing tests pass and new tests verify the reset-then-train cold-start behavior.

## Tasks / Subtasks

- [x] Task 1: Write failing tests for reset-then-train cold-start behavior (AC: #2, #4)
  - [x] Test: after reset, first comparison from `AdaptiveNoteStrategy` uses 100 cents
  - [x] Test: after reset, `weightedEffectiveDifficulty()` returns default (no trained neighbors)
  - [x] Test: after reset, `PerceptualProfile.statsForNote()` returns `currentDifficulty == 100.0` for all notes
- [x] Task 2: Add `resetTrainingData()` method to `TrainingSession` (AC: #3, #5)
  - [x] Clear `lastCompletedComparison` and `sessionBestCentDifference`
  - [x] Call `profile.reset()` and `trendAnalyzer.reset()` from TrainingSession (single responsibility)
  - [x] Ensure the method is safe to call regardless of training state
- [x] Task 3: Update `SettingsScreen.resetAllTrainingData()` to use TrainingSession's reset (AC: #1, #5)
  - [x] Inject `TrainingSession` via `@Environment` in SettingsScreen
  - [x] Replace direct `profile.reset()` / `trendAnalyzer.reset()` calls with `trainingSession.resetTrainingData()`
  - [x] Keep `dataStore.deleteAll()` as the first step with atomic error handling
- [x] Task 4: Verify cold-start behavior end-to-end (AC: #2, #4, #6)
  - [x] Run full test suite
  - [x] Verify no regressions in existing reset, convergence, or training tests

## Dev Notes

### Bug Analysis

The `SettingsScreen.resetAllTrainingData()` currently resets three things:
1. `TrainingDataStore.deleteAll()` — deletes all `ComparisonRecord` entries
2. `profile.reset()` — reinitializes all 128 `PerceptualNote` stats (including `currentDifficulty = 100.0`)
3. `trendAnalyzer.reset()` — clears trend history

**What it does NOT reset:**
- `TrainingSession.lastCompletedComparison` — the chain link for Kazez formula input
- `TrainingSession.sessionBestCentDifference` — session tracking state

While `TrainingSession.stop()` does clear `lastCompletedComparison`, the reset flow relies on the implicit assumption that training was stopped before reset. This creates a fragile contract — the reset's correctness depends on navigation flow rather than an explicit guarantee.

**The fix centralizes convergence chain reset in `TrainingSession`**, making the contract explicit: call `resetTrainingData()` and all difficulty/convergence state is guaranteed cleared, regardless of training state.

### Architecture Compliance

- **TrainingSession is the central state machine** — it should own the reset contract for all training-related state, not have it scattered across SettingsScreen
- **PerceptualProfile reset already works correctly** — `PerceptualNote()` defaults `currentDifficulty` to `100.0`, and `reset()` reinitializes all 128 notes
- **AdaptiveNoteStrategy is stateless** — no internal state to reset; uses `lastComparison` parameter and profile's `currentDifficulty`
- **Composition root (PeachApp.swift)** wires `TrainingSession` — it's already available in the environment

### Kazez Convergence Chain — How It Works

The Kazez sqrt(P)-scaled formulas in `AdaptiveNoteStrategy.determineCentDifference()`:
- **Correct:** `N = P × [1 - (0.08 × √P)]` — narrows difficulty
- **Incorrect:** `N = P × [1 + (0.09 × √P)]` — widens difficulty

Where `P` comes from `lastComparison.centDifference` (chain-based). When `lastComparison` is nil (cold start), falls back to `weightedEffectiveDifficulty()` which bootstraps from neighboring notes' `currentDifficulty`.

**Both chain inputs must be nil/default after reset:**
1. `lastCompletedComparison = nil` → forces cold-start bootstrap path
2. All `currentDifficulty = 100.0` → `weightedEffectiveDifficulty()` finds no trained neighbors → returns 100.0

### Key Files

| File | Role |
|------|------|
| `Peach/Settings/SettingsScreen.swift:123-135` | Current `resetAllTrainingData()` — modify to use TrainingSession |
| `Peach/Training/TrainingSession.swift:145` | `lastCompletedComparison` — convergence chain state |
| `Peach/Training/TrainingSession.swift:295-324` | `stop()` — currently the only place chain state is cleared |
| `Peach/Core/Profile/PerceptualProfile.swift:146-149` | `reset()` — already resets `currentDifficulty` to 100.0 |
| `Peach/Core/Profile/TrendAnalyzer.swift` | `reset()` — already clears trend data |
| `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift:197-224` | `determineCentDifference()` — Kazez formula, reads `lastComparison` |
| `Peach/Core/Algorithm/AdaptiveNoteStrategy.swift:236-291` | `weightedEffectiveDifficulty()` — cold-start bootstrap |
| `Peach/Core/Data/TrainingDataStore.swift:57-66` | `deleteAll()` — batch deletion of ComparisonRecords |
| `PeachTests/Settings/SettingsTests.swift` | Existing reset tests — extend with convergence chain assertions |

### What NOT to Do

- Do NOT add @AppStorage keys for Kazez coefficients — they are intentionally hardcoded (0.08, 0.09)
- Do NOT reset user settings (naturalVsMechanical, noteRange, duration, etc.) — those are preferences, not training data
- Do NOT modify `AdaptiveNoteStrategy` — it is correctly stateless
- Do NOT modify `PerceptualProfile.reset()` — it already correctly resets `currentDifficulty`
- Do NOT add a separate "reset difficulty" button — this fix is about the existing "Reset All Training Data" action

### Testing Approach

Use the existing mock/factory pattern from `TrainingSessionTests`. Key patterns:
- `MockNotePlayer` with `instantPlayback` mode for deterministic timing
- `MockNextNoteStrategy` or real `AdaptiveNoteStrategy` for integration tests
- Factory method returns `(session:, notePlayer:, strategy:, profile:, ...)` tuple
- `waitForState` helper for async state transitions
- All tests `@MainActor async`

**Critical test scenario:**
1. Create TrainingSession with real AdaptiveNoteStrategy and PerceptualProfile
2. Simulate training: update profile with comparisons, set currentDifficulty < 100 on some notes
3. Call `resetTrainingData()` on TrainingSession
4. Call `nextComparison()` on strategy with `lastComparison: nil`
5. Assert returned comparison has `centDifference == 100.0`

### Project Structure Notes

- All changes are within existing files — no new files needed
- `TrainingSession` environment key already exists (wired in `PeachApp.swift`)
- `SettingsScreen` already has `@Environment` access to profile and trendAnalyzer; add TrainingSession access
- Test changes go in `PeachTests/Settings/` and/or `PeachTests/Training/`

### References

- [Source: Peach/Settings/SettingsScreen.swift#resetAllTrainingData] — current reset implementation
- [Source: Peach/Training/TrainingSession.swift#stop] — where chain state is currently cleared
- [Source: Peach/Core/Algorithm/AdaptiveNoteStrategy.swift#determineCentDifference] — Kazez formula and chain input
- [Source: Peach/Core/Profile/PerceptualProfile.swift#reset] — profile reset (already correct)
- [Source: docs/implementation-artifacts/hotfix-tune-kazez-convergence.md] — Kazez coefficient tuning context
- [Source: docs/project-context.md] — project rules and patterns

## Senior Developer Review (AI)

### Review Date: 2026-02-22

### Outcome: Changes Requested

### Summary

All 6 Acceptance Criteria are fully implemented and verified. All tasks marked [x] are genuinely complete. The implementation is correct and well-structured. However, the review identified test organization and coverage gaps that needed addressing.

### Action Items

- [x] [Med] TrendAnalyzer reset path untested — `trendAnalyzer?.reset()` never exercised (all tests used nil trendAnalyzer). Added `resetTrainingDataClearsTrendAnalyzer` test.
- [x] [Med] Tests mislocated — 3 convergence chain reset tests were in `SettingsTests.swift` but test `TrainingSession.resetTrainingData()`. Moved to `TrainingSessionResetTests.swift`.
- [x] [Low] No test for stop-before-reset during active training. Added `resetTrainingDataStopsActiveTraining` test.
- [ ] [Low] TrendAnalyzer dual relationship — both observer and direct dependency in TrainingSession. Accepted as pragmatic trade-off; no code change needed.
- [x] [Low] Misleading "Atomic reset" comment in SettingsScreen. Changed to "Guard: only clear...".

### Severity Breakdown

- High: 0
- Medium: 2 (both fixed)
- Low: 3 (2 fixed, 1 accepted)

## Change Log

- 2026-02-22: Centralized training data reset in TrainingSession.resetTrainingData() — clears convergence chain state (lastCompletedComparison, sessionBestCentDifference), profile, and trend analyzer atomically. SettingsScreen now delegates to this single method instead of calling profile.reset()/trendAnalyzer.reset() directly.
- 2026-02-22: Code review fixes — moved reset tests to TrainingSessionResetTests.swift, added TrendAnalyzer reset coverage and stop-before-reset test, fixed misleading comment.

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Red phase: 3 new tests failed as expected (empty stub)
- Green phase: All 3 tests passed after implementing resetTrainingData()
- Full suite: All tests pass, zero regressions
- Code review: Moved 3 tests to TrainingSessionResetTests.swift, added 2 new tests (trendAnalyzer reset, stop-before-reset). All 302 tests pass.

### Completion Notes List

- Added `resetTrainingData()` to `TrainingSession` — stops training if active, clears `lastCompletedComparison`, `sessionBestCentDifference`, calls `profile.reset()` and `trendAnalyzer?.reset()`
- Added `trendAnalyzer: TrendAnalyzer?` optional dependency to `TrainingSession` init (default nil for backward compatibility in tests)
- Updated `PeachApp.swift` to pass `trendAnalyzer` when constructing `TrainingSession`
- Updated `SettingsScreen` to inject `TrainingSession` via `@Environment` instead of separate profile/trendAnalyzer; reset now calls `trainingSession.resetTrainingData()`
- Removed unused `@Environment(\.perceptualProfile)` and `@Environment(\.trendAnalyzer)` from SettingsScreen
- Code review: Moved 3 reset tests from SettingsTests to TrainingSessionResetTests (correct file location per convention)
- Code review: Added `resetTrainingDataClearsTrendAnalyzer` test (exercises trendAnalyzer?.reset() path)
- Code review: Added `resetTrainingDataStopsActiveTraining` test (verifies stop-before-reset when training active)
- Code review: Fixed misleading "Atomic reset" comment to "Guard" in SettingsScreen

### File List

- Peach/Training/TrainingSession.swift (modified — added `resetTrainingData()`, `trendAnalyzer` dependency)
- Peach/Settings/SettingsScreen.swift (modified — replaced direct profile/trend reset with `trainingSession.resetTrainingData()`, fixed comment)
- Peach/App/PeachApp.swift (modified — passes `trendAnalyzer` to TrainingSession init)
- PeachTests/Settings/SettingsTests.swift (modified — removed mislocated convergence chain reset tests)
- PeachTests/Training/TrainingSessionResetTests.swift (new — 5 tests for resetTrainingData: 3 moved + 2 new)
