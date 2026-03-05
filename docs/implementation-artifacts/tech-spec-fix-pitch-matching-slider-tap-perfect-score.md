---
title: 'Fix pitch matching slider-tap-perfect-score regression'
slug: 'fix-pitch-matching-slider-tap-perfect-score'
created: '2026-03-05'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['Swift 6.2', 'SwiftUI', 'Swift Testing']
files_to_modify: ['Peach/PitchMatching/PitchMatchingSession.swift', 'PeachTests/PitchMatching/PitchMatchingSessionTests.swift']
code_patterns: ['TDD bug fix', 'state machine', 'cent offset = initialCentOffset + value * range']
test_patterns: ['Swift Testing @Test/@Suite/#expect', 'waitForState helper', 'transitionToPlayingTunable helper', 'makePitchMatchingSession factory', 'MockNotePlayer/MockPitchMatchingProfile/MockPitchMatchingObserver']
---

# Tech-Spec: Fix pitch matching slider-tap-perfect-score regression

**Created:** 2026-03-05

## Overview

### Problem Statement

In both pitch matching training variants (unison and interval), tapping the slider without moving it always produces a perfect score (0 cent error). The slider center (value=0) maps to the exact target frequency, completely ignoring `initialCentOffset`. This means users can achieve perfect results without actually matching pitch.

### Solution

Add `challenge.initialCentOffset` into the cent offset calculation in both `adjustPitch()` and `commitPitch()`, so that slider value 0 corresponds to the initial detuned pitch (not the perfect target). The user must drag the slider to find the position where the detuning is cancelled.

### Scope

**In Scope:**
- Fix `adjustPitch()` and `commitPitch()` in `PitchMatchingSession.swift` to include `initialCentOffset` in frequency calculation
- Write regression test proving tap-without-move does not produce perfect score

**Out of Scope:**
- Slider UI changes (VerticalPitchSlider is unchanged)
- Challenge generation logic
- Data model changes
- Profile/statistics changes

## Context for Development

### Codebase Patterns

- Bug fix workflow: write a failing test that reproduces the bug before fixing it (TDD)
- `PitchMatchingSession` is the sole state machine for pitch matching training
- `referenceFrequency` (line 250) stores the exact (un-detuned) target frequency
- `initialCentOffset` is a random value in -20...+20 cents, stored on `PitchMatchingChallenge`
- Slider value range: -1.0...1.0, mapped to cents via `value * initialCentOffsetRange.upperBound` (i.e. value * 20.0)
- `adjustPitch()` (line 103): transitions from `awaitingSliderTouch` → `playingTunable` on first call, then adjusts note frequency on subsequent calls
- `commitPitch()` (line 118): handles both `awaitingSliderTouch` quick-tap and normal `playingTunable` commit
- Both methods compute: `centOffset = value * 20.0` then `frequency = referenceFrequency * pow(2, centOffset/1200)` — this is the buggy formula (ignores `initialCentOffset`)

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/PitchMatching/PitchMatchingSession.swift` | State machine with `adjustPitch()` (line 103) and `commitPitch()` (line 118) — the bug location |
| `Peach/PitchMatching/PitchMatchingChallenge.swift` | Value type holding `initialCentOffset` |
| `Peach/PitchMatching/VerticalPitchSlider.swift` | Slider UI — NOT modified, but useful for understanding gesture flow |
| `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` | Existing tests; `commitPitchFromAwaitingSliderTouchProducesResult` (line 174) asserts the buggy behavior (`abs(result.userCentError) < 0.01`) |

### Technical Decisions

- The slider always starts at center (value=0). The sound starts detuned by `initialCentOffset` cents. The scoring must reflect that slider=0 means "accept the detuned pitch as-is" (not perfect).
- The correct formula: `centOffset = challenge.initialCentOffset + value * 20.0`. At slider=0, `centOffset = initialCentOffset` (user gets the detuning as their error). User must find value where `initialCentOffset + value * 20 ≈ 0` for a perfect score.
- The existing test `commitPitchFromAwaitingSliderTouchProducesResult` (line 174) must be updated — it currently encodes the bug by asserting `< 0.01` cents error for `commitPitch(0.0)`.
- The `transitionToPlayingTunable` helper calls `adjustPitch(0.0)` — after the fix, this sets the note to the initial detuned frequency instead of perfect. This is correct behavior and existing tests using this helper should still pass (they test state transitions, not frequency values).

## Implementation Plan

### Tasks

- [ ] Task 1: Write failing regression test
  - File: `PeachTests/PitchMatching/PitchMatchingSessionTests.swift`
  - Action: Add a test that starts a session, waits for `awaitingSliderTouch`, calls `commitPitch(0.0)`, and asserts that `userCentError` is NOT near zero (it should equal the challenge's `initialCentOffset`). Use fixed `noteRange` (e.g., `MIDINote(69)...MIDINote(81)`) and `.concert440` reference pitch for deterministic frequency values. Assert `abs(result.userCentError) > 1.0` to prove the bug (this test will fail before the fix).
  - Notes: The `initialCentOffset` is random in -20...+20 range, so any non-trivial offset will produce error > 1.0 cent. To make the test deterministic, also assert that `abs(result.userCentError - challenge.initialCentOffset) < 0.01` after the fix — slider=0 should produce exactly the initial detuning as error.

- [ ] Task 2: Fix `adjustPitch()` to include `initialCentOffset`
  - File: `Peach/PitchMatching/PitchMatchingSession.swift`
  - Action: Change the cent offset calculation (line 111) from:
    ```swift
    let centOffset = value * Self.initialCentOffsetRange.upperBound
    ```
    to:
    ```swift
    guard let challenge = currentChallenge else { return }
    let centOffset = challenge.initialCentOffset + value * Self.initialCentOffsetRange.upperBound
    ```
  - Notes: This makes slider=0 set the note to the initial detuned frequency (no audible jump when first touching). Moving the slider adjusts from the detuned starting point.

- [ ] Task 3: Fix `commitPitch()` to include `initialCentOffset`
  - File: `Peach/PitchMatching/PitchMatchingSession.swift`
  - Action: Change the cent offset calculation (line 126) from:
    ```swift
    let centOffset = value * Self.initialCentOffsetRange.upperBound
    ```
    to:
    ```swift
    guard let challenge = currentChallenge else { return }
    let centOffset = challenge.initialCentOffset + value * Self.initialCentOffsetRange.upperBound
    ```
  - Notes: This makes slider=0 submit `initialCentOffset` as the user's cent error instead of 0.

- [ ] Task 4: Fix the existing buggy test
  - File: `PeachTests/PitchMatching/PitchMatchingSessionTests.swift`
  - Action: Update `commitPitchFromAwaitingSliderTouchProducesResult` (line 174). Change the assertion from `#expect(abs(result.userCentError) < 0.01)` to assert that the error equals the challenge's `initialCentOffset`. For example:
    ```swift
    let challenge = try #require(session.currentChallenge)
    #expect(abs(result.userCentError - challenge.initialCentOffset) < 0.01)
    ```
  - Notes: The test description should also be updated to reflect the corrected behavior (e.g., "commitPitch from awaitingSliderTouch produces result with initial offset error").

