import Testing
@testable import Peach

/// Tests for Story 3.4: Training Interruption and App Lifecycle Handling
@Suite("PitchDiscriminationSession Lifecycle Tests")
struct PitchDiscriminationSessionLifecycleTests {

    // MARK: - Data Integrity Tests (AC#4)

    @Test("stop() during playingReferenceNote discards incomplete comparison")
    func stopDuringReferenceNoteDiscardsComparison() async {
        let f = makePitchDiscriminationSession()

        var stateWhenPlayCalled: PitchDiscriminationSessionState?
        f.mockPlayer.onPlayCalled = {
            // Capture state and stop immediately when first note starts
            if stateWhenPlayCalled == nil {
                stateWhenPlayCalled = f.session.state
                f.session.stop()
            }
        }

        f.session.start(settings: defaultTestSettings)
        await Task.yield()  // Let training task start

        // Verify we captured playingReferenceNote state
        #expect(stateWhenPlayCalled == .playingReferenceNote)

        // Verify no data was saved
        #expect(f.mockDataStore.saveCallCount == 0)
        #expect(f.session.state == .idle)
    }

    @Test("stop() during playingTargetNote discards incomplete comparison")
    func stopDuringTargetNoteDiscardsComparison() async throws {
        let f = makePitchDiscriminationSession()

        f.mockPlayer.instantPlayback = false
        f.mockPlayer.simulatedPlaybackDuration = .milliseconds(500)

        var noteCount = 0
        f.mockPlayer.onPlayCalled = {
            noteCount += 1
            if noteCount == 2 {
                f.session.stop()
            }
        }

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .idle)

        #expect(f.mockDataStore.saveCallCount == 0)
        #expect(f.session.state == .idle)
    }

    @Test("stop() during awaitingAnswer discards incomplete comparison")
    func stopDuringAwaitingAnswerDiscardsComparison() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)

        f.session.stop()

        #expect(f.mockDataStore.saveCallCount == 0)
        #expect(f.session.state == .idle)
    }

    @Test("stop() during showingFeedback preserves already-saved data")
    func stopDuringFeedbackPreservesData() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
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

    @Test("stop() clears feedback state")
    func stopClearsFeedbackState() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)
        #expect(f.session.showFeedback == true)

        f.session.stop()

        #expect(f.session.showFeedback == false)
        #expect(f.session.isLastAnswerCorrect == nil)
    }

    @Test("stop() is safe to call multiple times")
    func stopIsSafeToCallMultipleTimes() async {
        let f = makePitchDiscriminationSession()

        // Call stop when already idle
        f.session.stop()
        #expect(f.session.state == .idle)

        // Start training
        f.session.start(settings: defaultTestSettings)

        // Stop multiple times
        f.session.stop()
        #expect(f.session.state == .idle)

        f.session.stop()
        #expect(f.session.state == .idle)

        // Should not crash or cause issues
    }

    @Test("stop() transitions to idle and cancels training")
    func stopTransitionsToIdleAndCancelsTraining() async {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        await f.mockPlayer.waitForPlay()

        f.session.stop()

        #expect(f.session.state == .idle)
    }

    // MARK: - Navigation-Based Stop Tests

    @Test("Simulated onDisappear triggers stop")
    func simulatedOnDisappearTriggersStop() async {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        await f.mockPlayer.waitForPlay()

        #expect(f.session.state != .idle)

        f.session.stop()

        #expect(f.session.state == .idle)
    }

    // MARK: - Edge Case Tests

    @Test("Rapid stop and start sequence")
    func rapidStopAndStartSequence() async {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        await Task.yield()

        f.session.stop()
        #expect(f.session.state == .idle)

        f.mockPlayer.reset()
        f.session.start(settings: defaultTestSettings)
        await f.mockPlayer.waitForPlay()

        #expect(f.session.state != .idle)
        #expect(f.mockPlayer.playCallCount >= 1)
    }

    @Test("stop() during transition between states")
    func stopDuringStateTransition() async {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        await Task.yield()

        f.session.stop()

        #expect(f.session.state == .idle)
        #expect(f.mockDataStore.saveCallCount == 0)
    }

    // MARK: - stopAll() Verification

    @Test("stop() calls notePlayer.stopAll() for audio cleanup")
    func stopCallsStopAll() async {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        await f.mockPlayer.waitForPlay()

        f.session.stop()

        await f.mockPlayer.waitForStopAll()
        #expect(f.mockPlayer.stopAllCallCount >= 1)
    }

    @Test("handleAnswer during target calls notePlayer.stopAll()")
    func handleAnswerDuringTargetCallsStopAll() async throws {
        let f = makePitchDiscriminationSession()
        f.mockPlayer.instantPlayback = false
        f.mockPlayer.simulatedPlaybackDuration = .milliseconds(500)

        var noteCount = 0
        f.mockPlayer.onPlayCalled = {
            noteCount += 1
            if noteCount == 2 {
                // Answer during note 2
                f.session.handleAnswer(isHigher: true)
            }
        }

        f.session.start(settings: defaultTestSettings)

        // Wait for feedback state (answer was given during target)
        try await waitForState(f.session, .showingFeedback)

        await f.mockPlayer.waitForStopAll()
        #expect(f.mockPlayer.stopAllCallCount >= 1)
    }
}
