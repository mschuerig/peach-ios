# Story 68.6: Menu Navigation State Machine — Reliable Screen Transitions

Status: ready-for-dev

## Story

As a **macOS user navigating via the menu bar**,
I want screen transitions to be reliable without timing hacks,
so that playback doesn't break on any device speed.

## Acceptance Criteria

1. **Given** a menu command navigating between training screens **When** the old session is active **Then** it is stopped and confirmed idle before the new destination is pushed.

2. **Given** the navigation sequencing **When** implemented **Then** no `Task.sleep` or fixed-delay workarounds are used.

3. **Given** the sequencing logic **When** examined **Then** it lives in a model (coordinator), not in view code.

4. **Given** navigation from Start Screen (no active session) **When** triggered **Then** it navigates immediately with no unnecessary delay.

5. **Given** rapid sequential menu commands **When** processed **Then** only the last destination wins.

6. **Given** the full test suite **When** run on both platforms **Then** all tests pass.

## Tasks / Subtasks

- [ ] Task 1: Design navigation coordinator (AC: #1, #2, #3)
  - [ ] 1.1 Add a `navigate(to:)` async method on `TrainingLifecycleCoordinator` (or a new focused coordinator) that: stops the active session if any, awaits idle confirmation, then publishes the new destination
  - [ ] 1.2 The idle confirmation must be event-driven (observe `isIdle` becoming true), not a `Task.sleep` poll
  - [ ] 1.3 If no active session, publish the destination immediately (AC: #4)

- [ ] Task 2: Handle rapid sequential commands (AC: #5)
  - [ ] 2.1 Track the in-flight navigation task; when a new `navigate(to:)` arrives, cancel the previous task
  - [ ] 2.2 Only the last destination survives -- intermediate destinations are never pushed

- [ ] Task 3: Wire into `ContentView` and `PeachCommands` (AC: #3)
  - [ ] 3.1 Replace the current `Task.sleep(for: .milliseconds(50))` workaround in `ContentView.swift` (line 48-51) with a call to the coordinator's `navigate(to:)` method
  - [ ] 3.2 The coordinator publishes the resolved destination; `ContentView` observes it and updates `navigationPath`
  - [ ] 3.3 `PeachCommands.navigate(to:)` continues to set `commandState.navigationRequest` -- the view layer picks it up and delegates to the coordinator

- [ ] Task 4: Tests (AC: #6)
  - [ ] 4.1 Test: navigate with no active session pushes destination immediately
  - [ ] 4.2 Test: navigate with active session stops session and pushes destination only after idle
  - [ ] 4.3 Test: rapid sequential navigations -- only final destination is pushed
  - [ ] 4.4 Test: cancellation of in-flight navigation does not leave stale state
  - [ ] 4.5 Run `bin/test.sh && bin/test.sh -p mac`

## Pre-Existing Finding: iOS Inactive-to-Active Clears Navigation with Running Session

Surfaced during story 68.5 code review. On iOS, `IOSBackgroundPolicy.shouldClearNavigation` returns `true` for `inactive -> active`, but `shouldStopTraining` returns `false` for `.inactive`. This means a transient interruption (notification center pull-down) clears navigation to the Start Screen while the session continues running underneath. The coordinator redesign in this story should address this inconsistency — either by stopping the session before clearing navigation, or by not clearing navigation on transient `inactive -> active` transitions (only on `background -> active`).

## Dev Notes

### Current Implementation -- The Problem

In `ContentView.swift` (line 45-52), menu navigation uses a `Task.sleep` workaround:

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

This clears navigation, waits 50 ms (hoping the old screen's session has stopped), then pushes the new destination. Problems:
- The 50 ms delay is arbitrary -- on slow devices it may not be enough; on fast devices it is wasted time.
- No actual confirmation that the old session has stopped.
- Rapid menu commands can race: the first sleep completes and pushes a destination that is immediately overwritten by the second command's `removeAll()`.

### Design: Event-Driven Idle Confirmation

The key insight is that all sessions are `@Observable` and expose `isIdle: Bool`. The coordinator can:

1. Call `activeSession?.stop()`
2. If the session was active, use `withObservationTracking` or an async stream / continuation to await `isIdle == true`
3. Publish the new destination

Since `stop()` is synchronous on all session types (it sets state immediately and cancels async work), `isIdle` should become true on the same MainActor turn. In practice this means step 2 may resolve immediately without any actual waiting. But the event-driven approach is correct regardless -- it handles any future session that needs async cleanup.

### `MenuCommandState` and `NavigationRequest`

`PeachCommands.swift` defines:
- `NavigationRequest` -- wraps a `NavigationDestination` + unique UUID for `Equatable` identity
- `MenuCommandState` -- `@Observable` class with `navigationRequest`, `helpSheetContent`, etc.
- `PeachCommands` sets `commandState?.navigationRequest` on menu actions

The coordinator should own the navigation resolution logic. `ContentView` should observe the coordinator's resolved destination, not the raw `navigationRequest`.

### Rapid Command Handling

Track the current navigation `Task`. When a new command arrives:
1. Cancel the in-flight task (if any)
2. Start a new task that stops the session and navigates
3. The cancelled task's `withTaskCancellationHandler` (or `Task.isCancelled` check) ensures it does not push its destination

### Project Structure Notes

- Modified: `Peach/App/TrainingLifecycleCoordinator.swift` -- add `navigate(to:)` async method
- Modified: `Peach/App/ContentView.swift` -- replace Task.sleep workaround with coordinator-driven navigation
- Possibly modified: `Peach/App/PeachCommands.swift` -- minimal changes, still sets navigationRequest
- New/modified tests: `PeachTests/App/TrainingLifecycleCoordinatorTests.swift`

### References

- [Source: Peach/App/ContentView.swift lines 45-52 -- Task.sleep(for: .milliseconds(50)) workaround for menu navigation]
- [Source: Peach/App/PeachCommands.swift -- NavigationRequest, MenuCommandState, PeachCommands.navigate(to:)]
- [Source: Peach/App/TrainingLifecycleCoordinator.swift -- handleScenePhase, activeSession, stop methods]
- [Source: Peach/App/NavigationDestination.swift -- enum with 6 cases]
- [Source: PeachTests/App/TrainingLifecycleCoordinatorTests.swift -- MockTrainingSession with stopCallCount]

## Dev Agent Record

### Agent Model Used
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-03-29: Story created
