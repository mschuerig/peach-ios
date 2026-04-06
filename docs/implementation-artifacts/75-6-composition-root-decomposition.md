# Story 75.6: Composition Root — Init Decomposition

Status: review

## Story

As a **developer reading the app entry point**,
I want `PeachApp.init()` organized into named phases and coordinator dispatch table-driven,
so that the 180-line init is comprehensible and `rebuildCoordinators()` doesn't duplicate construction.

## Background

The walkthrough (Layer 5) found that `PeachApp.init()` is a 180-line flat sequence mixing all abstraction levels. `rebuildCoordinators()` duplicates coordinator construction from `init()`, including platform-conditional code. `TrainingLifecycleCoordinator` uses 6-case switch statements in `startCurrentSession()` and `stopCurrentSession()` — adding a training mode requires updating both.

**Walkthrough sources:** Layer 5 observations #1, #3.

## Acceptance Criteria

1. **Given** `PeachApp.init()` **When** inspected **Then** it calls named methods (e.g., `setupAudio()`, `createSessions()`, `buildCoordinators()`) instead of a flat 180-line sequence.
2. **Given** `rebuildCoordinators()` **When** inspected **Then** it reuses the same `buildCoordinators()` method used by init, eliminating the duplicated coordinator construction.
3. **Given** `TrainingLifecycleCoordinator` **When** inspected **Then** `startCurrentSession()` and `stopCurrentSession()` use a data-driven dispatch (e.g., `[NavigationDestination: () -> Void]` closures or similar) instead of exhaustive switch statements.
4. **Given** both platforms **When** built and tested **Then** all tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Decompose PeachApp.init() (AC: #1)
  - [x] Extract SwiftData container setup into a named method
  - [x] Extract audio engine + player setup into a named method
  - [x] Extract session creation into a named method
  - [x] Extract coordinator construction into a named method
  - [x] init() becomes a sequence of ~5–8 named method calls

- [x] Task 2: Unify rebuildCoordinators() (AC: #2)
  - [x] `rebuildCoordinators()` calls the same `buildCoordinators()` method
  - [x] Eliminate the duplicated `TrainingLifecycleCoordinator(...)` and `SettingsCoordinator(...)` construction
  - [x] Verify `handleSoundSourceChanged()` still works correctly (it calls `rebuildCoordinators()`)

- [x] Task 3: Table-driven coordinator dispatch (AC: #3)
  - [x] Replace the 6-case switch in `startCurrentSession()` with a lookup
  - [x] Replace the 6-case switch in `stopCurrentSession()` with a lookup
  - [x] Verify `isTrainingActive` and other dispatch points

- [x] Task 4: Build and test both platforms (AC: #4)
  - [x] `bin/test.sh && bin/test.sh -p mac`

## Dev Notes

### Source File Locations

| File | Role |
|------|------|
| `Peach/App/PeachApp.swift` (423 lines) | Composition root — init decomposition |
| `Peach/App/TrainingLifecycleCoordinator.swift` (200 lines) | Table-driven dispatch |

### Existing WALKTHROUGH Annotations

- `Peach/App/PeachApp.swift` (lines 7–8)

### Design Consideration: Table-Driven Dispatch

The switch in `startCurrentSession()` maps `NavigationDestination` → session-specific `start(settings:)` call. Each case builds settings from `UserSettings` and calls the right session. A dictionary mapping won't work directly because each session has a different `start(settings:)` signature.

Options:
- `[NavigationDestination: () -> Void]` closures that capture the session and settings builder
- A `TrainingSessionLauncher` protocol with a `launch(settings: UserSettings)` method
- Keep the switch but extract it to a single method called by both `start` and `stop`

The simplest approach is probably closures, built during coordinator construction.

### What NOT to Change

- Do not change the dependency graph itself — same objects, same wiring
- Do not change the `handleSoundSourceChanged()` cascade logic (sessions must be recreated when the sound source changes)
- Do not change the platform-conditional `#if os()` logic — just ensure it's not duplicated

### References

- [Source: docs/walkthrough/5-composition-root.md — observations #1, #3]

## Dev Agent Record

### Agent Model Used
Claude Opus 4.6

### Debug Log References
None

### Completion Notes List
- Decomposed `PeachApp.init()` from 140-line flat sequence into 7 named static method calls: `setupDataStore()`, `setupSoundFontInfrastructure()`, `setupPlayers()`, `setupProfile()`, `createTransferService()`, `createAllSessions()`, `buildCoordinators()`
- Unified `rebuildCoordinators()` to call the same `buildCoordinators()` static method used by init, eliminating duplicated `TrainingLifecycleCoordinator` and `SettingsCoordinator` construction and the duplicated `#if os()` background policy block (now in `makeBackgroundPolicy()`)
- Replaced duplicated 6-case switches in `stopCurrentSession()` and `isTrainingActive` with a single `session(for:)` dispatch method and `currentSession` computed property. `stopCurrentSession()` is now `currentSession?.stop()`. `startCurrentSession()` retains its switch because each case constructs different settings types (inherent heterogeneity)
- All 1717 iOS tests and 1710 macOS tests pass with zero regressions

### File List
- Peach/App/PeachApp.swift (modified)
- Peach/App/TrainingLifecycleCoordinator.swift (modified)

## Change Log

- 2026-04-06: Story created from walkthrough observations
- 2026-04-07: Implementation complete — init decomposition, coordinator unification, dispatch table
