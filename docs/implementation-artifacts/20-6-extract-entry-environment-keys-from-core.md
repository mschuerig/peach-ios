# Story 20.6: Extract @Entry Environment Keys from Core/

Status: pending

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **developer maintaining Peach**,
I want all `@Entry` environment key definitions consolidated into a single `App/EnvironmentKeys.swift` file,
So that Core/ files no longer import SwiftUI, the domain layer is framework-free, and all environment wiring is visible in one place.

## Acceptance Criteria

1. **`App/EnvironmentKeys.swift` exists** -- A new file `Peach/App/EnvironmentKeys.swift` contains all `extension EnvironmentValues` blocks with `@Entry` definitions.

2. **No Core/ file imports SwiftUI** -- After extracting the `@Entry` definitions, `SoundFontLibrary.swift`, `TrendAnalyzer.swift`, `ThresholdTimeline.swift`, and `TrainingSession.swift` no longer `import SwiftUI`.

3. **Core/ @Entry blocks removed** -- The `extension EnvironmentValues { @Entry var ... }` blocks are removed from:
   - `Core/Audio/SoundFontLibrary.swift` (lines 43-47)
   - `Core/Profile/TrendAnalyzer.swift` (lines 89-93)
   - `Core/Profile/ThresholdTimeline.swift` (lines 124-128)
   - `Core/TrainingSession.swift` (lines 7-11)

4. **Screen @Entry blocks moved** -- The `extension EnvironmentValues` blocks and associated preview mock types are moved from:
   - `Comparison/ComparisonScreen.swift` (`@Entry var comparisonSession` + `MockNotePlayerForPreview`, `MockPlaybackHandleForPreview`, `MockDataStoreForPreview`)
   - `PitchMatching/PitchMatchingScreen.swift` (`@Entry var pitchMatchingSession` + `MockNotePlayerForPitchMatchingPreview`, `MockPlaybackHandleForPitchMatchingPreview`)
   - `Profile/ProfileScreen.swift` (`@Entry var perceptualProfile`)

5. **Preview stubs simplified** -- The `@Entry` default values for `comparisonSession` and `pitchMatchingSession` no longer reference concrete implementation types (`KazezNoteStrategy`, `AppUserSettings`, `MockHapticFeedbackManager`) from outside the file. Preview stubs are defined as `private` types within `EnvironmentKeys.swift`.

6. **SwiftUI previews still work** -- Previews for `ComparisonScreen`, `PitchMatchingScreen`, and `ProfileScreen` render without crashes.

