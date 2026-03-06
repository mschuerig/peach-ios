---
title: 'Pitch Comparison Feedback: Checkmark/X Icons in Top-Right'
slug: 'pitch-comparison-feedback-checkmark-top-right'
created: '2026-03-06'
status: 'complete'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['SwiftUI', 'Swift 6.2']
files_to_modify: ['Peach/PitchComparison/PitchComparisonFeedbackIndicator.swift', 'Peach/PitchComparison/PitchComparisonScreen.swift', 'PeachTests/PitchComparison/PitchComparisonScreenLayoutTests.swift']
code_patterns: ['thin views', 'static methods for testable layout logic', 'HStack(alignment: .top) for top-right feedback placement', 'opacity-based visibility control']
test_patterns: ['Swift Testing @Test/@Suite/#expect', 'static method unit tests for layout params', 'accessibility label tests']
---

# Tech-Spec: Pitch Comparison Feedback: Checkmark/X Icons in Top-Right

**Created:** 2026-03-06

## Overview

### Problem Statement

The pitch comparison feedback indicator uses thumbs up/down icons, but the help text describes a checkmark (correct) and X (incorrect). The help text is actually better. Additionally, the feedback is displayed as a centered overlay on the entire screen, whereas the pitch matching screen positions feedback in the top-right — the pitch comparison screen should follow the same pattern for consistency.

### Solution

Replace `hand.thumbsup.fill` / `hand.thumbsdown.fill` with `checkmark.circle.fill` (green) / `xmark.circle.fill` (red) in `PitchComparisonFeedbackIndicator`. Restructure `PitchComparisonScreen` layout to use an HStack with stats on the left and feedback on the right (top-right), matching the `PitchMatchingScreen` pattern.

### Scope

**In Scope:**
- Change feedback icons from thumbs to checkmark/X in `PitchComparisonFeedbackIndicator`
- Move feedback from centered overlay to top-right HStack layout in `PitchComparisonScreen`
- Use `.font(.title2)` sizing to match pitch matching screen
- Remove unused size constants and static methods
- Update tests to reflect removed API

**Out of Scope:**
- Help text changes (already says checkmark/X)
- German translation changes
- Pitch matching screen changes
- Feedback timing, animation logic, or haptics

## Context for Development

### Codebase Patterns

