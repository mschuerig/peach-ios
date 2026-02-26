import Foundation
import Testing
@testable import Peach

// MARK: - Test Helpers

enum WaitError: Error {
    case timeout(expected: String, actual: String)
}

func waitForState(
    _ session: PitchMatchingSession,
    _ expectedState: PitchMatchingSessionState,
    timeout: Duration = .seconds(2)
) async throws {
    let deadline = ContinuousClock.now + timeout
    while session.state != expectedState {
        guard ContinuousClock.now < deadline else {
            throw WaitError.timeout(expected: "\(expectedState)", actual: "\(session.state)")
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

// MARK: - Factory

func makePitchMatchingSession(
    settingsOverride: TrainingSettings? = TrainingSettings(),
    noteDurationOverride: TimeInterval? = 0.0
) -> (session: PitchMatchingSession, notePlayer: MockNotePlayer, profile: MockPitchMatchingProfile, observer: MockPitchMatchingObserver) {
    let notePlayer = MockNotePlayer()
    let profile = MockPitchMatchingProfile()
    let observer = MockPitchMatchingObserver()
    let session = PitchMatchingSession(
        notePlayer: notePlayer,
        profile: profile,
        observers: [observer],
        settingsOverride: settingsOverride,
        noteDurationOverride: noteDurationOverride
    )
    return (session, notePlayer, profile, observer)
}

// MARK: - Task 1: Skeleton Tests

@Suite("PitchMatchingSession")
struct PitchMatchingSessionTests {

    @Test("starts in idle state")
    func startsInIdleState() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.state == .idle)
    }

    @Test("currentChallenge is nil initially")
    func currentChallengeNilInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.currentChallenge == nil)
    }

    @Test("lastResult is nil initially")
    func lastResultNilInitially() async {
        let (session, _, _, _) = makePitchMatchingSession()
        #expect(session.lastResult == nil)
    }

    // MARK: - Task 2: Challenge Generation Tests

    @Test("challenge has note within configured range")
    func challengeNoteWithinRange() async throws {
        let settings = TrainingSettings(noteRangeMin: 48, noteRangeMax: 72)
        let (session, _, _, _) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.referenceNote >= 48)
        #expect(challenge.referenceNote <= 72)
    }

    @Test("challenge has offset within ±100 cents")
    func challengeOffsetWithinRange() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        #expect(challenge.initialCentOffset >= -100)
        #expect(challenge.initialCentOffset <= 100)
    }

    // MARK: - Task 3: State Transition Tests

    @Test("startPitchMatching transitions to playingReference")
    func startTransitionsToPlayingReference() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        notePlayer.instantPlayback = false
        notePlayer.simulatedPlaybackDuration = 5.0
        session.startPitchMatching()
        try await waitForState(session, .playingReference)

        #expect(session.state == .playingReference)
    }

    @Test("reference note played at correct frequency")
    func referenceNoteFrequency() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, notePlayer, _, _) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let expectedFrequency = try FrequencyCalculation.frequency(midiNote: 69, referencePitch: 440.0)
        #expect(notePlayer.playHistory.first != nil)
        let firstPlay = notePlayer.playHistory.first!
        #expect(abs(firstPlay.frequency - expectedFrequency) < 0.01)
    }

    @Test("auto-transitions to playingTunable after reference")
    func autoTransitionsToPlayingTunable() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        #expect(session.state == .playingTunable)
    }

    @Test("tunable note played at offset frequency")
    func tunableNoteAtOffsetFrequency() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, notePlayer, _, _) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let challenge = try #require(session.currentChallenge)
        let expectedTunableFreq = try FrequencyCalculation.frequency(
            midiNote: challenge.referenceNote,
            cents: challenge.initialCentOffset,
            referencePitch: 440.0
        )

        // The second play call (handle-returning) should be the tunable note
        #expect(notePlayer.playCallCount >= 2)
        let tunableFreq = notePlayer.lastFrequency!
        #expect(abs(tunableFreq - expectedTunableFreq) < 0.01)
    }

    // MARK: - Task 4: adjustFrequency and commitResult Tests

    @Test("adjustFrequency delegates to handle")
    func adjustFrequencyDelegatesToHandle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.adjustFrequency(450.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.adjustFrequencyCallCount == 1)
        #expect(handle.lastAdjustedFrequency == 450.0)
    }

    @Test("commitResult stops handle")
    func commitResultStopsHandle() async throws {
        let (session, notePlayer, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        let handle = try #require(notePlayer.lastHandle)
        session.commitResult(userFrequency: 440.0)
        try await Task.sleep(for: .milliseconds(50))

        #expect(handle.stopCallCount == 1)
    }

    @Test("commitResult computes correct cent error")
    func commitResultComputesCentError() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, _, _, observer) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        // User sings exactly at reference → 0 cent error
        let referenceFreq = try FrequencyCalculation.frequency(midiNote: 69, referencePitch: 440.0)
        session.commitResult(userFrequency: referenceFreq)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(abs(result.userCentError) < 0.01)
    }

    @Test("commitResult computes positive cent error when sharp")
    func commitResultSharpCentError() async throws {
        let settings = TrainingSettings(noteRangeMin: 69, noteRangeMax: 69, referencePitch: 440.0)
        let (session, _, _, observer) = makePitchMatchingSession(settingsOverride: settings)
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        // User plays sharp (higher frequency)
        let sharpFreq = 440.0 * pow(2.0, 50.0 / 1200.0) // 50 cents sharp
        session.commitResult(userFrequency: sharpFreq)
        try await waitForState(session, .showingFeedback)

        let result = try #require(observer.lastResult)
        #expect(result.userCentError > 0)
        #expect(abs(result.userCentError - 50.0) < 0.1)
    }

    @Test("commitResult notifies observers")
    func commitResultNotifiesObservers() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)

        #expect(observer.pitchMatchingCompletedCallCount == 1)
        #expect(observer.lastResult != nil)
    }

    @Test("transitions to showingFeedback after commitResult")
    func transitionsToShowingFeedback() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)

        #expect(session.state == .showingFeedback)
    }

    @Test("auto-advances from showingFeedback to playingReference")
    func autoAdvancesFromFeedback() async throws {
        let (session, _, _, _) = makePitchMatchingSession()
        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)

        // After feedback duration (~400ms), should auto-advance
        try await waitForState(session, .playingTunable, timeout: .seconds(3))
        // It went through playingReference and is now back to playingTunable (next challenge)
        #expect(session.state == .playingTunable)
    }

    @Test("full cycle: idle → playingReference → playingTunable → showingFeedback → loop")
    func fullStateCycle() async throws {
        let (session, _, _, observer) = makePitchMatchingSession()

        #expect(session.state == .idle)

        session.startPitchMatching()
        try await waitForState(session, .playingTunable)

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 1)

        // Wait for auto-advance to next challenge
        try await waitForState(session, .playingTunable, timeout: .seconds(3))

        session.commitResult(userFrequency: 440.0)
        try await waitForState(session, .showingFeedback)
        #expect(observer.pitchMatchingCompletedCallCount == 2)
    }
}
