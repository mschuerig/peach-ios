import Testing
import Foundation
@testable import Peach

/// Integration tests for TrainingSession with NotePlayer, DataStore, and Profile
@Suite("TrainingSession Integration Tests")
struct TrainingSessionIntegrationTests {

    // MARK: - NotePlayer Integration Tests

    @Test("TrainingSession calls play twice per comparison")
    func callsPlayTwicePerComparison() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playCallCount == 2)
    }

    @Test("TrainingSession uses correct frequency calculation")
    func usesCorrectFrequencyCalculation() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastFrequency != nil)
        #expect(f.mockPlayer.lastFrequency! > 0)
        #expect(f.mockPlayer.lastFrequency! >= 100 && f.mockPlayer.lastFrequency! <= 1200)
    }

    @Test("TrainingSession passes correct duration to NotePlayer")
    func passesCorrectDuration() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastDuration == 1.0)
    }

    @Test("TrainingSession passes correct velocity to NotePlayer")
    func passesCorrectVelocity() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastVelocity == 63)
    }

    // MARK: - TrainingDataStore Integration Tests

    @Test("TrainingSession records comparison on answer")
    func recordsComparisonOnAnswer() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.mockDataStore.saveCallCount == 1)
        #expect(f.mockDataStore.lastSavedRecord != nil)
    }

    @Test("ComparisonRecord contains correct note data")
    func comparisonRecordContainsCorrectData() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)

        let record = f.mockDataStore.lastSavedRecord!
        #expect(record.note1 == 60)
        #expect(record.note2 == 60)
        #expect(record.note2CentOffset == 100.0)
    }

    @Test("Data error does not stop training")
    func dataErrorDoesNotStopTraining() async throws {
        let f = makeTrainingSession()
        f.mockDataStore.shouldThrowError = true

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)

        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
    }

    // MARK: - PerceptualProfile Integration Tests (Story 4.1)

    @Test("Profile is updated incrementally when comparison is recorded")
    func profileUpdatesIncrementallyAfterComparison() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)

        try #require(f.mockDataStore.lastSavedRecord != nil, "No comparison was recorded")

        let stats = f.profile.statsForNote(60)
        #expect(stats.sampleCount == 1)
        #expect(stats.mean == 100.0)
    }

    @Test("Profile updates use unsigned centOffset for threshold measurement")
    func profileUsesUnsignedCentOffset() async {
        let f = makeTrainingSession()

        f.profile.update(note: 60, centOffset: 50.0, isCorrect: true)
        f.profile.update(note: 60, centOffset: 30.0, isCorrect: true)

        let stats = f.profile.statsForNote(60)
        #expect(stats.sampleCount == 2)
        #expect(stats.mean == 40.0)
    }

    @Test("Profile statistics accumulate correctly over multiple comparisons")
    func profileAccumulatesMultipleComparisons() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(f.mockPlayer, 3)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)
        #expect(f.session.state == .showingFeedback)

        #expect(f.mockDataStore.savedRecords.count == 2)

        let stats60 = f.profile.statsForNote(60)
        #expect(stats60.sampleCount == 1)
        #expect(stats60.mean == 100.0)

        let stats62 = f.profile.statsForNote(62)
        #expect(stats62.sampleCount == 1)
        #expect(stats62.mean == 95.0)
    }

    @Test("Profile updates for all answers (both correct and incorrect)")
    func profileUpdatesForAllAnswers() async throws {
        let f = makeTrainingSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)
        #expect(f.session.state == .showingFeedback)

        try #require(f.mockDataStore.lastSavedRecord != nil, "No comparison was recorded")

        let stats = f.profile.statsForNote(60)
        #expect(stats.sampleCount == 1, "Profile should update for all answers, not just correct ones")
        #expect(stats.mean == 100.0)
    }

    // MARK: - Profile Loading from DataStore (Story 4.3 AC#2)

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
