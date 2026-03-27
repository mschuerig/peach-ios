# Story 64.11: Extract Session Lifecycle Orchestration from Views

Status: ready-for-dev

## Story

As a **developer maintaining Peach**,
I want views to contain zero business logic — including session start/stop orchestration —
so that the project's own architectural rules are enforced and training lifecycle is testable without SwiftUI.

## Acceptance Criteria

1. **Given** the 4 training screens (`PitchDiscriminationScreen`, `PitchMatchingScreen`, `RhythmOffsetDetectionScreen`, `ContinuousRhythmMatchingScreen`) **When** reviewed after this story **Then** none of them call `session.start(settings:)` or `session.stop()` directly — lifecycle orchestration is delegated to an injected coordinator or closure.

2. **Given** `ContentView` **When** the app is backgrounded **Then** the active session is stopped by a coordinator or composition-root-owned closure, not by logic in the view.

3. **Given** `ContentView` **When** the app is foregrounded after backgrounding **Then** navigation reset (returning to Start Screen) is handled by the same coordinator, not by the view.

4. **Given** training screen help sheet display **When** the help sheet is shown or dismissed **Then** session stop/restart is handled by the coordinator, not by `onChange(of: showHelpSheet)` in the view.

5. **Given** settings transformation (`PitchDiscriminationSettings.from(userSettings, intervals:)` etc.) **When** a training session is started **Then** the transformation happens in the coordinator or factory, not repeated in each view's `onAppear`.

6. **Given** `SettingsScreen` **When** reviewed after this story **Then** import orchestration (parse → validate → mode choice → execute), data reset, and sound preview playback are delegated to injected services or closures — the view calls one thing per action, not three.

7. **Given** `SettingsScreen` `@Environment` dependencies **When** counted **Then** the view has at most 3 direct environment dependencies (down from 7), because orchestration dependencies are owned by the coordinator.

8. **Given** the full test suite **When** run **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [ ] Task 1: Design the coordination pattern (AC: #1–#7)
  - [ ] 1.1 Read `PeachApp.swift` — the composition root already owns all services. The pattern from `project-context.md`: "if a view needs to coordinate multiple services, wrap that coordination in a closure or method owned by the composition root and inject the closure; the view should call one thing, not three"
  - [ ] 1.2 Decide: (a) inject closures for each action (e.g., `startTraining: (PitchDiscriminationSettings) -> Void`, `stopTraining: () -> Void`) via `@Environment`, or (b) create a lightweight coordinator per screen that the composition root configures
  - [ ] 1.3 Choose the minimal approach — closures if the coordination is simple, coordinator if there are >3 related actions

- [ ] Task 2: Extract training screen lifecycle (AC: #1, #4, #5)
  - [ ] 2.1 For each of the 4 training screens: replace direct `session.start(settings:)` and `session.stop()` calls with the injected coordination mechanism
  - [ ] 2.2 Move `PitchDiscriminationSettings.from(userSettings, intervals:)` (and equivalents) into the coordinator or factory
  - [ ] 2.3 Move help-sheet stop/restart logic into the coordinator
  - [ ] 2.4 Views should only: (a) read observable session state for rendering, (b) call injected actions for user interactions

- [ ] Task 3: Extract `ContentView` app lifecycle logic (AC: #2, #3)
  - [ ] 3.1 Move `handleAppBackgrounding()` and `handleAppForegrounding()` into a composition-root-owned coordinator or closure
  - [ ] 3.2 `ContentView` calls the injected action from `onChange(of: scenePhase)` — one call, no branching logic

- [ ] Task 4: Extract `SettingsScreen` orchestration (AC: #6, #7)
  - [ ] 4.1 Create an import coordinator (or closure bundle) that owns the parse → validate → mode choice → execute flow
  - [ ] 4.2 Move sound preview toggle/stop into an injected closure or service
  - [ ] 4.3 Move data reset into an injected closure
  - [ ] 4.4 `SettingsScreen` should only need: `userSettings` (or @AppStorage), `soundSourceProvider` (for picker), and the coordinator — at most 3 environment dependencies

- [ ] Task 5: Write tests for coordinators (AC: #8)
  - [ ] 5.1 Test training lifecycle coordinator: calling start invokes session.start with correct settings, calling stop invokes session.stop
  - [ ] 5.2 Test app lifecycle coordinator: backgrounding stops active session, foregrounding clears navigation path
  - [ ] 5.3 Test settings coordinator: import flow calls prepareImport then executeImport with correct mode

- [ ] Task 6: Run full test suite (AC: #8)

## Dev Notes

### What Views Currently Do Wrong

**Training screens (all 4):**
```swift
.onAppear {
    session.start(settings: .from(userSettings, intervals: intervals))
}
.onDisappear {
    session.stop()
}
.onChange(of: showHelpSheet) { _, isShowing in
    if isShowing { session.stop() }
    else { session.start(settings: .from(userSettings, intervals: intervals)) }
}
```

This is business logic: "when help is shown, stop training; when dismissed, restart with current settings." The view should call `coordinator.helpSheetChanged(isShowing:)` and the coordinator decides what to do.

**ContentView:**
```swift
private func handleAppBackgrounding() {
    activeSession?.stop()
}
private func handleAppForegrounding() {
    if !navigationPath.isEmpty { navigationPath.removeAll() }
}
```

App lifecycle policy belongs in a coordinator. The view should call `coordinator.scenePhaseChanged(to: newPhase)`.

**SettingsScreen (7 @Environment + orchestration):**
- `dataStoreResetter`, `soundPreviewPlay`, `soundPreviewStop`, `prepareImport`, `executeImport`, `trainingDataTransferService`, `soundSourceProvider`
- The view owns the entire import flow (parse → mode choice → execute → summary display)
- Sound preview lifecycle management (task creation, cancellation)

### Recommended Pattern

Use the existing pattern from `project-context.md`: inject closures from the composition root.

```swift
// In EnvironmentKeys.swift
@Entry var startPitchDiscrimination: (Set<DirectedInterval>) -> Void = { _ in }
@Entry var stopPitchDiscrimination: () -> Void = { }

// In PeachApp.swift
.environment(\.startPitchDiscrimination) { [weak pitchDiscriminationSession, weak userSettings] intervals in
    guard let session = pitchDiscriminationSession, let settings = userSettings else { return }
    session.start(settings: .from(settings, intervals: intervals))
}
```

This keeps the composition root as the single place where services are wired, and views call one injected closure per action.

### Source File Locations

| File | Path |
|------|------|
| PitchDiscriminationScreen | `Peach/PitchDiscrimination/PitchDiscriminationScreen.swift` |
| PitchMatchingScreen | `Peach/PitchMatching/PitchMatchingScreen.swift` |
| RhythmOffsetDetectionScreen | `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift` |
| ContinuousRhythmMatchingScreen | `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` |
| ContentView | `Peach/App/ContentView.swift` |
| SettingsScreen | `Peach/Settings/SettingsScreen.swift` |
| PeachApp | `Peach/App/PeachApp.swift` |
| EnvironmentKeys | `Peach/App/EnvironmentKeys.swift` |

### References

- [Source: docs/project-context.md] — "Views must not orchestrate services", "minimize @Environment surface"
- [Source: Peach/PitchDiscrimination/PitchDiscriminationScreen.swift] — Direct session.start/stop calls
- [Source: Peach/Settings/SettingsScreen.swift:38-44] — 7 @Environment dependencies
- [Source: Peach/App/ContentView.swift:36-54] — App lifecycle logic in view
