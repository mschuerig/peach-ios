import Testing
@testable import Peach

/// Tests for TrainingSession state machine transitions and core training loop
@Suite("TrainingSession Tests")
struct TrainingSessionTests {

    // MARK: - State Transition Tests

    @MainActor
    @Test("TrainingSession starts in idle state")
    func startsInIdleState() {
        let f = makeTrainingSession()
        #expect(f.session.state == .idle)
    }

    @MainActor
    @Test("startTraining transitions from idle to playingNote1")
    func startTrainingTransitionsToPlayingNote1() async {
        let f = makeTrainingSession()

        var capturedState: TrainingState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.startTraining()
        await Task.yield()

        #expect(capturedState == .playingNote1)
        #expect(f.mockPlayer.playCallCount >= 1)
    }

    @MainActor
    @Test("TrainingSession transitions from playingNote1 to playingNote2")
    func transitionsFromNote1ToNote2() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForPlayCallCount(f.mockPlayer, 2)

        #expect(f.mockPlayer.playCallCount >= 2)
        #expect(f.session.state == .playingNote2 || f.session.state == .awaitingAnswer)
    }

    @MainActor
    @Test("TrainingSession transitions from playingNote2 to awaitingAnswer")
    func transitionsFromNote2ToAwaitingAnswer() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @MainActor
    @Test("handleAnswer transitions to showingFeedback")
    func handleAnswerTransitionsToShowingFeedback() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)
    }

    @MainActor
    @Test("TrainingSession loops back to playingNote1 after feedback")
    func loopsBackAfterFeedback() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)

        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
    }

    @MainActor
    @Test("stop() transitions to idle from any state")
    func stopTransitionsToIdle() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForPlayCallCount(f.mockPlayer, 1)

        f.session.stop()

        #expect(f.session.state == .idle)
    }

    @MainActor
    @Test("Audio error transitions to idle")
    func audioErrorTransitionsToIdle() async throws {
        let f = makeTrainingSession()
        f.mockPlayer.shouldThrowError = true
        f.mockPlayer.errorToThrow = .engineStartFailed("Test error")

        f.session.startTraining()
        try await waitForState(f.session, .idle)

        #expect(f.session.state == .idle)
    }

    // MARK: - Timing and Coordination Tests

    @MainActor
    @Test("Buttons disabled during playingNote1")
    func buttonsDisabledDuringNote1() async {
        let f = makeTrainingSession()

        var capturedState: TrainingState?
        f.mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = f.session.state
            }
        }

        f.session.startTraining()
        await Task.yield()

        #expect(capturedState == .playingNote1)
    }

    @MainActor
    @Test("Buttons enabled during awaitingAnswer")
    func buttonsEnabledDuringAwaitingAnswer() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.session.state == .awaitingAnswer)
    }

    @MainActor
    @Test("TrainingSession completes full comparison loop")
    func completesFullLoop() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
        #expect(f.mockDataStore.saveCallCount == 1)
    }

    // MARK: - Comparison Value Type Tests

    @Test("Comparison.note1Frequency calculates valid frequency")
    func note1FrequencyCalculatesCorrectly() throws {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)

        let freq = try comparison.note1Frequency()

        #expect(freq >= 260 && freq <= 263)
    }

    @Test("Comparison.note2Frequency applies cent offset higher")
    func note2FrequencyAppliesCentOffsetHigher() throws {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)

        let freq1 = try comparison.note1Frequency()
        let freq2 = try comparison.note2Frequency()

        #expect(freq2 > freq1)

        let ratio = freq2 / freq1
        #expect(ratio >= 1.05 && ratio <= 1.07)
    }

    @Test("Comparison.note2Frequency applies cent offset lower")
    func note2FrequencyAppliesCentOffsetLower() throws {
        let comparison = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: false)

        let freq1 = try comparison.note1Frequency()
        let freq2 = try comparison.note2Frequency()

        #expect(freq2 < freq1)
    }

    @Test("Comparison.isCorrect validates user answer correctly")
    func isCorrectValidatesAnswer() {
        let comparisonHigher = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true)
        let comparisonLower = Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: false)

        #expect(comparisonHigher.isCorrect(userAnswerHigher: true) == true)
        #expect(comparisonHigher.isCorrect(userAnswerHigher: false) == false)
        #expect(comparisonLower.isCorrect(userAnswerHigher: false) == true)
        #expect(comparisonLower.isCorrect(userAnswerHigher: true) == false)
    }
}
