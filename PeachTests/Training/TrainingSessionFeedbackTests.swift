import Testing
@testable import Peach

/// Tests for TrainingSession feedback state management (Story 3.3)
@Suite("TrainingSession Feedback Tests")
struct TrainingSessionFeedbackTests {

    // MARK: - Feedback State Tests

    @MainActor
    @Test("Initial feedback state is hidden")
    func initialFeedbackState() async {
        let f = makeTrainingSession(includeHaptic: true)

        #expect(f.session.showFeedback == false)
        #expect(f.session.isLastAnswerCorrect == nil)
    }

    @MainActor
    @Test("Feedback shows after correct answer")
    func feedbackShowsAfterCorrectAnswer() async throws {
        let f = makeTrainingSession(includeHaptic: true)

        // Start training
        f.session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(f.session, .awaitingAnswer)

        // Answer correctly by checking which note was higher
        try #require(f.mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(f.mockPlayer.playHistory.count)")
        let isSecondHigher = f.mockPlayer.playHistory[1].frequency > f.mockPlayer.playHistory[0].frequency
        f.session.handleAnswer(isHigher: isSecondHigher)

        // Verify feedback state is set correctly
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect == true)
    }

    @MainActor
    @Test("Feedback shows after incorrect answer")
    func feedbackShowsAfterIncorrectAnswer() async throws {
        let f = makeTrainingSession(includeHaptic: true)

        // Start training
        f.session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(f.session, .awaitingAnswer)

        // Answer incorrectly (opposite of what the comparison says)
        try #require(f.mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(f.mockPlayer.playHistory.count)")
        let isSecondHigher = f.mockPlayer.playHistory[1].frequency > f.mockPlayer.playHistory[0].frequency
        // Answer incorrectly by saying the opposite
        f.session.handleAnswer(isHigher: !isSecondHigher)

        // Verify feedback state is set correctly
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect == false)
    }

    @MainActor
    @Test("Feedback clears before next comparison")
    func feedbackClearsBeforeNextComparison() async throws {
        let f = makeTrainingSession(includeHaptic: true)

        // Start training
        f.session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(f.session, .awaitingAnswer)

        // Answer (correct or incorrect doesn't matter)
        try #require(f.mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(f.mockPlayer.playHistory.count)")
        let isSecondHigher = f.mockPlayer.playHistory[1].frequency > f.mockPlayer.playHistory[0].frequency
        f.session.handleAnswer(isHigher: isSecondHigher)

        // Verify feedback is showing
        #expect(f.session.showFeedback == true)

        // Wait for feedback to clear (polls until false)
        try await waitForFeedbackToClear(f.session)

        // Verify feedback has cleared
        #expect(f.session.showFeedback == false)
    }

    // MARK: - Haptic Feedback Tests

    @MainActor
    @Test("Haptic fires on incorrect answer")
    func hapticFiresOnIncorrectAnswer() async throws {
        let f = makeTrainingSession(includeHaptic: true)

        // Start training
        f.session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(f.session, .awaitingAnswer)

        // Answer incorrectly
        try #require(f.mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(f.mockPlayer.playHistory.count)")
        let isSecondHigher = f.mockPlayer.playHistory[1].frequency > f.mockPlayer.playHistory[0].frequency
        f.session.handleAnswer(isHigher: !isSecondHigher)

        // Verify haptic was triggered
        #expect(f.mockHaptic!.incorrectFeedbackCount == 1)
    }

    @MainActor
    @Test("Haptic does NOT fire on correct answer")
    func hapticDoesNotFireOnCorrectAnswer() async throws {
        let f = makeTrainingSession(includeHaptic: true)

        // Start training
        f.session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(f.session, .awaitingAnswer)

        // Answer correctly
        try #require(f.mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(f.mockPlayer.playHistory.count)")
        let isSecondHigher = f.mockPlayer.playHistory[1].frequency > f.mockPlayer.playHistory[0].frequency
        f.session.handleAnswer(isHigher: isSecondHigher)

        // Verify haptic was NOT triggered
        #expect(f.mockHaptic!.incorrectFeedbackCount == 0)
    }

    @MainActor
    @Test("Feedback state clears when training stops")
    func feedbackClearsWhenTrainingStops() async throws {
        let f = makeTrainingSession(includeHaptic: true)

        // Start training
        f.session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(f.session, .awaitingAnswer)

        // Answer to trigger feedback
        try #require(f.mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(f.mockPlayer.playHistory.count)")
        let isSecondHigher = f.mockPlayer.playHistory[1].frequency > f.mockPlayer.playHistory[0].frequency
        f.session.handleAnswer(isHigher: isSecondHigher)

        // Verify feedback is showing
        #expect(f.session.showFeedback == true)
        #expect(f.session.isLastAnswerCorrect != nil)

        // Stop training
        f.session.stop()

        // Verify feedback state is cleared
        #expect(f.session.showFeedback == false)
        #expect(f.session.isLastAnswerCorrect == nil)
    }
}
