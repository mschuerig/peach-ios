# Story 24.2: Start Screen Four Training Buttons

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **musician using Peach**,
I want to see four training buttons on the Start Screen — Comparison, Pitch Matching, Interval Comparison, and Interval Pitch Matching — with a visual separator between unison and interval groups,
So that I can launch any training mode with a single tap (FR65).

## Acceptance Criteria

### AC 1: Four buttons visible in vertical stack
**Given** the Start Screen
**When** it loads
**Then** four training buttons are visible in a vertical stack:
1. "Comparison" — `.borderedProminent` style (hero action, unchanged position)
2. "Pitch Matching" — `.bordered` style
3. A subtle visual separator (spacing or divider)
4. "Interval Comparison" — `.bordered` style
5. "Interval Pitch Matching" — `.bordered` style

### AC 2: Interval Comparison navigates correctly
**Given** the "Interval Comparison" button
**When** tapped
**Then** it navigates to `.comparison(intervals: [.perfectFifth])` (FR56, FR67)

### AC 3: Interval Pitch Matching navigates correctly
**Given** the "Interval Pitch Matching" button
**When** tapped
**Then** it navigates to `.pitchMatching(intervals: [.perfectFifth])` (FR60, FR67)

### AC 4: Existing buttons preserve behavior
**Given** the "Comparison" button
**When** tapped
**Then** it navigates to `.comparison(intervals: [.prime])` — unchanged behavior

**Given** the "Pitch Matching" button
**When** tapped
**Then** it navigates to `.pitchMatching(intervals: [.prime])` — unchanged behavior

### AC 5: Responsive layout preserved
**Given** the Start Screen layout
**When** viewed in portrait and landscape on iPhone and iPad
**Then** all four buttons are accessible and the visual separator is visible
**And** the one-handed, thumb-friendly layout is preserved

## Tasks / Subtasks

- [x] Task 1: Rename "Start Training" button label to "Comparison" (AC: 1, 4)
  - [x] Update button label from `"Start Training"` to `"Comparison"` in `StartScreen.swift`
  - [x] Update localization entry in `Localizable.xcstrings` (English: "Comparison", German: "Vergleich")
- [x] Task 2: Add visual separator between unison and interval groups (AC: 1)
  - [x] Add subtle spacing or divider between "Pitch Matching" and "Interval Comparison" buttons
  - [x] Verify separator is visible in both portrait and landscape
- [x] Task 3: Add "Interval Comparison" button (AC: 1, 2)
  - [x] Add NavigationLink with value `.comparison(intervals: [.perfectFifth])`
  - [x] Use `.bordered` style and `.controlSize(.large)`
  - [x] Add localization entry (English: "Interval Comparison", German: "Intervallvergleich")
- [x] Task 4: Add "Interval Pitch Matching" button (AC: 1, 3)
  - [x] Add NavigationLink with value `.pitchMatching(intervals: [.perfectFifth])`
  - [x] Use `.bordered` style and `.controlSize(.large)`
  - [x] Add localization entry (English: "Interval Pitch Matching", German: "Intervall-Tonhöhenübung")
- [x] Task 5: Verify responsive layout (AC: 5)
  - [x] Check layout in iPhone portrait and landscape
  - [x] Check layout in iPad portrait and landscape
  - [x] Ensure compact height mode spacing still works with 4 buttons
- [x] Task 6: Update tests (AC: 1-5)
  - [x] Add new tests for interval navigation destinations
  - [x] Update existing test assertions if button label changed
  - [x] Add test verifying ComparisonScreen can be instantiated with `[.perfectFifth]`
  - [x] Run full test suite

## Dev Notes

### Developer Context — Critical Implementation Intelligence

This story adds two new training buttons to the Start Screen and renames the existing "Start Training" button to "Comparison". It is a pure UI change — all navigation infrastructure was already implemented in Story 24.1 (NavigationDestination parameterization). No session, model, or business logic changes are needed.

**What this story changes:**
- `StartScreen.swift`: rename "Start Training" → "Comparison", add visual separator, add two new NavigationLink buttons for interval modes
- `Localizable.xcstrings`: add 3 new localization entries (Comparison, Interval Comparison, Interval Pitch Matching)
- `StartScreenTests.swift`: add tests for new navigation destinations and screen instantiation with interval parameters

**What this story does NOT change:**
- No changes to `NavigationDestination.swift` (already parameterized in Story 24.1)
- No changes to `ComparisonSession`, `PitchMatchingSession`, or `TrainingSession`
- No changes to `ComparisonScreen` or `PitchMatchingScreen` (already accept `intervals` parameter)
- No changes to the destination handler in `StartScreen.swift` (already routes intervals)
- No changes to `PeachApp.swift`, `ContentView.swift`, or any environment setup
- No changes to any data models, profiles, or observers

