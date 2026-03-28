# Story 66.4: macOS Haptic Feedback Abstraction

Status: draft

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

- [ ] Task 1: Guard existing `HapticFeedbackManager` for iOS only (AC: #4)
  - [ ] 1.1 Wrap `HapticFeedbackManager.swift` content in `#if os(iOS)` (the file imports UIKit)

- [ ] Task 2: Create macOS no-op implementation (AC: #1, #2, #3)
  - [ ] 2.1 In the same file (or a new file in `PitchDiscrimination/`), add `#else` with a `NoOpHapticFeedbackManager` that conforms to `HapticFeedback`, `PitchDiscriminationObserver`, and `RhythmOffsetDetectionObserver`
  - [ ] 2.2 All methods are empty bodies

- [ ] Task 3: Wire in composition root (AC: #1)
  - [ ] 3.1 In `PeachApp.swift`, use `#if os(iOS)` to instantiate the appropriate implementation
  - [ ] 3.2 Both are injected into the observer arrays the same way

- [ ] Task 4: Run full test suite (AC: #5)

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
