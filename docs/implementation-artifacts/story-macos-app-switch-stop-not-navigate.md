# Story: macOS App-Switch — Stop Session but Don't Navigate Away

Status: draft

## Story

As a macOS user switching between Peach and other apps,
I want Peach to stop the active training session but leave me on the training screen,
so that I can resume training with one tap instead of navigating back from the Start Screen.

## Background

Currently, when the user Cmd+Tabs away on macOS, the app stops the active session AND clears navigation back to the Start Screen. On iOS this makes sense — backgrounding is a strong signal the user is done. On macOS, losing focus is routine (checking a tuner, reading sheet music, replying to a message). Forcing back to the Start Screen every time is disruptive.

The fix: stop playback on focus loss (correct — audio shouldn't bleed), but preserve the navigation stack so the user stays on the training screen and can restart immediately.

**Source:** future-work.md "macOS App-Switch Behavior: Resume vs. Reset"

## Acceptance Criteria

1. **macOS focus loss stops the session:** When the app transitions to `.inactive` on macOS, the active training session is stopped (audio ceases, session goes to `idle`). This behavior is unchanged.

2. **macOS focus gain does NOT clear navigation:** When returning to the app on macOS, the user remains on whichever screen they were on. The navigation stack is preserved. The user can tap "Start" (or equivalent) to begin a new training round from the same screen.

3. **iOS behavior unchanged:** On iOS, backgrounding still stops the session AND clears navigation back to the Start Screen on foreground. No change to the iOS path.

4. **Training screen shows idle state correctly:** When the user returns to a training screen after focus loss, the screen must display its idle state (ready to start), not a stale mid-session state. The session's `isIdle` property drives this — verify that each training screen handles the `idle` state visually.

5. **Menu navigation still works:** macOS menu commands (if any trigger navigation) must still work correctly after a focus-loss/gain cycle. The preserved navigation path must not interfere with menu-driven navigation.

## Tasks / Subtasks

- [ ] Task 1: Remove navigation clearing on macOS focus gain (AC: #2, #3)
  - [ ] In `TrainingLifecycleCoordinator.handleScenePhase()`, gate the `clearNavigation()` call behind `#if os(iOS)` so it only runs on iOS
  - [ ] Verify that the `new == .active` branch on macOS still logs the return but does not clear navigation

- [ ] Task 2: Verify training screens handle idle state after external stop (AC: #4)
  - [ ] Check each training screen (PitchDiscrimination, PitchMatching, RhythmOffsetDetection, ContinuousRhythmMatching) renders correctly when session is stopped externally (goes from active → idle without user pressing stop)
  - [ ] Ensure no stale UI state (progress indicators, feedback overlays) persists after the session is stopped

- [ ] Task 3: Verify menu navigation (AC: #5)
  - [ ] Test that menu commands navigate correctly after a focus-loss/gain cycle
  - [ ] Test that the 50ms navigation workaround in ContentView still functions with a preserved navigation stack

- [ ] Task 4: Tests (AC: #1, #2, #3)
  - [ ] Update `TrainingLifecycleCoordinator` tests to verify macOS path stops session but does NOT call `clearNavigation`
  - [ ] Verify iOS path still calls both stop and clearNavigation

## Dev Notes

### The Change Is Small

The core fix is a single `#if os(iOS)` guard in `TrainingLifecycleCoordinator.handleScenePhase()`. Currently (lines 41–44):

```swift
if new == .active && (old == .background || old == .inactive) {
    Self.logger.info("App returned to active from \(String(describing: old)) — clearing navigation")
    clearNavigation()
}
```

After the change, the navigation clearing only runs on iOS:

```swift
if new == .active && (old == .background || old == .inactive) {
    Self.logger.info("App returned to active from \(String(describing: old))")
    #if os(iOS)
    clearNavigation()
    #endif
}
```

The session stop on `.inactive` (lines 30–39) remains unchanged for both platforms.

### Key Files

- `Peach/App/TrainingLifecycleCoordinator.swift` — the only file that needs code changes (lines 41–44)
- `Peach/App/ContentView.swift` — passes `clearNavigation` closure (line 31: `navigationPath.removeAll()`); no change needed but verify the integration
- `Peach/App/PeachApp.swift` — `trackActiveSession` and notification-based lifecycle; no changes needed

### Training Screen Idle States to Verify

Each training screen observes its session and renders based on state. When the session is stopped externally, it transitions to `idle`. Verify these screens show appropriate idle UI:

- `PitchDiscriminationScreen` — should show "Start" button when `session.state == .idle`
- `PitchMatchingScreen` — should show "Start" button when idle
- `RhythmOffsetDetectionScreen` — should show ready state when idle
- `ContinuousRhythmMatchingScreen` — should show ready state when idle

### What NOT to Change

- Session stop behavior on macOS `.inactive` — audio must still stop immediately
- iOS lifecycle behavior — backgrounding still clears navigation
- `AudioSessionInterruptionMonitor` — separate concern, not affected
- Menu command navigation in `ContentView` — the 50ms workaround is independent of this change

### References

- [Source: docs/implementation-artifacts/future-work.md#macOS App-Switch Behavior]
- [Source: Peach/App/TrainingLifecycleCoordinator.swift lines 30–44 — handleScenePhase]
- [Source: Peach/App/ContentView.swift lines 29–32 — onChange scenePhase + clearNavigation closure]
- [Source: Peach/App/PeachApp.swift lines 226–236 — trackActiveSession]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
