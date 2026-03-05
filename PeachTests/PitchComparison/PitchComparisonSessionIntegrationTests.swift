import Testing
import Foundation
@testable import Peach

/// Integration tests for PitchComparisonSession with NotePlayer, DataStore, and Profile
@Suite("PitchComparisonSession Integration Tests")
struct PitchComparisonSessionIntegrationTests {

    // MARK: - NotePlayer Integration Tests

    @Test("PitchComparisonSession calls play twice per comparison")
    func callsPlayTwicePerComparison() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playCallCount == 2)
    }

    @Test("PitchComparisonSession plays correct frequencies")
    func playsCorrectFrequencies() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastFrequency != nil)
        #expect(f.mockPlayer.lastFrequency! > 0)
        #expect(f.mockPlayer.lastFrequency! >= 100 && f.mockPlayer.lastFrequency! <= 1200)
    }

    @Test("PitchComparisonSession passes correct duration to NotePlayer")
    func passesCorrectDuration() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastDuration == 1.0)
    }

    @Test("PitchComparisonSession passes correct velocity to NotePlayer")
    func passesCorrectVelocity() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastVelocity == 63)
    }

    @Test("PitchComparisonSession passes default amplitudeDB 0.0 to NotePlayer for both notes")
    func passesDefaultAmplitude() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }

    // MARK: - TrainingDataStore Integration Tests

    @Test("PitchComparisonSession records comparison on answer")
    func recordsComparisonOnAnswer() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.mockDataStore.saveCallCount == 1)
        #expect(f.mockDataStore.lastSavedRecord != nil)
    }

    @Test("PitchComparisonRecord contains correct note data")
    func comparisonRecordContainsCorrectData() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)

        let record = f.mockDataStore.lastSavedRecord!
        #expect(record.referenceNote == 60)
        #expect(record.targetNote == 60)
        #expect(record.centOffset == 100.0)
    }

    @Test("Data error does not stop training")
    func dataErrorDoesNotStopTraining() async throws {
        let f = makePitchComparisonSession()
        f.mockDataStore.shouldThrowError = true

        f.session.start(intervals: [.prime])
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)

        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockPlayer.playCallCount >= 3)
    }

    // MARK: - PerceptualProfile Integration Tests (Story 4.1)

    @Test("Profile is updated incrementally when comparison is recorded")
    func profileUpdatesIncrementallyAfterComparison() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
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
        let f = makePitchComparisonSession()

        f.profile.update(note: 60, centOffset: 50.0, isCorrect: true)
        f.profile.update(note: 60, centOffset: 30.0, isCorrect: true)

        let stats = f.profile.statsForNote(60)
        #expect(stats.sampleCount == 2)
        #expect(stats.mean == 40.0)
    }

    @Test("Profile statistics accumulate correctly over multiple comparisons")
    func profileAccumulatesMultipleComparisons() async throws {
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
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
        let f = makePitchComparisonSession()

        f.session.start(intervals: [.prime])
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
            PitchComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 50.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: Date()),
            PitchComparisonRecord(referenceNote: 60, targetNote: 60, centOffset: 30.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: Date()),
            PitchComparisonRecord(referenceNote: 62, targetNote: 62, centOffset: -40.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: Date())
        ]

        // Loading uses abs() on stored signed centOffset for unsigned threshold
        for record in records {
            profile.update(note: MIDINote(record.referenceNote), centOffset: Cents(abs(record.centOffset)), isCorrect: record.isCorrect)
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
        let strategy = KazezNoteStrategy()

        let comparison = strategy.nextPitchComparison(
            profile: profile,
            settings: TrainingSettings(referencePitch: .concert440),
            lastPitchComparison: nil,
            interval: .prime,
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
        #expect(comparison.referenceNote >= 36 && comparison.referenceNote <= 84)
    }
}
