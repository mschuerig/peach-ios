import Testing
@testable import Peach

/// Tests for feedback indicator state transitions when correctness changes between cycles
///
/// These tests verify the state contract that prevents feedback icon flicker:
/// when showFeedback becomes true, isLastAnswerCorrect must reflect the CURRENT answer.
@Suite("TrainingScreen Feedback Tests")
struct TrainingScreenFeedbackTests {

    // MARK: - Test Fixtures

    @MainActor
    private func makeTrainingSession(
        comparisons: [Comparison]? = nil
    ) -> (TrainingSession, MockNotePlayer) {
        let defaultComparisons = comparisons ?? [
            // 1st: second note is higher
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            // 2nd: second note is lower
            Comparison(note1: 62, note2: 62, centDifference: 100.0, isSecondNoteHigher: false),
            // 3rd: second note is higher
            Comparison(note1: 64, note2: 64, centDifference: 100.0, isSecondNoteHigher: true),
        ]
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: defaultComparisons)
        let observers: [ComparisonObserver] = [mockDataStore, profile]
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0,
            observers: observers
        )
        return (session, mockPlayer)
    }

    // MARK: - Subtask 1.1: Correct icon shown immediately on correctness change

    @MainActor
    @Test("feedback reflects current correctness after incorrect-to-correct change")
    func feedbackReflectsCorrectnessAfterIncorrectToCorrect() async throws {
        let (session, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        // Answer incorrectly (answer "lower" when second note is higher)
        session.handleAnswer(isHigher: false)
        #expect(session.state == .showingFeedback)
        #expect(session.isLastAnswerCorrect == false)

        // Wait for feedback cycle to complete and next comparison
        try await waitForFeedbackToClear(session)
        try await waitForState(session, .awaitingAnswer)

        // Answer correctly (answer "lower" when second note is lower)
        session.handleAnswer(isHigher: false)
        #expect(session.state == .showingFeedback)
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect == true)
    }

    @MainActor
    @Test("feedback reflects current correctness after correct-to-incorrect change")
    func feedbackReflectsCorrectnessAfterCorrectToIncorrect() async throws {
        let (session, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        // Answer correctly (answer "higher" when second note is higher)
        session.handleAnswer(isHigher: true)
        #expect(session.state == .showingFeedback)
        #expect(session.isLastAnswerCorrect == true)

        // Wait for feedback cycle to complete and next comparison
        try await waitForFeedbackToClear(session)
        try await waitForState(session, .awaitingAnswer)

        // Answer incorrectly (answer "higher" when second note is lower)
        session.handleAnswer(isHigher: true)
        #expect(session.state == .showingFeedback)
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect == false)
    }

    // MARK: - Subtask 1.2: No stale icon state between feedback cycles

    @MainActor
    @Test("showFeedback is false between feedback cycles")
    func showFeedbackIsFalseBetweenCycles() async throws {
        let (session, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        // Complete first answer
        session.handleAnswer(isHigher: true)
        #expect(session.showFeedback == true)

        // Wait for feedback to clear
        try await waitForFeedbackToClear(session)
        #expect(session.showFeedback == false)

        // While awaiting next answer, feedback must remain off
        try await waitForState(session, .awaitingAnswer)
        #expect(session.showFeedback == false)
    }

    @MainActor
    @Test("first answer of session shows feedback without stale state")
    func firstAnswerShowsFeedbackCleanly() async throws {
        let (session, _) = makeTrainingSession()

        // Before training, no feedback state
        #expect(session.showFeedback == false)
        #expect(session.isLastAnswerCorrect == nil)

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        // First answer ever — no previous state to leak
        session.handleAnswer(isHigher: true)
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect == true)
    }

    // MARK: - Subtask 1.3: Same correctness between consecutive answers (AC #3)

    @MainActor
    @Test("feedback displays correctly on consecutive same-correctness answers")
    func feedbackDisplaysCorrectlyOnConsecutiveSameCorrectness() async throws {
        let (session, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        // First answer: correct (answer "higher" when second note is higher)
        session.handleAnswer(isHigher: true)
        #expect(session.state == .showingFeedback)
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect == true)

        // Wait for feedback cycle to complete and next comparison
        try await waitForFeedbackToClear(session)
        try await waitForState(session, .awaitingAnswer)

        // Second answer: also correct (answer "lower" when second note is lower)
        session.handleAnswer(isHigher: false)
        #expect(session.state == .showingFeedback)
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect == true)
    }

    // MARK: - Reduce Motion

    @MainActor
    @Test("feedbackAnimation returns nil when Reduce Motion is enabled")
    func feedbackAnimationReturnsNilForReduceMotion() async {
        #expect(TrainingScreen.feedbackAnimation(reduceMotion: true) == nil)
    }

    @MainActor
    @Test("feedbackAnimation returns animation when Reduce Motion is disabled")
    func feedbackAnimationReturnsAnimationNormally() async {
        #expect(TrainingScreen.feedbackAnimation(reduceMotion: false) != nil)
    }
}
