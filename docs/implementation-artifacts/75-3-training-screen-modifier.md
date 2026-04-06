# Story 75.3: Training Screen Modifier — Shared Boilerplate Extraction

Status: ready-for-dev

## Story

As a **developer adding or modifying training screens**,
I want shared scaffolding extracted into a `TrainingScreenModifier`,
so that each screen defines only its unique content and help sections.

## Background

The walkthrough (Layer 6) found that all 4 training screens duplicate ~30 lines of identical scaffolding: `@FocusState` + focus modifiers, `onKeyPress(.escape)` dismiss, `onAppear`/`onDisappear` lifecycle calls, help sheet `onChange` with lifecycle notifications, toolbar with help/settings/profile links, and `trainingIdleOverlay()`. A view modifier can absorb all of it.

**Walkthrough source:** Layer 6 observation #1.

## Acceptance Criteria

1. **Given** a new `TrainingScreenModifier` view modifier **When** applied **Then** it provides:
   - `@FocusState` + `.focusable()` + `.focusEffectDisabled()` + `.focused()`
   - `onKeyPress(.escape)` to dismiss/navigate back
   - `onAppear` → `lifecycle.trainingScreenAppeared()`, `onDisappear` → `lifecycle.trainingScreenDisappeared()`
   - Help sheet state + `onChange` with `lifecycle.helpSheetPresented()`/`helpSheetDismissed()`
   - Toolbar: principal title + help button + settings link + profile link
   - `trainingIdleOverlay()`
2. **Given** all 4 training screens **When** inspected **Then** they apply the modifier instead of duplicating the scaffolding.
3. **Given** each training screen **When** inspected **Then** it defines only: its unique visual content (buttons/slider/dots), screen-specific keyboard shortcuts (arrows, letters), and its help sections array.
4. **Given** the modifier **When** parameterized **Then** it accepts the screen's title string and help sections as arguments.
5. **Given** both platforms **When** built and tested **Then** all tests pass and all 4 training screens behave identically to before (focus, keyboard, lifecycle, help, toolbar, idle overlay).

## Tasks / Subtasks

- [ ] Task 1: Identify the exact shared scaffolding (AC: #1)
  - [ ] Diff all 4 screens to confirm the identical lines
  - [ ] Note any minor variations that need parameterization

- [ ] Task 2: Create TrainingScreenModifier (AC: #1, #4)
  - [ ] Define the modifier with parameters: `title: LocalizedStringKey`, `helpSections: [HelpSection]`
  - [ ] Move all shared scaffolding into the modifier's `body(content:)`
  - [ ] Handle the `@FocusState` — may need to be managed inside the modifier or passed as a binding

- [ ] Task 3: Apply to all 4 training screens (AC: #2, #3)
  - [ ] `PitchDiscriminationScreen` — remove duplicated scaffolding, apply modifier
  - [ ] `PitchMatchingScreen` — remove duplicated scaffolding, apply modifier
  - [ ] `RhythmOffsetDetectionScreen` — remove duplicated scaffolding, apply modifier
  - [ ] `ContinuousRhythmMatchingScreen` — remove duplicated scaffolding, apply modifier

- [ ] Task 4: Verify behavior (AC: #5)
  - [ ] `bin/test.sh && bin/test.sh -p mac`
  - [ ] Manual check: focus, keyboard shortcuts, help sheet, toolbar, idle overlay on each screen

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| New: `Peach/App/TrainingScreenModifier.swift` | The shared modifier |
| `Peach/PitchDiscrimination/PitchDiscriminationScreen.swift` | Apply modifier, remove ~30 lines |
| `Peach/PitchMatching/PitchMatchingScreen.swift` | Apply modifier, remove ~30 lines |
| `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift` | Apply modifier, remove ~30 lines |
| `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` | Apply modifier, remove ~30 lines |

### Design Consideration: @FocusState Ownership

`@FocusState` is a property wrapper that typically lives on the view. The modifier needs to either:
- Own the `@FocusState` internally and expose a binding to the content view
- Accept a `FocusState<Bool>.Binding` from the content view

The first approach is cleaner (the content view doesn't need to know about focus state). Test which works with SwiftUI's focus system.

### Screen-Specific Keyboard Shortcuts

Each screen has its own keyboard shortcuts (arrows, letters) defined in `onKeyPress`. These remain on the individual screens — only the shared `.escape` dismiss and the `.focusable()` setup move to the modifier.

### What NOT to Change

- Do not change any screen's unique content (buttons, slider, dots, feedback indicators)
- Do not change screen-specific keyboard shortcuts
- Do not change the help section content itself (that's Story 75.8)

### References

- [Source: docs/walkthrough/6-screens-and-navigation.md — observation #1]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
