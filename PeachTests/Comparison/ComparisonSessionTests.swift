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

        f.session.start()
        await Task.yield()

        #expect(capturedState == .playingNote1)
        #expect(f.mockPlayer.playCallCount >= 1)
    }

    @Test("ComparisonSession transitions from playingNote1 to playingNote2")
    func transitionsFromNote1ToNote2() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForPlayCallCount(f.mockPlayer, 2)

        #expect(f.mockPlayer.playCallCount >= 2)
        #expect(f.session.state == .playingNote2 || f.session.state == .awaitingAnswer)
    }

    @Test("ComparisonSession transitions from playingNote2 to awaitingAnswer")
    func transitionsFromNote2ToAwaitingAnswer() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @Test("handleAnswer transitions to showingFeedback")
    func handleAnswerTransitionsToShowingFeedback() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)
    }

    @Test("ComparisonSession loops back to playingNote1 after feedback")
    func loopsBackAfterFeedback() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)

        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
    }

    @Test("stop() transitions to idle from any state")
    func stopTransitionsToIdle() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForPlayCallCount(f.mockPlayer, 1)

        f.session.stop()

        #expect(f.session.state == .idle)
    }

    @Test("Audio error transitions to idle")
    func audioErrorTransitionsToIdle() async throws {
        let f = makeComparisonSession()
        f.mockPlayer.shouldThrowError = true
        f.mockPlayer.errorToThrow = .engineStartFailed("Test error")

        f.session.start()
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

        f.session.start()
        await Task.yield()

        #expect(capturedState == .playingNote1)
    }

    @Test("Buttons enabled during awaitingAnswer")
    func buttonsEnabledDuringAwaitingAnswer() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @Test("ComparisonSession completes full comparison loop")
    func completesFullLoop() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
        #expect(f.mockDataStore.saveCallCount == 1)
    }

    // MARK: - Interval Context Tests (Story 23.2)

    @Test("start reads intervals from userSettings")
    func startReadsIntervalsFromSettings() async throws {
        let settings = MockUserSettings()
        settings.intervals = [.perfectFifth]
        let f = makeComparisonSession(
            comparisons: [
                Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ],
            userSettings: settings
        )

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.lastReceivedInterval == .perfectFifth)
    }

    @Test("currentInterval is nil when idle")
    func currentIntervalNilWhenIdle() {
        let f = makeComparisonSession()
        #expect(f.session.currentInterval == nil)
    }

    @Test("currentInterval is set after starting with prime")
    func currentIntervalSetAfterStartPrime() async throws {
        let settings = MockUserSettings()
        settings.intervals = [.prime]
        let f = makeComparisonSession(userSettings: settings)

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .prime)
    }

    @Test("currentInterval is set after starting with perfectFifth")
    func currentIntervalSetAfterStartFifth() async throws {
        let settings = MockUserSettings()
        settings.intervals = [.perfectFifth]
        let f = makeComparisonSession(
            comparisons: [
                Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ],
            userSettings: settings
        )

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .perfectFifth)
    }

    @Test("isIntervalMode is false for prime")
    func isIntervalModeFalseForPrime() async throws {
        let settings = MockUserSettings()
        settings.intervals = [.prime]
        let f = makeComparisonSession(userSettings: settings)

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(!f.session.isIntervalMode)
    }

    @Test("isIntervalMode is true for perfectFifth")
    func isIntervalModeTrueForFifth() async throws {
        let settings = MockUserSettings()
        settings.intervals = [.perfectFifth]
        let f = makeComparisonSession(
            comparisons: [
                Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ],
            userSettings: settings
        )

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.isIntervalMode)
    }

    @Test("currentInterval cleared after stop")
    func currentIntervalClearedAfterStop() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.stop()

        #expect(f.session.currentInterval == nil)
    }

    @Test("CompletedComparison uses session tuningSystem not hardcoded")
    func completedComparisonUsesSessionTuningSystem() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        let record = f.mockDataStore.lastSavedRecord
        #expect(record != nil)
        #expect(record?.tuningSystem == "equalTemperament")
    }

    @Test("interval comparison with perfectFifth produces correct target")
    func intervalComparisonPerfectFifth() async throws {
        let settings = MockUserSettings()
        settings.intervals = [.perfectFifth]
        let strategy = KazezNoteStrategy()
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()

        let session = ComparisonSession(
            notePlayer: mockPlayer,
            strategy: strategy,
            profile: profile,
            userSettings: settings,
            observers: [mockDataStore, profile]
        )

        session.start()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        let record = mockDataStore.lastSavedRecord
        #expect(record != nil)
        // Target note should be 7 semitones above reference note
        #expect(record!.targetNote == record!.referenceNote + 7)
    }
}
