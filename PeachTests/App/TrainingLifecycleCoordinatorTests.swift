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

    @Test("startCurrentSession dispatches to timing offset detection")
    func startCurrentSessionDispatchesTimingOffsetDetection() async throws {
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

    // MARK: - Registry-Keyed Dispatch (per-destination coverage)

    @Test("registry dispatches start to every shipping training destination, leaving siblings idle", arguments: [
        NavigationDestination.pitchDiscrimination(isIntervalMode: false),
        NavigationDestination.pitchDiscrimination(isIntervalMode: true),
        NavigationDestination.pitchMatching(isIntervalMode: false),
        NavigationDestination.pitchMatching(isIntervalMode: true),
        NavigationDestination.timingOffsetDetection,
        NavigationDestination.continuousRhythmMatching,
    ])
    func registryDispatchesEveryTrainingDestination(destination: NavigationDestination) async throws {
        let fixture = makeFixture(policy: MacOSBackgroundPolicy())
        let expected: any TrainingSession = switch destination {
        case .pitchDiscrimination: fixture.pdSession
        case .pitchMatching: fixture.pmSession
        case .timingOffsetDetection: fixture.todSession
        case .continuousRhythmMatching: fixture.crmSession
        case .settings, .profile: fatalError("non-training destination not in test arguments")
        }

        fixture.coordinator.trainingScreenAppeared(destination: destination)
        fixture.coordinator.startCurrentSession()

        try await waitUntilNotIdle(expected)

        for session in fixture.allSessions {
            if session === expected {
                #expect(!session.isIdle, "expected session for \(destination) to start")
            } else {
                #expect(session.isIdle, "sibling session became active for \(destination)")
            }
        }
    }

    // MARK: - Helpers

    private struct LifecycleFixture {
        let coordinator: TrainingLifecycleCoordinator
        let pdSession: PitchDiscriminationSession
        let pmSession: PitchMatchingSession
        let todSession: TimingOffsetDetectionSession
        let crmSession: ContinuousRhythmMatchingSession

        var allSessions: [any TrainingSession] {
            [pdSession, pmSession, todSession, crmSession]
        }
    }

    private func makeFixture(
        policy: BackgroundPolicy,
        userSettings: MockUserSettings = MockUserSettings(),
        crmUserSettings: MockContinuousRhythmMatchingUserSettings = MockContinuousRhythmMatchingUserSettings(),
        todUserSettings: MockTimingOffsetDetectionUserSettings = MockTimingOffsetDetectionUserSettings()
    ) -> LifecycleFixture {
        let notePlayer = MockNotePlayer()
        notePlayer.instantPlayback = true
        let profile = PerceptualProfile()
        let pdSession = PitchDiscriminationSession(
            notePlayer: notePlayer,
            strategy: MockNextPitchDiscriminationStrategy(),
            profile: profile,
            observers: [],
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
        let pmSession = PitchMatchingSession(
            notePlayer: notePlayer,
            profile: profile,
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
        let todSession = TimingOffsetDetectionSession(
            beatSequencer: MockBeatSequencer(),
            strategy: MockNextTimingOffsetDetectionStrategy(),
            profile: profile,
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
        let crmSession = ContinuousRhythmMatchingSession(
            beatSequencer: MockBeatSequencer(),
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )
        let registry = TrainingLifecycleRegistry { builder in
            pdSession.contribute(to: builder, userSettings: userSettings)
            pmSession.contribute(to: builder, userSettings: userSettings)
            todSession.contribute(to: builder, userSettings: userSettings, todUserSettings: todUserSettings)
            crmSession.contribute(to: builder, userSettings: userSettings, crmUserSettings: crmUserSettings)
        }
        let coordinator = TrainingLifecycleCoordinator(
            registry: registry,
            backgroundPolicy: policy,
            initialAutoStartSetting: userSettings.autoStartTraining
        )
        return LifecycleFixture(
            coordinator: coordinator,
            pdSession: pdSession,
            pmSession: pmSession,
            todSession: todSession,
            crmSession: crmSession
        )
    }

    private func makeCoordinator(
        policy: BackgroundPolicy,
        userSettings: MockUserSettings = MockUserSettings(),
        crmUserSettings: MockContinuousRhythmMatchingUserSettings = MockContinuousRhythmMatchingUserSettings(),
        todUserSettings: MockTimingOffsetDetectionUserSettings = MockTimingOffsetDetectionUserSettings()
    ) -> TrainingLifecycleCoordinator {
        makeFixture(
            policy: policy,
            userSettings: userSettings,
            crmUserSettings: crmUserSettings,
            todUserSettings: todUserSettings
        ).coordinator
    }

    private func waitUntilNotIdle(_ session: any TrainingSession, timeout: Duration = .seconds(1)) async throws {
        let deadline = ContinuousClock.now + timeout
        while session.isIdle {
            if ContinuousClock.now >= deadline {
                Issue.record("session did not become active within \(timeout)")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
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
