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

    @Test("iOS: calls clearNavigation on foreground from background")
    func iosForegroundClearsNavigation() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        var navigationCleared = false

        coordinator.handleScenePhase(old: .background, new: .active) {
            navigationCleared = true
        }

        #expect(navigationCleared)
    }

    @Test("iOS: clears navigation when returning from inactive")
    func iosInactiveToActiveClearsNavigation() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        var navigationCleared = false

        coordinator.handleScenePhase(old: .inactive, new: .active) {
            navigationCleared = true
        }

        #expect(navigationCleared)
    }

    @Test("does not clear navigation when going to background")
    func backgroundDoesNotClear() {
        let coordinator = makeCoordinator(policy: IOSBackgroundPolicy())
        var navigationCleared = false

        coordinator.handleScenePhase(old: .active, new: .background) {
            navigationCleared = true
        }

        #expect(!navigationCleared)
    }

    // MARK: - macOS Navigation Preservation

    @Test("macOS: does not clear navigation when returning from inactive")
    func macosInactiveToActivePreservesNavigation() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        var navigationCleared = false

        coordinator.handleScenePhase(old: .inactive, new: .active) {
            navigationCleared = true
        }

        #expect(!navigationCleared)
    }

    @Test("macOS: does not clear navigation when returning from background")
    func macosBackgroundToActivePreservesNavigation() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        var navigationCleared = false

        coordinator.handleScenePhase(old: .background, new: .active) {
            navigationCleared = true
        }

        #expect(!navigationCleared)
    }

    @Test("macOS: inactive still stops active session")
    func macosInactiveStopsSession() {
        let coordinator = makeCoordinator(policy: MacOSBackgroundPolicy())
        let mockSession = MockTrainingSession()
        coordinator.activeSession = mockSession

        coordinator.handleScenePhase(old: .active, new: .inactive) {}

        #expect(mockSession.stopCallCount == 1)
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
