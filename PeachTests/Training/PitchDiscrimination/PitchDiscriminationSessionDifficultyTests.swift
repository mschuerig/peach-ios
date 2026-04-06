import Testing
@testable import Peach

/// Tests for difficulty display support in PitchDiscriminationSession (session best tracking, current difficulty)
@Suite("PitchDiscriminationSession Difficulty Tests")
struct PitchDiscriminationSessionDifficultyTests {

    // MARK: - currentDifficulty Tests

    @Test("currentDifficulty is nil before training starts")
    func currentDifficultyNilBeforeTraining() async {
        let f = makePitchDiscriminationSession()
        #expect(f.session.currentDifficulty == nil)
    }

    @Test("currentDifficulty returns cent difference of current comparison during training")
    func currentDifficultyReturnsCentDifference() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentDifficulty == 100.0)
    }

    @Test("currentDifficulty is nil after stopping training")
    func currentDifficultyNilAfterStop() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)
        f.session.stop()

        #expect(f.session.currentDifficulty == nil)
    }

    // MARK: - sessionBestCentDifference Tests

    @Test("sessionBestCentDifference is nil before any correct answer")
    func sessionBestNilBeforeCorrectAnswer() async {
        let f = makePitchDiscriminationSession()
        #expect(f.session.sessionBestCentDifference == nil)
    }

    @Test("sessionBestCentDifference updates on first correct answer")
    func sessionBestUpdatesOnFirstCorrectAnswer() async throws {
        let comparisons = [
            PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))
        ]
        let f = makePitchDiscriminationSession(comparisons: comparisons)

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // Answer correctly (second note IS higher, user says higher)
        f.session.handleAnswer(isHigher: true)

        #expect(f.session.sessionBestCentDifference == 100.0)
    }

    @Test("sessionBestCentDifference does not update on incorrect answer")
    func sessionBestDoesNotUpdateOnIncorrectAnswer() async throws {
        let comparisons = [
            PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))
        ]
        let f = makePitchDiscriminationSession(comparisons: comparisons)

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        // Answer incorrectly (second note IS higher, user says lower)
        f.session.handleAnswer(isHigher: false)

        #expect(f.session.sessionBestCentDifference == nil)
    }

    @Test("sessionBestCentDifference tracks smallest cent difference across correct answers")
    func sessionBestTracksSmallestDifference() async throws {
        let comparisons = [
            PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0))),
            PitchDiscriminationTrial(referenceNote: 62, targetNote: DetunedMIDINote(note: 62, offset: Cents(50.0)))
        ]
        let f = makePitchDiscriminationSession(comparisons: comparisons)

        // First comparison: 100 cents, answer correctly
        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.sessionBestCentDifference == 100.0)

        // Wait for second comparison
        await f.mockPlayer.waitForPlay(minCount: 4)
        try await waitForState(f.session, .awaitingAnswer)

        // Second comparison: 50 cents, answer correctly
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.sessionBestCentDifference == 50.0)
    }

    @Test("sessionBestCentDifference does not increase when larger difference answered correctly")
    func sessionBestDoesNotIncrease() async throws {
        let comparisons = [
            PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(50.0))),
            PitchDiscriminationTrial(referenceNote: 62, targetNote: DetunedMIDINote(note: 62, offset: Cents(100.0)))
        ]
        let f = makePitchDiscriminationSession(comparisons: comparisons)

        // First comparison: 50 cents, answer correctly
        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.sessionBestCentDifference == 50.0)

        // Wait for second comparison
        await f.mockPlayer.waitForPlay(minCount: 4)
        try await waitForState(f.session, .awaitingAnswer)

        // Second comparison: 100 cents, answer correctly — best should remain 50
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.sessionBestCentDifference == 50.0)
    }

    @Test("sessionBestCentDifference resets when training stops")
    func sessionBestResetsOnStop() async throws {
        let comparisons = [
            PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0)))
        ]
        let f = makePitchDiscriminationSession(comparisons: comparisons)

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.sessionBestCentDifference == 100.0)

        f.session.stop()
        #expect(f.session.sessionBestCentDifference == nil)
    }
}
