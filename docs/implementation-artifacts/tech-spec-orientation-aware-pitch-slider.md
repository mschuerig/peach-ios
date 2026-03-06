---
title: 'Orientation-Aware Pitch Slider'
slug: 'orientation-aware-pitch-slider'
created: '2026-03-06'
status: 'ready-for-dev'
stepsCompleted: [1, 2, 3, 4]
tech_stack: ['SwiftUI', 'Swift 6.2', 'Swift Testing']
files_to_modify: ['Peach/PitchMatching/VerticalPitchSlider.swift → PitchSlider.swift', 'Peach/PitchMatching/PitchMatchingScreen.swift', 'PeachTests/PitchMatching/VerticalPitchSliderTests.swift → PitchSliderTests.swift']
code_patterns: ['verticalSizeClass with isCompactHeight computed property', 'static methods for testable layout logic', 'GeometryReader for track dimensions', 'isHorizontal Bool parameter on slider']
test_patterns: ['Swift Testing @Test/@Suite', 'static method unit tests for layout params', 'round-trip consistency tests', 'dedicated layout test files (e.g. PitchComparisonScreenLayoutTests)']
---

# Tech-Spec: Orientation-Aware Pitch Slider

**Created:** 2026-03-06

## Overview

### Problem Statement

In landscape orientation, the vertical pitch slider on the pitch matching screen has very little height, making it nearly unusable for pitch adjustment.

### Solution

Rename `VerticalPitchSlider` to `PitchSlider` and make it orientation-aware: vertical in portrait, horizontal in landscape (left = lower, right = higher). Adjust `PitchMatchingScreen` layout so stats and feedback remain usable in both orientations. Change the thumb from a rounded rectangle to a circle.

### Scope

**In Scope:**
- Rename `VerticalPitchSlider` to `PitchSlider` (file, type, tests)
- Detect orientation via `verticalSizeClass` and switch slider axis accordingly
- Portrait: slider is vertical (current behavior — top = sharper, bottom = flatter)
- Landscape: slider is horizontal (right = sharper, left = flatter)
- Landscape layout on `PitchMatchingScreen`: stats (left) + feedback (right) on top row, horizontal slider below
- Change thumb shape from rounded rectangle (80x60) to circle (~70pt diameter)
- Update static calculation methods to work for both axes
- Update all tests

**Out of Scope:**
- Changes to `PitchMatchingSession` or any business logic
- Changes to the feedback indicator or stats views themselves
- iPad-specific layout adjustments

## Context for Development

### Codebase Patterns

- `StartScreen` and `PitchComparisonScreen` already use `@Environment(\.verticalSizeClass)` with `isCompactHeight` computed property
- Layout parameters extracted to `static` methods for unit testability (e.g., `buttonIconSize(isCompact:)`)
- Dedicated layout test files: `StartScreenLayoutTests`, `PitchComparisonScreenLayoutTests`
- Views are thin — no business logic
- `GeometryReader` used in slider for responsive sizing within available space
- `PitchMatchingFeedbackIndicator` is already compact (HStack with arrow + cents text, `.font(.title2)`)
- `TrainingStatsView` uses `.frame(maxWidth: .infinity, alignment: .leading)`

### Files to Reference

| File | Purpose |
| ---- | ------- |
| `Peach/PitchMatching/VerticalPitchSlider.swift` | Current vertical-only slider — rename to `PitchSlider.swift` and make orientation-aware |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Screen layout — add `verticalSizeClass` detection, landscape layout variant |
| `PeachTests/PitchMatching/VerticalPitchSliderTests.swift` | Existing slider tests — rename to `PitchSliderTests.swift` and extend |
| `Peach/PitchComparison/PitchComparisonScreen.swift` | Reference for `isCompactHeight` pattern |
| `PeachTests/PitchComparison/PitchComparisonScreenLayoutTests.swift` | Reference for layout test pattern |
| `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` | Already compact — no changes needed |
| `Peach/App/TrainingStatsView.swift` | Stats display — no changes needed |

### Technical Decisions

