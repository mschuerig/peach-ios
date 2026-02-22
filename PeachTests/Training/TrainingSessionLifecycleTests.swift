import Testing
import AVFoundation
@testable import Peach

/// Tests for Story 3.4: Training Interruption and App Lifecycle Handling
@Suite("TrainingSession Lifecycle Tests")
struct TrainingSessionLifecycleTests {

    // MARK: - Test Fixtures

    @MainActor
    func makeTrainingSession() -> (TrainingSession, MockNotePlayer, MockTrainingDataStore) {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()
        let observers: [ComparisonObserver] = [mockDataStore, profile]
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: observers
        )
        return (session, mockPlayer, mockDataStore)
    }

    // MARK: - Data Integrity Tests (AC#4)

    @MainActor
    @Test("stop() during playingNote1 discards incomplete comparison")
    func stopDuringNote1DiscardsComparison() async {
        let (session, mockPlayer, mockDataStore) = makeTrainingSession()

        var stateWhenPlayCalled: TrainingState?
        mockPlayer.onPlayCalled = {
            // Capture state and stop immediately when first note starts
            if stateWhenPlayCalled == nil {
                stateWhenPlayCalled = session.state
                session.stop()
            }
        }

        session.startTraining()
        await Task.yield()  // Let training task start

        // Verify we captured playingNote1 state
        #expect(stateWhenPlayCalled == .playingNote1)

        // Verify no data was saved
        #expect(mockDataStore.saveCallCount == 0)
        #expect(session.state == .idle)
    }

    @MainActor
    @Test("stop() during playingNote2 discards incomplete comparison")
    func stopDuringNote2DiscardsComparison() async throws {
        let (session, mockPlayer, mockDataStore) = makeTrainingSession()

        mockPlayer.instantPlayback = false
        mockPlayer.simulatedPlaybackDuration = 0.5

        var noteCount = 0
        mockPlayer.onPlayCalled = {
            noteCount += 1
            if noteCount == 2 {
                session.stop()
            }
        }

        session.startTraining()
        try await waitForState(session, .idle)

        #expect(mockDataStore.saveCallCount == 0)
        #expect(session.state == .idle)
    }

    @MainActor
    @Test("stop() during awaitingAnswer discards incomplete comparison")
    func stopDuringAwaitingAnswerDiscardsComparison() async throws {
        let (session, _, mockDataStore) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(session.state == .awaitingAnswer)

        session.stop()

        #expect(mockDataStore.saveCallCount == 0)
        #expect(session.state == .idle)
    }

    @MainActor
    @Test("stop() during showingFeedback preserves already-saved data")
    func stopDuringFeedbackPreservesData() async throws {
        let (session, _, mockDataStore) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        #expect(session.state == .showingFeedback)
        #expect(mockDataStore.saveCallCount == 1)

        session.stop()

        #expect(mockDataStore.saveCallCount == 1)
        #expect(mockDataStore.lastSavedRecord != nil)
        #expect(session.state == .idle)
    }

    // MARK: - stop() Behavior Tests

    @MainActor
    @Test("stop() clears feedback state")
    func stopClearsFeedbackState() async throws {
        let (session, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: false)
        #expect(session.showFeedback == true)

        session.stop()

        #expect(session.showFeedback == false)
        #expect(session.isLastAnswerCorrect == nil)
    }

    @MainActor
    @Test("stop() is safe to call multiple times")
    func stopIsSafeToCallMultipleTimes() {
        let (session, _, _) = makeTrainingSession()

        // Call stop when already idle
        session.stop()
        #expect(session.state == .idle)

        // Start training
        session.startTraining()

        // Stop multiple times
        session.stop()
        #expect(session.state == .idle)

        session.stop()
        #expect(session.state == .idle)

        // Should not crash or cause issues
    }

    @MainActor
    @Test("stop() calls notePlayer.stop()")
    func stopCallsNotePlayerStop() async throws {
        let (session, mockPlayer, _) = makeTrainingSession()

        session.startTraining()
        try await waitForPlayCallCount(mockPlayer, 1)

        mockPlayer.stopCallCount = 0

        session.stop()
        await Task.yield()

        #expect(mockPlayer.stopCallCount >= 1)
    }

    // MARK: - Navigation-Based Stop Tests

    @MainActor
    @Test("Simulated onDisappear triggers stop")
    func simulatedOnDisappearTriggersStop() async throws {
        let (session, mockPlayer, _) = makeTrainingSession()

        session.startTraining()
        try await waitForPlayCallCount(mockPlayer, 1)

        #expect(session.state != .idle)

        session.stop()

        #expect(session.state == .idle)
    }

    // MARK: - Edge Case Tests

    @MainActor
    @Test("Rapid stop and start sequence")
    func rapidStopAndStartSequence() async throws {
        let (session, mockPlayer, _) = makeTrainingSession()

        session.startTraining()
        await Task.yield()

        session.stop()
        #expect(session.state == .idle)

        mockPlayer.reset()
        session.startTraining()
        try await waitForPlayCallCount(mockPlayer, 1)

        #expect(session.state != .idle)
        #expect(mockPlayer.playCallCount >= 1)
    }

    @MainActor
    @Test("stop() during transition between states")
    func stopDuringStateTransition() async {
        let (session, _, mockDataStore) = makeTrainingSession()

        session.startTraining()
        await Task.yield()

        session.stop()

        #expect(session.state == .idle)
        #expect(mockDataStore.saveCallCount == 0)
    }
}
