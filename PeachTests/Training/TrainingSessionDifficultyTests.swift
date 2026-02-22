import Testing
import Foundation
@testable import Peach

/// Tests for difficulty display support in TrainingSession (session best tracking, current difficulty)
@Suite("TrainingSession Difficulty Tests")
@MainActor
struct TrainingSessionDifficultyTests {

    // MARK: - Test Fixtures

    func makeTrainingSession(
        comparisons: [Comparison] = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 50.0, isSecondNoteHigher: true),
            Comparison(note1: 64, note2: 64, centDifference: 25.0, isSecondNoteHigher: false)
        ]
    ) -> (TrainingSession, MockNotePlayer, MockNextNoteStrategy) {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: comparisons)
        let observers: [ComparisonObserver] = [mockDataStore, profile]
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0,
            observers: observers
        )
        return (session, mockPlayer, mockStrategy)
    }

    // MARK: - currentDifficulty Tests

    @Test("currentDifficulty is nil before training starts")
    func currentDifficultyNilBeforeTraining() {
        let (session, _, _) = makeTrainingSession()
        #expect(session.currentDifficulty == nil)
    }

    @Test("currentDifficulty returns cent difference of current comparison during training")
    func currentDifficultyReturnsCentDifference() async throws {
        let (session, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(session.currentDifficulty == 100.0)
    }

    @Test("currentDifficulty is nil after stopping training")
    func currentDifficultyNilAfterStop() async throws {
        let (session, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)
        session.stop()

        #expect(session.currentDifficulty == nil)
    }

    // MARK: - sessionBestCentDifference Tests

    @Test("sessionBestCentDifference is nil before any correct answer")
    func sessionBestNilBeforeCorrectAnswer() {
        let (session, _, _) = makeTrainingSession()
        #expect(session.sessionBestCentDifference == nil)
    }

    @Test("sessionBestCentDifference updates on first correct answer")
    func sessionBestUpdatesOnFirstCorrectAnswer() async throws {
        let comparisons = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)
        ]
        let (session, _, _) = makeTrainingSession(comparisons: comparisons)

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        // Answer correctly (second note IS higher, user says higher)
        session.handleAnswer(isHigher: true)

        #expect(session.sessionBestCentDifference == 100.0)
    }

    @Test("sessionBestCentDifference does not update on incorrect answer")
    func sessionBestDoesNotUpdateOnIncorrectAnswer() async throws {
        let comparisons = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)
        ]
        let (session, _, _) = makeTrainingSession(comparisons: comparisons)

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        // Answer incorrectly (second note IS higher, user says lower)
        session.handleAnswer(isHigher: false)

        #expect(session.sessionBestCentDifference == nil)
    }

    @Test("sessionBestCentDifference tracks smallest cent difference across correct answers")
    func sessionBestTracksSmallestDifference() async throws {
        let comparisons = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 50.0, isSecondNoteHigher: true)
        ]
        let (session, mockPlayer, _) = makeTrainingSession(comparisons: comparisons)

        // First comparison: 100 cents, answer correctly
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)
        session.handleAnswer(isHigher: true)
        #expect(session.sessionBestCentDifference == 100.0)

        // Wait for second comparison
        try await waitForPlayCallCount(mockPlayer, 4)
        try await waitForState(session, .awaitingAnswer)

        // Second comparison: 50 cents, answer correctly
        session.handleAnswer(isHigher: true)
        #expect(session.sessionBestCentDifference == 50.0)
    }

    @Test("sessionBestCentDifference does not increase when larger difference answered correctly")
    func sessionBestDoesNotIncrease() async throws {
        let comparisons = [
            Comparison(note1: 60, note2: 60, centDifference: 50.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 100.0, isSecondNoteHigher: true)
        ]
        let (session, mockPlayer, _) = makeTrainingSession(comparisons: comparisons)

        // First comparison: 50 cents, answer correctly
        session.startTraining()
        try await waitForState(session, .awaitingAnswer)
        session.handleAnswer(isHigher: true)
        #expect(session.sessionBestCentDifference == 50.0)

        // Wait for second comparison
        try await waitForPlayCallCount(mockPlayer, 4)
        try await waitForState(session, .awaitingAnswer)

        // Second comparison: 100 cents, answer correctly — best should remain 50
        session.handleAnswer(isHigher: true)
        #expect(session.sessionBestCentDifference == 50.0)
    }

    @Test("sessionBestCentDifference resets when training stops")
    func sessionBestResetsOnStop() async throws {
        let comparisons = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)
        ]
        let (session, _, _) = makeTrainingSession(comparisons: comparisons)

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)
        session.handleAnswer(isHigher: true)
        #expect(session.sessionBestCentDifference == 100.0)

        session.stop()
        #expect(session.sessionBestCentDifference == nil)
    }
}
