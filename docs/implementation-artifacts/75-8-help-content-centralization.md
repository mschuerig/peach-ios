# Story 75.8: Help Content Centralization

Status: ready-for-dev

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

- [ ] Task 1: Create central help content (AC: #1)
  - [ ] Create `HelpContent.swift` (or `HelpSections.swift`) with a namespace enum
  - [ ] Move help section arrays from each screen into the central file
  - [ ] Preserve the conditional interval-mode sections as parameterized functions (e.g., `HelpContent.pitchDiscrimination(isIntervalMode: Bool)`)

- [ ] Task 2: Update PeachCommands (AC: #2)
  - [ ] Replace `PitchDiscriminationScreen.helpSections` references with `HelpContent.pitchDiscrimination`
  - [ ] Same for all other screen references in the menu

- [ ] Task 3: Update training screens (AC: #3, #4)
  - [ ] Replace `Self.helpSections` with `HelpContent.pitchDiscrimination(isIntervalMode:)` etc.
  - [ ] Remove the `static let helpSections` from each screen

- [ ] Task 4: Build and test both platforms (AC: #5)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
