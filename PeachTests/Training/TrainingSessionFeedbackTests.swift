import Testing
@testable import Peach

/// Tests for TrainingSession feedback state management (Story 3.3)
@Suite("TrainingSession Feedback Tests")
struct TrainingSessionFeedbackTests {

    // MARK: - Test Fixtures

    @MainActor
    func makeTrainingSession() -> (TrainingSession, MockNotePlayer, MockTrainingDataStore, MockHapticFeedbackManager) {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let mockHaptic = MockHapticFeedbackManager()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()
        let observers: [ComparisonObserver] = [mockDataStore, profile, mockHaptic]
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: observers
        )
        return (session, mockPlayer, mockDataStore, mockHaptic)
    }

    // MARK: - Feedback State Tests

    @MainActor
    @Test("Initial feedback state is hidden")
    func initialFeedbackState() async {
        let (session, _, _, _) = makeTrainingSession()

        #expect(session.showFeedback == false)
        #expect(session.isLastAnswerCorrect == nil)
    }

    @MainActor
    @Test("Feedback shows after correct answer")
    func feedbackShowsAfterCorrectAnswer() async throws {
        let (session, mockPlayer, _, _) = makeTrainingSession()

        // Start training
        session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(session, .awaitingAnswer)

        // Answer correctly by checking which note was higher
        try #require(mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(mockPlayer.playHistory.count)")
        let isSecondHigher = mockPlayer.playHistory[1].frequency > mockPlayer.playHistory[0].frequency
        session.handleAnswer(isHigher: isSecondHigher)

        // Verify feedback state is set correctly
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect == true)
    }

    @MainActor
    @Test("Feedback shows after incorrect answer")
    func feedbackShowsAfterIncorrectAnswer() async throws {
        let (session, mockPlayer, _, _) = makeTrainingSession()

        // Start training
        session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(session, .awaitingAnswer)

        // Answer incorrectly (opposite of what the comparison says)
        try #require(mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(mockPlayer.playHistory.count)")
        let isSecondHigher = mockPlayer.playHistory[1].frequency > mockPlayer.playHistory[0].frequency
        // Answer incorrectly by saying the opposite
        session.handleAnswer(isHigher: !isSecondHigher)

        // Verify feedback state is set correctly
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect == false)
    }

    @MainActor
    @Test("Feedback clears before next comparison")
    func feedbackClearsBeforeNextComparison() async throws {
        let (session, mockPlayer, _, _) = makeTrainingSession()

        // Start training
        session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(session, .awaitingAnswer)

        // Answer (correct or incorrect doesn't matter)
        try #require(mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(mockPlayer.playHistory.count)")
        let isSecondHigher = mockPlayer.playHistory[1].frequency > mockPlayer.playHistory[0].frequency
        session.handleAnswer(isHigher: isSecondHigher)

        // Verify feedback is showing
        #expect(session.showFeedback == true)

        // Wait for feedback to clear (polls until false)
        try await waitForFeedbackToClear(session)

        // Verify feedback has cleared
        #expect(session.showFeedback == false)
    }

    // MARK: - Haptic Feedback Tests

    @MainActor
    @Test("Haptic fires on incorrect answer")
    func hapticFiresOnIncorrectAnswer() async throws {
        let (session, mockPlayer, _, mockHaptic) = makeTrainingSession()

        // Start training
        session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(session, .awaitingAnswer)

        // Answer incorrectly
        try #require(mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(mockPlayer.playHistory.count)")
        let isSecondHigher = mockPlayer.playHistory[1].frequency > mockPlayer.playHistory[0].frequency
        session.handleAnswer(isHigher: !isSecondHigher)

        // Verify haptic was triggered
        #expect(mockHaptic.incorrectFeedbackCount == 1)
    }

    @MainActor
    @Test("Haptic does NOT fire on correct answer")
    func hapticDoesNotFireOnCorrectAnswer() async throws {
        let (session, mockPlayer, _, mockHaptic) = makeTrainingSession()

        // Start training
        session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(session, .awaitingAnswer)

        // Answer correctly
        try #require(mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(mockPlayer.playHistory.count)")
        let isSecondHigher = mockPlayer.playHistory[1].frequency > mockPlayer.playHistory[0].frequency
        session.handleAnswer(isHigher: isSecondHigher)

        // Verify haptic was NOT triggered
        #expect(mockHaptic.incorrectFeedbackCount == 0)
    }

    @MainActor
    @Test("Feedback state clears when training stops")
    func feedbackClearsWhenTrainingStops() async throws {
        let (session, mockPlayer, _, _) = makeTrainingSession()

        // Start training
        session.startTraining()

        // Wait for awaitingAnswer state
        try await waitForState(session, .awaitingAnswer)

        // Answer to trigger feedback
        try #require(mockPlayer.playHistory.count >= 2,
            "Expected 2 notes to be played, got \(mockPlayer.playHistory.count)")
        let isSecondHigher = mockPlayer.playHistory[1].frequency > mockPlayer.playHistory[0].frequency
        session.handleAnswer(isHigher: isSecondHigher)

        // Verify feedback is showing
        #expect(session.showFeedback == true)
        #expect(session.isLastAnswerCorrect != nil)

        // Stop training
        session.stop()

        // Verify feedback state is cleared
        #expect(session.showFeedback == false)
        #expect(session.isLastAnswerCorrect == nil)
    }
}
