# Story 67.1: Push Platform Behavior Behind Protocol Ports

Status: review

## Story

As a **developer**,
I want platform-divergent behavior abstracted behind protocols in `Core/Ports/`,
so that `Core/` files and business logic contain zero `#if os` macros and platform behavior is testable through injection.

## Acceptance Criteria

1. **BackgroundPolicy protocol** -- `TrainingLifecycleCoordinator` delegates stop decisions to an injected `BackgroundPolicy` with no `#if os` in the coordinator. iOS policy: stop on background only. macOS policy: stop on background or inactive.

2. **AudioSessionConfiguring protocol** -- `SoundFontEngine` delegates audio session setup to an injected `AudioSessionConfiguring` with no `#if os` in the engine. iOS: configures AVAudioSession. macOS: no-op with log.

3. **AudioInterruptionObserving protocol** -- `AudioSessionInterruptionMonitor` delegates iOS-specific interruption/route-change observers to an injected `AudioInterruptionObserving` with no `#if os` in the monitor.

4. **PlatformNotifications** -- `PeachApp.swift` uses a centralized `PlatformNotifications` enum for background/foreground notification names instead of inline `#if os`.

5. **PlatformImage** -- `ChartImageRenderer` delegates PNG encoding to a centralized `PlatformImage` helper with no `#if os` in the renderer.

6. **HapticFeedbackManager split** -- iOS and macOS haptic implementations live in separate files under `App/Platform/`.

7. **Core/ clean** -- Zero `#if os` occurrences in any `Core/` file.

8. **Testability** -- Both `BackgroundPolicy` implementations tested on both platforms (no `#if os` in test assertions). `AudioSessionInterruptionMonitor` tests use a mock observer.

9. **No regressions** -- Full test suite passes on both iOS and macOS.

## Tasks / Subtasks

