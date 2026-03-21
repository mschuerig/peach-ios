import Testing
@testable import Peach

/// Tests for PitchDiscriminationSession state machine transitions and core training loop
@Suite("PitchDiscriminationSession Tests")
struct PitchDiscriminationSessionTests {

    // MARK: - State Transition Tests

    @Test("PitchDiscriminationSession starts in idle state")
    func startsInIdleState() {
        let f = makePitchDiscriminationSession()
        #expect(f.session.state == .idle)
    }

    @Test("start transitions from idle to playingNote1")
    func startTransitionsToPlayingNote1() async {
        let f = makePitchDiscriminationSession()

        var capturedState: PitchDiscriminationSessionState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.start(settings: defaultTestSettings)
        await Task.yield()

        #expect(capturedState == .playingNote1)
        #expect(f.mockPlayer.playCallCount >= 1)
    }

    @Test("PitchDiscriminationSession transitions from playingNote1 to playingNote2")
    func transitionsFromNote1ToNote2() async {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        await f.mockPlayer.waitForPlay(minCount: 2)

        #expect(f.mockPlayer.playCallCount >= 2)
        #expect(f.session.state == .playingNote2 || f.session.state == .awaitingAnswer)
    }

    @Test("PitchDiscriminationSession transitions from playingNote2 to awaitingAnswer")
    func transitionsFromNote2ToAwaitingAnswer() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @Test("handleAnswer transitions to showingFeedback")
    func handleAnswerTransitionsToShowingFeedback() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)
    }

    @Test("PitchDiscriminationSession loops back to playingNote1 after feedback")
    func loopsBackAfterFeedback() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)

        await f.mockPlayer.waitForPlay(minCount: 3)

        #expect(f.mockPlayer.playCallCount >= 3)
    }

    @Test("stop() transitions to idle from any state")
    func stopTransitionsToIdle() async {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        await f.mockPlayer.waitForPlay()

        f.session.stop()

        #expect(f.session.state == .idle)
    }

    @Test("Audio error transitions to idle")
    func audioErrorTransitionsToIdle() async throws {
        let f = makePitchDiscriminationSession()
        f.mockPlayer.shouldThrowError = true
        f.mockPlayer.errorToThrow = .engineStartFailed("Test error")

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .idle)

        #expect(f.session.state == .idle)
    }

    // MARK: - Timing and Coordination Tests

    @Test("Buttons disabled during playingNote1")
    func buttonsDisabledDuringNote1() async {
        let f = makePitchDiscriminationSession()

        var capturedState: PitchDiscriminationSessionState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.start(settings: defaultTestSettings)
        await Task.yield()

        #expect(capturedState == .playingNote1)
    }

    @Test("Buttons enabled during awaitingAnswer")
    func buttonsEnabledDuringAwaitingAnswer() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @Test("PitchDiscriminationSession completes full comparison loop")
    func completesFullLoop() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        await f.mockPlayer.waitForPlay(minCount: 3)

        #expect(f.mockPlayer.playCallCount >= 3)
        #expect(f.mockDataStore.saveCallCount == 1)
    }

    // MARK: - Interval Context Tests (Story 23.2)

    @Test("start passes intervals to strategy")
    func startPassesIntervalsToStrategy() async throws {
        let f = makePitchDiscriminationSession(
            comparisons: [
                PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ]
        )

        f.session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.up(.perfectFifth)]))
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.lastReceivedInterval == .up(.perfectFifth))
    }

    @Test("currentInterval is nil when idle")
    func currentIntervalNilWhenIdle() {
        let f = makePitchDiscriminationSession()
        #expect(f.session.currentInterval == nil)
    }

    @Test("currentInterval is set after starting with prime")
    func currentIntervalSetAfterStartPrime() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .prime)
    }

    @Test("currentInterval is set after starting with perfectFifth")
    func currentIntervalSetAfterStartFifth() async throws {
        let f = makePitchDiscriminationSession(
            comparisons: [
                PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ]
        )

        f.session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.up(.perfectFifth)]))
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .up(.perfectFifth))
    }

    @Test("isIntervalMode is false for prime")
    func isIntervalModeFalseForPrime() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(!f.session.isIntervalMode)
    }

    @Test("isIntervalMode is true for perfectFifth")
    func isIntervalModeTrueForFifth() async throws {
        let f = makePitchDiscriminationSession(
            comparisons: [
                PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(50.0)))
            ]
        )

        f.session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.up(.perfectFifth)]))
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.isIntervalMode)
    }

    @Test("currentInterval cleared after stop")
    func currentIntervalClearedAfterStop() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.stop()

        #expect(f.session.currentInterval == nil)
    }

    @Test("tuningSystem from userSettings flows through to CompletedPitchDiscriminationTrial record")
    func tuningSystemFlowsToRecord() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
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

        let session = PitchDiscriminationSession(
            notePlayer: mockPlayer,
            strategy: strategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.up(.perfectFifth)]))
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        let record = mockDataStore.lastSavedRecord
        #expect(record != nil)
        // Target note should be 7 semitones above reference note
        #expect(record!.targetNote == record!.referenceNote + 7)
    }

    @Test("start with perfectFifth sets currentInterval to perfectFifth")
    func startWithPerfectFifthSetsCurrentInterval() async throws {
        let f = makePitchDiscriminationSession()
        f.session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: [.up(.perfectFifth)]))
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.currentInterval == .up(.perfectFifth))
        #expect(f.session.isIntervalMode)
        f.session.stop()
    }

    @Test("start with multiple intervals picks from the provided set")
    func startWithMultipleIntervals() async throws {
        let f = makePitchDiscriminationSession()
        let intervals: Set<DirectedInterval> = [.prime, .up(.perfectFifth)]
        f.session.start(settings: PitchDiscriminationSettings(referencePitch: Frequency(440.0), intervals: intervals))
        try await waitForState(f.session, .awaitingAnswer)

        let interval = try #require(f.session.currentInterval)
        #expect(intervals.contains(interval))
        f.session.stop()
    }

    // MARK: - Note Gap Tests

    @Test("plays notes without gap when noteGap is zero")
    func playsNotesWithoutGap() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playCallCount == 2)
    }

    @Test("plays both notes with positive noteGap and reaches awaitingAnswer")
    func playsBothNotesWithPositiveGap() async throws {
        let f = makePitchDiscriminationSession()

        var gapSettings = defaultTestSettings
        gapSettings.noteGap = .milliseconds(50)

        f.session.start(settings: gapSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playCallCount == 2)
    }

    @Test("stops during note gap aborts comparison")
    func stopsDuringNoteGapAbortsComparison() async throws {
        let f = makePitchDiscriminationSession()
        f.mockPlayer.instantPlayback = true

        var gapSettings = defaultTestSettings
        gapSettings.noteGap = .seconds(5)

        f.session.start(settings: gapSettings)
        await f.mockPlayer.waitForPlay(minCount: 1)

        // Allow session task to proceed past guard into the 5s gap sleep
        try await Task.sleep(for: .milliseconds(50))

        f.session.stop()

        #expect(f.session.state == .idle)
        // Only note 1 should have played
        #expect(f.mockPlayer.playCallCount == 1)
    }

    // MARK: - Tuning System Visibility Tests (Story 30.3)

    @Test("sessionTuningSystem is equalTemperament by default")
    func sessionTuningSystemDefault() async {
        let f = makePitchDiscriminationSession()
        #expect(f.session.sessionTuningSystem == .equalTemperament)
    }

    @Test("sessionTuningSystem reflects settings after start")
    func sessionTuningSystemFromSettings() async {
        let f = makePitchDiscriminationSession()
        f.mockPlayer.instantPlayback = true
        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            tuningSystem: .justIntonation
        )
        f.session.start(settings: settings)
        await Task.yield()
        #expect(f.session.sessionTuningSystem == .justIntonation)
        f.session.stop()
    }

    @Test("sessionTuningSystem resets to equalTemperament after stop")
    func sessionTuningSystemResetsOnStop() async {
        let f = makePitchDiscriminationSession()
        f.mockPlayer.instantPlayback = true
        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            tuningSystem: .justIntonation
        )
        f.session.start(settings: settings)
        await Task.yield()
        f.session.stop()
        #expect(f.session.sessionTuningSystem == .equalTemperament)
    }
}
