# Story 57.2: Replace Dot Coloring with Timing Feedback Indicator

Status: done

## Story

As a **user training continuous rhythm matching**,
I want to see a brief directional indicator showing how many milliseconds early or late my tap was,
So that I get precise, actionable feedback without relying on the too-fast dot coloring.

## Context

Currently `ContinuousRhythmMatchingDotView` flashes the gap dot in green/yellow/red based on offset percentage. User testing showed this passes too quickly to be useful. This story removes the dot coloring and replaces it with a `RhythmTimingFeedbackIndicator` — a transient arrow + millisecond display modeled on `PitchMatchingFeedbackIndicator`.

The accuracy bands use `SpectrogramThresholds.default` — the same hybrid model (base percentage of sixteenth-note duration, clamped to floor/ceiling ms values) used in the profile spectrogram. This ensures feedback colors match what the user sees on their profile.

### Key files

- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingDotView.swift` — remove color feedback
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` — add feedback indicator
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` — expose offset ms + direction
- `Peach/PitchMatching/PitchMatchingFeedbackIndicator.swift` — reference pattern
- `Peach/Core/Profile/SpectrogramData.swift` — `SpectrogramThresholds`, `SpectrogramAccuracyLevel`

## Acceptance Criteria

1. **No dot coloring** — `ContinuousRhythmMatchingDotView` no longer applies green/yellow/red fills. The gap dot is always rendered as an outline stroke (existing gap styling). The `feedbackPercentage` parameter and `feedbackColor()` method are removed.

2. **New feedback indicator** — A `RhythmTimingFeedbackIndicator` view shows:
   - `←` arrow + `X ms` for early taps (negative offset)
   - `→` arrow + `X ms` for late taps (positive offset)
   - `•` for dead center (0ms rounded)

3. **Spectrogram accuracy bands** — The indicator color uses `SpectrogramThresholds.default.accuracyLevel(for:tempoRange:)` to determine precise (green), moderate (yellow), or erratic (red). The tempo range is derived from the current training tempo.

4. **Transient display** — The feedback appears for 200ms (matching `ContinuousRhythmMatchingSession.feedbackDuration`), then fades out.

5. **No feedback on miss** — If the user doesn't tap during a gap, no feedback is shown.

6. **Session state** — The session exposes `lastHitOffsetMs: Double?` (signed, in milliseconds) alongside or replacing `lastHitOffsetPercentage`.

7. **Help text updated** — The "Feedback" help section describes arrows and milliseconds instead of dot colors.

8. **All existing tests pass** with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Create `RhythmTimingFeedbackIndicator`
  - [x] New file: `Peach/ContinuousRhythmMatching/RhythmTimingFeedbackIndicator.swift`
  - [x] Parameters: `offsetMs: Double?`, `tempo: TempoBPM`
  - [x] Static methods (extracted for testability, matching `PitchMatchingFeedbackIndicator` pattern):
    - [x] `arrowSymbolName(offsetMs:)` → `"arrow.left"` / `"arrow.right"` / `"circle.fill"`
    - [x] `offsetText(offsetMs:)` → `"← 5 ms"` / `"→ 3 ms"` / `"• 0 ms"`
    - [x] `accuracyLevel(offsetMs:tempo:)` → uses `SpectrogramThresholds` with a `TempoRange` derived from the tempo
    - [x] `feedbackColor(level:)` → green / yellow / red
    - [x] `accessibilityLabel(offsetMs:)` → e.g., "5 milliseconds early"
  - [x] HStack layout: arrow image + offset text, both colored by accuracy level
  - [x] Accessibility: `.accessibilityElement(children: .combine)`

- [x] Task 2: Expose offset milliseconds from session
  - [x] Add `lastHitOffsetMs: Double?` to `ContinuousRhythmMatchingSession`
  - [x] In `showHitFeedback()`, compute ms from `RhythmOffset.duration` and store it
  - [x] Clear on feedback timeout

- [x] Task 3: Remove dot coloring from `ContinuousRhythmMatchingDotView`
  - [x] Remove `feedbackPercentage` parameter
  - [x] Remove `feedbackColor(forPercentage:)` static method
  - [x] Gap dot always renders as outline stroke (no fill branch)
  - [x] Update all call sites and previews

- [x] Task 4: Integrate feedback indicator into `ContinuousRhythmMatchingScreen`
  - [x] Add `RhythmTimingFeedbackIndicator` to the stats header area (right side, matching pitch matching layout)
  - [x] Bind to `session.lastHitOffsetMs` and `session.showFeedback`
  - [x] Use opacity + animation for transient display (matching existing `feedbackAnimation` pattern)

- [x] Task 5: Update help text
  - [x] Change "Feedback" help section to describe arrows and milliseconds
  - [x] Update German translation

- [x] Task 6: Write tests
  - [x] Test `arrowSymbolName`: negative → left, positive → right, zero → circle
  - [x] Test `offsetText`: formatting with ms unit
  - [x] Test `accuracyLevel`: verify it uses `SpectrogramThresholds` correctly for various tempos
  - [x] Test `feedbackColor`: green/yellow/red mapping
  - [x] Test `accessibilityLabel`: direction + ms text
  - [x] Test session exposes `lastHitOffsetMs` correctly

## Dev Agent Record

### Implementation Plan
- Created `RhythmTimingFeedbackIndicator` following `PitchMatchingFeedbackIndicator` pattern with static methods for testability
- Used `SpectrogramThresholds.default` with a single-tempo `TempoRange` for accurate accuracy classification
- Converted ms offset to percentage via duration arithmetic for the threshold API
- Removed dot coloring entirely, gap dot now always renders as outline stroke
- Integrated indicator into stats header with opacity/animation matching pitch matching screen pattern

### Completion Notes
- All 6 tasks completed with TDD approach
- 18 new tests for `RhythmTimingFeedbackIndicator` (arrow symbols, offset text, accuracy levels, colors, accessibility)
- 3 new tests for session `lastHitOffsetMs` exposure (positive/negative offsets, cleared on stop)
- 4 dot view feedback color tests removed (dead code)
- German translations added for "milliseconds early", "milliseconds late", and updated feedback help text
- All tests pass with zero regressions

## File List

- `Peach/ContinuousRhythmMatching/RhythmTimingFeedbackIndicator.swift` (new)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift` (modified)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingDotView.swift` (modified)
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` (modified)
- `Peach/Resources/Localizable.xcstrings` (modified)
- `PeachTests/ContinuousRhythmMatching/RhythmTimingFeedbackIndicatorTests.swift` (new)
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift` (modified)
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingDotViewTests.swift` (modified)
- `docs/implementation-artifacts/57-2-replace-dot-coloring-with-timing-feedback-indicator.md` (modified)
- `docs/implementation-artifacts/sprint-status.yaml` (modified)

## Change Log

- 2026-03-23: Implemented story 57.2 — replaced dot coloring with timing feedback indicator showing directional arrows and millisecond offset

## Technical Notes

- `SpectrogramThresholds.accuracyLevel(for:tempoRange:)` takes a percentage, not ms. The indicator needs to convert the ms offset to a percentage of sixteenth-note duration first, then call the threshold method. This reuses `RhythmOffset.percentageOfSixteenthNote(at:)`.
- For the `TempoRange` parameter, construct a single-tempo range from the current tempo (or use the closest predefined range). The threshold calculation uses the range's midpoint, so a single-tempo range gives exact results.
- The 200ms feedback duration is already defined as `ContinuousRhythmMatchingSession.feedbackDuration`. The indicator display timing piggybacks on the existing `showFeedback` flag.
