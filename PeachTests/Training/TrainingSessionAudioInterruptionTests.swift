import Testing
import Foundation
import AVFoundation
@testable import Peach

/// Tests for audio interruption and route change handling in TrainingSession
@Suite("TrainingSession Audio Interruption Tests", .serialized)
struct TrainingSessionAudioInterruptionTests {

    // MARK: - Test Fixtures

    @MainActor
    func makeTrainingSession(
        comparisons: [Comparison] = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 95.0, isSecondNoteHigher: false),
            Comparison(note1: 64, note2: 64, centDifference: 90.0, isSecondNoteHigher: true),
            Comparison(note1: 66, note2: 66, centDifference: 85.0, isSecondNoteHigher: false)
        ]
    ) -> (TrainingSession, MockNotePlayer, NotificationCenter) {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: comparisons)
        let observers: [ComparisonObserver] = [mockDataStore, profile]
        let nc = NotificationCenter()
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 0.01,
            observers: observers,
            notificationCenter: nc
        )
        return (session, mockPlayer, nc)
    }

    // MARK: - Audio Interruption Tests

    @Test("Audio interruption began stops training from awaitingAnswer state")
    @MainActor
    func audioInterruption_Began_StopsFromAwaitingAnswer() async throws {
        let (session, _, nc) = makeTrainingSession()
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption began stops training from playingNote1 state")
    @MainActor
    func audioInterruption_Began_StopsFromPlayingNote1() async throws {
        let (session, mockPlayer, nc) = makeTrainingSession()
        mockPlayer.instantPlayback = false
        mockPlayer.simulatedPlaybackDuration = 5.0

        session.startTraining()
        try await waitForState(session, .playingNote1)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption began stops training from playingNote2 state")
    @MainActor
    func audioInterruption_Began_StopsFromPlayingNote2() async throws {
        let (session, mockPlayer, nc) = makeTrainingSession()
        mockPlayer.instantPlayback = false
        mockPlayer.simulatedPlaybackDuration = 0.01

        session.startTraining()
        try await waitForPlayCallCount(mockPlayer, 2)
        mockPlayer.simulatedPlaybackDuration = 5.0

        try await waitForState(session, .playingNote2)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption ended does NOT auto-restart training")
    @MainActor
    func audioInterruption_Ended_DoesNotAutoRestart() async throws {
        let (session, _, nc) = makeTrainingSession()
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await waitForState(session, .idle)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle, "Training should NOT auto-restart after interruption ends")
    }

    @Test("Audio interruption with nil type is handled gracefully")
    @MainActor
    func audioInterruption_NilType_HandledGracefully() async throws {
        let (session, _, nc) = makeTrainingSession()
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: nil
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .awaitingAnswer, "Session should continue when interruption type is nil")
    }

    @Test("Audio interruption on idle session is safe (no crash)")
    @MainActor
    func audioInterruption_Began_WhileIdle_IsSafe() async throws {
        let (session, _, nc) = makeTrainingSession()
        #expect(session.state == .idle)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    // MARK: - Route Change Tests

    @Test("Route change oldDeviceUnavailable stops training")
    @MainActor
    func routeChange_OldDeviceUnavailable_StopsTraining() async throws {
        let (session, _, nc) = makeTrainingSession()
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Route change non-stop reasons continue training (newDevice, categoryChange, nil)")
    @MainActor
    func routeChange_NonStopReasons_ContinueTraining() async throws {
        let nonStopReasons: [UInt?] = [
            AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue,
            AVAudioSession.RouteChangeReason.categoryChange.rawValue,
            nil
        ]

        for reason in nonStopReasons {
            let (session, _, nc) = makeTrainingSession()
            session.startTraining()
            try await waitForState(session, .awaitingAnswer)

            let userInfo: [AnyHashable: Any]? = reason.map { [AVAudioSessionRouteChangeReasonKey: $0] }
            nc.post(
                name: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                userInfo: userInfo
            )

            try await Task.sleep(for: .milliseconds(50))
            await Task.yield()
            #expect(session.state == .awaitingAnswer, "Training should continue for route change reason \(String(describing: reason))")
            session.stop()
        }
    }

    @Test("Route change oldDeviceUnavailable on idle session is safe")
    @MainActor
    func routeChange_OldDeviceUnavailable_WhileIdle_IsSafe() async throws {
        let (session, _, nc) = makeTrainingSession()
        #expect(session.state == .idle)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    // MARK: - Combined Scenario Tests

    @Test("Training can restart after audio interruption stops it")
    @MainActor
    func canRestartAfterInterruption() async throws {
        let (session, _, nc) = makeTrainingSession()
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await waitForState(session, .idle)

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)
        #expect(session.state == .awaitingAnswer)
    }

    @Test("Training can restart after route change stops it")
    @MainActor
    func canRestartAfterRouteChange() async throws {
        let (session, _, nc) = makeTrainingSession()
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
        try await waitForState(session, .idle)

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)
        #expect(session.state == .awaitingAnswer)
    }
}
