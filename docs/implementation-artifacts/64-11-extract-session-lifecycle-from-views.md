# Story 64.11: Extract Session Lifecycle Orchestration from Views

Status: done

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

- [x] Task 1: Design the coordination pattern (AC: #1–#7)
  - [x] 1.1 Read `PeachApp.swift` — the composition root already owns all services. The pattern from `project-context.md`: "if a view needs to coordinate multiple services, wrap that coordination in a closure or method owned by the composition root and inject the closure; the view should call one thing, not three"
  - [x] 1.2 Decide: (a) inject closures for each action (e.g., `startTraining: (PitchDiscriminationSettings) -> Void`, `stopTraining: () -> Void`) via `@Environment`, or (b) create a lightweight coordinator per screen that the composition root configures
  - [x] 1.3 Choose the minimal approach — closures if the coordination is simple, coordinator if there are >3 related actions

- [x] Task 2: Extract training screen lifecycle (AC: #1, #4, #5)
  - [x] 2.1 For each of the 4 training screens: replace direct `session.start(settings:)` and `session.stop()` calls with the injected coordination mechanism
  - [x] 2.2 Move `PitchDiscriminationSettings.from(userSettings, intervals:)` (and equivalents) into the coordinator or factory
  - [x] 2.3 Move help-sheet stop/restart logic into the coordinator
  - [x] 2.4 Views should only: (a) read observable session state for rendering, (b) call injected actions for user interactions

- [x] Task 3: Extract `ContentView` app lifecycle logic (AC: #2, #3)
  - [x] 3.1 Move `handleAppBackgrounding()` and `handleAppForegrounding()` into a composition-root-owned coordinator or closure
  - [x] 3.2 `ContentView` calls the injected action from `onChange(of: scenePhase)` — one call, no branching logic

- [x] Task 4: Extract `SettingsScreen` orchestration (AC: #6, #7)
  - [x] 4.1 Create an import coordinator (or closure bundle) that owns the parse → validate → mode choice → execute flow
  - [x] 4.2 Move sound preview toggle/stop into an injected closure or service
  - [x] 4.3 Move data reset into an injected closure
  - [x] 4.4 `SettingsScreen` should only need: `userSettings` (or @AppStorage), `soundSourceProvider` (for picker), and the coordinator — at most 3 environment dependencies

- [x] Task 5: Write tests for coordinators (AC: #8)
  - [x] 5.1 Test training lifecycle coordinator: calling start invokes session.start with correct settings, calling stop invokes session.stop
  - [x] 5.2 Test app lifecycle coordinator: backgrounding stops active session, foregrounding clears navigation path
  - [x] 5.3 Test settings coordinator: import flow calls prepareImport then executeImport with correct mode

- [x] Task 6: Run full test suite (AC: #8)

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

## Dev Agent Record

### Implementation Plan

**Design decision (Task 1):** Closures for training screens (≤3 actions) and ContentView (2 actions); lightweight `SettingsCoordinator` class for SettingsScreen (>3 related actions: 5 methods).

**Training screens (Task 2):** Added 8 `@Entry` environment keys (start/stop per session type) in `EnvironmentKeys.swift`. Pitch start closures take `Set<DirectedInterval>` as parameter. Wired in `PeachApp.swift` — closures capture session + userSettings and construct settings internally. All 4 screens now call injected closures from `onAppear`, `onDisappear`, and `onChange(of: showHelpSheet)`.

**ContentView (Task 3):** Single `handleScenePhaseChange` closure taking `(old, new, clearNavigation)`. View calls one thing with zero branching. Coordinator decides when to stop session and when to clear navigation. Removed logger, helper methods, and `activeSession` dependency.

**SettingsScreen (Task 4):** Created `SettingsCoordinator` wrapping reset, sound preview play/stop, and import prepare/execute. Reduced `@Environment` deps from 7 to 3: `soundSourceProvider`, `trainingDataTransferService`, `settingsCoordinator`.

### Debug Log

No issues encountered. Build succeeded cleanly. All 1618 tests pass.

### Completion Notes

- `TrainingLifecycleCoordinator`: reference-based coordinator with required deps, `activeSession` var, and `handleScenePhase` method
- `SettingsCoordinator`: reference-based coordinator with required deps — encapsulates all settings actions including export/import formatting
- Both coordinators stored as `@State` in PeachApp — stable identity prevents unnecessary child re-renders
- SettingsScreen @Environment: 7 → 2 (soundSourceProvider + settingsCoordinator)
- ContentView: ~55 lines → ~18 lines

## File List

- `Peach/App/EnvironmentKeys.swift` — Replaced closure/service entries with 2 coordinator entries; preview factories use existing stubs
- `Peach/App/SettingsCoordinator.swift` — Coordinator wrapping all settings-related actions (reset, preview, import/export)
- `Peach/App/TrainingLifecycleCoordinator.swift` — **New** — Coordinator for session start/stop lifecycle and scene phase handling
- `Peach/App/PeachApp.swift` — Wired coordinators as `@State`, syncs activeSession to coordinator
- `Peach/App/ContentView.swift` — Replaced lifecycle logic with single coordinator call
- `Peach/PitchDiscrimination/PitchDiscriminationScreen.swift` — Uses `trainingLifecycle` coordinator for start/stop
- `Peach/PitchMatching/PitchMatchingScreen.swift` — Uses `trainingLifecycle` coordinator for start/stop
- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionScreen.swift` — Uses `trainingLifecycle` coordinator for start/stop
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingScreen.swift` — Uses `trainingLifecycle` coordinator for start/stop
- `Peach/Settings/SettingsScreen.swift` — Uses `settingsCoordinator` for all settings actions
- `PeachTests/App/SettingsCoordinatorTests.swift` — Tests for SettingsCoordinator using MockUserSettings
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift` — **New** — Tests for scene phase handling with MockTrainingSession
- `docs/implementation-artifacts/64-11-extract-session-lifecycle-from-views.md` — Story file updates
- `docs/implementation-artifacts/sprint-status.yaml` — Status: done

## Change Log

- 2026-03-28: Implemented story 64.11 — extracted session lifecycle orchestration from views into composition-root-owned closures and SettingsCoordinator
- 2026-03-28: Refactored to reference-based coordinators (findings 2 & 3) — replaced closure entries with stable `@State` coordinators, extracted DependencyGraphModifier