- Views are thin — observe state, render, send actions; no business logic
- Layout parameters extracted to `static` methods for unit testability
- `@Environment(\.accessibilityReduceMotion)` used for feedback animation control
- `PitchMatchingScreen` uses `HStack(alignment: .top)` with stats left, feedback right, then `Spacer()` between them — this is the reference pattern
- `PitchMatchingScreen` controls feedback visibility via `.opacity()` + `.accessibilityHidden()` (not conditional `if` + `.transition`) — keeps layout stable
- `PitchComparisonScreen` currently uses `.overlay { if showFeedback { ... } }` with `.transition(.opacity)` — this will change to the opacity-based approach

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/PitchComparison/PitchComparisonFeedbackIndicator.swift` | Feedback view — icons to change, sizing to simplify |
| `Peach/PitchComparison/PitchComparisonScreen.swift` | Main screen — layout restructure from overlay to HStack |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Reference pattern for top-right feedback placement (lines 45-74) |
| `PeachTests/PitchComparison/PitchComparisonScreenLayoutTests.swift` | Layout tests — `feedbackIconSize` tests to remove |
| `PeachTests/PitchComparison/PitchComparisonScreenAccessibilityTests.swift` | Accessibility tests — unchanged |
| `PeachTests/PitchComparison/PitchComparisonScreenFeedbackTests.swift` | Feedback state tests — unchanged |

### Technical Decisions

- Use `checkmark.circle.fill` (green) and `xmark.circle.fill` (red) — matches the help text and is more universally understood than thumbs up/down
- Use `.font(.title2)` for the icon, matching the pitch matching screen's compact feedback sizing — no more fixed pixel sizes or compact/regular variants
- Switch from conditional `if` + `.transition(.opacity)` to `.opacity()` + `.accessibilityHidden()` for layout stability (no layout jumps), matching pitch matching screen pattern
- Remove `defaultIconSize` constant and `iconSize` property from `PitchComparisonFeedbackIndicator` — no longer needed with `.font(.title2)`
- Remove `feedbackIconSize(isCompact:)` from `PitchComparisonScreen` — no longer needed
- The `isCorrect` property remains `Bool?` — when `nil`, the view renders nothing (empty body), so the layout space is reserved but visually empty

## Implementation Plan

### Tasks

- [x] Task 1: Simplify `PitchComparisonFeedbackIndicator` with new icons and font sizing
  - File: `Peach/PitchComparison/PitchComparisonFeedbackIndicator.swift`
  - Action: Replace icon names and remove fixed-size constants
  - Details:
    - Change `"hand.thumbsup.fill"` to `"checkmark.circle.fill"`
    - Change `"hand.thumbsdown.fill"` to `"xmark.circle.fill"`
    - Remove `static let defaultIconSize: CGFloat = 100`
    - Remove `var iconSize: CGFloat = defaultIconSize`
    - Replace `.font(.system(size: iconSize))` with `.font(.title2)`
    - Update the doc comment to say "checkmark (green) for correct answers or X (red) for incorrect answers"
    - Update the code example in the doc comment to remove the `iconSize` parameter usage

- [x] Task 2: Restructure `PitchComparisonScreen` layout to top-right feedback
  - File: `Peach/PitchComparison/PitchComparisonScreen.swift`
  - Action: Replace centered overlay with HStack layout matching `PitchMatchingScreen` pattern
  - Details:
    - Remove the `.overlay { if pitchComparisonSession.showFeedback { ... } }` block (lines 91-99)
    - Remove the `.animation(...)` modifier on the VStack that was tied to `showFeedback` (line 100)
    - Remove `static func feedbackIconSize(isCompact:)` (lines 221-223)
    - Wrap TrainingStatsView + interval label + feedback indicator in an `HStack(alignment: .top)`:
      - Left side (VStack, `.leading` alignment): TrainingStatsView on top, interval label below (when in interval mode)
      - `Spacer()` in between
      - Right side: `PitchComparisonFeedbackIndicator(isCorrect: pitchComparisonSession.isLastAnswerCorrect)` with `.opacity(pitchComparisonSession.showFeedback ? 1 : 0)` and `.accessibilityHidden(!pitchComparisonSession.showFeedback)` and `.animation(Self.feedbackAnimation(reduceMotion: reduceMotion), value: pitchComparisonSession.showFeedback)`
    - Add `.padding(.horizontal)` to the HStack (matching PitchMatchingScreen)
    - Remove `.padding(.horizontal)` from TrainingStatsView if it becomes redundant

- [x] Task 3: Update layout tests to remove `feedbackIconSize` tests
  - File: `PeachTests/PitchComparison/PitchComparisonScreenLayoutTests.swift`
  - Action: Remove tests for the deleted `feedbackIconSize(isCompact:)` method
  - Details:
    - Remove the "Feedback Icon Size" MARK section and its two tests (`feedbackIconSizeCompact`, `feedbackIconSizeRegular`) at lines 45-55
    - Remove the `feedbackIconSize` comparison from `compactDimensionsSmallerThanRegular` test (line 63)

### Acceptance Criteria

- [ ] AC 1: Given the pitch comparison screen is displayed, when the user answers correctly, then a green `checkmark.circle.fill` icon appears in the top-right area of the screen
- [ ] AC 2: Given the pitch comparison screen is displayed, when the user answers incorrectly, then a red `xmark.circle.fill` icon appears in the top-right area of the screen
- [ ] AC 3: Given feedback is not being shown, when the screen is displayed, then the feedback area has zero opacity but still occupies its natural layout space (no layout jumps)
- [ ] AC 4: Given interval mode is active, when the screen is displayed, then the interval label and tuning system appear below the stats in the left column, with feedback to the right
- [ ] AC 5: Given Reduce Motion is enabled, when feedback appears, then no animation is applied (existing behavior preserved)
- [ ] AC 6: Given VoiceOver is active, when feedback is shown, then the accessibility label reads "Correct" or "Incorrect" (unchanged)
- [ ] AC 7: Given the help sheet is opened, when the user reads the Feedback section, then the text accurately describes what the UI shows (checkmark/X)

## Additional Context

### Dependencies

None — pure UI changes with no service or data model impacts.

### Testing Strategy

- **Test removal:** Remove 2 tests for `feedbackIconSize(isCompact:)` and update the comparison test — these test a method that no longer exists
- **No new tests needed:** The icon change and layout restructure are visual; the existing feedback state tests (`PitchComparisonScreenFeedbackTests`) verify the `showFeedback`/`isLastAnswerCorrect` contract which is unchanged
- **Existing tests unchanged:** Accessibility label tests, feedback animation tests, help section tests all pass without modification
- **Manual verification:** Check both portrait and landscape on iPhone and iPad to confirm feedback renders in top-right and icons are correct

### Notes

- The `feedbackAnimation` static method and its tests remain unchanged
- The help text already says "checkmark" and "X" — no localization changes needed
- The German help text already says "Hakchen" (checkmark) and "X" — no translation changes needed
