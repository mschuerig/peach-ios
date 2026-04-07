# Story 75.7: Platform Split — ContentView and SettingsScreen Import

Status: done

## Story

As a **developer maintaining platform-specific code**,
I want `ContentView` split into per-platform files and `SettingsScreen`'s inline `#if os()` import logic moved to `App/Platform/`,
so that each platform's code is straightforward to read independently.

## Background

The walkthrough (Layers 5, 6) found that `ContentView` is ~75% macOS-only code: 4 extra `@State` properties, 7 modifiers, two helper methods, and a `MainWindowReader` representable. The shared code is just `NavigationStack(path:) { StartScreen() }` + `.onChange(of: scenePhase)`. Similarly, `SettingsScreen.importTrainingData()` has inline `#if os(macOS)` / `#elseif os(iOS)` that doesn't follow the project's platform abstraction pattern.

**Walkthrough sources:** Layer 5 observation #8; Layer 6 observation #7.

## Acceptance Criteria

1. **Given** `ContentView` **When** inspected **Then** iOS and macOS have separate files with no `#if os()` guards.
2. **Given** the iOS ContentView **When** inspected **Then** it contains only the `NavigationStack` + `scenePhase` handling.
3. **Given** the macOS ContentView **When** inspected **Then** it contains the `NavigationStack`, `scenePhase`, menu command wiring, window lifecycle, file importer, and `MainWindowReader`.
4. **Given** `SettingsScreen.importTrainingData()` **When** inspected **Then** the platform-specific import mechanism (`NSOpenPanel` on macOS, `.fileImporter` on iOS) is abstracted behind a protocol or platform file in `App/Platform/`.
5. **Given** both platforms **When** built and tested **Then** all tests pass and navigation/import behavior is identical to before.

## Tasks / Subtasks

- [x] Task 1: Split ContentView (AC: #1, #2, #3)
  - [x] Create `Peach/App/Platform/ContentView+iOS.swift` with the iOS-only content
  - [x] Create `Peach/App/Platform/ContentView+macOS.swift` with the macOS-only content
  - [x] Remove the original `ContentView.swift` (or make it a thin `#if` that selects the right file, though separate files are preferred)
  - [x] Move `MainWindowReader` to the macOS file if it isn't already

- [x] Task 2: Extract SettingsScreen import abstraction (AC: #4)
  - [x] Define a platform abstraction for file import (protocol or platform-specific implementations)
  - [x] Move `NSOpenPanel` logic to `App/Platform/` macOS file
  - [x] Move `.fileImporter` logic to `App/Platform/` iOS file
  - [x] `SettingsScreen` calls the abstraction instead of using `#if os()` inline

- [x] Task 3: Build and test both platforms (AC: #5)
  - [x] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| `Peach/App/ContentView.swift` (128 lines) | Split into two platform files |
| `Peach/Settings/SettingsScreen.swift` (367 lines) | Extract import logic |
| `Peach/App/Platform/` | Existing platform abstractions directory |

### Shared vs Platform-Specific in ContentView

**Shared (both platforms):**
- `NavigationStack(path: $navigationPath) { StartScreen().navigationDestination(for:) }`
- `.onChange(of: scenePhase)` → lifecycle coordinator

**macOS only (~75% of the file):**
- `@State private var menuCommandState`, `columnVisibility`, `importerPresented`, `importURL`
- `.focusedSceneValue`, `.onReceive(menuCommandState.$navigationRequest)`, `.onReceive(menuCommandState.$helpSheetContent)`
- `.fileImporter` for CSV import via menu
- `MainWindowReader` (NSViewRepresentable) for window-close-terminates-app
- `.frame(minWidth: 400, minHeight: 500)`
- `.onReceive(NSApplication.didResignActiveNotification)` / `didBecomeActiveNotification`

### Platform Abstraction Pattern

The project's existing pattern: Core defines a protocol in `Core/Ports/`, `App/Platform/` provides per-platform implementations, `PeachApp.init()` selects via `#if os()`. Follow this pattern for the file import abstraction.

### What NOT to Change

- Do not change the navigation structure or destination routing
- Do not change `PeachCommands` — it communicates with ContentView via `FocusedSceneValue`
- Do not change `SettingsScreen`'s UI layout or export functionality

### References

- [Source: docs/walkthrough/5-composition-root.md — observation #8]
- [Source: docs/walkthrough/6-screens-and-navigation.md — observation #7]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None

### Completion Notes List
- Split `ContentView.swift` (128 lines) into `ContentView+iOS.swift` (23 lines) and `ContentView+macOS.swift` (107 lines) with no `#if os()` guards — each file is wrapped in a top-level `#if os()` block
- iOS ContentView contains only NavigationStack + scenePhase handling
- macOS ContentView contains NavigationStack, scenePhase, menu command wiring, window lifecycle (MainWindowReader, willCloseNotification), file importer, help sheet, and app activation/deactivation handlers
- MainWindowReader (NSViewRepresentable) moved to macOS file as a private struct
- Created `PlatformFileImporter.swift` view modifier in `App/Platform/` — iOS uses `.fileImporter`, macOS uses `NSOpenPanel` via `.onChange` trigger
- SettingsScreen's `importTrainingData()` simplified to `showFileImporter = true` with no `#if os()` — platform logic handled by `.platformFileImporter` modifier
- All 1717 iOS tests and 1710 macOS tests pass with no regressions

### File List
- `Peach/App/ContentView.swift` — deleted
- `Peach/App/Platform/ContentView+iOS.swift` — new
- `Peach/App/Platform/ContentView+macOS.swift` — new
- `Peach/App/Platform/PlatformFileImporter.swift` — new
- `Peach/Settings/SettingsScreen.swift` — modified

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-07: Implementation complete — ContentView split into platform files, SettingsScreen import abstracted via platformFileImporter modifier