- [ ] Task 5: Run full test suite
  - Action: `bin/test.sh` — all tests must pass with zero regressions
  - Notes: Pay attention to tests that assert specific frequency values after `adjustPitch(0.0)` — these should now produce the detuned frequency, not the perfect frequency. The `transitionToPlayingTunable` helper uses `adjustPitch(0.0)` but tests using it check state transitions, not frequencies, so they should pass.

### Acceptance Criteria

- [ ] AC 1: Given the session is in `awaitingSliderTouch` state, when the user commits pitch at slider value 0 (tap without moving), then `userCentError` equals `initialCentOffset` (not 0)
- [ ] AC 2: Given the session is in `playingTunable` state with the slider at value 0, when `adjustPitch(0.0)` is called, then the tunable note plays at the initial detuned frequency (not the exact target frequency)
- [ ] AC 3: Given the session is in `playingTunable` state, when the user drags the slider to the position where `initialCentOffset + value * 20 = 0`, then `userCentError` is approximately 0 (perfect match requires finding the correct slider position)
- [ ] AC 4: Given the fix is applied, when the full test suite runs, then all existing tests pass with zero regressions

## Additional Context

### Dependencies

None. Pure logic fix within `PitchMatchingSession`.

### Testing Strategy

- **TDD:** Write failing regression test first (Task 1), then fix production code (Tasks 2-3), then fix existing buggy test (Task 4), then run full suite (Task 5)
- **Regression test:** Proves that `commitPitch(0.0)` from `awaitingSliderTouch` does NOT produce 0 cent error
- **Existing test fix:** `commitPitchFromAwaitingSliderTouchProducesResult` updated to assert correct behavior
- **Full suite:** `bin/test.sh` — ensures no regressions in state transitions, frequency calculations, or other pitch matching tests

### Notes

- This is a regression of a previously fixed bug. The regression was likely introduced during the story 26.1 refactoring (delay target note until slider touch), which restructured `adjustPitch()` and `commitPitch()` with early-return paths for the `awaitingSliderTouch` state.
- The fix is a two-line change in production code (plus the `guard let challenge` for safe access). The test changes are slightly larger but straightforward.
- Risk: low. The formula change is additive (`initialCentOffset +` prefix), the `challenge` is always set when these methods are called in valid states, and the `transitionToPlayingTunable` helper still works (just produces detuned frequency instead of perfect, which is correct).
