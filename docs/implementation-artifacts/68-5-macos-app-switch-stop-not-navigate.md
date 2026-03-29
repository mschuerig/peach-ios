# Story 68.5: macOS App Switch Stops Session but Preserves Navigation

Status: done

## Story

As a **macOS user switching between apps**,
I want Peach to stop the training session but leave me on the training screen,
so that I can resume with one tap instead of navigating back from the Start Screen.

## Acceptance Criteria

1. **Given** macOS focus loss **When** the app transitions to `.inactive` **Then** the active session is stopped (unchanged).

2. **Given** macOS focus gain **When** the app returns to `.active` **Then** the navigation stack is preserved -- the user stays on whichever screen they were on.

3. **Given** iOS backgrounding **When** the app is foregrounded **Then** behavior is unchanged -- session stops AND navigation clears to Start Screen.

4. **Given** a training screen after external stop **When** displayed **Then** it shows its idle/ready state correctly with no stale mid-session UI.

## Tasks / Subtasks

- [x] Task 1: Split `clearNavigation` behavior by platform in `TrainingLifecycleCoordinator` (AC: #1, #2, #3)
  - [x] 1.1 Modify `handleScenePhase(old:new:clearNavigation:)` so that on macOS, `clearNavigation()` is NOT called when returning to `.active` -- only session stop on deactivation
  - [x] 1.2 On iOS, preserve the current behavior: `clearNavigation()` is called when returning to `.active` from `.background` or `.inactive`
  - [x] 1.3 This follows the existing `BackgroundPolicy` protocol pattern (from story 67.1) if already implemented, or uses `#if os` in the coordinator if not yet abstracted

- [x] Task 2: Verify training screens handle external stop gracefully (AC: #4)
  - [x] 2.1 Review each training screen to confirm that when the session transitions to idle externally (via `stop()`), the screen shows its ready/idle state without stale feedback indicators, progress, or mid-comparison UI
  - [x] 2.2 Specifically check: `PitchDiscriminationScreen`, `PitchMatchingScreen`, `RhythmOffsetDetectionScreen`, `ContinuousRhythmMatchingScreen`
  - [x] 2.3 The session's `@Observable` state should drive the view -- when `isIdle` becomes true, the screen should reflect it. Verify no view state leaks.

- [x] Task 3: Update tests (AC: #1, #2, #3)
  - [x] 3.1 Update `TrainingLifecycleCoordinatorTests` -- on macOS: `inactive -> active` must NOT call `clearNavigation`
  - [x] 3.2 Update `TrainingLifecycleCoordinatorTests` -- on macOS: `inactive` must still call `stop()` on active session
  - [x] 3.3 Verify iOS tests unchanged: `background -> active` still calls both stop and clearNavigation
  - [x] 3.4 Add test: macOS `background -> active` also preserves navigation (does not clear)
  - [x] 3.5 Run `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Current Behavior

In `TrainingLifecycleCoordinator.handleScenePhase()` (line 30-45):

```swift
func handleScenePhase(old: ScenePhase, new: ScenePhase, clearNavigation: () -> Void) {
    #if os(iOS)
    let shouldStop = new == .background
    #else
    let shouldStop = new == .background || new == .inactive
    #endif

    if shouldStop {
        activeSession?.stop()
    }
    if new == .active && (old == .background || old == .inactive) {
        clearNavigation()
    }
}
```

The problem: `clearNavigation()` is called unconditionally on both platforms when returning to `.active`. On macOS, where `.inactive` happens on every app switch (Cmd+Tab), this forces the user back to the Start Screen every time they switch away and back.

### Required Change

The fix is straightforward: on macOS, do not call `clearNavigation()` at all. The session is already stopped on deactivation. When the user returns, they see the training screen in its idle state and can restart with one action.

On iOS, the current behavior (clear to Start Screen) makes sense because backgrounding implies a longer interruption and the user may have force-quit or been away for a long time.

### ContentView Navigation

In `ContentView.swift` (line 30-32), the scene phase handler calls the coordinator:

```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    lifecycle.handleScenePhase(old: oldPhase, new: newPhase) {
        navigationPath.removeAll()
    }
}
```

The `clearNavigation` closure removes all entries from `navigationPath`, navigating back to `StartScreen()`. After this change, on macOS this closure will simply never be called.

### Existing Tests

`TrainingLifecycleCoordinatorTests.swift` has platform-conditional tests:
- `inactiveDoesNotStopSessionOnIOS` (iOS only)
- `inactiveStopsSessionOnMacOS` (macOS only)
- `foregroundClearsNavigation` -- this test currently asserts `clearNavigation` is called; it needs to become iOS-only or be split
- `backgroundStopsButDoesNotClear` -- asserts stop is called but navigation is NOT cleared on `.background` (both platforms)

### Project Structure Notes

- Modified: `Peach/App/TrainingLifecycleCoordinator.swift` -- conditional `clearNavigation()` call
- Modified: `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` -- platform-conditional assertions

### References

- [Source: Peach/App/TrainingLifecycleCoordinator.swift -- handleScenePhase lines 30-45, clearNavigation called unconditionally on .active]
- [Source: Peach/App/ContentView.swift -- onChange(of: scenePhase) passes navigationPath.removeAll() as clearNavigation closure]
- [Source: PeachTests/App/TrainingLifecycleCoordinatorTests.swift -- 8 tests covering scene phase transitions with platform conditionals]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References

### Completion Notes List
- Extended `BackgroundPolicy` protocol with `shouldClearNavigation(oldPhase:newPhase:)` method, following the existing platform abstraction pattern from story 67.1
- `IOSBackgroundPolicy` returns `true` when returning to `.active` from `.background` or `.inactive` (preserving current behavior)
- `MacOSBackgroundPolicy` returns `false` always — macOS users stay on the training screen after app switch
- Updated `TrainingLifecycleCoordinator.handleScenePhase()` to delegate navigation clearing to the policy instead of unconditional logic
- Verified all four training screens (`PitchDiscriminationScreen`, `PitchMatchingScreen`, `RhythmOffsetDetectionScreen`, `ContinuousRhythmMatchingScreen`) correctly display idle state when session is stopped externally — all driven by `@Observable` session state with proper cleanup in `stop()`
- Added 5 new `BackgroundPolicyTests` (3 iOS, 2 macOS) for `shouldClearNavigation`
- Added 3 new macOS-specific coordinator tests and renamed 2 existing tests for clarity
- All 1673 iOS tests and 1666 macOS tests pass

### File List
- Peach/Core/Ports/BackgroundPolicy.swift (modified — added `shouldClearNavigation` to protocol)
- Peach/App/Platform/IOSBackgroundPolicy.swift (modified — added `shouldClearNavigation` implementation)
- Peach/App/Platform/MacOSBackgroundPolicy.swift (modified — added `shouldClearNavigation` implementation)
- Peach/App/TrainingLifecycleCoordinator.swift (modified — delegate clearNavigation to policy)
- PeachTests/Core/Ports/BackgroundPolicyTests.swift (modified — 5 new navigation clearing tests)
- PeachTests/App/TrainingLifecycleCoordinatorTests.swift (modified — 3 new macOS tests, renamed 2 existing)

## Change Log

- 2026-03-29: Story created
- 2026-03-29: Implemented — extended BackgroundPolicy with shouldClearNavigation; macOS preserves navigation on app switch
