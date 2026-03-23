# Story 56.4: Overlapping-Circle Visualization for Tested Note

Status: backlog

## Story

As a **user training rhythm offset discrimination**,
I want the tested note (3rd position) to appear as two overlapping circles,
So that I can see at a glance which note may be shifted, and the double shape visually suggests imprecise timing.

## Context

After Story 56.2 moves the tested note to position 3 (index 2), this story adds a permanent visual cue: instead of a single circle, the 3rd dot is rendered as two circles offset horizontally by about half their diameter. This "fuzzy" double shape communicates that the note's timing is uncertain — it could be early or late.

The double-circle is always visible (dimmed when not playing, full opacity when lit), serving as a static visual label for the tested position.

### Key files

- `Peach/RhythmOffsetDetection/RhythmDotView.swift` — dot rendering

## Acceptance Criteria

1. **Double circle at index 2** — The 3rd dot position renders as two circles of standard diameter (16pt), horizontally offset by approximately half the diameter (~8pt), creating a partial overlap.

2. **Always visible** — The double-circle shape is visible at all times: dimmed (opacity 0.2) when between patterns, full opacity (1.0) when lit during playback.

3. **Opacity follows existing logic** — Both circles share the same opacity, controlled by the existing `litCount` comparison.

4. **Layout stability** — The overlapping circles should not change the overall HStack spacing. Use a `ZStack` or overlay approach so the composite shape occupies roughly the same footprint as other dots plus the overlap extension.

5. **Accessibility** — The dot view remains `accessibilityHidden(true)` (unchanged — dots are decorative).

6. **All existing tests pass** with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Implement double-circle rendering in `RhythmDotView`
  - [ ] At index 2, replace the single `Circle()` with two circles in a `ZStack` (or `HStack` with negative spacing)
  - [ ] Each circle uses standard `dotDiameter` (16pt)
  - [ ] Horizontal offset: ~8pt (half diameter) — first circle at -4pt, second at +4pt, or equivalent
  - [ ] Both circles share the same `.fill(.primary)` and opacity

- [ ] Task 2: Ensure layout stability
  - [ ] The composite shape should occupy a defined frame so the HStack spacing remains consistent
  - [ ] Consider using `.frame(width: dotDiameter + overlapOffset, height: dotDiameter)` on the container

- [ ] Task 3: Update previews
  - [ ] Add previews showing the double-circle at various lit states (dimmed, lit, all lit)

## Technical Notes

- The overlap amount (~50% of diameter) is a visual design parameter. The exact value can be tuned during implementation; half the diameter is the starting point.
- The double-circle is specific to Rhythm Offset Discrimination. It is not a shared component — it lives entirely within `RhythmDotView`.
- No changes to `ContinuousRhythmMatchingDotView` — that view has its own gap-stroke visual for its tested position.