- `PitchSlider` receives `isHorizontal: Bool` as an input parameter — the screen reads `verticalSizeClass` and passes it down, keeping the slider a pure testable component
- The slider's public API (`onValueChange`, `onCommit` with `-1.0...1.0`) stays unchanged — orientation is purely a visual concern
- Static methods gain an `isHorizontal` parameter: `value(dragPosition:trackLength:isHorizontal:)` and `thumbPosition(value:trackLength:isHorizontal:)`
- Vertical: top = +1.0 (sharper), bottom = -1.0 (flatter). Horizontal: right = +1.0, left = -1.0
- Range indicator `Capsule` rotates with the slider axis
- Thumb becomes a `Circle` (~70pt diameter) in both orientations
- Portrait layout stays the same (VStack: stats row on top, vertical slider below)
- Landscape layout: stats (left) + feedback (right) in top HStack, horizontal slider fills remaining space below

## Implementation Plan

### Tasks

- [ ] Task 1: Rename `VerticalPitchSlider` to `PitchSlider`
  - File: `Peach/PitchMatching/VerticalPitchSlider.swift` → rename to `PitchSlider.swift`
  - Action: Rename file. Rename `struct VerticalPitchSlider` to `struct PitchSlider`. No logic changes yet.

- [ ] Task 2: Change thumb from rounded rectangle to circle
  - File: `Peach/PitchMatching/PitchSlider.swift`
  - Action: Replace `RoundedRectangle(cornerRadius: 12).frame(width: 80, height: 60)` with `Circle().frame(width: 70, height: 70)`. Remove the separate `thumbWidth`/`thumbHeight` constants, replace with single `thumbDiameter: CGFloat = 70`.

- [ ] Task 3: Add `isHorizontal` parameter and orientation-aware layout to `PitchSlider`
  - File: `Peach/PitchMatching/PitchSlider.swift`
  - Action:
    - Add `var isHorizontal: Bool` property
    - Refactor static methods to accept `isHorizontal`:
      - `value(dragPosition:trackLength:isHorizontal:)` — when vertical: uses current logic (top=+1, bottom=-1). When horizontal: left edge (0) = -1.0, right edge = +1.0, so `value = 2 * fraction - 1` where `fraction = dragX / trackWidth`
      - `thumbPosition(value:trackLength:isHorizontal:)` — inverse of above. When horizontal: `fraction = (value + 1) / 2`, position = `trackWidth * fraction`
    - In `body`: read `geometry.size.width` or `.height` based on `isHorizontal`
    - When horizontal: range indicator `Capsule` uses `.frame(height: 2)` instead of `.frame(width: 2)`. Thumb positioned with `x:` varying and `y:` centered (inverse of current)
    - `DragGesture` reads `value.location.x` when horizontal, `.y` when vertical
    - Accessibility label: update to mention direction ("left to right" vs "up and down")

- [ ] Task 4: Add `verticalSizeClass` detection to `PitchMatchingScreen`
  - File: `Peach/PitchMatching/PitchMatchingScreen.swift`
  - Action:
    - Add `@Environment(\.verticalSizeClass) private var verticalSizeClass`
    - Add `private var isCompactHeight: Bool { verticalSizeClass == .compact }`
    - Pass `isHorizontal: isCompactHeight` to `PitchSlider`
    - Update `VerticalPitchSlider` reference to `PitchSlider`

- [ ] Task 5: Adjust `PitchMatchingScreen` layout for landscape
  - File: `Peach/PitchMatching/PitchMatchingScreen.swift`
  - Action:
    - Portrait (current): `VStack { HStack(stats, feedback) ; PitchSlider(isHorizontal: false) }`
    - Landscape: same top-level `VStack { HStack(stats, feedback) ; PitchSlider(isHorizontal: true) }` — the stats/feedback row stays at top, horizontal slider fills below
    - The existing HStack with stats (left) and feedback (right) already works for both orientations — no structural change needed there
    - Help text in `helpSections` referencing "up or down" should be updated to mention both directions