7. **All existing tests pass** -- Full test suite passes with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Create `Peach/App/EnvironmentKeys.swift` (AC: #1, #5)
  - [ ] Add `import SwiftUI` and all necessary imports
  - [ ] Add all `@Entry` definitions from Core/ files (soundFontLibrary, trendAnalyzer, thresholdTimeline, activeSession)
  - [ ] Add `@Entry var perceptualProfile` from ProfileScreen
  - [ ] Add `@Entry var comparisonSession` with simplified preview stubs
  - [ ] Add `@Entry var pitchMatchingSession` with simplified preview stubs
  - [ ] Define `private` preview stub types (mock NotePlayer, mock PlaybackHandle, mock DataStore, mock UserSettings) within the file

- [ ] Task 2: Remove @Entry from Core/ files (AC: #2, #3)
  - [ ] `SoundFontLibrary.swift`: remove `extension EnvironmentValues` block, remove `import SwiftUI`
  - [ ] `TrendAnalyzer.swift`: remove `extension EnvironmentValues` block, change `import SwiftUI` to `import Foundation`
  - [ ] `ThresholdTimeline.swift`: remove `extension EnvironmentValues` block, change `import SwiftUI` to `import Foundation`
  - [ ] `TrainingSession.swift`: remove `extension EnvironmentValues` block, change `import SwiftUI` to `import Foundation`

- [ ] Task 3: Remove @Entry from screen files (AC: #4)
  - [ ] `ComparisonScreen.swift`: remove `extension EnvironmentValues` block and preview mock classes
  - [ ] `PitchMatchingScreen.swift`: remove `extension EnvironmentValues` block and preview mock classes
  - [ ] `ProfileScreen.swift`: remove `extension EnvironmentValues` block

- [ ] Task 4: Verify previews (AC: #6)
  - [ ] Confirm ComparisonScreen preview renders
  - [ ] Confirm PitchMatchingScreen preview renders
  - [ ] Confirm ProfileScreen preview renders

- [ ] Task 5: Run full test suite (AC: #7)
  - [ ] `xcodebuild test -scheme Peach -destination 'platform=iOS Simulator,name=iPhone 17'`
  - [ ] All tests pass, zero regressions

## Dev Notes

### Critical Design Decisions

- **Single file for all @Entry keys** -- Centralizing in one file makes the DI wiring visible at a glance and prevents SwiftUI from leaking into domain code. This mirrors how `PeachApp.swift` is the composition root for instances -- `EnvironmentKeys.swift` is the registry for environment keys.
- **Preview stubs are private** -- The mock types used in @Entry defaults (for SwiftUI previews) are defined `private` within `EnvironmentKeys.swift`. They exist solely to satisfy the `@Entry` default requirement and should never be used elsewhere.
- **@Entry defaults reference only types visible in `EnvironmentKeys.swift`** -- The simplified defaults should not pull in `KazezNoteStrategy`, `AppUserSettings`, or `MockHapticFeedbackManager`. Use lightweight inline stubs that satisfy protocol requirements with minimal implementation.
- **`TrendAnalyzer.swift` and `ThresholdTimeline.swift` use `@Observable`** -- These classes use `import Observation`, not SwiftUI. After removing the `@Entry` block, they need `import Foundation` and `import Observation` (or just `import Foundation` with `import OSLog` if they use logging). Check the actual imports needed.

### Architecture & Integration

**New files:**
- `Peach/App/EnvironmentKeys.swift` (all @Entry definitions + private preview stubs)

**Modified production files:**
- `Peach/Core/Audio/SoundFontLibrary.swift` -- remove @Entry block, remove `import SwiftUI`
- `Peach/Core/Profile/TrendAnalyzer.swift` -- remove @Entry block, remove `import SwiftUI`
- `Peach/Core/Profile/ThresholdTimeline.swift` -- remove @Entry block, remove `import SwiftUI`
- `Peach/Core/TrainingSession.swift` -- remove @Entry block, remove `import SwiftUI`
- `Peach/Comparison/ComparisonScreen.swift` -- remove @Entry block and preview mock classes
- `Peach/PitchMatching/PitchMatchingScreen.swift` -- remove @Entry block and preview mock classes
- `Peach/Profile/ProfileScreen.swift` -- remove @Entry block

### Existing Code to Reference

- **`SoundFontLibrary.swift:43-47`** -- `extension EnvironmentValues { @Entry var soundFontLibrary = SoundFontLibrary() }`. [Source: Peach/Core/Audio/SoundFontLibrary.swift]
- **`TrendAnalyzer.swift:89-93`** -- `extension EnvironmentValues { @Entry var trendAnalyzer = TrendAnalyzer() }`. [Source: Peach/Core/Profile/TrendAnalyzer.swift]
- **`ThresholdTimeline.swift:124-128`** -- `extension EnvironmentValues { @Entry var thresholdTimeline = ThresholdTimeline() }`. [Source: Peach/Core/Profile/ThresholdTimeline.swift]
- **`TrainingSession.swift:7-11`** -- `extension EnvironmentValues { @Entry var activeSession: (any TrainingSession)? = nil }`. [Source: Peach/Core/TrainingSession.swift]
- **`ComparisonScreen.swift:160-201`** -- @Entry with MockNotePlayerForPreview, MockPlaybackHandleForPreview, MockDataStoreForPreview, full ComparisonSession construction. [Source: Peach/Comparison/ComparisonScreen.swift]
- **`PitchMatchingScreen.swift:66-92`** -- @Entry with MockNotePlayerForPitchMatchingPreview, MockPlaybackHandleForPitchMatchingPreview. [Source: Peach/PitchMatching/PitchMatchingScreen.swift]
- **`ProfileScreen.swift:108-112`** -- `extension EnvironmentValues { @Entry var perceptualProfile = PerceptualProfile() }`. [Source: Peach/Profile/ProfileScreen.swift]

### Testing Approach

- **No new tests** -- This is a structural refactoring that moves code between files without changing behavior.
- **Preview verification** is manual (open Xcode, check previews render).
- **Full test suite** verifies no compile errors or behavioral regressions.

### Previous Story Learnings (from 20.1)

- File moves in this project are safe because of the single-module architecture and Xcode objectVersion 77.

### Risk Assessment

- **Medium risk: Preview stubs** -- The @Entry defaults for `comparisonSession` and `pitchMatchingSession` construct full session objects with mocks. Simplifying these stubs must still satisfy all the protocol and type requirements or previews will crash. Test by opening previews in Xcode after the change.
- **Low risk: Import changes** -- After removing `import SwiftUI`, verify each Core/ file still compiles. `SoundFontLibrary` may need `import Foundation` explicitly. `TrendAnalyzer` and `ThresholdTimeline` may need `import Observation`.

### Git Intelligence

Commit message: `Implement story 20.5: Extract @Entry environment keys from Core/`

### Project Structure Notes

- `App/EnvironmentKeys.swift` sits alongside `PeachApp.swift`, `ContentView.swift`, and `NavigationDestination.swift` in the `App/` directory

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 20]
- [Source: docs/project-context.md -- @Environment for dependency injection, @Entry macro]
- [Source: Peach/App/PeachApp.swift -- Composition root that provides the actual values]

## Change Log

- 2026-02-27: Story created from Epic 20 adversarial dependency review.
