# Story 59.1: Unify Gap Position Selector to Grid Buttons

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a user,
I want the gap position selector to use the same grid-button visual style as the interval selector,
so that the settings screen has a consistent look and feel for all multi-select controls.

## Acceptance Criteria

1. **Grid button appearance** — Gap positions are displayed as a single horizontal row of 4 square toggle-buttons labeled "1", "2", "3", "4", using the same visual treatment as `IntervalSelectorView` cells: accent-color background when active, `Color.secondary.opacity(0.2)` when inactive, white foreground when active, `.secondary` foreground when inactive, `RoundedRectangle(cornerRadius: 6)` clip shape.

2. **Toggle behavior preserved** — Tapping an active button deactivates it; tapping an inactive button activates it. At least one position must remain active — the last remaining active button is `.disabled(true)`.

3. **Reusable component** — The new view is a standalone `struct` that accepts a generic set-binding, not hardcoded to `StepPosition`. It must be reusable for any `CaseIterable & Hashable` element type with a label-providing closure, so future multi-select grid needs can use the same component.

4. **IntervalSelectorView unchanged** — The existing `IntervalSelectorView` is not modified. It has a 2D grid structure (directions × intervals) that does not fit the generic 1D component. No refactoring of `IntervalSelectorView` is in scope.

5. **SettingsScreen integration** — The `gapPositionsSection` in `SettingsScreen` uses the new component in place of the current `Toggle`-based list. The section header ("Gap Positions") and footer ("Select which gap positions to practice. At least one must remain active.") remain unchanged.

6. **Encoding unchanged** — `GapPositionEncoding` (CSV format) and `@AppStorage` key are not modified. The view reads/writes through the same `enabledGapPositionsEncoded` binding.

7. **Localization** — Button labels "1", "2", "3", "4" are plain digits and do not require localization. No new localization keys are introduced.

## Tasks / Subtasks

- [x] Task 1: Create `GridToggleRow` reusable view (AC: 1, 3)
  - [x] 1.1 Create `Peach/Settings/GridToggleRow.swift`
  - [x] 1.2 Generic over `Element: CaseIterable & Hashable`, accepts `Binding<Set<Element>>` and `label: (Element) -> String` closure
  - [x] 1.3 Render a single `HStack` (or `GridRow`) of square toggle-buttons matching `IntervalSelectorView` cell styling
  - [x] 1.4 Disable the last remaining active button to enforce minimum-one constraint
- [x] Task 2: Integrate into `SettingsScreen` (AC: 2, 5, 6)
  - [x] 2.1 Replace `gapPositionsSection` body: swap `ForEach` + `Toggle` for `GridToggleRow<StepPosition>`
  - [x] 2.2 Provide label closure mapping `StepPosition` → `"1"`, `"2"`, `"3"`, `"4"`
  - [x] 2.3 Remove now-dead helper methods (`isGapPositionEnabled`, `isLastEnabledGapPosition`, `gapPositionLabels`) and `toggleGapPosition` if fully subsumed by the binding
  - [x] 2.4 Keep section header/footer text unchanged
- [x] Task 3: Tests (AC: 1, 2, 3, 4)
  - [x] 3.1 Unit test `GridToggleRow` toggle behavior: activate, deactivate, last-remaining guard
  - [x] 3.2 Verify visual styling matches spec (accent background, rounded rect, disabled state)

## Dev Notes

### Key Files

| File | Role |
|------|------|
| `Peach/Settings/IntervalSelectorView.swift` | **Reference** — copy cell styling from `intervalCell(interval:direction:)` lines 48-57 |
| `Peach/Settings/SettingsScreen.swift:301-318` | **Modify** — replace `gapPositionsSection` body |
| `Peach/Settings/SettingsScreen.swift:271-299` | **Remove** — dead helpers after integration (`gapPositionLabels`, `isGapPositionEnabled`, `isLastEnabledGapPosition`, `toggleGapPosition`) |
| `Peach/Settings/GapPositionEncoding.swift` | **Do not modify** — encoding stays CSV |
| `Peach/Settings/IntervalSelectorView.swift` | **Do not modify** |
| `Peach/Core/Audio/StepSequencer.swift:5-10` | **Read only** — `StepPosition` enum definition (4 cases, `CaseIterable`, `Hashable`) |

### Cell Styling Reference (from `IntervalSelectorView`)

```swift
Text(label)
    .font(.caption2)
    .frame(width: 32, height: 32)
    .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
    .foregroundStyle(isActive ? .white : .secondary)
    .clipShape(RoundedRectangle(cornerRadius: 6))
```

Wrap in `Button` with `.buttonStyle(.plain)` and `.disabled()` for last-remaining guard.

### Generic Design

`GridToggleRow` should look roughly like:

```swift
struct GridToggleRow<Element: CaseIterable & Hashable>: View {
    @Binding var selection: Set<Element>
    let label: (Element) -> String

    // body: HStack of toggle-buttons for each Element.allCases
    // disable button when selection.count == 1 && selection.contains(element)
}
```

The `Binding<Set<Element>>` means SettingsScreen must bridge the `enabledGapPositionsEncoded` string to a `Set<StepPosition>` binding. Create a computed `Binding<Set<StepPosition>>` using `Binding(get:set:)` that reads via `GapPositionEncoding.decodeWithDefault` and writes via `GapPositionEncoding.encode`.

### Architecture Constraints

- **Swift 6.2 default MainActor isolation** — do not add explicit `@MainActor`
- **No `ObservableObject`/`@Published`** — pure SwiftUI `@Binding`
- **Access control** — default to `private`; `GridToggleRow` itself is `internal` (used across files)
- **Extract at ~40 lines** — `GridToggleRow` should be well under this limit
- **No new dependencies** — pure SwiftUI

### Project Structure Notes

- New file `Peach/Settings/GridToggleRow.swift` follows existing pattern (`IntervalSelectorView.swift` is in the same directory)
- Test file: `PeachTests/Settings/GridToggleRowTests.swift` (mirrors source structure)

### References

- [Source: Peach/Settings/IntervalSelectorView.swift — cell styling pattern]
- [Source: Peach/Settings/SettingsScreen.swift:301-318 — current gap position section]
- [Source: Peach/Settings/GapPositionEncoding.swift — encoding unchanged]
- [Source: Peach/Core/Audio/StepSequencer.swift:5-10 — StepPosition enum]
- [Source: docs/project-context.md — testing rules, SwiftUI conventions, access control]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None — clean implementation with no build or test failures.

### Completion Notes List
- Created `GridToggleRow<Element>` generic reusable component with `Binding<Set<Element>>`, matching `IntervalSelectorView` cell styling exactly
- Static `toggle` and `isLastRemaining` methods extracted for testability
- Replaced `gapPositionsSection` in `SettingsScreen` using `GridToggleRow<StepPosition>` with computed `Binding` bridging `@AppStorage` string ↔ `Set<StepPosition>`
- Removed 4 dead helpers: `enabledGapPositions`, `isGapPositionEnabled`, `isLastEnabledGapPosition`, `toggleGapPosition`, and `gapPositionLabels`
- 6 unit tests for toggle behavior and last-remaining guard
- All 1472 tests pass, no regressions

### Change Log
- 2026-03-23: Implemented story 59.1 — unified gap position selector to grid buttons

### File List
- Peach/Settings/GridToggleRow.swift (new)
- Peach/Settings/SettingsScreen.swift (modified)
- PeachTests/Settings/GridToggleRowTests.swift (new)
