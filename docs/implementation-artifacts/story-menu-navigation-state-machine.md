# Story: Menu Navigation State Machine

Status: draft

## Story

As a macOS user navigating between training modes via the menu bar,
I want screen transitions to be reliable without timing hacks,
so that playback doesn't break and navigation works on any device speed.

## Background

When macOS menu commands navigate between training screens, the departing screen's `onDisappear` fires *after* the arriving screen's `onAppear`. Both screens share the same `NotePlayer`/`StepSequencer`, so the old screen's teardown kills playback that the new screen just started.

The current workaround in `ContentView` (lines 45–52):
```swift
.onChange(of: commandState.navigationRequest) {
    guard let request = commandState.navigationRequest else { return }
    navigationPath.removeAll()
    Task {
        try? await Task.sleep(for: .milliseconds(50))
        navigationPath = [request.destination]
    }
}
```

This is fragile — the 50ms delay is a guess, and a slower device or heavier view hierarchy could break it. The sequencing logic lives in the view instead of a model.

**Source:** future-work.md "Menu Navigation State Machine"

## Acceptance Criteria

1. **No timing-dependent delays:** The 50ms `Task.sleep` workaround is removed. Navigation transitions must be sequenced deterministically, not by guessing a safe delay.

2. **Old session stopped before new screen appears:** When a menu command navigates from training screen A to training screen B, screen A's session must be fully stopped before screen B's navigation push occurs. No race between `onDisappear` teardown and `onAppear` setup.

3. **Sequencing logic lives in a model:** The stop → await idle → navigate sequence is coordinated by `TrainingLifecycleCoordinator` (or a new dedicated coordinator), not by view code in `ContentView`.

4. **Direct navigation works:** Navigating from StartScreen to a training screen (no departing session) must work without unnecessary delays.

5. **Same-destination navigation works:** If the user selects the same training mode they're already on via the menu, the session is restarted cleanly (stop → idle → restart).

6. **iOS unaffected:** Menu navigation is macOS-only (`#if os(macOS)`). No changes to iOS navigation flow.

7. **Existing tests pass:** All lifecycle and navigation-related tests continue to pass. New tests verify the sequenced navigation.

## Tasks / Subtasks

- [ ] Task 1: Add navigation coordination to `TrainingLifecycleCoordinator` (AC: #2, #3)
  - [ ] Add a method like `navigate(to: NavigationDestination, updatePath: @escaping ([NavigationDestination]) -> Void)`
  - [ ] The method: (1) stops the active session if any, (2) waits for `activeSession?.isIdle == true`, (3) calls `updatePath` with the new destination
  - [ ] Use a polling loop with short async yield (e.g., `Task.yield()` or check on next run loop) instead of a fixed sleep — the session `stop()` is synchronous-to-near-synchronous, so idle should be immediate or within one run loop cycle

- [ ] Task 2: Replace the workaround in `ContentView` (AC: #1, #3, #6)
  - [ ] In the `.onChange(of: commandState.navigationRequest)` handler, call the coordinator's navigate method instead of the manual clear + sleep + push
  - [ ] The coordinator handles the sequencing; the view just provides the path update closure

- [ ] Task 3: Handle edge cases (AC: #4, #5)
  - [ ] Direct navigation (no active session): coordinator detects `activeSession == nil`, skips the stop/wait, navigates immediately
  - [ ] Same-destination: coordinator stops the current session, waits for idle, then pushes the same destination (forces a fresh `onAppear`)

- [ ] Task 4: Tests (AC: #7)
  - [ ] Test: navigate with no active session → immediate path update
  - [ ] Test: navigate with active session → session stopped, then path updated
  - [ ] Test: navigate to same destination → session restarted
  - [ ] Test: rapid sequential navigation requests → only the last destination wins

## Dev Notes

### Why the 50ms Hack Exists

SwiftUI's `NavigationStack` fires `onDisappear` of the old view *after* `onAppear` of the new view when replacing the path. The shared `NotePlayer` means:

1. Menu command fires → path cleared → new destination pushed
2. New screen's `onAppear` starts a new session → audio begins
3. Old screen's `onDisappear` stops its session → kills the shared audio

The 50ms sleep gives the old view time to disappear before the new view appears. The real fix is to ensure the old session is stopped *before* the new destination is pushed.

### Design Approach

The coordinator already holds `activeSession` and all session references. Adding navigation coordination here is natural:

```
Menu command → NavigationRequest → Coordinator.navigate(to:updatePath:)
  1. activeSession?.stop()
  2. await activeSession == nil (observed via trackActiveSession)
  3. updatePath([destination])
```

The key insight: `session.stop()` is synchronous — it sets state to `.idle` immediately. `trackActiveSession` in `PeachApp` then sets `activeSession = nil` via the `onChange(of: session.isIdle)` observer. So the wait is at most one SwiftUI observation cycle, not a time-based guess.

### Alternative: Check `isIdle` Directly

Instead of waiting for `activeSession` to become nil (which depends on the observation chain in PeachApp), the coordinator could check the session's `isIdle` directly after calling `stop()`:

```swift
activeSession?.stop()
// stop() is synchronous — isIdle is already true
updatePath([destination])
```

If `stop()` guarantees synchronous transition to idle (which the state machine docs suggest), no waiting is needed at all — the workaround may reduce to just "stop, then navigate" without any async gap.

### Key Files

- `Peach/App/TrainingLifecycleCoordinator.swift` — add `navigate(to:updatePath:)` method
- `Peach/App/ContentView.swift` — lines 45–52: replace the workaround with coordinator call
- `Peach/App/PeachCommands.swift` — `NavigationRequest`, `MenuCommandState` (no changes expected)
- `Peach/App/PeachApp.swift` — `trackActiveSession` (verify stop → nil propagation timing)

### What NOT to Change

- `PeachCommands` menu structure — commands still produce `NavigationRequest` as today
- `NavigationDestination` enum — no changes needed
- iOS navigation — this is macOS-only, gated by `#if os(macOS)`
- Session state machines — `stop()` behavior is unchanged
- The `onDisappear`/`onAppear` handlers in training screens — they continue to work as before, but the race is eliminated because the old screen disappears before the new one appears

### References

- [Source: docs/implementation-artifacts/future-work.md#Menu Navigation State Machine]
- [Source: Peach/App/ContentView.swift lines 45–52 — current workaround]
- [Source: Peach/App/TrainingLifecycleCoordinator.swift — handleScenePhase, activeSession]
- [Source: Peach/App/PeachCommands.swift — NavigationRequest, MenuCommandState]
- [Source: Peach/App/PeachApp.swift lines 226–236 — trackActiveSession]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
