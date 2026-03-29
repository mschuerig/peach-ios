# Story 67.2: Centralize View Modifiers and Harden `#else` Branches

Status: ready-for-dev

## Story

As a **developer**,
I want repeated `#if os` view styling consolidated into shared modifiers and all bare `#else` branches hardened,
so that adding a third platform produces compiler errors instead of silent wrong behavior.

## Acceptance Criteria

1. **inlineNavigationBarTitle()** -- All 12 `#if os(iOS) .navigationBarTitleDisplayMode(.inline) #endif` blocks replaced with `.inlineNavigationBarTitle()` from a shared `PlatformModifiers.swift`.

2. **platformFormStyle()** -- `SettingsScreen.swift` grouped form style conditional replaced with `.platformFormStyle()`.

3. **Color.platformBackground** -- `ExportChartView.swift` background color conditional replaced with `Color.platformBackground`.

4. **#else hardening** -- Every remaining `#if os` block with a bare `#else` uses `#elseif os(macOS)` followed by `#else #error("Unsupported platform")`.

5. **No regressions** -- Full test suite passes on both iOS and macOS.

## Tasks / Subtasks

- [ ] Task 1: Create platform view modifiers (AC: #1, #2, #3)
  - [ ] 1.1 Create `App/Platform/PlatformModifiers.swift` with `inlineNavigationBarTitle()`, `platformFormStyle()`, and `Color.platformBackground`

- [ ] Task 2: Replace scattered `#if os` in screen files (AC: #1)
  - [ ] 2.1 `PitchMatchingScreen.swift` -- replace 2 occurrences
  - [ ] 2.2 `PitchDiscriminationScreen.swift` -- replace 2 occurrences
  - [ ] 2.3 `RhythmOffsetDetectionScreen.swift` -- replace 2 occurrences
  - [ ] 2.4 `ContinuousRhythmMatchingScreen.swift` -- replace 2 occurrences
  - [ ] 2.5 `ProfileScreen.swift` -- replace 2 occurrences
  - [ ] 2.6 `SettingsScreen.swift` -- replace 2 navigation + 1 form style (AC: #2)
  - [ ] 2.7 `StartScreen.swift` -- replace 1 occurrence
  - [ ] 2.8 `InfoScreen.swift` -- replace 1 occurrence

- [ ] Task 3: Replace color conditionals (AC: #3)
  - [ ] 3.1 `ExportChartView.swift` -- replace with `Color.platformBackground`

- [ ] Task 4: Harden all bare `#else` branches (AC: #4)
  - [ ] 4.1 Find all `#else` not followed by `#if` or `#elseif`
  - [ ] 4.2 Convert each to `#elseif os(macOS)` + `#else #error("Unsupported platform")`
  - [ ] 4.3 Applies to: `App/Platform/` files, `PeachApp.swift`, `ContentView.swift`, `PeachCommands.swift`, test files

- [ ] Task 5: Verify (AC: #5)
  - [ ] 5.1 `bin/test.sh && bin/test.sh -p mac`
  - [ ] 5.2 Verify no bare `#else` remains

## Dev Notes

### Architecture & Integration

**New files:**
- `Peach/App/Platform/PlatformModifiers.swift`

**Modified files:**
- `Peach/PitchMatching/PitchMatchingScreen.swift`
- `Peach/PitchDiscrimination/PitchDiscriminationScreen.swift`
- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift`
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift`
- `Peach/Profile/ProfileScreen.swift`
- `Peach/Profile/ExportChartView.swift`
- `Peach/Settings/SettingsScreen.swift`
- `Peach/Start/StartScreen.swift`
- `Peach/Info/InfoScreen.swift`
- All files with bare `#else` branches

### Testing Approach

- **No new tests** -- this is a mechanical refactoring of view-layer code. Existing tests validate behavior is unchanged.
- Full suite on both platforms is the verification gate.

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 67: Platform Ports]

## Change Log

- 2026-03-29: Story created
