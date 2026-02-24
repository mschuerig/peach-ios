import Testing
@testable import Peach

/// Tests for Story 3.4: Training Interruption and App Lifecycle Handling
@Suite("TrainingSession Lifecycle Tests")
struct TrainingSessionLifecycleTests {

    // MARK: - Data Integrity Tests (AC#4)

    @MainActor
    @Test("stop() during playingNote1 discards incomplete comparison")
    func stopDuringNote1DiscardsComparison() async {
        let f = makeTrainingSession()

        var stateWhenPlayCalled: TrainingState?
        f.mockPlayer.onPlayCalled = {
            // Capture state and stop immediately when first note starts
            if stateWhenPlayCalled == nil {
                stateWhenPlayCalled = f.session.state
                f.session.stop()
            }
        }

        f.session.startTraining()
        await Task.yield()  // Let training task start

        // Verify we captured playingNote1 state
        #expect(stateWhenPlayCalled == .playingNote1)

        // Verify no data was saved
        #expect(f.mockDataStore.saveCallCount == 0)
        #expect(f.session.state == .idle)
    }

    @MainActor
    @Test("stop() during playingNote2 discards incomplete comparison")
    func stopDuringNote2DiscardsComparison() async throws {
        let f = makeTrainingSession()

        f.mockPlayer.instantPlayback = false
        f.mockPlayer.simulatedPlaybackDuration = 0.5

        var noteCount = 0
        f.mockPlayer.onPlayCalled = {
            noteCount += 1
            if noteCount == 2 {
                f.session.stop()
            }
        }

        f.session.startTraining()
        try await waitForState(f.session, .idle)

        #expect(f.mockDataStore.saveCallCount == 0)
        #expect(f.session.state == .idle)
    }

    @MainActor
    @Test("stop() during awaitingAnswer discards incomplete comparison")
    func stopDuringAwaitingAnswerDiscardsComparison() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)

        f.session.stop()

        #expect(f.mockDataStore.saveCallCount == 0)
        #expect(f.session.state == .idle)
    }

    @MainActor
    @Test("stop() during showingFeedback preserves already-saved data")
    func stopDuringFeedbackPreservesData() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)
        #expect(f.mockDataStore.saveCallCount == 1)

        f.session.stop()

        #expect(f.mockDataStore.saveCallCount == 1)
        #expect(f.mockDataStore.lastSavedRecord != nil)
        #expect(f.session.state == .idle)
    }

    // MARK: - stop() Behavior Tests

    @MainActor
    @Test("stop() clears feedback state")
    func stopClearsFeedbackState() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)
        #expect(f.session.showFeedback == true)

        f.session.stop()

        #expect(f.session.showFeedback == false)
        #expect(f.session.isLastAnswerCorrect == nil)
    }

    @MainActor
    @Test("stop() is safe to call multiple times")
    func stopIsSafeToCallMultipleTimes() {
        let f = makeTrainingSession()

        // Call stop when already idle
        f.session.stop()
        #expect(f.session.state == .idle)

        // Start training
        f.session.startTraining()

        // Stop multiple times
        f.session.stop()
        #expect(f.session.state == .idle)

        f.session.stop()
        #expect(f.session.state == .idle)

        // Should not crash or cause issues
    }

    @MainActor
    @Test("stop() calls notePlayer.stop()")
    func stopCallsNotePlayerStop() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForPlayCallCount(f.mockPlayer, 1)

        f.mockPlayer.stopCallCount = 0

        f.session.stop()
        await Task.yield()

        #expect(f.mockPlayer.stopCallCount >= 1)
    }

    // MARK: - Navigation-Based Stop Tests

    @MainActor
    @Test("Simulated onDisappear triggers stop")
    func simulatedOnDisappearTriggersStop() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForPlayCallCount(f.mockPlayer, 1)

        #expect(f.session.state != .idle)

        f.session.stop()

        #expect(f.session.state == .idle)
    }

    // MARK: - Edge Case Tests

    @MainActor
    @Test("Rapid stop and start sequence")
    func rapidStopAndStartSequence() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        await Task.yield()

        f.session.stop()
        #expect(f.session.state == .idle)

        f.mockPlayer.reset()
        f.session.startTraining()
        try await waitForPlayCallCount(f.mockPlayer, 1)

        #expect(f.session.state != .idle)
        #expect(f.mockPlayer.playCallCount >= 1)
    }

    @MainActor
    @Test("stop() during transition between states")
    func stopDuringStateTransition() async {
        let f = makeTrainingSession()

        f.session.startTraining()
        await Task.yield()

        f.session.stop()

        #expect(f.session.state == .idle)
        #expect(f.mockDataStore.saveCallCount == 0)
    }
}
