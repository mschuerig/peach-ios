# Story 75.8: Help Content Centralization

Status: review

## Story

As a **developer maintaining help content**,
I want help sections decoupled from individual screen types,
so that `PeachCommands` (macOS menu bar) doesn't depend on screen implementations.

## Background

The walkthrough (Layer 6) found that all 4 training screens, the settings screen, and the profile screen each define `static let helpSections: [HelpSection]` inline. The macOS menu bar (`PeachCommands`) accesses these as `PitchDiscriminationScreen.helpSections`, creating a dependency from the menu system to individual screen types. Centralizing help content would decouple the menu from screens and make help content easier to find and maintain.

**Walkthrough source:** Layer 6 observation #4.

## Acceptance Criteria

1. **Given** help sections **When** inspected **Then** they are defined in a central location (e.g., a `HelpContent` enum namespace) rather than as static properties on each screen.
2. **Given** `PeachCommands` **When** inspected **Then** it references the central help content (e.g., `HelpContent.pitchDiscrimination`) instead of `PitchDiscriminationScreen.helpSections`.
3. **Given** each training screen **When** inspected **Then** it references the central help content for its help sheet.
4. **Given** help content for interval-aware screens **When** the screen is in interval mode **Then** the interval-specific help sections are still included (the current conditional logic is preserved).
5. **Given** both platforms **When** built and tested **Then** all tests pass and help content is identical to before.

## Tasks / Subtasks

- [x] Task 1: Create central help content (AC: #1)
  - [x] Create `HelpContent.swift` with a namespace enum
  - [x] Move help section arrays from each screen into the central file
  - [x] Help sections are unconditional static arrays (no conditional interval logic existed) — moved as-is

- [x] Task 2: Update PeachCommands (AC: #2)
  - [x] Replace `PitchDiscriminationScreen.helpSections` references with `HelpContent.pitchDiscrimination`
  - [x] Same for all other screen references in the menu

- [x] Task 3: Update training screens (AC: #3, #4)
  - [x] Replace `Self.helpSections` with `HelpContent.pitchDiscrimination` etc.
  - [x] Remove the `static let helpSections` from each screen
  - [x] Also updated SettingsScreen, ProfileScreen, InfoScreen, and StartScreen

- [x] Task 4: Build and test both platforms (AC: #5)
  - [x] `bin/test.sh && bin/test.sh -p mac` — 1717 iOS + 1710 macOS tests pass

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| New: `Peach/App/HelpContent.swift` (or `Info/HelpContent.swift`) | Central help sections |
| `Peach/PitchDiscrimination/PitchDiscriminationScreen.swift` | Remove `static let helpSections` |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Remove `static let helpSections` |
| `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift` | Remove `static let helpSections` |
| `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` | Remove `static let helpSections` |
| `Peach/App/PeachCommands.swift` | Update references |

### Interaction with Story 75.3 (TrainingScreenModifier)

If 75.3 is done first, the modifier accepts `helpSections` as a parameter. This story changes what gets passed (from `Self.helpSections` to `HelpContent.xxx`). If 75.8 is done first, the screens still pass their local static to the help sheet, and 75.3 later moves that call into the modifier. Either order works.

### What NOT to Change

- Do not change `HelpContentView` (the rendering component)
- Do not change the `HelpSection` type itself
- Do not change the actual help text content — only its location

### References

- [Source: docs/walkthrough/6-screens-and-navigation.md — observation #4]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References

### Completion Notes List
- Created `Peach/App/HelpContent.swift` enum namespace with all help section arrays centralized
- Moved help sections from 7 screens (4 training + settings + profile + info) into `HelpContent`
- Updated `PeachCommands.HelpSheetContent.sections` to reference `HelpContent.*` instead of screen types
- Updated all training screens to pass `HelpContent.*` to `.trainingScreen(helpSections:)` modifier
- Updated `SettingsScreen`, `ProfileScreen`, `InfoScreen`, and `StartScreen` references
- Updated 6 test files to reference `HelpContent.*` instead of screen types
- Note: The story expected conditional interval-mode logic but none existed — interval help sections were always included unconditionally. Preserved as-is.
- Simplify-code: Moved text constants (appDescription, trainingModesDescription, gettingStartedText, acknowledgmentsText) from `InfoScreen` into `HelpContent` to eliminate mutual coupling
- Simplify-code: Added `HelpContent.about` computed property to deduplicate `info + acknowledgments` concatenation

### File List
- Peach/App/HelpContent.swift (new)
- Peach/App/PeachCommands.swift (modified)
- Peach/Training/PitchDiscrimination/PitchDiscriminationScreen.swift (modified)
- Peach/Training/PitchMatching/PitchMatchingScreen.swift (modified)
- Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift (modified)
- Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift (modified)
- Peach/Settings/SettingsScreen.swift (modified)
- Peach/Profile/ProfileScreen.swift (modified)
- Peach/Info/InfoScreen.swift (modified)
- Peach/Start/StartScreen.swift (modified)
- PeachTests/App/HelpContentViewTests.swift (modified)
- PeachTests/Start/StartScreenTests.swift (modified)
- PeachTests/Training/PitchMatching/PitchMatchingScreenTests.swift (modified)
- PeachTests/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreenTests.swift (modified)
- PeachTests/Training/PitchDiscrimination/PitchDiscriminationScreenLayoutTests.swift (modified)
- PeachTests/Settings/SettingsTests.swift (modified)
- PeachTests/Training/TimingOffsetDetection/TimingOffsetDetectionScreenLayoutTests.swift (modified)
- docs/implementation-artifacts/75-8-help-content-centralization.md (modified)
- docs/implementation-artifacts/sprint-status.yaml (modified)

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-07: Implementation complete — centralized all help content into HelpContent enum namespace
