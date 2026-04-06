# Story 75.3: Training Screen Modifier — Shared Boilerplate Extraction

Status: review

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

- [x] Task 1: Identify the exact shared scaffolding (AC: #1)
  - [x] Diff all 4 screens to confirm the identical lines
  - [x] Note any minor variations that need parameterization

- [x] Task 2: Create TrainingScreenModifier (AC: #1, #4)
  - [x] Define the modifier with parameters: `helpSections: [HelpSection]`, `destination: NavigationDestination`, `@ViewBuilder title`
  - [x] Move all shared scaffolding into the modifier's `body(content:)`
  - [x] Handle the `@FocusState` — owned internally by the modifier (cleaner approach)

- [x] Task 3: Apply to all 4 training screens (AC: #2, #3)
  - [x] `PitchDiscriminationScreen` — remove duplicated scaffolding, apply modifier
  - [x] `PitchMatchingScreen` — remove duplicated scaffolding, apply modifier
  - [x] `TimingOffsetDetectionScreen` — remove duplicated scaffolding, apply modifier
  - [x] `ContinuousRhythmMatchingScreen` — remove duplicated scaffolding, apply modifier

- [x] Task 4: Verify behavior (AC: #5)
  - [x] `bin/test.sh && bin/test.sh -p mac` — 1717 iOS + 1710 macOS tests pass
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
Claude Opus 4.6

### Debug Log References

### Completion Notes List
- Created `TrainingScreenModifier` as a generic `ViewModifier` with `@ViewBuilder` title parameter (instead of plain `LocalizedStringKey`) because the toolbar principal content varies per screen (icon + text + accessibility label)
- `@FocusState` is owned internally by the modifier — content views don't need to know about it
- The modifier absorbs: `@FocusState` + focus modifiers, escape key dismiss, onAppear/onDisappear lifecycle, help sheet state + onChange lifecycle, toolbar (principal title + help/settings/profile), `inlineNavigationBarTitle()`, `trainingIdleOverlay()`
- Each screen retains only: unique content, screen-specific keyboard shortcuts, help sections array
- Convenience extension `View.trainingScreen(helpSections:destination:title:)` provides clean call-site API
- Story specified `title: LocalizedStringKey` but actual toolbar principal uses icon + text + accessibility, so `@ViewBuilder` was the right choice

### File List
- `Peach/App/TrainingScreenModifier.swift` (new)
- `Peach/Training/PitchDiscrimination/PitchDiscriminationScreen.swift` (modified — removed ~40 lines of scaffolding)
- `Peach/Training/PitchMatching/PitchMatchingScreen.swift` (modified — removed ~45 lines of scaffolding)
- `Peach/Training/TimingOffsetDetection/TimingOffsetDetectionScreen.swift` (modified — removed ~45 lines of scaffolding)
- `Peach/Training/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` (modified — removed ~45 lines of scaffolding)

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-07: Implemented TrainingScreenModifier and applied to all 4 training screens