### Technical Requirements

**Button label rename:**

Current (`Peach/Start/StartScreen.swift:30-35`):
```swift
NavigationLink(value: NavigationDestination.comparison(intervals: [.prime])) {
    Text("Start Training")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.borderedProminent)
.controlSize(.large)
```

Target:
```swift
NavigationLink(value: NavigationDestination.comparison(intervals: [.prime])) {
    Text("Comparison")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.borderedProminent)
.controlSize(.large)
```

**New interval buttons pattern (after separator):**

```swift
// Visual separator between unison and interval groups
Divider()

// Interval Comparison Button
NavigationLink(value: NavigationDestination.comparison(intervals: [.perfectFifth])) {
    Text("Interval Comparison")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.controlSize(.large)

// Interval Pitch Matching Button
NavigationLink(value: NavigationDestination.pitchMatching(intervals: [.perfectFifth])) {
    Text("Interval Pitch Matching")
        .frame(maxWidth: .infinity)
}
.buttonStyle(.bordered)
.controlSize(.large)
```

**Visual separator options:** The UX spec says "subtle divider or spacing." A simple `Divider()` between the second and third buttons is the simplest approach. Alternatively, extra spacing could work. Use `Divider()` for clarity — it's standard SwiftUI and provides the visual grouping the UX spec describes.

**Existing Pitch Matching button — remove icon:** Currently the Pitch Matching button uses `Label("Pitch Matching", systemImage: "waveform")`. For consistency with the four-button layout where all buttons are text-only, consider whether to keep or remove the icon. The epic ACs describe plain text buttons. Follow the ACs — use `Text("Pitch Matching")` for consistency.

### Architecture Compliance

**Required patterns from architecture document:**

