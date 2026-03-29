# Story 68.4: Dynamic Type Support for Grid Toggle Cells

Status: ready-for-dev

## Story

As a **user with large accessibility text sizes**,
I want grid toggle cells to scale with Dynamic Type,
so that labels remain readable instead of being clipped.

## Acceptance Criteria

1. **Given** `GridToggleRow` and `IntervalSelectorView` **When** the user has a large Dynamic Type setting **Then** cell dimensions scale proportionally via `@ScaledMetric`.

2. **Given** default Dynamic Type size **When** rendering grid cells **Then** they appear at exactly 32x32 pt (no visual change).

3. **Given** large accessibility sizes **When** cells exceed available width **Then** the content is horizontally scrollable.

4. **Given** `IntervalSelectorView` header column **When** scaling **Then** the 24 pt direction column also scales via `@ScaledMetric`.

## Tasks / Subtasks

- [ ] Task 1: Add `@ScaledMetric` to `GridToggleRow` (AC: #1, #2)
  - [ ] 1.1 Add `@ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 32` property
  - [ ] 1.2 Replace the hardcoded `width: 32, height: 32` in the `.frame()` modifier with the scaled metric
  - [ ] 1.3 Verify at default size the cells remain exactly 32x32 pt

- [ ] Task 2: Add `@ScaledMetric` to `IntervalSelectorView` (AC: #1, #2, #4)
  - [ ] 2.1 Add `@ScaledMetric(relativeTo: .caption2) private var cellSize: CGFloat = 32` property
  - [ ] 2.2 Add `@ScaledMetric(relativeTo: .caption) private var directionColumnWidth: CGFloat = 24` property
  - [ ] 2.3 Replace hardcoded `width: 32, height: 32` in `intervalCell` with the scaled metric
  - [ ] 2.4 Replace hardcoded `width: 32` in `headerRow` ForEach with the scaled metric
  - [ ] 2.5 Replace hardcoded `width: 24` in direction column frames with `directionColumnWidth`

- [ ] Task 3: Add horizontal scrolling to `GridToggleRow` (AC: #3)
  - [ ] 3.1 Wrap the `HStack` in a `ScrollView(.horizontal, showsIndicators: false)` so cells that exceed available width become scrollable
  - [ ] 3.2 `IntervalSelectorView` already has `ScrollView(.horizontal)` -- verify it works correctly with scaled cells

- [ ] Task 4: Verify accessibility behavior (AC: #1, #2, #3)
  - [ ] 4.1 Test with Xcode Accessibility Inspector at AX1, AX3, AX5 text sizes
  - [ ] 4.2 Verify cells scale proportionally and labels remain readable
  - [ ] 4.3 Verify horizontal scrolling activates only when needed
  - [ ] 4.4 Run `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Current Implementation

**`GridToggleRow` (Peach/Settings/GridToggleRow.swift):**
- Generic over `Element: CaseIterable & Hashable`
- Renders a horizontal `HStack(spacing: 4)` of `Button` views
- Each button label uses `.frame(width: 32, height: 32)` with `.font(.caption2)`
- No scrolling -- if too many elements, they overflow or clip

**`IntervalSelectorView` (Peach/Settings/IntervalSelectorView.swift):**
- Uses a `Grid` with `horizontalSpacing: 4, verticalSpacing: 4`
- Header row: empty 24pt-wide column + interval abbreviations at `width: 32`
- Direction rows: direction symbol at `width: 24` + interval cells at `width: 32, height: 32`
- Already wrapped in `ScrollView(.horizontal)` -- good, but cell sizes are still hardcoded

### `@ScaledMetric` Considerations

- `@ScaledMetric(relativeTo:)` scales the value relative to the specified text style. Using `.caption2` matches the font used in the cells.
- At the default Dynamic Type size, `@ScaledMetric` returns the initial value unchanged (32 pt), satisfying AC #2.
- At AX5 (the largest accessibility size), `.caption2` scales to roughly 2.3x, so cells would be ~74 pt. This is large but readable.

### `GridToggleRow` Usage

`GridToggleRow` is used on `SettingsScreen.swift` for selecting tempo ranges and other options. The settings screen is presented in a `NavigationStack` which provides its own scrolling, but the horizontal overflow of the grid row itself needs the `ScrollView` wrapper.

### Project Structure Notes

- Modified: `Peach/Settings/GridToggleRow.swift`
- Modified: `Peach/Settings/IntervalSelectorView.swift`
- Test verification: `PeachTests/Settings/GridToggleRowTests.swift` (existing tests cover toggle logic, not layout)

### References

- [Source: Peach/Settings/GridToggleRow.swift -- HStack of buttons with hardcoded 32x32 frames, .caption2 font]
- [Source: Peach/Settings/IntervalSelectorView.swift -- Grid with 24pt direction column, 32x32 interval cells, already has horizontal ScrollView]
- [Source: Peach/Settings/SettingsScreen.swift -- uses GridToggleRow and IntervalSelectorView]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
