#if os(iOS)
import Testing
import AVFoundation
@testable import Peach

/// Tests for audio interruption and route change handling in PitchDiscriminationSession
@Suite("PitchDiscriminationSession Audio Interruption Tests", .serialized)
struct PitchDiscriminationSessionAudioInterruptionTests {

    // MARK: - Audio Interruption Tests

    @Test("Audio interruption began stops training from awaitingAnswer state")
    func audioInterruption_Began_StopsFromAwaitingAnswer() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption began stops training from playingReferenceNote state")
    func audioInterruption_Began_StopsFromPlayingReferenceNote() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        let mockPlayer = f.mockPlayer
        mockPlayer.instantPlayback = false
        mockPlayer.simulatedPlaybackDuration = .seconds(5)

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .playingReferenceNote)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption began stops training from playingTargetNote state")
    func audioInterruption_Began_StopsFromPlayingTargetNote() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        let mockPlayer = f.mockPlayer
        mockPlayer.instantPlayback = false
        mockPlayer.simulatedPlaybackDuration = .milliseconds(10)

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        await mockPlayer.waitForPlay(minCount: 2)
        mockPlayer.simulatedPlaybackDuration = .seconds(5)

        try await waitForState(session, .playingTargetNote)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption ended does NOT auto-restart training")
    func audioInterruption_Ended_DoesNotAutoRestart() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
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
    func audioInterruption_NilType_HandledGracefully() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
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
    func audioInterruption_Began_WhileIdle_IsSafe() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
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
    func routeChange_OldDeviceUnavailable_StopsTraining() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
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
    func routeChange_NonStopReasons_ContinueTraining() async throws {
        let nonStopReasons: [UInt?] = [
            AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue,
            AVAudioSession.RouteChangeReason.categoryChange.rawValue,
            nil
        ]

        for reason in nonStopReasons {
            let nc = NotificationCenter()
            let f = makePitchDiscriminationSession(notificationCenter: nc)
            let session = f.session
            session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
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
    func routeChange_OldDeviceUnavailable_WhileIdle_IsSafe() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
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
    func canRestartAfterInterruption() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )
        try await waitForState(session, .idle)

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)
        #expect(session.state == .awaitingAnswer)
    }

    @Test("Training can restart after route change stops it")
    func canRestartAfterRouteChange() async throws {
        let nc = NotificationCenter()
        let f = makePitchDiscriminationSession(notificationCenter: nc)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)

        nc.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
        try await waitForState(session, .idle)

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)
        #expect(session.state == .awaitingAnswer)
    }
}
#endif
