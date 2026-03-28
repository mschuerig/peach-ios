# Story 66.7: Menu Bar Integration

Status: draft

## Story

As a **Mac user**,
I want a proper menu bar with training, profile, and help menus,
so that Peach feels like a native Mac application and I can discover all features from the menu bar.

## Acceptance Criteria

1. **Given** the macOS build **When** the menu bar is viewed **Then** there is a "Training" menu containing one item per training discipline, grouped by section:
   - **Pitch**: "Compare Pitch" and "Match Pitch"
   - **Intervals**: "Compare Intervals" and "Match Intervals"
   - **Rhythm**: "Compare Timing" and "Fill the Gap"

2. **Given** the Training menu **When** a discipline is selected **Then** the app navigates to that training screen (same as tapping the corresponding card on the Start Screen).

3. **Given** the macOS build **When** the menu bar is viewed **Then** there is a "Profile" menu containing a "Show Profile" item.

4. **Given** the Profile menu **When** "Show Profile" is selected **Then** the app navigates to the Profile Screen.

5. **Given** the macOS build **When** the Help menu is opened **Then** it includes:
   - "About Peach" — opens the Info screen content (general app help)
   - A divider
   - "Pitch Compare Help" — opens the pitch comparison help content
   - "Pitch Match Help" — opens the pitch matching help content
   - "Rhythm Compare Help" — opens the rhythm offset detection help content
   - "Fill the Gap Help" — opens the continuous rhythm matching help content

6. **Given** a Help menu item for a training discipline **When** selected **Then** a sheet or window presents the corresponding `HelpContentView(sections:)` using the same `helpSections` defined on that screen.

7. **Given** the File menu on macOS **When** viewed **Then** it includes "Export Training Data..." (Cmd+E) and "Import Training Data..." (Cmd+I).

8. **Given** the File menu commands **When** invoked **Then** they perform the same actions as their in-app equivalents.

9. **Given** the iOS build **When** tested **Then** behaviour is unchanged — menu bar commands are macOS-only.

10. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Add `.commands` modifier to `WindowGroup` (AC: #9)
  - [ ] 1.1 Add `#if os(macOS)` `.commands { ... }` block to the `WindowGroup`
  - [ ] 1.2 Add `CommandGroup(replacing: .newItem) { }` to remove the default New Window command (single-window app)

- [ ] Task 2: Add Training menu (AC: #1, #2)
  - [ ] 2.1 Add `CommandMenu("Training")` with items grouped by section using `Section` views
  - [ ] 2.2 Pitch section: "Compare Pitch" and "Match Pitch"
  - [ ] 2.3 Intervals section: "Compare Intervals" and "Match Intervals"
  - [ ] 2.4 Rhythm section: "Compare Timing" and "Fill the Gap"
  - [ ] 2.5 Each item navigates by appending to the `navigationPath` (needs access to navigation state — see Dev Notes)

- [ ] Task 3: Add Profile menu (AC: #3, #4)
  - [ ] 3.1 Add `CommandMenu("Profile")` with a "Show Profile" item
  - [ ] 3.2 Navigates to the Profile Screen

- [ ] Task 4: Add Help menu items (AC: #5, #6)
  - [ ] 4.1 Add `CommandGroup(replacing: .help)` or `CommandGroup(after: .help)` to customise the Help menu
  - [ ] 4.2 Add "About Peach" item that presents the `InfoScreen` help content
  - [ ] 4.3 Add per-discipline help items using each screen's `static helpSections`
  - [ ] 4.4 Present help content in a sheet or popover — consider whether to open a new window or show in the main window

- [ ] Task 5: Add File menu items (AC: #7, #8)
  - [ ] 5.1 Add "Export Training Data..." (Cmd+E) and "Import Training Data..." (Cmd+I)
  - [ ] 5.2 Wire export and import actions to the same services as the in-app buttons

- [ ] Task 6: Localise menu items (AC: #1, #3, #5)
  - [ ] 6.1 All menu item titles must be localized (English + German)
  - [ ] 6.2 Use the same localized strings as the Start Screen cards and help sheets where possible

- [ ] Task 7: Verify iOS unchanged (AC: #9) and run tests (AC: #10)

## Dev Notes

### Navigation from Menu Commands

Menu commands need to push destinations onto the `navigationPath`. The path is currently `@State` in `ContentView`. Options:
1. **Lift `navigationPath` to `PeachApp`** and pass it via `@Environment` — then commands can append to it
2. **Use `FocusedValue`** — the SwiftUI pattern for commands that interact with the focused window's state
3. **Use `openWindow`** — for help content, consider opening in a separate window

Option 2 (`FocusedValue`) is the idiomatic SwiftUI approach for menu commands on macOS. `ContentView` would expose the navigation path as a focused value, and commands would read it.

### Help Content Architecture

Each training screen already defines `static let helpSections: [HelpSection]`. The menu items can reuse these directly:

| Screen | Help Sections Location |
|--------|----------------------|
| PitchDiscriminationScreen | `.helpSections` (5 sections) |
| PitchMatchingScreen | `.helpSections` (4 sections) |
| RhythmOffsetDetectionScreen | `.helpSections` (4 sections) |
| ContinuousRhythmMatchingScreen | `.helpSections` (3 sections) |
| InfoScreen | `.helpSections` (3 sections) + `.acknowledgmentsSections` (1 section) |

### Training Menu Structure

```
Training
├── Pitch
│   ├── Compare Pitch
│   └── Match Pitch
├── Intervals
│   ├── Compare Intervals
│   └── Match Intervals
└── Rhythm
    ├── Compare Timing
    └── Fill the Gap
```

### Window Management

Peach is a single-window app. Consider:
- Removing or disabling "New Window" (Cmd+N) — `CommandGroup(replacing: .newItem) { }`
- The default Window menu with minimize/zoom is fine as-is

### Source File Locations

| File | Path | Change |
|------|------|--------|
| PeachApp | `Peach/App/PeachApp.swift` | Add `.commands` modifier |
| ContentView | `Peach/App/ContentView.swift` | Expose `navigationPath` as `FocusedValue` |
| NavigationDestination | `Peach/App/NavigationDestination.swift` | No change |
| HelpContentView | `Peach/App/HelpContentView.swift` | No change (reused) |
| Each *Screen | Various | No change (static `helpSections` already exist) |