1. **NavigationDestination enum for type-safe routing** — already done in Story 24.1 [Source: docs/project-context.md#Framework-Specific Rules]
2. **Button styling per UX spec** — `.borderedProminent` for Comparison (hero), `.bordered` for all others [Source: docs/planning-artifacts/ux-design-specification.md#Interval Training — Component Strategy]
3. **Hub-and-spoke navigation** — all four buttons navigate to screens one level deep from Start Screen [Source: docs/planning-artifacts/ux-design-specification.md#Navigation Patterns]
4. **Screen reuse, not duplication** — same ComparisonScreen/PitchMatchingScreen, just different intervals [Source: docs/planning-artifacts/architecture.md#v0.3 Navigation & Start Screen]
5. **Start/ is exempt from cross-feature coupling rule** — it is the navigation router and can reference all screen types [Source: docs/project-context.md#Dependency Direction Rules]
6. **Views are thin** — no business logic in StartScreen, just NavigationLinks [Source: docs/project-context.md#Framework-Specific Rules]

### Library/Framework Requirements

- **SwiftUI `NavigationStack`** — value-based routing with `.navigationDestination(for:)`, already in use
- **No new dependencies** — zero third-party packages
- **Swift 6.2** — default MainActor isolation
- **`Interval` enum** — `.prime` and `.perfectFifth` already available (`Peach/Core/Audio/Interval.swift`)
- **`Divider()`** — standard SwiftUI component, no imports needed

### File Structure — Files to Modify

| File | Change | Why |
|------|--------|-----|
| `Peach/Start/StartScreen.swift` | Rename "Start Training" → "Comparison", remove waveform icon from Pitch Matching, add Divider, add two interval NavigationLinks | Core UI change |
| `Peach/Resources/Localizable.xcstrings` | Add "Comparison" (de: "Vergleich"), "Interval Comparison" (de: "Intervallvergleich"), "Interval Pitch Matching" (de: "Intervall-Tonhöhenübung") entries | Localization |
| `PeachTests/Start/StartScreenTests.swift` | Add interval destination tests, add interval screen instantiation test | Test coverage |

**Files NOT to modify:**
- `Peach/App/NavigationDestination.swift` — already parameterized (Story 24.1)
- `Peach/Comparison/ComparisonScreen.swift` — already accepts intervals (Story 24.1)
- `Peach/PitchMatching/PitchMatchingScreen.swift` — already accepts intervals (Story 24.1)
- `Peach/Comparison/ComparisonSession.swift` — no changes needed
- `Peach/PitchMatching/PitchMatchingSession.swift` — no changes needed
- `Peach/App/PeachApp.swift` — no composition root changes
- `Peach/App/ContentView.swift` — no changes needed

### Testing Requirements

**TDD approach — write failing tests first:**

1. **NavigationDestination interval tests** — already covered by Story 24.1 (comparison/pitchMatching with different intervals are not equal). No new NavigationDestination tests needed.

2. **Screen instantiation with interval parameters:**
   - New test: `ComparisonScreen(intervals: [.perfectFifth])` can be instantiated
   - New test: `PitchMatchingScreen(intervals: [.perfectFifth])` can be instantiated

3. **Hub-and-spoke completeness:**
   - Update `allNavigationDestinationsCanBeCreated` to include interval variants

4. **No behavioral UI tests** — Swift Testing cannot test SwiftUI interactions (button taps, navigation). The structural tests verify the views can be created with the right parameters. Visual verification is manual.

**Test execution:** `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`

### Previous Story Intelligence (Story 24.1)

**From Story 24.1 (NavigationDestination Parameterization and Routing):**
- `NavigationDestination.comparison(intervals:)` and `.pitchMatching(intervals:)` already parameterized
- Destination handler in `StartScreen.swift` (lines 72-83) already routes intervals to screens
- `ComparisonScreen(intervals:)` and `PitchMatchingScreen(intervals:)` already accept intervals
- Session `start(intervals:)` already accepts intervals
- All 701 tests pass after Story 24.1
- Key learning: destination handler is in `StartScreen.swift`, NOT `ContentView.swift`

**Patterns established:**
- NavigationLink uses `NavigationDestination.comparison(intervals: [.prime])` syntax
- `.buttonStyle(.borderedProminent)` for hero action, `.borderedProminent` for secondary
- `.controlSize(.large)` on all training buttons
- `.frame(maxWidth: .infinity)` on button label text

### Git Intelligence

Recent commits (Story 24.1 and Epic 23):
```
b4d924c Fix code review findings for story 24.1 and mark done
94b8672 Implement story 24.1: NavigationDestination Parameterization and Routing
46a85ac Add story 24.1: NavigationDestination Parameterization and Routing
c233a51 Fix code review findings for story 23.4 and mark done
c2661fc Implement story 23.4: Training Screen Interval Label and Observer Verification
```

**Pattern:** Each story implemented then code-reviewed. Code review findings led to follow-up commits.

### Project Structure Notes

- All changes align with existing project structure
- No new files needed — only modifications to existing files
- `StartScreen.swift` stays in `Start/` directory
- Localization entries follow existing format in `Localizable.xcstrings`
- No cross-feature coupling introduced (Start/ is exempt as navigation router)

### References

- [Source: docs/planning-artifacts/epics.md#Epic 24, Story 24.2] — Story definition and ACs
- [Source: docs/planning-artifacts/architecture.md#v0.3 Navigation & Start Screen] — Four-button layout, button styling, navigation routing
- [Source: docs/planning-artifacts/ux-design-specification.md#Interval Training — Component Strategy] — Start Screen button layout spec, button hierarchy
- [Source: docs/planning-artifacts/ux-design-specification.md#Interval Training — UX Consistency Patterns] — Updated button hierarchy table
- [Source: docs/planning-artifacts/prd.md#FR65] — Start Screen shows four training buttons
- [Source: docs/planning-artifacts/prd.md#FR66] — Unison = prime case of interval variants
- [Source: docs/planning-artifacts/prd.md#FR67] — Initial interval: perfect fifth up
- [Source: docs/project-context.md#Framework-Specific Rules] — NavigationDestination enum, thin views
- [Source: docs/project-context.md#Dependency Direction Rules] — Start/ exempt from cross-feature rule
- [Source: docs/implementation-artifacts/24-1-navigationdestination-parameterization-and-routing.md] — Previous story with full navigation infrastructure

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Renamed "Start Training" button to "Comparison" using `Text("Comparison")` instead of `Text("Start Training")`
- Removed `Label("Pitch Matching", systemImage: "waveform")` icon, replaced with `Text("Pitch Matching")` for consistency across all four buttons
- Added `Divider()` between Pitch Matching and Interval Comparison buttons as visual separator
- Added "Interval Comparison" NavigationLink with `.comparison(intervals: [.perfectFifth])`, `.bordered` style
- Added "Interval Pitch Matching" NavigationLink with `.pitchMatching(intervals: [.perfectFifth])`, `.bordered` style
- Added 3 localization entries: "Comparison" (de: "Vergleich"), "Interval Comparison" (de: "Intervallvergleich"), "Interval Pitch Matching" (de: "Intervall-Tonhöhenübung")
- Added tests: `ComparisonScreen` instantiation with `[.perfectFifth]`, `PitchMatchingScreen` instantiation with `[.perfectFifth]`
- Updated `allNavigationDestinationsCanBeCreated` test to include interval variants
- All tests pass (full suite)

### Change Log

- 2026-03-01: Implemented story 24.2 — four training buttons on Start Screen with visual separator and localization

### File List

- Peach/Start/StartScreen.swift (modified)
- Peach/Resources/Localizable.xcstrings (modified)
- PeachTests/Start/StartScreenTests.swift (modified)
