import SwiftUI
import Testing
@testable import Peach

@Suite("TrainingLifecycleCoordinator")
struct TrainingLifecycleCoordinatorTests {

    // MARK: - Scene Phase

    @Test("stops active session on background")
    func backgroundStopsActiveSession() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .background) {}

        #expect(mockSession.stopCallCount == 1)
    }

    @Test("does not stop session when no active session")
    func backgroundWithNoActiveSession() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())

        coordinator.handleScenePhase(old: .active, new: .background) {}
        // No crash — nil activeSession is safe
    }

    @Test("calls clearNavigation on foreground from background")
    func foregroundClearsNavigation() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        var navigationCleared = false

        coordinator.handleScenePhase(old: .background, new: .active) {
            navigationCleared = true
        }

        #expect(navigationCleared)
    }

    @Test("clears navigation when returning from inactive (e.g. phone call)")
    func inactiveToActiveClearsNavigation() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        var navigationCleared = false

        coordinator.handleScenePhase(old: .inactive, new: .active) {
            navigationCleared = true
        }

        #expect(navigationCleared)
    }

    @Test("backgrounds both stops session and does not clear navigation")
    func backgroundStopsButDoesNotClear() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession
        var navigationCleared = false

        coordinator.handleScenePhase(old: .active, new: .background) {
            navigationCleared = true
        }

        #expect(mockSession.stopCallCount == 1)
        #expect(!navigationCleared)
    }

    // MARK: - iOS Background Policy

    @Test("iOS policy does not stop session when transitioning to inactive")
    func iosPolicyDoesNotStopOnInactive() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .inactive) {}

        #expect(mockSession.stopCallCount == 0)
    }

    // MARK: - macOS Background Policy

    @Test("macOS policy stops active session when transitioning to inactive")
    func macosPolicyStopsOnInactive() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .inactive) {}

        #expect(mockSession.stopCallCount == 1)
    }

    @Test("macOS policy stops active session on background")
    func macosPolicyStopsOnBackground() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .background) {}

        #expect(mockSession.stopCallCount == 1)
    }

    // MARK: - Helpers

    private func makeCoordinator(policy: BackgroundPolicy) -> TrainingLifecycleCoordinator {
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
            rhythmOffsetDetectionSession: RhythmOffsetDetectionSession(
                rhythmPlayer: MockRhythmPlayer(),
                strategy: MockNextRhythmOffsetDetectionStrategy(),
                profile: profile,
                sampleRate: .standard48000,
                audioInterruptionObserver: NoOpAudioInterruptionObserver()
            ),
            continuousRhythmMatchingSession: ContinuousRhythmMatchingSession(
                stepSequencer: MockStepSequencer(),
                audioInterruptionObserver: NoOpAudioInterruptionObserver()
            ),
            userSettings: MockUserSettings(),
            backgroundPolicy: policy
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
