# Story 57.2: Replace Dot Coloring with Timing Feedback Indicator

Status: backlog

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

- [ ] Task 1: Create `RhythmTimingFeedbackIndicator`
  - [ ] New file: `Peach/ContinuousRhythmMatching/RhythmTimingFeedbackIndicator.swift`
  - [ ] Parameters: `offsetMs: Double?`, `tempo: TempoBPM`
  - [ ] Static methods (extracted for testability, matching `PitchMatchingFeedbackIndicator` pattern):
    - [ ] `arrowSymbolName(offsetMs:)` → `"arrow.left"` / `"arrow.right"` / `"circle.fill"`
    - [ ] `offsetText(offsetMs:)` → `"← 5 ms"` / `"→ 3 ms"` / `"• 0 ms"`
    - [ ] `accuracyLevel(offsetMs:tempo:)` → uses `SpectrogramThresholds` with a `TempoRange` derived from the tempo
    - [ ] `feedbackColor(level:)` → green / yellow / red
    - [ ] `accessibilityLabel(offsetMs:)` → e.g., "5 milliseconds early"
  - [ ] HStack layout: arrow image + offset text, both colored by accuracy level
  - [ ] Accessibility: `.accessibilityElement(children: .combine)`

- [ ] Task 2: Expose offset milliseconds from session
  - [ ] Add `lastHitOffsetMs: Double?` to `ContinuousRhythmMatchingSession`
  - [ ] In `showHitFeedback()`, compute ms from `RhythmOffset.duration` and store it
  - [ ] Clear on feedback timeout

- [ ] Task 3: Remove dot coloring from `ContinuousRhythmMatchingDotView`
  - [ ] Remove `feedbackPercentage` parameter
  - [ ] Remove `feedbackColor(forPercentage:)` static method
  - [ ] Gap dot always renders as outline stroke (no fill branch)
  - [ ] Update all call sites and previews

- [ ] Task 4: Integrate feedback indicator into `ContinuousRhythmMatchingScreen`
  - [ ] Add `RhythmTimingFeedbackIndicator` to the stats header area (right side, matching pitch matching layout)
  - [ ] Bind to `session.lastHitOffsetMs` and `session.showFeedback`
  - [ ] Use opacity + animation for transient display (matching existing `feedbackAnimation` pattern)

- [ ] Task 5: Update help text
  - [ ] Change "Feedback" help section to describe arrows and milliseconds
  - [ ] Update German translation

- [ ] Task 6: Write tests
  - [ ] Test `arrowSymbolName`: negative → left, positive → right, zero → circle
  - [ ] Test `offsetText`: formatting with ms unit
  - [ ] Test `accuracyLevel`: verify it uses `SpectrogramThresholds` correctly for various tempos
  - [ ] Test `feedbackColor`: green/yellow/red mapping
  - [ ] Test `accessibilityLabel`: direction + ms text
  - [ ] Test session exposes `lastHitOffsetMs` correctly

## Technical Notes

- `SpectrogramThresholds.accuracyLevel(for:tempoRange:)` takes a percentage, not ms. The indicator needs to convert the ms offset to a percentage of sixteenth-note duration first, then call the threshold method. This reuses `RhythmOffset.percentageOfSixteenthNote(at:)`.
- For the `TempoRange` parameter, construct a single-tempo range from the current tempo (or use the closest predefined range). The threshold calculation uses the range's midpoint, so a single-tempo range gives exact results.
- The 200ms feedback duration is already defined as `ContinuousRhythmMatchingSession.feedbackDuration`. The indicator display timing piggybacks on the existing `showFeedback` flag.
