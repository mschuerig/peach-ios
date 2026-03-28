import SwiftUI
import Testing
@testable import Peach

@Suite("TrainingLifecycleCoordinator")
struct TrainingLifecycleCoordinatorTests {

    // MARK: - Scene Phase

    @Test("stops active session on background")
    func backgroundStopsActiveSession() {
        let coordinator = makeCoordinator()
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .background) {}

        #expect(mockSession.stopCallCount == 1)
    }

    @Test("does not stop session when no active session")
    func backgroundWithNoActiveSession() {
        let coordinator = makeCoordinator()

        coordinator.handleScenePhase(old: .active, new: .background) {}
        // No crash — nil activeSession is safe
    }

    @Test("calls clearNavigation on foreground from background")
    func foregroundClearsNavigation() {
        let coordinator = makeCoordinator()
        var navigationCleared = false

        coordinator.handleScenePhase(old: .background, new: .active) {
            navigationCleared = true
        }

        #expect(navigationCleared)
    }

    @Test("clears navigation when returning from inactive (e.g. phone call)")
    func inactiveToActiveClearsNavigation() {
        let coordinator = makeCoordinator()
        var navigationCleared = false

        coordinator.handleScenePhase(old: .inactive, new: .active) {
            navigationCleared = true
        }

        #expect(navigationCleared)
    }

    #if os(iOS)
    @Test("does not stop session when transitioning to inactive on iOS")
    func inactiveDoesNotStopSessionOnIOS() {
        let coordinator = makeCoordinator()
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .inactive) {}

        #expect(mockSession.stopCallCount == 0)
    }
    #endif

    #if os(macOS)
    @Test("stops active session when transitioning to inactive on macOS")
    func inactiveStopsSessionOnMacOS() {
        let coordinator = makeCoordinator()
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .inactive) {}

        #expect(mockSession.stopCallCount == 1)
    }
    #endif

    @Test("backgrounds both stops session and does not clear navigation")
    func backgroundStopsButDoesNotClear() {
        let coordinator = makeCoordinator()
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession
        var navigationCleared = false

        coordinator.handleScenePhase(old: .active, new: .background) {
            navigationCleared = true
        }

        #expect(mockSession.stopCallCount == 1)
        #expect(!navigationCleared)
    }

    // MARK: - Helpers

    private func makeCoordinator() -> TrainingLifecycleCoordinator {
        let notePlayer = MockNotePlayer()
        notePlayer.instantPlayback = true
        let profile = PerceptualProfile()
        return TrainingLifecycleCoordinator(
            pitchDiscriminationSession: PitchDiscriminationSession(
                notePlayer: notePlayer,
                strategy: MockNextPitchDiscriminationStrategy(),
                profile: profile,
                observers: []
            ),
            pitchMatchingSession: PitchMatchingSession(
                notePlayer: notePlayer,
                profile: profile
            ),
            rhythmOffsetDetectionSession: RhythmOffsetDetectionSession(
                rhythmPlayer: MockRhythmPlayer(),
                strategy: MockNextRhythmOffsetDetectionStrategy(),
                profile: profile,
                sampleRate: .standard48000
            ),
            continuousRhythmMatchingSession: ContinuousRhythmMatchingSession(
                stepSequencer: MockStepSequencer()
            ),
            userSettings: MockUserSettings()
        )
    }
}

private final class MockTrainingSession: TrainingSession {
    var isIdle: Bool = true
    var stopCallCount = 0

    func stop() {
        stopCallCount += 1
    }
}
