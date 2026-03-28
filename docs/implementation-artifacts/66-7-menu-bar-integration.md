# Story 66.7: Menu Bar Integration

Status: draft

## Story

As a **Mac user**,
I want a proper menu bar with standard and app-specific commands,
so that Peach feels like a native Mac application.

## Acceptance Criteria

1. **Given** the macOS build **When** the app is running **Then** the menu bar includes a File menu with an "Export Training Data..." item that triggers CSV export.

2. **Given** the macOS build **When** the app is running **Then** the menu bar includes a File menu with an "Import Training Data..." item.

3. **Given** the menu bar **When** the Help menu is opened **Then** it includes a "Peach Help" item that opens the Info screen content.

4. **Given** menu commands **When** invoked **Then** they perform the same actions as their in-app equivalents (export from Profile, import from Settings).

5. **Given** the iOS build **When** tested **Then** behaviour is unchanged — menu bar commands are macOS-only.

6. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Add `.commands` modifier to `WindowGroup` (AC: #1, #2, #3, #5)
  - [ ] 1.1 Add `#if os(macOS)` `.commands { ... }` block to the `WindowGroup`
  - [ ] 1.2 Add `CommandGroup(replacing: .newItem) { }` to remove the default New Window command (single-window app)
  - [ ] 1.3 Add File > Export Training Data... (Cmd+E)
  - [ ] 1.4 Add File > Import Training Data... (Cmd+I)
  - [ ] 1.5 Add Help > Peach Help (Cmd+?)

- [ ] Task 2: Wire menu actions (AC: #4)
  - [ ] 2.1 Export and Import actions need access to the same services as the in-app buttons
  - [ ] 2.2 Consider using `@Environment` or shared state to trigger these from the menu

- [ ] Task 3: Verify iOS unchanged (AC: #5) and run tests (AC: #6)

## Dev Notes

### SwiftUI Commands API

```swift
WindowGroup {
    ContentView()
}
#if os(macOS)
.commands {
    CommandGroup(replacing: .newItem) { } // Remove "New Window"
    CommandMenu("File") {
        Button("Export Training Data...") { ... }
            .keyboardShortcut("e", modifiers: .command)
        Button("Import Training Data...") { ... }
            .keyboardShortcut("i", modifiers: .command)
    }
}
#endif
```

### Window Management

Peach is a single-window app. Consider:
- Removing or disabling "New Window" (Cmd+N) — `CommandGroup(replacing: .newItem) { }`
- The default Window menu with minimize/zoom is fine as-is

### Scope Limitation

This story adds basic menu bar integration. Advanced menu items (per-training-mode commands, recent exports, etc.) can be added later based on user feedback. Keep it minimal for the initial macOS release.

### Source File Locations

| File | Path | Change |
|------|------|--------|
| PeachApp | `Peach/App/PeachApp.swift` | Add `.commands` modifier |