- [x] Task 1: Create `App/Platform/` directory and `BackgroundPolicy` abstraction (AC: #1, #8)
  - [x] 1.1 Create `Core/Ports/BackgroundPolicy.swift` protocol
  - [x] 1.2 Create `App/Platform/IOSBackgroundPolicy.swift` (unconditional)
  - [x] 1.3 Create `App/Platform/MacOSBackgroundPolicy.swift` (unconditional)
  - [x] 1.4 Add `backgroundPolicy` param to `TrainingLifecycleCoordinator.init`, remove `#if os`
  - [x] 1.5 Wire in `PeachApp.swift` with `#if os` selection at composition root
  - [x] 1.6 Update `TrainingLifecycleCoordinatorTests` -- remove `#if os` blocks, inject specific policies
  - [x] 1.7 Add `BackgroundPolicyTests.swift`

- [x] Task 2: Create `AudioSessionConfiguring` abstraction (AC: #2)
  - [x] 2.1 Create `Core/Ports/AudioSessionConfiguring.swift` protocol
  - [x] 2.2 Create `App/Platform/IOSAudioSessionConfigurator.swift` (`#if os(iOS)` file-level)
  - [x] 2.3 Create `App/Platform/MacOSAudioSessionConfigurator.swift` (`#if os(macOS)` file-level)
  - [x] 2.4 Add `audioSessionConfigurator` param to `SoundFontEngine.init`, replace `Self.configureAudioSession()` calls
  - [x] 2.5 Wire in `PeachApp.swift`

- [x] Task 3: Create `AudioInterruptionObserving` abstraction (AC: #3)
  - [x] 3.1 Create `Core/Ports/AudioInterruptionObserving.swift` protocol
  - [x] 3.2 Create `App/Platform/IOSAudioInterruptionObserver.swift` (`#if os(iOS)` file-level) -- move interruption + route change logic from AudioSessionInterruptionMonitor
  - [x] 3.3 Create `App/Platform/NoOpAudioInterruptionObserver.swift` (no guard)
  - [x] 3.4 Refactor `AudioSessionInterruptionMonitor` to accept and delegate to `AudioInterruptionObserving`
  - [x] 3.5 Wire in `PeachApp.swift`
  - [x] 3.6 Update `AudioSessionInterruptionMonitorTests` -- use mock observer

- [x] Task 4: Centralize platform notification names (AC: #4)
  - [x] 4.1 Create `App/Platform/PlatformNotifications.swift`
  - [x] 4.2 Update `PeachApp.swift` to use `PlatformNotifications.background` / `.foreground`

- [x] Task 5: Centralize platform image encoding (AC: #5)
  - [x] 5.1 Create `App/Platform/PlatformImage.swift`
  - [x] 5.2 Update `ChartImageRenderer.pngData` to delegate to `PlatformImage`

- [x] Task 6: Split HapticFeedbackManager (AC: #6)
  - [x] 6.1 Create `App/Platform/HapticFeedbackManager.swift` with iOS implementation (`#if os(iOS)`)
  - [x] 6.2 Create `App/Platform/NoOpHapticFeedbackManager.swift` (no guard)
  - [x] 6.3 Delete `PitchDiscrimination/HapticFeedbackManager.swift`
  - [x] 6.4 Update `HapticFeedbackManagerTests` imports

- [x] Task 7: Verify and run tests (AC: #7, #9)
  - [x] 7.1 `bin/check-dependencies.sh` -- Core/ stays framework-free
  - [x] 7.2 `bin/test.sh && bin/test.sh -p mac` -- all tests pass

## Dev Notes

### Critical Design Decisions

- **BackgroundPolicy uses ScenePhase directly** -- The protocol imports SwiftUI for `ScenePhase`. This is acceptable because the protocol lives in `Core/Ports/` which defines interfaces, not implementations. However, if this violates the "no SwiftUI in Core/" rule, an alternative is to use a raw enum. Decision: check `bin/check-dependencies.sh` and adjust if needed.

- **SoundFontEngine.configureAudioSession is currently `private static`** -- Called at lines 188 and 323. Refactoring to instance method that delegates to injected protocol. The two call sites become `audioSessionConfigurator.configure()`.

- **AudioSessionInterruptionMonitor keeps its cross-platform logic** -- The background/foreground notification observers (lines 78-100) are already platform-agnostic (parameterized by notification name). Only the iOS-specific AVAudioSession observers (lines 54-76, 105-141) move behind the protocol.

- **File-level `#if os` on leaf implementations is acceptable** -- `IOSAudioSessionConfigurator.swift` must guard with `#if os(iOS)` because it imports `AVAudioSession` which doesn't exist on macOS. This is the "leaf node" pattern -- the macro is at the boundary, not in business logic.

### Architecture & Integration

**New files:**
- `Peach/Core/Ports/BackgroundPolicy.swift`
- `Peach/Core/Ports/AudioSessionConfiguring.swift`
- `Peach/Core/Ports/AudioInterruptionObserving.swift`
- `Peach/App/Platform/IOSBackgroundPolicy.swift`
- `Peach/App/Platform/MacOSBackgroundPolicy.swift`
- `Peach/App/Platform/IOSAudioSessionConfigurator.swift`
- `Peach/App/Platform/MacOSAudioSessionConfigurator.swift`
- `Peach/App/Platform/IOSAudioInterruptionObserver.swift`
- `Peach/App/Platform/NoOpAudioInterruptionObserver.swift`
- `Peach/App/Platform/PlatformNotifications.swift`
- `Peach/App/Platform/PlatformImage.swift`
- `Peach/App/Platform/HapticFeedbackManager.swift`
- `Peach/App/Platform/NoOpHapticFeedbackManager.swift`

**Modified files:**
- `Peach/App/TrainingLifecycleCoordinator.swift` -- inject BackgroundPolicy, remove `#if os`
- `Peach/Core/Audio/SoundFontEngine.swift` -- inject AudioSessionConfiguring, remove `#if os`
- `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift` -- inject AudioInterruptionObserving, remove `#if os`
- `Peach/Profile/ChartImageRenderer.swift` -- delegate to PlatformImage
- `Peach/App/PeachApp.swift` -- wire all new protocols, use PlatformNotifications

**Deleted files:**
- `Peach/PitchDiscrimination/HapticFeedbackManager.swift`

### Existing Code to Reference

- **`HapticFeedback.swift`** -- existing protocol pattern in Core/Ports/. [Source: Peach/Core/Ports/HapticFeedback.swift]
- **`PeachApp.swift`** -- composition root wiring pattern. [Source: Peach/App/PeachApp.swift]
- **`EnvironmentKeys.swift`** -- `@Entry` injection pattern. [Source: Peach/App/EnvironmentKeys.swift]

### Testing Approach

- **BackgroundPolicyTests** -- unit tests for both policies, unconditional (no `#if os`)
- **TrainingLifecycleCoordinatorTests** -- inject specific policies instead of relying on compile-time selection
- **AudioSessionInterruptionMonitorTests** -- inject MockAudioInterruptionObserver
- **IOSAudioInterruptionObserverTests** -- iOS-only test file for the concrete observer

### References

- [Source: docs/planning-artifacts/epics.md -- Epic 67: Platform Ports]
- [Source: docs/implementation-artifacts/66-4-macos-haptic-feedback-abstraction.md -- pattern reference]

## Dev Agent Record

### Completion Notes

- Created `AppScenePhase` enum in Core/ as a SwiftUI-free mirror of `ScenePhase`, avoiding SwiftUI import in Core/Ports/. Conversion extension lives in App/ layer.
- `IOSAudioInterruptionObserver` implemented as `final class` (not struct) to support `[weak self]` capture in notification closures and callback retention across the observer's lifetime.
- Each training session creates its own `IOSAudioInterruptionObserver` instance via factory method `makeAudioInterruptionObserver()` in `PeachApp.swift`, because each session stores a session-specific `onStopRequired` callback.
- `AudioSessionInterruptionMonitor` retains the `AudioInterruptionObserving` instance as a stored property to prevent premature deallocation of the observer (and its `[weak self]` closures).
- All four session types (PitchDiscrimination, PitchMatching, RhythmOffsetDetection, ContinuousRhythmMatching) updated to accept and pass through `audioInterruptionObserver`.
- Test helpers default `audioInterruptionObserver` to `NoOpAudioInterruptionObserver()` for backward compatibility; iOS audio interruption tests explicitly inject `IOSAudioInterruptionObserver()`.
- Verified: zero `#if os` in any Core/ file. All `#if os` now confined to leaf implementations in App/Platform/ and composition root.
- Full test suite: 1649 iOS tests passed, 1625 macOS tests passed, `bin/check-dependencies.sh` passed.

## File List

### New Files
- `Peach/Core/Ports/BackgroundPolicy.swift`
- `Peach/Core/Ports/AudioSessionConfiguring.swift`
- `Peach/Core/Ports/AudioInterruptionObserving.swift`
- `Peach/App/Platform/IOSBackgroundPolicy.swift`
- `Peach/App/Platform/MacOSBackgroundPolicy.swift`
- `Peach/App/Platform/IOSAudioSessionConfigurator.swift`
- `Peach/App/Platform/MacOSAudioSessionConfigurator.swift`
- `Peach/App/Platform/IOSAudioInterruptionObserver.swift`
- `Peach/App/Platform/NoOpAudioInterruptionObserver.swift`
- `Peach/App/Platform/PlatformNotifications.swift`
- `Peach/App/Platform/PlatformImage.swift`
- `Peach/App/Platform/HapticFeedbackManager.swift`
- `Peach/App/Platform/NoOpHapticFeedbackManager.swift`
- `PeachTests/Core/Ports/BackgroundPolicyTests.swift`
- `PeachTests/Core/Audio/MockAudioSessionConfigurator.swift`

### Modified Files
- `Peach/App/TrainingLifecycleCoordinator.swift`
- `Peach/Core/Audio/SoundFontEngine.swift`
- `Peach/Core/Audio/AudioSessionInterruptionMonitor.swift`
- `Peach/Core/Training/SessionLifecycle.swift`
- `Peach/Profile/ChartImageRenderer.swift`
- `Peach/App/PeachApp.swift`
- `Peach/App/PreviewDefaults.swift`
- `Peach/PitchDiscrimination/PitchDiscriminationSession.swift`
- `Peach/PitchMatching/PitchMatchingSession.swift`
- `Peach/RhythmOffsetDetection/RhythmOffsetDetectionSession.swift`
- `Peach/ContinuousRhythmMatching/ContinuousRhythmMatchingSession.swift`
- `PeachTests/App/TrainingLifecycleCoordinatorTests.swift`
- `PeachTests/Core/Audio/AudioSessionInterruptionMonitorTests.swift`
- `PeachTests/Core/Audio/SoundFontEngineTests.swift`
- `PeachTests/Core/Audio/SoundFontPlayerTests.swift`
- `PeachTests/Core/Audio/SoundFontPresetStressTests.swift`
- `PeachTests/Core/Audio/SoundFontPlaybackHandleTests.swift`
- `PeachTests/Core/Training/SessionLifecycleTests.swift`
- `PeachTests/PitchDiscrimination/PitchDiscriminationTestHelpers.swift`
- `PeachTests/PitchDiscrimination/PitchDiscriminationSessionAudioInterruptionTests.swift`
- `PeachTests/PitchMatching/PitchMatchingSessionTests.swift`
- `PeachTests/ContinuousRhythmMatching/ContinuousRhythmMatchingSessionTests.swift`

### Deleted Files
- `Peach/PitchDiscrimination/HapticFeedbackManager.swift`

## Change Log

- 2026-03-29: Story created
- 2026-03-29: Implementation complete — all 7 tasks done, all ACs satisfied, full test suite passing on both platforms
