import Testing
import Foundation
@testable import Peach

/// Tests for audio interruption handling in PitchDiscriminationSession.
///
/// Uses `MockAudioInterruptionObserver` to simulate interruptions cross-platform.
/// Filtering logic (began vs ended, route change reasons) is tested in
/// `IOSAudioInterruptionObserverTests`.
@Suite("PitchDiscriminationSession Audio Interruption Tests", .serialized)
struct PitchDiscriminationSessionAudioInterruptionTests {

    // MARK: - Interruption Stops From Each State

    @Test("Audio interruption stops training from awaitingAnswer state")
    func audioInterruption_StopsFromAwaitingAnswer() async throws {
        let mock = MockAudioInterruptionObserver()
        let f = makePitchDiscriminationSession(audioInterruptionObserver: mock)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)

        mock.simulateInterruption()

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption stops training from playingReferenceNote state")
    func audioInterruption_StopsFromPlayingReferenceNote() async throws {
        let mock = MockAudioInterruptionObserver()
        let f = makePitchDiscriminationSession(audioInterruptionObserver: mock)
        let session = f.session
        let mockPlayer = f.mockPlayer
        mockPlayer.instantPlayback = false
        mockPlayer.simulatedPlaybackDuration = .seconds(5)

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .playingReferenceNote)

        mock.simulateInterruption()

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    @Test("Audio interruption stops training from playingTargetNote state")
    func audioInterruption_StopsFromPlayingTargetNote() async throws {
        let mock = MockAudioInterruptionObserver()
        let f = makePitchDiscriminationSession(audioInterruptionObserver: mock)
        let session = f.session
        let mockPlayer = f.mockPlayer
        mockPlayer.instantPlayback = false
        mockPlayer.simulatedPlaybackDuration = .milliseconds(10)

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        await mockPlayer.waitForPlay(minCount: 2)
        mockPlayer.simulatedPlaybackDuration = .seconds(5)

        try await waitForState(session, .playingTargetNote)

        mock.simulateInterruption()

        try await waitForState(session, .idle)
        #expect(session.state == .idle)
    }

    // MARK: - Safe on Idle

    @Test("Audio interruption on idle session is safe (no crash)")
    func audioInterruption_WhileIdle_IsSafe() async throws {
        let mock = MockAudioInterruptionObserver()
        let f = makePitchDiscriminationSession(audioInterruptionObserver: mock)
        let session = f.session
        #expect(session.state == .idle)

        mock.simulateInterruption()

        try await Task.sleep(for: .milliseconds(50))
        await Task.yield()
        #expect(session.state == .idle)
    }

    // MARK: - Restart After Interruption

    @Test("Training can restart after audio interruption stops it")
    func canRestartAfterInterruption() async throws {
        let mock = MockAudioInterruptionObserver()
        let f = makePitchDiscriminationSession(audioInterruptionObserver: mock)
        let session = f.session
        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)

        mock.simulateInterruption()
        try await waitForState(session, .idle)

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.prime], noteDuration: NoteDuration(0.3)))
        try await waitForState(session, .awaitingAnswer)
        #expect(session.state == .awaitingAnswer)
    }
}
