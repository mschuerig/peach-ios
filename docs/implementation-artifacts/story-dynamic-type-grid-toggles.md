# Story: Dynamic Type Support for Grid Toggle Cells

Status: draft

## Story

As a user with large accessibility text sizes,
I want the grid toggle cells in settings to scale with my Dynamic Type preference,
so that labels remain readable instead of being clipped by fixed-size frames.

## Background

`GridToggleRow` and `IntervalSelectorView` both use `.frame(width: 32, height: 32)` for toggle cells. With large accessibility font sizes, the `.caption2` text overflows the fixed frame and gets clipped. `IntervalSelectorView` already wraps its grid in a horizontal `ScrollView`, but `GridToggleRow` does not.

**Source:** future-work.md "Dynamic Type Support for Grid Toggle Cells"

## Acceptance Criteria

1. **Cell dimensions scale with Dynamic Type:** Replace the fixed `width: 32, height: 32` with `@ScaledMetric`-based dimensions in both `GridToggleRow` and `IntervalSelectorView`. The base size remains 32 pt at the default text size.

2. **Text not clipped at large sizes:** At the largest accessibility text sizes (AX1–AX5), all cell labels must remain fully visible and legible.

3. **Layout fits on screen:** At large sizes, if the grid exceeds the available width, the content must be scrollable. `IntervalSelectorView` already has a horizontal `ScrollView`; `GridToggleRow` needs one added if cells overflow.

4. **Header column scales too:** The `IntervalSelectorView` header row uses `.frame(width: 24)` for the direction column and `.frame(width: 32)` for interval headers — both must scale.

5. **Default size unchanged:** At the default Dynamic Type size, the cells must render at exactly 32×32 pt (no visual change for users who haven't changed their text size).

6. **Both views tested visually at AX3+:** Verify in preview or simulator with an accessibility text size that cells, labels, and scroll behavior work correctly.

## Tasks / Subtasks

- [ ] Task 1: Add `@ScaledMetric` to `GridToggleRow` (AC: #1, #2, #5)
  - [ ] Add `@ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 32`
  - [ ] Replace `.frame(width: 32, height: 32)` with `.frame(width: cellSize, height: cellSize)`

- [ ] Task 2: Add horizontal scroll to `GridToggleRow` (AC: #3)
  - [ ] Wrap the `HStack` in `ScrollView(.horizontal, showsIndicators: false)` to handle overflow at large sizes

- [ ] Task 3: Add `@ScaledMetric` to `IntervalSelectorView` (AC: #1, #2, #4, #5)
  - [ ] Add `@ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 32`
  - [ ] Add `@ScaledMetric(relativeTo: .caption) private var headerWidth: CGFloat = 24`
  - [ ] Replace all fixed `.frame(width: 32, height: 32)` with `cellSize`
  - [ ] Replace `.frame(width: 24)` with `headerWidth`
  - [ ] Replace `.frame(width: 32)` in header row with `cellSize`

- [ ] Task 4: Visual verification (AC: #6)
  - [ ] Check both views at default size — no visual change
  - [ ] Check both views at AX3 and AX5 — labels readable, scrolling works

## Dev Notes

### Scope — Minimal Change

This is a 2-file, constants-only change. Replace fixed frame dimensions with `@ScaledMetric` properties and add a `ScrollView` wrapper to `GridToggleRow`.

### Key Files

- `Peach/Settings/GridToggleRow.swift` — line 18: `.frame(width: 32, height: 32)`
- `Peach/Settings/IntervalSelectorView.swift` — line 24: `.frame(width: 32)`, line 20: `.frame(width: 24)`, line 53: `.frame(width: 32, height: 32)`

### `@ScaledMetric` Notes

- `relativeTo:` should match the text style used in the cell (`.caption2`) so the frame scales at the same rate as the text
- At default Dynamic Type, `@ScaledMetric` returns the base value unchanged (AC #5)
- `@ScaledMetric` is a SwiftUI property wrapper — it must be a stored property on the view struct

### What NOT to Change

- Toggle logic (`toggle`, `isLastRemaining`) — purely visual change
- `IntervalSelectorView`'s existing `ScrollView` — keep it, just update the dimensions inside it
- Button styles, colors, corner radius — only the frame sizes change

### References

- [Source: docs/implementation-artifacts/future-work.md#Dynamic Type Support for Grid Toggle Cells]
- [Source: Peach/Settings/GridToggleRow.swift — fixed frame at line 18]
- [Source: Peach/Settings/IntervalSelectorView.swift — fixed frames at lines 20, 24, 53]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
