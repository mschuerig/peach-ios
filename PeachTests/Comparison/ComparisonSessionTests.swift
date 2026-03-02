import Testing
@testable import Peach

/// Tests for ComparisonSession state machine transitions and core training loop
@Suite("ComparisonSession Tests")
struct ComparisonSessionTests {

    // MARK: - State Transition Tests

    @Test("ComparisonSession starts in idle state")
    func startsInIdleState() {
        let f = makeComparisonSession()
        #expect(f.session.state == .idle)
    }

    @Test("start transitions from idle to playingNote1")
    func startTransitionsToPlayingNote1() async {
        let f = makeComparisonSession()

        var capturedState: ComparisonSessionState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.start(intervals: [.prime])
        await Task.yield()

        #expect(capturedState == .playingNote1)
        #expect(f.mockPlayer.playCallCount >= 1)
    }

    @Test("ComparisonSession transitions from playingNote1 to playingNote2")
    func transitionsFromNote1ToNote2() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForPlayCallCount(f.mockPlayer, 2)

        #expect(f.mockPlayer.playCallCount >= 2)
        #expect(f.session.state == .playingNote2 || f.session.state == .awaitingAnswer)
    }

    @Test("ComparisonSession transitions from playingNote2 to awaitingAnswer")
    func transitionsFromNote2ToAwaitingAnswer() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @Test("handleAnswer transitions to showingFeedback")
    func handleAnswerTransitionsToShowingFeedback() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)
    }

    @Test("ComparisonSession loops back to playingNote1 after feedback")
    func loopsBackAfterFeedback() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)

        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
    }

    @Test("stop() transitions to idle from any state")
    func stopTransitionsToIdle() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForPlayCallCount(f.mockPlayer, 1)

        f.session.stop()

        #expect(f.session.state == .idle)
    }

    @Test("Audio error transitions to idle")
    func audioErrorTransitionsToIdle() async throws {
        let f = makeComparisonSession()
        f.mockPlayer.shouldThrowError = true
        f.mockPlayer.errorToThrow = .engineStartFailed("Test error")

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .idle)

        #expect(f.session.state == .idle)
    }

    // MARK: - Timing and Coordination Tests

    @Test("Buttons disabled during playingNote1")
    func buttonsDisabledDuringNote1() async {
        let f = makeComparisonSession()

        var capturedState: ComparisonSessionState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.start(intervals: [.prime])
        await Task.yield()

        #expect(capturedState == .playingNote1)
    }

    @Test("Buttons enabled during awaitingAnswer")
    func buttonsEnabledDuringAwaitingAnswer() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @Test("ComparisonSession completes full comparison loop")
    func completesFullLoop() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
        #expect(f.mockDataStore.saveCallCount == 1)
    }

    // MARK: - Interval Context Tests (Story 23.2)

    @Test("start passes intervals to strategy")
    func startPassesIntervalsToStrategy() async throws {
        let f = makeComparisonSession(
            comparisons: [
                Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ]
        )

        f.session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.lastReceivedInterval == .up(.perfectFifth))
    }

    @Test("currentInterval is nil when idle")
    func currentIntervalNilWhenIdle() {
        let f = makeComparisonSession()
        #expect(f.session.currentInterval == nil)
    }

    @Test("currentInterval is set after starting with prime")
    func currentIntervalSetAfterStartPrime() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .prime)
    }

    @Test("currentInterval is set after starting with perfectFifth")
    func currentIntervalSetAfterStartFifth() async throws {
        let f = makeComparisonSession(
            comparisons: [
                Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ]
        )

        f.session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .up(.perfectFifth))
    }

    @Test("isIntervalMode is false for prime")
    func isIntervalModeFalseForPrime() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(!f.session.isIntervalMode)
    }

    @Test("isIntervalMode is true for perfectFifth")
    func isIntervalModeTrueForFifth() async throws {
        let f = makeComparisonSession(
            comparisons: [
                Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ]
        )

        f.session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.isIntervalMode)
    }

    @Test("currentInterval cleared after stop")
    func currentIntervalClearedAfterStop() async throws {
        let f = makeComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.stop()

        #expect(f.session.currentInterval == nil)
    }

    @Test("tuningSystem from userSettings flows through to CompletedComparison record")
    func tuningSystemFlowsToRecord() async throws {
        let settings = MockUserSettings()
        // Explicitly set tuningSystem to verify it flows from userSettings → session → record
        // (currently only .equalTemperament exists; test guards the flow path for future tuning systems)
        settings.tuningSystem = .equalTemperament
        let f = makeComparisonSession(userSettings: settings)

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        let record = f.mockDataStore.lastSavedRecord
        #expect(record != nil)
        #expect(record?.tuningSystem == "equalTemperament")
    }

    @Test("interval comparison with perfectFifth produces correct target")
    func intervalComparisonPerfectFifth() async throws {
        let strategy = KazezNoteStrategy()
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()

        let session = ComparisonSession(
            notePlayer: mockPlayer,
            strategy: strategy,
            profile: profile,
            userSettings: MockUserSettings(),
            observers: [mockDataStore, profile]
        )

        session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        let record = mockDataStore.lastSavedRecord
        #expect(record != nil)
        // Target note should be 7 semitones above reference note
        #expect(record!.targetNote == record!.referenceNote + 7)
    }

    @Test("start with perfectFifth sets currentInterval to perfectFifth")
    func startWithPerfectFifthSetsCurrentInterval() async throws {
        let f = makeComparisonSession()
        f.session.start(intervals: [.up(.perfectFifth)])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .up(.perfectFifth))
        #expect(f.session.isIntervalMode)
        f.session.stop()
    }

    @Test("start with multiple intervals picks from the provided set")
    func startWithMultipleIntervals() async throws {
        let f = makeComparisonSession()
        let intervals: Set<DirectedInterval> = [.prime, .up(.perfectFifth)]
        f.session.start(intervals: intervals)
        try await waitForState(f.session, .awaitingAnswer)

        let interval = try #require(f.session.currentInterval)
        #expect(intervals.contains(interval))
        f.session.stop()
    }

    // MARK: - Tuning System Visibility Tests (Story 30.3)

    @Test("sessionTuningSystem is equalTemperament by default")
    func sessionTuningSystemDefault() async {
        let f = makeComparisonSession()
        #expect(f.session.sessionTuningSystem == .equalTemperament)
    }

    @Test("sessionTuningSystem reflects userSettings after start")
    func sessionTuningSystemFromSettings() async {
        let f = makeComparisonSession()
        f.mockPlayer.instantPlayback = true
        f.mockSettings.tuningSystem = .justIntonation
        f.session.start(intervals: [.prime])
        await Task.yield()
        #expect(f.session.sessionTuningSystem == .justIntonation)
        f.session.stop()
    }
}
