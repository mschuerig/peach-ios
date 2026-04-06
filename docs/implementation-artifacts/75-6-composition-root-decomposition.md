# Story 75.6: Composition Root — Init Decomposition

Status: ready-for-dev

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

- [ ] Task 1: Decompose PeachApp.init() (AC: #1)
  - [ ] Extract SwiftData container setup into a named method
  - [ ] Extract audio engine + player setup into a named method
  - [ ] Extract session creation into a named method
  - [ ] Extract coordinator construction into a named method
  - [ ] init() becomes a sequence of ~5–8 named method calls

- [ ] Task 2: Unify rebuildCoordinators() (AC: #2)
  - [ ] `rebuildCoordinators()` calls the same `buildCoordinators()` method
  - [ ] Eliminate the duplicated `TrainingLifecycleCoordinator(...)` and `SettingsCoordinator(...)` construction
  - [ ] Verify `handleSoundSourceChanged()` still works correctly (it calls `rebuildCoordinators()`)

- [ ] Task 3: Table-driven coordinator dispatch (AC: #3)
  - [ ] Replace the 6-case switch in `startCurrentSession()` with a lookup
  - [ ] Replace the 6-case switch in `stopCurrentSession()` with a lookup
  - [ ] Verify `isTrainingActive` and other dispatch points

- [ ] Task 4: Build and test both platforms (AC: #4)
  - [ ] `bin/test.sh && bin/test.sh -p mac`

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
### Debug Log References
### Completion Notes List
### File List

## Change Log

- 2026-04-06: Story created from walkthrough observations
