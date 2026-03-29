# Story 66.6: Native macOS Settings Scene

Status: done

## Story

As a **Mac user**,
I want to open Settings with Cmd+, (the standard Mac shortcut),
so that I can configure the app using the native macOS Settings window.

## Acceptance Criteria

1. **Given** the macOS build **When** the user presses Cmd+, **Then** a native macOS Settings window opens showing the app's settings.

2. **Given** the macOS Settings window **When** it displays **Then** it reuses the same `SettingsScreen` content as the iOS navigation destination, wrapped in appropriate macOS window chrome.

3. **Given** the macOS Settings window **When** the user changes a setting **Then** the change takes effect immediately (same `@AppStorage` mechanism as iOS).

4. **Given** the iOS build **When** tested **Then** the Settings navigation destination works as before — the `Settings` scene is macOS-only.

5. **Given** the macOS build **When** the Settings button on the Start Screen is tapped **Then** it navigates to Settings the same way as on iOS (in-app navigation). The Cmd+, Settings window is an additional access point, not a replacement.

6. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Add a `Settings` scene to `PeachApp` (AC: #1, #4)
  - [x] 1.1 In `PeachApp.body`, add a `#if os(macOS)` block containing a `Settings { ... }` scene
  - [x] 1.2 The Settings scene content wraps `SettingsScreen()` with necessary environment injection
  - [x] 1.3 Verify Cmd+, works out of the box (SwiftUI provides this automatically for `Settings` scenes)

- [x] Task 2: Ensure environment values are available (AC: #2, #3)
  - [x] 2.1 The `Settings` scene needs the same `@Environment` values as the in-app SettingsScreen
  - [x] 2.2 Inject `soundSourceProvider` and `settingsCoordinator` (the two `@Environment` dependencies of SettingsScreen)
  - [x] 2.3 Test that changes in the Settings window reflect immediately in the main window

- [x] Task 3: Verify iOS unchanged (AC: #4) and run tests (AC: #6)

## Dev Notes

### SwiftUI `Settings` Scene

SwiftUI provides a dedicated `Settings` scene type for macOS. When included in the `App` body, it automatically:
- Adds a "Settings..." item to the app menu (with Cmd+, shortcut)
- Opens as a separate window with appropriate macOS chrome
- Manages window lifecycle

```swift
var body: some Scene {
    WindowGroup {
        ContentView()
    }
    #if os(macOS)
    Settings {
        SettingsScreen()
            .environment(\.userSettings, userSettings)
            // ... other environment values
    }
    #endif
}
```

### Environment Injection Consideration

The `Settings` scene is a separate scene from the `WindowGroup`, so it gets its own environment hierarchy. All `@Environment` values that `SettingsScreen` reads must be explicitly injected into the `Settings` scene. Check the current `SettingsScreen` for its `@Environment` dependencies and mirror them.

### Source File Locations

| File | Path | Change |
|------|------|--------|
| PeachApp | `Peach/App/PeachApp.swift` | Add `Settings` scene in `#if os(macOS)` |

## Dev Agent Record

### Implementation Plan

Add a `Settings` scene in `#if os(macOS)` after the `WindowGroup` in PeachApp.body, injecting the two `@Environment` values that `SettingsScreen` depends on: `soundSourceProvider` and `settingsCoordinator`. `@AppStorage` values are shared automatically via `UserDefaults.standard`.

### Debug Log

No issues encountered with the Settings scene. During test validation, discovered and fixed a bug in `PitchMatchingSession.commitResult()` — see Boy Scout Rule fix below.

### Completion Notes

- Added `Settings` scene to `PeachApp.body` wrapped in `#if os(macOS)` conditional compilation
- Injected `soundSourceProvider` (SoundFontLibrary) and `settingsCoordinator` (SettingsCoordinator) into the Settings scene
- SettingsScreen's `@AppStorage` properties automatically share state with the main window via `UserDefaults.standard`
- Cmd+, shortcut is provided automatically by SwiftUI's `Settings` scene type
- iOS build verified unchanged — the `#if os(macOS)` block compiles out entirely
- Full test suite passes on both iOS and macOS with zero regressions (1644 iOS, 1612 macOS)

**Boy Scout Rule fix:** `PitchMatchingSession.commitResult()` had a `guard currentHandle != nil` that prevented committing results when the user submitted from `awaitingSliderTouch` (before the tunable note played). The handle was always nil in this path because `playNextTrial()` hadn't resumed yet. Removed the hard guard — handle stop is now conditional. This fixed the flaky `commitPitchFromAwaitingSliderTouchProducesResult` test which was timing out waiting for `.showingFeedback` that could never be reached.

## File List

- `Peach/App/PeachApp.swift` — Added `Settings` scene in `#if os(macOS)` block
- `Peach/PitchMatching/PitchMatchingSession.swift` — Fixed `commitResult()` to allow commit without active playback handle

## Change Log

- 2026-03-29: Implemented native macOS Settings scene with Cmd+, shortcut support
- 2026-03-29: Fixed PitchMatchingSession.commitResult() early return when currentHandle is nil (Boy Scout Rule)
