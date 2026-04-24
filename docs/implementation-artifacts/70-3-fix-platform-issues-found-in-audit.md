# Story 70.3: Fix Platform Issues Found in Audit

Status: ready-for-dev

## Story

As a **developer**,
I want all issues discovered during platform testing fixed before release,
so that no platform ships with known UX defects.

## Acceptance Criteria

1. **Given** the issues list from Stories 70.1 and 70.2 **When** triaged **Then** all issues classified as "must fix before release" are resolved.
2. **Given** each fix **When** applied **Then** it is verified on the affected platform and does not regress other platforms.
3. **Given** the full test suite **When** run on both iOS and macOS **Then** all tests pass.

## Tasks / Subtasks

_Tasks will be populated after Stories 70.1 and 70.2 are complete. Each must-fix issue becomes a task here._

- [ ] Task 1: Triage issues from Story 70.1 (iOS/iPadOS audit) (AC: #1)
  - [ ] 1.1 Review all discovered issues
  - [ ] 1.2 Classify each as "must fix before release" or "nice-to-have / post-release"
- [ ] Task 2: Triage issues from Story 70.2 (macOS audit) (AC: #1)
  - [ ] 2.1 Review all discovered issues
  - [ ] 2.2 Classify each as "must fix before release" or "nice-to-have / post-release"
- [ ] Task 3c: Fix all must-fix macOS issues (AC: #1, #2)
  - [ ] 3c.1 [70.2-M1] Fix dual Settings access paths — gear icon in StartScreen/TrainingScreenModifier toolbar should open native Settings window on macOS (via `openWindow(id: "settings")`) instead of pushing SettingsScreen into NavigationStack
  - [ ] 3c.2 [70.2-M2] Fix StartScreen landscape layout at narrow macOS window heights — increase min width, add ScrollView to landscape layout, or add macOS-specific layout that avoids 3-column at <500px width
  - [ ] 3c.3 [70.2-M3] Add maxWidth constraint to ProfileScreen VStack (same fix as 70.1-M2, verify it applies to macOS window resizing)
  - [ ] 3c.4 [70.2-M4] Add maxWidth constraint to HelpPanel content — HelpPanelController wraps resizable NSWindow with no content width cap, text becomes unreadable when panel is widened
- [ ] Task 3d: Nice-to-have macOS issues (triage in Task 2)
  - [ ] 3d.1 [70.2-N1] Add keyboard shortcut for "Show Profile" in menu bar (e.g., Cmd+P)
  - [ ] 3d.2 [70.2-N2] Add visual indication of current active training mode in Training menu (checkmark or disabled state)
  - [ ] 3d.3 [70.2-N3] Verify PitchMatchingScreen arrow key behavior — lacks `.phases: .down` unlike all other training screens, may affect key repeat behavior
  - [ ] 3d.4 [70.2-N4] Unify file import on macOS — SettingsScreen uses blocking `NSOpenPanel.runModal()` while ContentView uses SwiftUI `.fileImporter()`
  - [ ] 3d.5 [70.2-N5] Verify window position/size restoration between app launches
- [ ] Task 3: Fix all must-fix iOS/iPadOS issues (AC: #1, #2)
  - [ ] 3.1 [70.1-M1] Add `.hoverEffect(.highlight)` to all custom interactive elements — StartScreen training cards, IntervalSelectorView toggles, GridToggleRow toggles, ContinuousRhythmMatching tap button, RhythmSpectrogramView cells
  - [ ] 3.2 [70.1-M2] Add maxWidth constraint (~700pt) to ProfileScreen VStack for readable layout on iPad
  - [ ] 3.3 [70.1-M3] Add maxWidth constraint to InfoScreen and HelpContentView for readable text lines on iPad
  - [ ] 3.4 [70.1-M4] Replace fixed 44pt Y-axis label width in RhythmSpectrogramView with `@ScaledMetric` or `.fixedSize()`
  - [ ] 3.5 [70.1-M5] Wrap StartScreen landscape layout in `ScrollView(.vertical)` or use `ViewThatFits` for Dynamic Type overflow
- [ ] Task 3b: Nice-to-have iOS/iPadOS issues (triage in Task 1)
  - [ ] 3b.1 [70.1-N1] Use `@ScaledMetric` for training button icon sizes in PitchDiscriminationScreen, TimingOffsetDetectionScreen, ContinuousRhythmMatchingScreen (currently fixed 60/80pt)
  - [ ] 3b.2 [70.1-N2] Add ScrollView wrapping to training screen VStack bodies (PitchDiscrimination, TimingOffsetDetection, ContinuousRhythmMatching) for Dynamic Type overflow on small landscape iPhones
  - [ ] 3b.3 [70.1-N3] Consider `@ScaledMetric` for ProgressSparklineView fixed 60x24 frame
  - [ ] 3b.4 [70.1-N4] Consider `@ScaledMetric` for ProgressChartView fixed chart heights (180/240pt)
  - [ ] 3b.5 [70.1-N5] Add `.contentShape(Rectangle())` to TrainingCardButtonStyle for full-area tap/hover target
  - [ ] 3b.6 [70.1-N6] Add `.hoverEffect()` to SettingsScreen data section buttons and ShareLink
  - [ ] 3b.7 [70.1-N7] Add hover cue to ProgressChartView SpatialTapGesture area for iPad pointer
  - [ ] 3b.8 [70.1-N8] Investigate PitchSlider thumb "jump" when orientation changes during active drag
- [ ] Task 4: Cross-platform verification (AC: #2)
  - [ ] 4.1 Verify each fix on the affected platform
  - [ ] 4.2 Verify no regressions on other platforms
- [ ] Task 5: Run full test suite on both platforms (AC: #3)
  - [ ] 5.1 `bin/test.sh` — iOS tests pass
  - [ ] 5.2 `bin/test.sh -p mac` — macOS tests pass

## Dev Notes

This is a **catch-all fix story**. Scope depends entirely on what Stories 70.1 and 70.2 discover. If no issues are found, this story is marked done immediately.

### Workflow

1. Complete Stories 70.1 and 70.2 first — they produce the issues list.
2. Triage: classify every issue. "Must fix" = anything that blocks a professional release (broken layouts, non-functional features, crashes). "Nice-to-have" = cosmetic polish that can ship in a point release.
3. Fix each must-fix issue in isolation, verifying cross-platform after each change.
4. Run `bin/test.sh && bin/test.sh -p mac` before marking done.

### Common Fix Patterns

- **Layout issues**: Adjust `frame`, `padding`, `fixedSize`, or size-class conditionals in the affected screen view.
- **Keyboard shortcut conflicts**: Adjust key assignments in `PeachCommands.swift` or training screen `.keyboardShortcut()` modifiers.
- **Lifecycle issues**: Update `TrainingLifecycleCoordinator.swift` platform-conditional notification handling.
- **Dynamic Type overflow**: Wrap content in `ScrollView`, use `@ScaledMetric` for fixed dimensions, avoid hardcoded heights.

### Project Structure Notes

- Platform conditionals spread across 18 files — changes must be tested on both iOS and macOS builds.
- All port abstractions: `Peach/Core/Ports/` — fixes should go through these abstractions, not add new `#if os()` branches.

### References

- Story 70.1: `docs/implementation-artifacts/70-1-platform-polish-audit-ios-ipados.md`
- Story 70.2: `docs/implementation-artifacts/70-2-platform-polish-audit-macos.md`

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
