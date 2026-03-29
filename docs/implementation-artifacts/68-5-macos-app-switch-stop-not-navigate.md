# Story 68.5: macOS App Switch Stops Session but Preserves Navigation

Status: ready-for-dev

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

- [ ] Task 1: Split `clearNavigation` behavior by platform in `TrainingLifecycleCoordinator` (AC: #1, #2, #3)
  - [ ] 1.1 Modify `handleScenePhase(old:new:clearNavigation:)` so that on macOS, `clearNavigation()` is NOT called when returning to `.active` -- only session stop on deactivation
  - [ ] 1.2 On iOS, preserve the current behavior: `clearNavigation()` is called when returning to `.active` from `.background` or `.inactive`
  - [ ] 1.3 This follows the existing `BackgroundPolicy` protocol pattern (from story 67.1) if already implemented, or uses `#if os` in the coordinator if not yet abstracted

- [ ] Task 2: Verify training screens handle external stop gracefully (AC: #4)
  - [ ] 2.1 Review each training screen to confirm that when the session transitions to idle externally (via `stop()`), the screen shows its ready/idle state without stale feedback indicators, progress, or mid-comparison UI
  - [ ] 2.2 Specifically check: `PitchDiscriminationScreen`, `PitchMatchingScreen`, `RhythmOffsetDetectionScreen`, `ContinuousRhythmMatchingScreen`
  - [ ] 2.3 The session's `@Observable` state should drive the view -- when `isIdle` becomes true, the screen should reflect it. Verify no view state leaks.

- [ ] Task 3: Update tests (AC: #1, #2, #3)
  - [ ] 3.1 Update `TrainingLifecycleCoordinatorTests` -- on macOS: `inactive -> active` must NOT call `clearNavigation`
  - [ ] 3.2 Update `TrainingLifecycleCoordinatorTests` -- on macOS: `inactive` must still call `stop()` on active session
  - [ ] 3.3 Verify iOS tests unchanged: `background -> active` still calls both stop and clearNavigation
  - [ ] 3.4 Add test: macOS `background -> active` also preserves navigation (does not clear)
  - [ ] 3.5 Run `bin/test.sh && bin/test.sh -p mac`

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
