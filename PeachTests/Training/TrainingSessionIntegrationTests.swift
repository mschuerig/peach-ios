import Testing
import Foundation
@testable import Peach

/// Integration tests for TrainingSession with NotePlayer, DataStore, and Profile
@Suite("TrainingSession Integration Tests")
struct TrainingSessionIntegrationTests {

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

    // MARK: - NotePlayer Integration Tests

    @MainActor
    @Test("TrainingSession calls play twice per comparison")
    func callsPlayTwicePerComparison() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.playCallCount == 2)
    }

    @MainActor
    @Test("TrainingSession uses correct frequency calculation")
    func usesCorrectFrequencyCalculation() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.lastFrequency != nil)
        #expect(mockPlayer.lastFrequency! > 0)
        #expect(mockPlayer.lastFrequency! >= 100 && mockPlayer.lastFrequency! <= 1200)
    }

    @MainActor
    @Test("TrainingSession passes correct duration to NotePlayer")
    func passesCorrectDuration() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.lastDuration == 1.0)
    }

    @MainActor
    @Test("TrainingSession passes correct amplitude to NotePlayer")
    func passesCorrectAmplitude() async throws {
        let (session, mockPlayer, _, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.lastAmplitude == 0.5)
    }

    // MARK: - TrainingDataStore Integration Tests

    @MainActor
    @Test("TrainingSession records comparison on answer")
    func recordsComparisonOnAnswer() async throws {
        let (session, _, mockDataStore, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        #expect(mockDataStore.saveCallCount == 1)
        #expect(mockDataStore.lastSavedRecord != nil)
    }

    @MainActor
    @Test("ComparisonRecord contains correct note data")
    func comparisonRecordContainsCorrectData() async throws {
        let (session, _, mockDataStore, _, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: false)

        let record = mockDataStore.lastSavedRecord!
        #expect(record.note1 == 60)
        #expect(record.note2 == 60)
        #expect(record.note2CentOffset == 100.0)
    }

    @MainActor
    @Test("Data error does not stop training")
    func dataErrorDoesNotStopTraining() async throws {
        let (session, mockPlayer, mockDataStore, _, _) = makeTrainingSession()
        mockDataStore.shouldThrowError = true

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)

        #expect(session.state == .showingFeedback)

        try await waitForPlayCallCount(mockPlayer, 3)

        #expect(mockPlayer.playCallCount >= 3)
    }

    // MARK: - PerceptualProfile Integration Tests (Story 4.1)

    @MainActor
    @Test("Profile is updated incrementally when comparison is recorded")
    func profileUpdatesIncrementallyAfterComparison() async throws {
        let (session, _, mockDataStore, profile, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)
        #expect(session.state == .showingFeedback)

        try #require(mockDataStore.lastSavedRecord != nil, "No comparison was recorded")

        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 1)
        #expect(stats.mean == 100.0)
    }

    @MainActor
    @Test("Profile updates use unsigned centOffset for threshold measurement")
    func profileUsesUnsignedCentOffset() async {
        let (_, _, _, profile, _) = makeTrainingSession()

        profile.update(note: 60, centOffset: 50.0, isCorrect: true)
        profile.update(note: 60, centOffset: 30.0, isCorrect: true)

        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 2)
        #expect(stats.mean == 40.0)
    }

    @MainActor
    @Test("Profile statistics accumulate correctly over multiple comparisons")
    func profileAccumulatesMultipleComparisons() async throws {
        let (session, mockPlayer, mockDataStore, profile, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(mockPlayer, 3)
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: false)
        #expect(session.state == .showingFeedback)

        #expect(mockDataStore.savedRecords.count == 2)

        let stats60 = profile.statsForNote(60)
        #expect(stats60.sampleCount == 1)
        #expect(stats60.mean == 100.0)

        let stats62 = profile.statsForNote(62)
        #expect(stats62.sampleCount == 1)
        #expect(stats62.mean == 95.0)
    }

    @MainActor
    @Test("Profile updates for all answers (both correct and incorrect)")
    func profileUpdatesForAllAnswers() async throws {
        let (session, _, mockDataStore, profile, _) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        session.handleAnswer(isHigher: false)
        #expect(session.state == .showingFeedback)

        try #require(mockDataStore.lastSavedRecord != nil, "No comparison was recorded")

        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 1, "Profile should update for all answers, not just correct ones")
        #expect(stats.mean == 100.0)
    }

    // MARK: - Profile Loading from DataStore (Story 4.3 AC#2)

    @MainActor
    @Test("Profile loaded from pre-populated data store reflects stored records")
    func profileLoadedFromDataStore() async {
        let profile = PerceptualProfile()
        let records = [
            ComparisonRecord(note1: 60, note2: 60, note2CentOffset: 50.0, isCorrect: true, timestamp: Date()),
            ComparisonRecord(note1: 60, note2: 60, note2CentOffset: 30.0, isCorrect: true, timestamp: Date()),
            ComparisonRecord(note1: 62, note2: 62, note2CentOffset: -40.0, isCorrect: false, timestamp: Date())
        ]

        // Loading uses abs() on stored signed note2CentOffset for unsigned threshold
        for record in records {
            profile.update(note: record.note1, centOffset: abs(record.note2CentOffset), isCorrect: record.isCorrect)
        }

        let stats60 = profile.statsForNote(60)
        #expect(stats60.sampleCount == 2)
        #expect(stats60.mean == 40.0)

        let stats62 = profile.statsForNote(62)
        #expect(stats62.sampleCount == 1)
        #expect(stats62.mean == 40.0)
    }

    // MARK: - Cold Start (Story 4.3)

    @MainActor
    @Test("Cold start with empty profile uses default difficulty")
    func coldStartWithEmptyProfile() async {
        let profile = PerceptualProfile()
        let strategy = AdaptiveNoteStrategy()

        let comparison = strategy.nextComparison(
            profile: profile,
            settings: TrainingSettings(),
            lastComparison: nil
        )

        #expect(comparison.centDifference == 100.0)
        #expect(comparison.note1 >= 36 && comparison.note1 <= 84)
    }
}