- [ ] Task 6: Rename test file and update references
  - File: `PeachTests/PitchMatching/VerticalPitchSliderTests.swift` → rename to `PitchSliderTests.swift`
  - Action: Rename file. Rename `@Suite("VerticalPitchSlider")` to `@Suite("PitchSlider")`. Replace all `VerticalPitchSlider.` calls with `PitchSlider.`. Update existing test calls to pass `isHorizontal: false` (preserving current vertical behavior tests).

- [ ] Task 7: Add horizontal-axis tests
  - File: `PeachTests/PitchMatching/PitchSliderTests.swift`
  - Action: Add new test section `// MARK: - Horizontal value Tests` mirroring existing vertical tests:
    - Center drag yields zero: `value(dragPosition: 200, trackLength: 400, isHorizontal: true)` → 0
    - Left edge yields -1.0: `value(dragPosition: 0, trackLength: 400, isHorizontal: true)` → -1.0
    - Right edge yields +1.0: `value(dragPosition: 400, trackLength: 400, isHorizontal: true)` → 1.0
    - Quarter from left yields -0.5: `value(dragPosition: 100, trackLength: 400, isHorizontal: true)` → -0.5
    - Drag beyond left clamps to -1.0
    - Drag beyond right clamps to +1.0
    - Horizontal thumbPosition tests (inverse of above)
    - Horizontal round-trip consistency test

### Acceptance Criteria

- [ ] AC 1: Given the app in portrait orientation, when the pitch matching screen is displayed, then the slider is vertical with the thumb moving top (sharper) to bottom (flatter) — identical to current behavior.
- [ ] AC 2: Given the app in landscape orientation, when the pitch matching screen is displayed, then the slider is horizontal with the thumb moving left (flatter) to right (sharper).
- [ ] AC 3: Given the app in landscape orientation, when viewing the pitch matching screen, then training stats appear at the top-left and the feedback indicator appears at the top-right, with the horizontal slider filling the space below.
- [ ] AC 4: Given the slider in horizontal mode, when the user drags to the left edge, then `onValueChange` receives -1.0 (flatter).
- [ ] AC 5: Given the slider in horizontal mode, when the user drags to the right edge, then `onValueChange` receives +1.0 (sharper).
- [ ] AC 6: Given the slider in horizontal mode, when the user drags to the center, then `onValueChange` receives 0.0.
- [ ] AC 7: Given the slider in either orientation, when the user drags beyond the track bounds, then the value clamps to -1.0 or +1.0 respectively.
- [ ] AC 8: Given the slider in horizontal mode, when `thumbPosition` is computed and then fed back through `value`, then the round-trip produces the original value (within floating point tolerance).
- [ ] AC 9: Given the type has been renamed, when searching the codebase for `VerticalPitchSlider`, then zero references remain.
- [ ] AC 10: Given either orientation, when viewing the slider, then the thumb is a circle of ~70pt diameter.
- [ ] AC 11: Given the slider in horizontal mode, when viewing the range indicator, then it is a horizontal capsule line (height: 2pt) instead of a vertical one.

## Additional Context

### Dependencies

None — pure UI change, no new services or models.

### Testing Strategy

- **Unit tests (static methods):** All existing vertical tests updated with `isHorizontal: false`. New horizontal tests mirror the vertical suite with `isHorizontal: true`. Round-trip consistency for both axes.
- **Manual testing:** Rotate device/simulator between portrait and landscape on the pitch matching screen. Verify slider axis changes, thumb is circular, stats/feedback layout remains usable. Test drag behavior in both orientations.

### Notes

- The `-1.0...1.0` value range semantics stay the same regardless of orientation: -1.0 = flatter, +1.0 = sharper
- In horizontal mode: left = flatter (-1.0), right = sharper (+1.0)
- In vertical mode: bottom = flatter (-1.0), top = sharper (+1.0)
- The existing portrait layout (`VStack { HStack(stats, feedback) ; slider }`) works for landscape too — the main change is the slider's internal axis, not the screen's top-level structure
- Help text in the help sheet currently says "drag up or down" — should be updated to reflect both orientations
