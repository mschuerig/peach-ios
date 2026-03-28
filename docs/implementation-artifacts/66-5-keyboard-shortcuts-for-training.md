# Story 66.5: Keyboard Shortcuts for Training

Status: draft

## Story

As a **musician using Peach on macOS**,
I want to control training with my keyboard,
so that I can train without reaching for the mouse/trackpad — matching the eyes-closed training philosophy.

## Acceptance Criteria

1. **Given** pitch comparison training is in `awaitingAnswer` state on macOS **When** the user presses the up arrow key **Then** the "Higher" answer is submitted (same as tapping the Higher button).

2. **Given** pitch comparison training is in `awaitingAnswer` state on macOS **When** the user presses the down arrow key **Then** the "Lower" answer is submitted (same as tapping the Lower button).

3. **Given** rhythm offset detection training is in `awaitingAnswer` state on macOS **When** the user presses the left arrow key **Then** the "Early" answer is submitted. **When** the user presses the right arrow key **Then** "Late" is submitted.

4. **Given** continuous rhythm matching training on macOS **When** the user presses the spacebar **Then** it registers as a tap (same as tapping the tap button).

5. **Given** pitch matching training in `playingTunable` state on macOS **When** the user presses the spacebar or return key **Then** the pitch is committed (same as releasing the slider — this allows keyboard-only commit after mouse/trackpad slider adjustment).

6. **Given** any training screen on macOS **When** the user presses Escape **Then** training stops and returns to the Start Screen.

7. **Given** keyboard shortcuts **When** training is not in a state that accepts input (e.g., playing notes, showing feedback) **Then** the shortcuts are ignored (same guards as the UI buttons).

8. **Given** the iOS build **When** tested **Then** behaviour is unchanged (keyboard shortcuts are additive, not replacing touch).

9. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Add keyboard shortcuts to pitch comparison (AC: #1, #2, #7)
  - [ ] 1.1 In `PitchDiscriminationScreen`, add `.onKeyPress(.upArrow)` and `.onKeyPress(.downArrow)` modifiers
  - [ ] 1.2 Guard on session state being `awaitingAnswer` before calling `answerHigher()` / `answerLower()`
  - [ ] 1.3 Same shortcuts work for interval pitch comparison (same screen)

- [ ] Task 2: Add keyboard shortcuts to rhythm offset detection (AC: #3, #7)
  - [ ] 2.1 In `RhythmOffsetDetectionScreen`, add `.onKeyPress(.leftArrow)` for Early and `.onKeyPress(.rightArrow)` for Late
  - [ ] 2.2 Guard on appropriate session state

- [ ] Task 3: Add keyboard shortcuts to continuous rhythm matching (AC: #4, #7)
  - [ ] 3.1 In `ContinuousRhythmMatchingScreen`, add `.onKeyPress(.space)` for tap
  - [ ] 3.2 Guard on session accepting taps

- [ ] Task 4: Add keyboard shortcuts to pitch matching (AC: #5, #7)
  - [ ] 4.1 In `PitchMatchingScreen`, add `.onKeyPress(.space)` or `.onKeyPress(.return)` for commit
  - [ ] 4.2 Guard on state being `playingTunable`

- [ ] Task 5: Add Escape to stop training (AC: #6)
  - [ ] 5.1 Add `.onKeyPress(.escape)` to each training screen that calls `session.stop()` and navigates back

- [ ] Task 6: Verify iOS unchanged (AC: #8) and run tests (AC: #9)

## Dev Notes

### SwiftUI `.onKeyPress` Availability

`.onKeyPress` is available on macOS 14.0+ and iOS 17.0+. Since Peach targets iOS 26 / macOS 26, this API is available. On iOS, hardware keyboard users will also benefit from these shortcuts (iPad with keyboard).

### Shortcut Summary

| Context | Key | Action |
|---------|-----|--------|
| Pitch comparison | ↑ | Higher |
| Pitch comparison | ↓ | Lower |
| Rhythm offset detection | ← | Early |
| Rhythm offset detection | → | Late |
| Continuous rhythm matching | Space | Tap |
| Pitch matching | Space / Return | Commit pitch |
| All training | Escape | Stop and return to Start |

### Alternative Considered

Menu bar commands with keyboard equivalents (Cmd+↑, etc.) were considered but rejected — training shortcuts should be single-key for speed, and menu bar commands are for app-level actions (story 66.7).
