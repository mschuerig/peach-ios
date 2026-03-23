# Story 56.2: Move Tested Note from 4th to 3rd Position

Status: review

## Story

As a **user training rhythm offset discrimination**,
I want the shifted note to be the 3rd sixteenth note instead of the 4th,
So that I have reference clicks on both sides of the tested note and can judge the offset more naturally.

## Context

Currently `buildPattern()` in `RhythmOffsetDetectionSession` applies the trial offset to event index 3 (the 4th and last note). This means the user has three on-grid notes followed by one shifted note, with no trailing reference. Moving the offset to event index 2 (the 3rd note) gives the user reference clicks at positions 1, 2, and 4, surrounding the tested note on both sides.

### Key files

- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` — `buildPattern(for:settings:)`
- `Peach/RhythmOffsetDetection/RhythmDotView.swift` — dot visualization
- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift` — help text

## Acceptance Criteria

1. **Pattern building** — `buildPattern()` applies the timing offset to event index 2 (3rd note). Events 0, 1, 3 remain on the sixteenth-note grid.

2. **Early offset** — Notes 1, 2, 4 on grid; note 3 arrives early (sample offset < 2 × samplesPerSixteenth).

3. **Late offset** — Notes 1, 2, 4 on grid; note 3 arrives late (sample offset > 2 × samplesPerSixteenth).

4. **Dot animation** — Dot index 2 (3rd dot) corresponds to the offset note in the lit-up sequence.

5. **Help text** — Updated to say the *third* click may be early or late (not the *last*).

6. **All existing tests pass** with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Modify `buildPattern()` to offset the 3rd note
  - [x] Build events 0, 1, 3 on the regular sixteenth-note grid
  - [x] Build event 2 at `2 * samplesPerSixteenth + offsetSamples`
  - [x] Sort events by sample offset (in case early offset moves event 2 before event 1's expected position — though this is unlikely at small percentages, defensive sorting is correct)

- [x] Task 2: Update help text
  - [x] Update the "Goal" help section: "The **third** click may arrive slightly early or late"
  - [x] Update German translation

- [x] Task 3: Update tests
  - [x] Verify event offsets: events 0, 1, 3 on grid; event 2 shifted
  - [x] Test with early and late offsets
  - [x] Test pattern total duration unchanged (still 4 × sixteenthDuration)

## Dev Agent Record

### Implementation Plan

Extracted `testedNoteIndex` as a static constant (= 2) on `RhythmOffsetDetectionSession`. `buildPattern()` now builds all 4 events in a single `(0..<4).map` loop, applying the offset only to the event at `testedNoteIndex`. Events are defensively sorted by `sampleOffset` after construction. Changing the tested note position is now a one-constant change.

### Completion Notes

- Extracted `private static let testedNoteIndex = 2` — changing this single constant moves the tested note to any position
- `buildPattern()` rewritten: unified loop with conditional offset application + defensive sort
- Help text updated: "last click" → "**third** click" in English and "letzte Klick" → "**dritte** Klick" in German
- Test renamed and updated: verifies events 0,1,3 on grid, event 2 shifted
- Added test for early-offset sorting correctness
- Added test confirming total duration unchanged
- All 1422 tests pass with zero regressions

## File List

- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift` — extracted `testedNoteIndex` constant, rewrote `buildPattern()`
- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift` — updated help text from "last" to "third"
- `Peach/Resources/Localizable.xcstrings` — updated English key and German translation
- `PeachTests/RhythmOffsetDetection/RhythmOffsetDetectionSessionTests.swift` — updated pattern test, added early-offset sort test and total-duration test

## Change Log

- Moved timing offset from 4th note (index 3) to 3rd note (index 2) with configurable constant (Date: 2026-03-23)

## Technical Notes

- The dot animation loop (`for i in 0..<4`) and `litDotCount` logic remain unchanged — dots still light up in order 1→2→3→4. The 3rd dot now corresponds to the offset note, which is correct since the note plays at that approximate time.
- No changes to the strategy (`AdaptiveRhythmOffsetDetectionStrategy`) or trial types — they produce offsets, not positions.
