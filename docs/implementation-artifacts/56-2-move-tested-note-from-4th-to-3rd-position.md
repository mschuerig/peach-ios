# Story 56.2: Move Tested Note from 4th to 3rd Position

Status: backlog

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

- [ ] Task 1: Modify `buildPattern()` to offset the 3rd note
  - [ ] Build events 0, 1, 3 on the regular sixteenth-note grid
  - [ ] Build event 2 at `2 * samplesPerSixteenth + offsetSamples`
  - [ ] Sort events by sample offset (in case early offset moves event 2 before event 1's expected position — though this is unlikely at small percentages, defensive sorting is correct)

- [ ] Task 2: Update help text
  - [ ] Update the "Goal" help section: "The **third** click may arrive slightly early or late"
  - [ ] Update German translation

- [ ] Task 3: Update tests
  - [ ] Verify event offsets: events 0, 1, 3 on grid; event 2 shifted
  - [ ] Test with early and late offsets
  - [ ] Test pattern total duration unchanged (still 4 × sixteenthDuration)

## Technical Notes

- The dot animation loop (`for i in 0..<4`) and `litDotCount` logic remain unchanged — dots still light up in order 1→2→3→4. The 3rd dot now corresponds to the offset note, which is correct since the note plays at that approximate time.
- No changes to the strategy (`AdaptiveRhythmOffsetDetectionStrategy`) or trial types — they produce offsets, not positions.
