# Story 66.6: Native macOS Settings Scene

Status: draft

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

- [ ] Task 1: Add a `Settings` scene to `PeachApp` (AC: #1, #4)
  - [ ] 1.1 In `PeachApp.body`, add a `#if os(macOS)` block containing a `Settings { ... }` scene
  - [ ] 1.2 The Settings scene content wraps `SettingsScreen()` with necessary environment injection
  - [ ] 1.3 Verify Cmd+, works out of the box (SwiftUI provides this automatically for `Settings` scenes)

- [ ] Task 2: Ensure environment values are available (AC: #2, #3)
  - [ ] 2.1 The `Settings` scene needs the same `@Environment` values as the in-app SettingsScreen
  - [ ] 2.2 Inject `userSettings`, `soundSourceProvider`, and `settingsCoordinator` (check current SettingsScreen dependencies)
  - [ ] 2.3 Test that changes in the Settings window reflect immediately in the main window

- [ ] Task 3: Verify iOS unchanged (AC: #4) and run tests (AC: #6)

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
