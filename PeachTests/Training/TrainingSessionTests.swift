import Testing
import Foundation
@testable import Peach

/// Tests for TrainingSession state machine transitions and core training loop
@Suite("TrainingSession Tests")
struct TrainingSessionTests {

    // MARK: - Test Fixtures

    @MainActor
    func makeTrainingSession(
        comparisons: [Comparison] = [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 95.0, isSecondNoteHigher: false)
        ]
    ) -> (TrainingSession, MockNotePlayer, MockTrainingDataStore, PerceptualProfile, MockNextNoteStrategy) {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: comparisons)
        let observers: [ComparisonObserver] = [mockDataStore, profile]
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 1.0,
            observers: observers
        )
        return (session, mockPlayer, mockDataStore, profile, mockStrategy)
    }

    // MARK: - State Transition Tests

    @MainActor
    @Test("TrainingSession starts in idle state")
    func startsInIdleState() {
        let (session, _, _, _, _) = makeTrainingSession()
        #expect(session.state == .idle)
    }

    @MainActor
    @Test("startTraining transitions from idle to playingNote1")
    func startTrainingTransitionsToPlayingNote1() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        var capturedState: TrainingState?
        mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = session.state
            }
        }

        session.startTraining()
        await Task.yield()

        #expect(capturedState == .playingNote1)
        #expect(mockPlayer.playCallCount >= 1)
    }

    @MainActor
    @Test("TrainingSession transitions from playingNote1 to playingNote2")
    func transitionsFromNote1ToNote2() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForPlayCallCount(mockPlayer, 2)

        #expect(mockPlayer.playCallCount >= 2)
        #expect(session.state == .playingNote2 || session.state == .awaitingAnswer)
    }

    @MainActor
    @Test("TrainingSession transitions from playingNote2 to awaitingAnswer")
    func transitionsFromNote2ToAwaitingAnswer() async throws {
        let (session, _, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(session.state == .awaitingAnswer)
    }

    @MainActor
    @Test("handleAnswer transitions to showingFeedback")
    func handleAnswerTransitionsToShowingFeedback() async throws {
        let (session, _, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        #expect(session.state == .showingFeedback)
    }

    @MainActor
    @Test("TrainingSession loops back to playingNote1 after feedback")
    func loopsBackAfterFeedback() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)
        #expect(session.state == .showingFeedback)

        try await waitForPlayCallCount(mockPlayer, 3)

        #expect(mockPlayer.playCallCount >= 3)
    }

    @MainActor
    @Test("stop() transitions to idle from any state")
    func stopTransitionsToIdle() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForPlayCallCount(mockPlayer, 1)

        session.stop()

        #expect(session.state == .idle)
    }

    @MainActor
    @Test("Audio error transitions to idle")
    func audioErrorTransitionsToIdle() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()
        mockPlayer.shouldThrowError = true
        mockPlayer.errorToThrow = .renderFailed("Test error")

        session.startTraining()
        try await waitForState(session, .idle)

        #expect(session.state == .idle)
    }

    // MARK: - Timing and Coordination Tests

    @MainActor
    @Test("Buttons disabled during playingNote1")
    func buttonsDisabledDuringNote1() async {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        var capturedState: TrainingState?
        mockPlayer.onPlayCalled = {
            if capturedState == nil {
                capturedState = session.state
            }
        }

        session.startTraining()
        await Task.yield()

        #expect(capturedState == .playingNote1)
    }

    @MainActor
    @Test("Buttons enabled during awaitingAnswer")
    func buttonsEnabledDuringAwaitingAnswer() async throws {
        let (session, _, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(session.state == .awaitingAnswer)
    }

    @MainActor
    @Test("TrainingSession completes full comparison loop")
    func completesFullLoop() async throws {
        let (session, mockPlayer, mockDataStore, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(mockPlayer, 3)

        #expect(mockPlayer.playCallCount >= 3)
        #expect(mockDataStore.saveCallCount == 1)
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
