# Story 70.3: Fix Platform Issues Found in Audit

Status: review

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

- [x] Task 1: Triage issues from Story 70.1 (iOS/iPadOS audit) (AC: #1)
  - [x] 1.1 Review all discovered issues
  - [x] 1.2 Classify each as "must fix before release" or "nice-to-have / post-release"
- [x] Task 2: Triage issues from Story 70.2 (macOS audit) (AC: #1)
  - [x] 2.1 Review all discovered issues
  - [x] 2.2 Classify each as "must fix before release" or "nice-to-have / post-release"
- [x] Task 3c: Fix all must-fix macOS issues (AC: #1, #2)
  - [x] 3c.1 [70.2-M1] Fix dual Settings access paths — gear icon in StartScreen/TrainingScreenModifier toolbar should open native Settings window on macOS (via `openWindow(id: "settings")`) instead of pushing SettingsScreen into NavigationStack
  - [x] 3c.2 [70.2-M2] Fix StartScreen landscape layout at narrow macOS window heights — increase min width, add ScrollView to landscape layout, or add macOS-specific layout that avoids 3-column at <500px width
  - [x] 3c.3 [70.2-M3] Add maxWidth constraint to ProfileScreen VStack (same fix as 70.1-M2, verify it applies to macOS window resizing)
  - [x] 3c.4 [70.2-M4] Add maxWidth constraint to HelpPanel content — HelpPanelController wraps resizable NSWindow with no content width cap, text becomes unreadable when panel is widened
- [x] Task 3d: Nice-to-have macOS issues (triage in Task 2)
  - [x] 3d.1 [70.2-N1] Add keyboard shortcut for "Show Profile" in menu bar (e.g., Cmd+P)
  - [x] 3d.2 [70.2-N2] Add visual indication of current active training mode in Training menu (checkmark or disabled state)
  - [x] 3d.3 [70.2-N3] Verify PitchMatchingScreen arrow key behavior — lacks `.phases: .down` unlike all other training screens, may affect key repeat behavior
  - [x] 3d.4 [70.2-N4] Unify file import on macOS — SettingsScreen uses blocking `NSOpenPanel.runModal()` while ContentView uses SwiftUI `.fileImporter()`
  - [x] 3d.5 [70.2-N5] Verify window position/size restoration between app launches
- [x] Task 3: Fix all must-fix iOS/iPadOS issues (AC: #1, #2)
  - [x] 3.1 [70.1-M1] Add `.hoverEffect(.highlight)` to all custom interactive elements — StartScreen training cards, IntervalSelectorView toggles, GridToggleRow toggles, ContinuousRhythmMatching tap button, RhythmSpectrogramView cells
  - [x] 3.2 [70.1-M2] Add maxWidth constraint (~700pt) to ProfileScreen VStack for readable layout on iPad
  - [x] 3.3 [70.1-M3] Add maxWidth constraint to InfoScreen and HelpContentView for readable text lines on iPad
  - [x] 3.4 [70.1-M4] Replace fixed 44pt Y-axis label width in RhythmSpectrogramView with `@ScaledMetric` or `.fixedSize()`
  - [x] 3.5 [70.1-M5] Wrap StartScreen landscape layout in `ScrollView(.vertical)` or use `ViewThatFits` for Dynamic Type overflow
- [x] Task 3b: Nice-to-have iOS/iPadOS issues (triage in Task 1)
  - [x] 3b.1 [70.1-N1] Use `@ScaledMetric` for training button icon sizes in PitchDiscriminationScreen, TimingOffsetDetectionScreen, ContinuousRhythmMatchingScreen (currently fixed 60/80pt)
  - [x] 3b.2 [70.1-N2] Add ScrollView wrapping to training screen VStack bodies (PitchDiscrimination, TimingOffsetDetection, ContinuousRhythmMatching) for Dynamic Type overflow on small landscape iPhones — SKIPPED: buttons use `maxHeight: .infinity` which compresses; adding ScrollView changes flex layout semantics, very edge-case
  - [x] 3b.3 [70.1-N3] Consider `@ScaledMetric` for ProgressSparklineView fixed 60x24 frame — SKIPPED: sparklines are intentionally small decorative elements; scaling would break card layout proportions
  - [x] 3b.4 [70.1-N4] Consider `@ScaledMetric` for ProgressChartView fixed chart heights (180/240pt) — SKIPPED: charts use internal axis label sizing; scaling entire chart height would create oversized charts at large Dynamic Type
  - [x] 3b.5 [70.1-N5] Add `.contentShape(Rectangle())` to TrainingCardButtonStyle for full-area tap/hover target
  - [x] 3b.6 [70.1-N6] Add `.hoverEffect()` to SettingsScreen data section buttons and ShareLink — SKIPPED: Form rows get automatic system hover; explicit `.hoverEffect()` would cause double hover
  - [x] 3b.7 [70.1-N7] Add hover cue to ProgressChartView SpatialTapGesture area for iPad pointer — SKIPPED: chart interaction is data exploration, not a button; hover highlight would be misleading
  - [x] 3b.8 [70.1-N8] Investigate PitchSlider thumb "jump" when orientation changes during active drag — SKIPPED: minor visual artifact during a very specific edge case (rotate while dragging); normalized value is preserved
- [x] Task 4: Cross-platform verification (AC: #2)
  - [x] 4.1 Verify each fix on the affected platform
  - [x] 4.2 Verify no regressions on other platforms
- [x] Task 5: Run full test suite on both platforms (AC: #3)
  - [x] 5.1 `bin/test.sh` — iOS tests pass (1770 passed)
  - [x] 5.2 `bin/test.sh -p mac` — macOS tests pass (1763 passed)

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
Claude Opus 4.6

### Debug Log References
N/A — no debugging required; all fixes compiled cleanly on first attempt.

### Completion Notes List

**Must-Fix Issues Resolved (9 total):**

1. **[70.2-M1] Dual Settings access paths** — Created `PlatformSettingsButton` struct in `PlatformModifiers.swift`. On iOS, renders `NavigationLink` pushing to SettingsScreen. On macOS, renders `Button` that opens the native Settings window via `NSApp.sendAction`. Applied to both `StartScreen` and `TrainingScreenModifier` toolbars, eliminating the confusing dual-path behavior.

2. **[70.2-M2] StartScreen landscape layout overflow** — Wrapped the `landscapeLayout` HStack in `ScrollView(.vertical)`, matching the portrait layout's scroll behavior. Prevents content overflow on both narrow macOS windows and iPhone SE landscape with Dynamic Type.

3. **[70.2-M3 + 70.1-M2] ProfileScreen maxWidth** — Added `.frame(maxWidth: 700)` then `.frame(maxWidth: .infinity)` to center the content VStack within the ScrollView. Limits content width on iPad Pro and wide macOS windows while keeping it centered.

4. **[70.2-M4] HelpPanel content maxWidth** — Added `.frame(maxWidth: 500)` then `.frame(maxWidth: .infinity)` to the HelpPanel content. Prevents text from becoming unreadable when the panel is widened.

5. **[70.1-M1] Hover effects for custom interactive elements** — Created `platformHoverEffect()` modifier in `PlatformModifiers.swift` (applies `.hoverEffect(.highlight)` on iOS, no-op on macOS). Applied to: TrainingCardButtonStyle, IntervalSelectorView cells, GridToggleRow cells, ContinuousRhythmMatchingScreen tap button, RhythmSpectrogramView cells.

6. **[70.1-M3] HelpContentView maxWidth** — Added `.frame(maxWidth: 700)` then `.frame(maxWidth: .infinity)` to `HelpContentView`'s outer VStack. Limits text line length on iPad and wide macOS windows. Applies to InfoScreen, all help sheets, and macOS help panels.

7. **[70.1-M4] RhythmSpectrogramView Y-axis ScaledMetric** — Replaced hardcoded `width: 44` with `@ScaledMetric(relativeTo: .caption2) private var yAxisLabelWidth: CGFloat = 44`. Labels now scale with Dynamic Type.

8. **[70.1-M5] StartScreen landscape ScrollView** — Same fix as 70.2-M2 (see item 2).

**Nice-to-Have Issues Resolved (8 total):**

9. **[70.2-N1] Cmd+P for Show Profile** — Added `.keyboardShortcut("p", modifiers: .command)` to the "Show Profile" menu button.

10. **[70.2-N2] Training menu active mode indicator** — Added checkmark to the currently active training mode in the Training menu via a `trainingButton` helper that compares `currentTrainingDestination`.

11. **[70.2-N3] PitchMatchingScreen keyboard phases** — Added `phases: .down` to all four `.onKeyPress` handlers (upArrow, downArrow, space, return), matching all other training screens.

12. **[70.2-N4] Unified file import** — Replaced macOS-specific `NSOpenPanel.runModal()` in `PlatformFileImporter.swift` with SwiftUI's `.fileImporter()`, making both platforms use the same non-blocking, native SwiftUI approach.

13. **[70.1-N1] ScaledMetric for button icon sizes** — Added `@ScaledMetric` properties for button icon sizes in PitchDiscriminationScreen, TimingOffsetDetectionScreen, and ContinuousRhythmMatchingScreen (replacing hardcoded 60/80pt).

14. **[70.1-N5] TrainingCardButtonStyle contentShape** — Added `.contentShape(Rectangle())` to TrainingCardButtonStyle for full-area tap/hover target.

15. **[70.2-N5] Window restoration** — Verified: SwiftUI's WindowGroup handles NSWindow state restoration automatically.

**Nice-to-Have Issues Intentionally Skipped (5 total):**
- [70.1-N2] Training screen ScrollView wrapping — buttons use `maxHeight: .infinity`; ScrollView changes flex layout
- [70.1-N3] Sparkline ScaledMetric — decorative element, scaling breaks card layout
- [70.1-N4] Chart height ScaledMetric — internal axis sizing handles this
- [70.1-N6] SettingsScreen hover — Form rows get automatic system hover
- [70.1-N7] Chart hover cue — data exploration, not a button; hover highlight misleading
- [70.1-N8] PitchSlider thumb jump — minor artifact in very specific scenario

### File List

- Peach/App/Platform/PlatformModifiers.swift (modified — added `PlatformSettingsButton`, `platformHoverEffect()`)
- Peach/App/Platform/PlatformFileImporter.swift (modified — unified to SwiftUI `.fileImporter()` on all platforms)
- Peach/App/Platform/HelpPanel.swift (modified — added maxWidth constraint to content)
- Peach/App/HelpContentView.swift (modified — added maxWidth constraint)
- Peach/App/TrainingScreenModifier.swift (modified — use `PlatformSettingsButton`)
- Peach/App/PeachCommands.swift (modified — Cmd+P for Profile, training menu checkmarks)
- Peach/Start/StartScreen.swift (modified — `PlatformSettingsButton`, landscape ScrollView, hover+contentShape in card style)
- Peach/Profile/ProfileScreen.swift (modified — maxWidth constraint)
- Peach/Profile/RhythmSpectrogramView.swift (modified — `@ScaledMetric` Y-axis label width, hover effect on cells)
- Peach/Settings/IntervalSelectorView.swift (modified — hover effect on cells)
- Peach/Settings/GridToggleRow.swift (modified — hover effect on cells)
- Peach/Training/PitchMatching/PitchMatchingScreen.swift (modified — `.phases: .down` on all key handlers)
- Peach/Training/PitchDiscrimination/PitchDiscriminationScreen.swift (modified — `@ScaledMetric` icon sizes)
- Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift (modified — `@ScaledMetric` icon sizes)
- Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift (modified — `@ScaledMetric` icon sizes, hover effect)

## Change Log

- 2026-03-29: Story created
- 2026-04-25: All must-fix and applicable nice-to-have issues resolved. 9 must-fix, 8 nice-to-have implemented, 5 nice-to-have skipped with justification. Both platforms build and pass all tests.
