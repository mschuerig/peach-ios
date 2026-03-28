# Story 66.3: Platform-Conditional Lifecycle Notifications

Status: review

## Story

As a **musician using Peach on macOS**,
I want training to stop when I switch away from the app,
so that incomplete exercises are discarded the same way they are on iOS.

## Acceptance Criteria

1. **Given** the macOS build **When** `PeachApp` creates training sessions **Then** it injects `NSApplication.didResignActiveNotification` as the background notification and `NSApplication.didBecomeActiveNotification` as the foreground notification.

2. **Given** the iOS build **When** `PeachApp` creates training sessions **Then** it continues to inject `UIApplication.didEnterBackgroundNotification` and `UIApplication.willEnterForegroundNotification` (no change from current behaviour).

3. **Given** an active training session on macOS **When** the user switches to another app (Cmd+Tab, click on another window) **Then** the session stops and returns to idle, discarding any incomplete exercise.

4. **Given** the app on macOS **When** the user switches back to Peach **Then** the Start Screen is shown (same behaviour as iOS foregrounding after backgrounding).

5. **Given** the full test suite **When** run on iOS Simulator **Then** all existing tests pass with zero regressions.

## Tasks / Subtasks

- [x] Task 1: Platform-conditional notification names in `PeachApp.swift` (AC: #1, #2)
  - [x] 1.1 Add `#if os(iOS)` / `#else` block where `UIApplication.didEnterBackgroundNotification` and `UIApplication.willEnterForegroundNotification` are referenced
  - [x] 1.2 On macOS, use `NSApplication.didResignActiveNotification` and `NSApplication.didBecomeActiveNotification`
  - [x] 1.3 Verify `import AppKit` is available on macOS (it is via SwiftUI)

- [x] Task 2: Verify `ContentView.scenePhase` works on macOS (AC: #3, #4)
  - [x] 2.1 Confirm `@Environment(\.scenePhase)` fires `.background` / `.active` transitions on macOS
  - [x] 2.2 If `scenePhase` behaves differently on macOS (some reports suggest it doesn't always fire `.background`), the notification-based approach provides the safety net

- [x] Task 3: Update test helpers if needed (AC: #5)
  - [x] 3.1 In `PitchMatchingSessionTests` factory method, the default notification names reference `UIApplication` — guard with `#if os(iOS)` or use custom names in tests

- [ ] Task 4: Manual test on macOS (AC: #3, #4)
  - [ ] 4.1 Start a training session, Cmd+Tab away — verify session stops
  - [ ] 4.2 Return to Peach — verify Start Screen shown

## Dev Notes

### Architecture Advantage

The notification names are already injected as parameters to `AudioSessionInterruptionMonitor` and passed through session creation in `PeachApp.swift`. This was done in story 20.7 to remove UIKit from `AudioSessionInterruptionMonitor`. The only change needed is in `PeachApp.swift` where the notification names originate.

### macOS vs iOS Lifecycle Mapping

| iOS Notification | macOS Equivalent | SwiftUI scenePhase |
|-----------------|------------------|--------------------|
| `UIApplication.didEnterBackgroundNotification` | `NSApplication.didResignActiveNotification` | `.inactive` / `.background` |
| `UIApplication.willEnterForegroundNotification` | `NSApplication.didBecomeActiveNotification` | `.active` |

Note: macOS `didResignActiveNotification` fires when the app loses focus (not just when minimised), which is slightly more aggressive than iOS backgrounding. This is acceptable for Peach — stopping training when the user switches away is the safe default.

### Source File Locations

| File | Path | Change |
|------|------|--------|
| PeachApp | `Peach/App/PeachApp.swift:329-330` | Platform-conditional notification names |

## Dev Agent Record

### Implementation Plan

- Replace `nil` macOS notification names in `PeachApp.swift` with `NSApplication.didResignActiveNotification` and `NSApplication.didBecomeActiveNotification`
- Add macOS-specific tests for `AudioSessionInterruptionMonitor` and `PitchMatchingSession` lifecycle
- Fix pre-existing macOS test compilation issues (Boy Scout Rule): guard `AVAudioSession`-dependent test suites and `HapticFeedbackManager` tests with `#if os(iOS)`

### Completion Notes

- ✅ Replaced `nil` macOS notification names with `NSApplication.didResignActiveNotification` / `NSApplication.didBecomeActiveNotification` in `PeachApp.swift`
- ✅ `scenePhase` handling already wired in `ContentView` via `TrainingLifecycleCoordinator` — no changes needed
- ✅ Added 3 macOS tests for `AudioSessionInterruptionMonitor` (resignActive, becomeActive, nil-disabled)
- ✅ Added 4 macOS tests for `PitchMatchingSession` lifecycle (stop from playingTunable, awaitingSliderTouch, idle safety, restart)
- ✅ Boy Scout: Wrapped `PitchMatchingSessionAudioInterruptionTests` suite in `#if os(iOS)` (was unguarded, used `AVAudioSession`)
- ✅ Boy Scout: Wrapped `HapticFeedbackManagerTests` in `#if os(iOS)` (referenced iOS-only `HapticFeedbackManager`)
- ✅ All tests pass: iOS 1645, macOS 1610
- Task 4 (manual macOS test) left unchecked — requires manual testing by developer

## File List

- `Peach/App/PeachApp.swift` — Changed `nil` to macOS notification names in `#else` block
- `PeachTests/PitchMatching/PitchMatchingSessionTests.swift` — Added `import AppKit` for macOS, wrapped audio interruption suite in `#if os(iOS)`, added macOS lifecycle test suite
- `PeachTests/Core/Audio/AudioSessionInterruptionMonitorTests.swift` — Added `#if os(macOS)` test suite for NSApplication notifications
- `PeachTests/PitchDiscrimination/HapticFeedbackManagerTests.swift` — Wrapped in `#if os(iOS)`

## Change Log

- 2026-03-28: Implemented platform-conditional lifecycle notifications for macOS; added macOS-specific tests; fixed pre-existing macOS test compilation issues
