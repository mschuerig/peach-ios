import Testing
@testable import Peach

/// Tests for feedback indicator state transitions when correctness changes between cycles
///
/// These tests verify the state contract that prevents feedback icon flicker:
/// when showFeedback becomes true, isLastAnswerCorrect must reflect the CURRENT answer.
@Suite("TrainingScreen Feedback Tests")
struct TrainingScreenFeedbackTests {

    // MARK: - Subtask 1.1: Correct icon shown immediately on correctness change

    @MainActor
    @Test("feedback reflects current correctness after incorrect-to-correct change")
    func feedbackReflectsCorrectnessAfterIncorrectToCorrect() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        // Answer incorrectly (answer "lower" when second note is higher)
        f.session.handleAnswer(isHigher: false)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.isLastAnswerCorrect == false)

        // Wait for feedback cycle to complete and next comparison
        try await waitForFeedbackToClear(f.session)
        try await waitForState(f.session, .awaitingAnswer)

        // Answer correctly (answer "lower" when second note is lower)
        f.session.handleAnswer(isHigher: false)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect == true)
    }

    @MainActor
    @Test("feedback reflects current correctness after correct-to-incorrect change")
    func feedbackReflectsCorrectnessAfterCorrectToIncorrect() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        // Answer correctly (answer "higher" when second note is higher)
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.isLastAnswerCorrect == true)

        // Wait for feedback cycle to complete and next comparison
        try await waitForFeedbackToClear(f.session)
        try await waitForState(f.session, .awaitingAnswer)

        // Answer incorrectly (answer "higher" when second note is lower)
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect == false)
    }

    // MARK: - Subtask 1.2: No stale icon state between feedback cycles

    @MainActor
    @Test("showFeedback is false between feedback cycles")
    func showFeedbackIsFalseBetweenCycles() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        // Complete first answer
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.showFeedback == true)

        // Wait for feedback to clear
        try await waitForFeedbackToClear(f.session)
        #expect(f.session.showFeedback == false)

        // While awaiting next answer, feedback must remain off
        try await waitForState(f.session, .awaitingAnswer)
        #expect(f.session.showFeedback == false)
    }

    @MainActor
    @Test("first answer of session shows feedback without stale state")
    func firstAnswerShowsFeedbackCleanly() async throws {
        let f = makeTrainingSession()

        // Before training, no feedback state
        #expect(f.session.showFeedback == false)
        #expect(f.session.isLastAnswerCorrect == nil)

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        // First answer ever — no previous state to leak
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect == true)
    }

    // MARK: - Subtask 1.3: Same correctness between consecutive answers (AC #3)

    @MainActor
    @Test("feedback displays correctly on consecutive same-correctness answers")
    func feedbackDisplaysCorrectlyOnConsecutiveSameCorrectness() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        // First answer: correct (answer "higher" when second note is higher)
        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect == true)

        // Wait for feedback cycle to complete and next comparison
        try await waitForFeedbackToClear(f.session)
        try await waitForState(f.session, .awaitingAnswer)

        // Second answer: also correct (answer "lower" when second note is lower)
        f.session.handleAnswer(isHigher: false)
        #expect(f.session.state == .showingFeedback)
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect == true)
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
