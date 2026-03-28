# Story 66.4: macOS Haptic Feedback Abstraction

Status: done

## Story

As a **developer**,
I want the macOS build to have a valid `HapticFeedback` implementation,
so that the composition root can inject it on macOS without compilation errors or runtime crashes.

## Acceptance Criteria

1. **Given** the macOS build **When** `PeachApp` instantiates the haptic feedback provider **Then** it creates a macOS-appropriate implementation that compiles and runs without error.

2. **Given** the macOS haptic feedback implementation **When** `playIncorrectFeedback()` is called **Then** it silently no-ops (Mac hardware does not have a taptic engine suitable for training feedback).

3. **Given** the macOS haptic feedback implementation **When** it conforms to `PitchDiscriminationObserver` and `RhythmOffsetDetectionObserver` **Then** it handles callbacks without side effects.

4. **Given** the iOS build **When** built and tested **Then** the existing `HapticFeedbackManager` with `UIImpactFeedbackGenerator` is used unchanged.

5. **Given** the full test suite **When** run on iOS Simulator **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Guard existing `HapticFeedbackManager` for iOS only (AC: #4)
  - [x] 1.1 Wrap `HapticFeedbackManager.swift` content in `#if os(iOS)` (the file imports UIKit)

- [x] Task 2: Create macOS no-op implementation (AC: #1, #2, #3)
  - [x] 2.1 In the same file (or a new file in `PitchDiscrimination/`), add `#else` with a `NoOpHapticFeedbackManager` that conforms to `HapticFeedback`, `PitchDiscriminationObserver`, and `RhythmOffsetDetectionObserver`
  - [x] 2.2 All methods are empty bodies

- [x] Task 3: Wire in composition root (AC: #1)
  - [x] 3.1 In `PeachApp.swift`, use `#if os(iOS)` to instantiate the appropriate implementation
  - [x] 3.2 Both are injected into the observer arrays the same way

- [x] Task 4: Run full test suite (AC: #5)

## Dev Notes

### Design Decision: No-Op vs NSHapticFeedbackManager

macOS has `NSHapticFeedbackManager` for Force Touch trackpad feedback, but:
- Not all Macs have Force Touch trackpads (external keyboards, older MacBooks)
- Trackpad haptics are subtle alignment/level feedback, not the "buzz" training feedback Peach uses
- The training value comes from audio feedback, not haptics (haptics are supplementary)

A no-op is the correct choice. If users request trackpad haptics in the future, it can be added to the macOS implementation without changing the architecture.

### Architecture Already Supports This

`HapticFeedback` is a protocol defined in `Core/Ports/`. `HapticFeedbackManager` is a concrete implementation injected from `PeachApp.swift`. The protocol already isolates the platform dependency — this story just provides the macOS conformance.

### Source File Locations

| File | Path | Change |
|------|------|--------|
| HapticFeedbackManager | `Peach/PitchDiscrimination/HapticFeedbackManager.swift` | `#if os(iOS)` + macOS no-op |
| PeachApp | `Peach/App/PeachApp.swift` | Conditional instantiation |

## Dev Agent Record

### Implementation Plan
- Task 1.1 was already complete (file was pre-wrapped in `#if os(iOS)`)
- Added `NoOpHapticFeedbackManager` in `#else` block of same file with empty-body conformances
- Simplified PeachApp.swift: replaced conditional observer arrays with conditional instantiation of haptic manager, then unified observer arrays

### Completion Notes
- `NoOpHapticFeedbackManager` added as `#else` branch in `HapticFeedbackManager.swift`, conforming to `HapticFeedback`, `PitchDiscriminationObserver`, and `RhythmOffsetDetectionObserver` with empty method bodies
- PeachApp.swift simplified: both `createPitchDiscriminationSession` and `createRhythmOffsetDetectionSession` now use a single observer array with the platform-appropriate haptic manager, eliminating duplicated observer list construction
- 3 new macOS-only tests verify protocol conformance and no-crash behavior
- All 1645 iOS tests pass, all 1613 macOS tests pass

## File List

- `Peach/PitchDiscrimination/HapticFeedbackManager.swift` — Added `#else` block with `NoOpHapticFeedbackManager`
- `Peach/App/PeachApp.swift` — Simplified conditional haptic manager instantiation and unified observer arrays
- `PeachTests/PitchDiscrimination/HapticFeedbackManagerTests.swift` — Added 3 macOS-only tests for NoOpHapticFeedbackManager

## Change Log

- 2026-03-28: Implemented macOS no-op haptic feedback abstraction with tests and simplified composition root wiring
