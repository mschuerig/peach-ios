import Observation
import SwiftUI
import Testing
@testable import Peach

@Suite("TrainingLifecycleCoordinator")
struct TrainingLifecycleCoordinatorTests {

    // MARK: - Scene Phase

    @Test("iOS: stops active session on background")
    func backgroundStopsActiveSession() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .background)

        #expect(!coordinator.isTrainingActive)
    }

    @Test("does not crash when no training destination")
    func backgroundWithNoTrainingDestination() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())

        coordinator.handleScenePhase(old: .active, new: .background)
        // No crash — nil currentTrainingDestination is safe
    }

    @Test("iOS: does not stop session on inactive")
    func iosDoesNotStopOnInactive() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .inactive)

        #expect(coordinator.isTrainingActive)
    }

    @Test("macOS: stops session on inactive")
    func macosStopsOnInactive() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .inactive)

        #expect(!coordinator.isTrainingActive)
    }

    @Test("macOS: stops session on background")
    func macosStopsOnBackground() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .active, new: .background)

        #expect(!coordinator.isTrainingActive)
    }

    // MARK: - Auto-Restart on Foreground Return

    @Test("iOS: auto-restarts training when returning to active with training destination")
    func iosAutoRestartsOnForeground() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        // Simulate being on a training screen that was stopped
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.stopCurrentSession()

        #expect(!coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .background, new: .active)

        #expect(coordinator.isTrainingActive)
    }

    @Test("macOS: does not auto-restart training when returning to active")
    func macosDoesNotAutoRestartOnForeground() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        // macOS doesn't auto-start, so manually start then stop
        coordinator.startCurrentSession()
        coordinator.stopCurrentSession()

        #expect(!coordinator.isTrainingActive)

        coordinator.handleScenePhase(old: .inactive, new: .active)

        #expect(!coordinator.isTrainingActive)
    }

    // MARK: - macOS App Activation

    @Test("handleAppDeactivated stops current session")
    func handleAppDeactivatedStopsSession() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.handleAppDeactivated()

        #expect(!coordinator.isTrainingActive)
    }

    @Test("handleAppActivated restarts when auto-start enabled")
    func handleAppActivatedRestartsWithAutoStart() {
        let settings = MockUserSettings()
        settings.autoStartTraining = true
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy(), userSettings: settings)

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        coordinator.handleAppDeactivated()
        #expect(!coordinator.isTrainingActive)

        coordinator.handleAppActivated()

        #expect(coordinator.isTrainingActive)
    }

    @Test("handleAppActivated does not restart when auto-start disabled")
    func handleAppActivatedDoesNotRestartWithoutAutoStart() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        coordinator.handleAppDeactivated()

        coordinator.handleAppActivated()

        #expect(!coordinator.isTrainingActive)
    }

    // MARK: - Training Screen Lifecycle

    @Test("trainingScreenAppeared auto-starts on iOS")
    func trainingScreenAppearedAutoStartsIOS() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())

        // Use continuousRhythmMatching because it sets isRunning synchronously
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        #expect(coordinator.currentTrainingDestination == .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)
    }

    @Test("trainingScreenAppeared does not auto-start on macOS")
    func trainingScreenAppearedDoesNotAutoStartMacOS() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)

        #expect(coordinator.currentTrainingDestination == .timingOffsetDetection)
        #expect(!coordinator.isTrainingActive)
    }

    @Test("trainingScreenDisappeared stops session and clears destination")
    func trainingScreenDisappearedStopsAndClears() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.trainingScreenDisappeared()

        #expect(!coordinator.isTrainingActive)
        #expect(coordinator.currentTrainingDestination == nil)
    }

    // MARK: - Toggle Training

    @Test("toggleTraining starts when idle")
    func toggleTrainingStartsWhenIdle() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(!coordinator.isTrainingActive)

        coordinator.toggleTraining()

        #expect(coordinator.isTrainingActive)
    }

    @Test("toggleTraining stops when active")
    func toggleTrainingStopsWhenActive() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.toggleTraining()

        #expect(!coordinator.isTrainingActive)
    }

    // MARK: - Auto-Start Setting

    @Test("macOS: auto-start setting enables auto-start on screen appear")
    func autoStartSettingEnablesAutoStart() {
        let settings = MockUserSettings()
        settings.autoStartTraining = true
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy(), userSettings: settings)

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        #expect(coordinator.isTrainingActive)
    }

    @Test("macOS: auto-start setting disabled does not auto-start")
    func autoStartSettingDisabledDoesNotAutoStart() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        #expect(!coordinator.isTrainingActive)
    }

    @Test("macOS: auto-start setting enables auto-restart on foreground return")
    func autoStartSettingEnablesAutoRestart() {
        let settings = MockUserSettings()
        settings.autoStartTraining = true
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy(), userSettings: settings)

        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        // Auto-started, now simulate app switch and return
        coordinator.stopCurrentSession()

        coordinator.handleScenePhase(old: .inactive, new: .active)

        #expect(coordinator.isTrainingActive)
    }

    // MARK: - Help Sheet

    @Test("helpSheetPresented stops active session")
    func helpSheetPresentedStopsSession() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(coordinator.isTrainingActive)

        coordinator.helpSheetPresented()

        #expect(!coordinator.isTrainingActive)
    }

    @Test("helpSheetDismissed restarts on iOS")
    func helpSheetDismissedRestartsOnIOS() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.helpSheetPresented()

        coordinator.helpSheetDismissed()

        #expect(coordinator.isTrainingActive)
    }

    @Test("helpSheetDismissed restarts on macOS when was active before")
    func helpSheetDismissedRestartsOnMacOSWhenWasActive() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        coordinator.startCurrentSession()
        #expect(coordinator.isTrainingActive)

        coordinator.helpSheetPresented()
        #expect(!coordinator.isTrainingActive)

        coordinator.helpSheetDismissed()
        #expect(coordinator.isTrainingActive)
    }

    @Test("helpSheetDismissed does not restart on macOS when was idle before")
    func helpSheetDismissedDoesNotRestartOnMacOSWhenWasIdle() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)
        #expect(!coordinator.isTrainingActive)

        coordinator.helpSheetPresented()
        coordinator.helpSheetDismissed()

        #expect(!coordinator.isTrainingActive)
    }

    // MARK: - startCurrentSession Dispatch

    @Test("startCurrentSession dispatches to pitch discrimination")
    func startCurrentSessionDispatchesPitchDiscrimination() async throws {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .pitchDiscrimination(isIntervalMode: false))

        coordinator.startCurrentSession()

        // Session starts asynchronously — yield to let the training task begin
        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession dispatches to pitch matching")
    func startCurrentSessionDispatchesPitchMatching() async throws {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .pitchMatching(isIntervalMode: false))

        coordinator.startCurrentSession()

        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession dispatches to rhythm offset detection")
    func startCurrentSessionDispatchesRhythm() async throws {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .timingOffsetDetection)

        coordinator.startCurrentSession()

        try await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession dispatches to continuous rhythm matching")
    func startCurrentSessionDispatchesContinuousRhythm() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        coordinator.trainingScreenAppeared(destination: .continuousRhythmMatching)

        coordinator.startCurrentSession()

        // ContinuousRhythmMatching sets isRunning synchronously
        #expect(coordinator.isTrainingActive)
    }

    @Test("startCurrentSession is no-op without destination")
    func startCurrentSessionNoOpWithoutDestination() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())

        coordinator.startCurrentSession()

        #expect(!coordinator.isTrainingActive)
    }

    // MARK: - Menu Navigation

    @Test("navigate with no active session pushes destination immediately")
    func navigateWithNoActiveSession() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.navigate(to: .profile)

        // Allow the internal Task to run
        await Task.yield()

        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("navigate with active session stops session and pushes destination after idle")
    func navigateWithActiveSession() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        mockSession.isIdle = false
        mockSession.onStopCalled = { mockSession.isIdle = true }
        coordinator.activeSession = mockSession

        coordinator.navigate(to: .profile)

        await Task.yield()

        #expect(mockSession.stopCallCount == 1)
        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("navigate with active session uses event-driven idle confirmation")
    func navigateUsesEventDrivenIdle() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        mockSession.isIdle = false
        // stop() does NOT set isIdle — we'll set it after a yield
        coordinator.activeSession = mockSession

        coordinator.navigate(to: .profile)

        await Task.yield()

        // Session was stopped but not yet idle — destination should not be published
        #expect(mockSession.stopCallCount == 1)
        #expect(coordinator.resolvedNavigation == nil)

        // Now session becomes idle (event-driven)
        mockSession.isIdle = true

        await Task.yield()

        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("rapid sequential navigations — only final destination is pushed")
    func rapidSequentialNavigations() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())

        coordinator.navigate(to: .pitchDiscrimination(isIntervalMode: false))
        coordinator.navigate(to: .pitchMatching(isIntervalMode: true))
        coordinator.navigate(to: .profile)

        await Task.yield()

        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    @Test("cancellation of in-flight navigation does not leave stale state")
    func cancellationDoesNotLeaveStaleState() async {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        mockSession.isIdle = false
        coordinator.activeSession = mockSession

        // First navigation — will block waiting for idle
        coordinator.navigate(to: .pitchDiscrimination(isIntervalMode: false))
        await Task.yield()

        // Second navigation cancels the first
        mockSession.onStopCalled = { mockSession.isIdle = true }
        coordinator.navigate(to: .profile)
        await Task.yield()

        // Only the second destination should appear
        #expect(coordinator.resolvedNavigation?.destination == .profile)
    }

    // MARK: - Helpers

    private func makeCoordinator(
        policy: BackgroundPolicy,
        userSettings: MockUserSettings = MockUserSettings()
    ) -> TrainingLifecycleCoordinator {
        let notePlayer = MockNotePlayer()
        notePlayer.instantPlayback = true
        let profile = PerceptualProfile()
        return TrainingLifecycleCoordinator(
            pitchDiscriminationSession: PitchDiscriminationSession(
                notePlayer: notePlayer,
                strategy: MockNextPitchDiscriminationStrategy(),
                profile: profile,
                observers: [],
                audioInterruptionObserver: NoOpAudioInterruptionObserver()
            ),
            pitchMatchingSession: PitchMatchingSession(
                notePlayer: notePlayer,
                profile: profile,
                audioInterruptionObserver: NoOpAudioInterruptionObserver()
            ),
            timingOffsetDetectionSession: TimingOffsetDetectionSession(
                rhythmPlayer: MockRhythmPlayer(),
                strategy: MockNextTimingOffsetDetectionStrategy(),
                profile: profile,
                sampleRate: .standard48000,
                audioInterruptionObserver: NoOpAudioInterruptionObserver()
            ),
            continuousRhythmMatchingSession: ContinuousRhythmMatchingSession(
                stepSequencer: MockStepSequencer(),
                audioInterruptionObserver: NoOpAudioInterruptionObserver()
            ),
            userSettings: userSettings,
            backgroundPolicy: policy
        )
    }
}

@Observable
private final class MockTrainingSession: TrainingSession {
    var isIdle: Bool = true
    var stopCallCount = 0
    var onStopCalled: (() -> Void)?

    func stop() {
        stopCallCount += 1
        onStopCalled?()
    }
}
