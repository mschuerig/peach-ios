import Testing
import Foundation
@testable import Peach

/// Integration tests for PitchDiscriminationSession with NotePlayer, DataStore, and Profile
@Suite("PitchDiscriminationSession Integration Tests")
struct PitchDiscriminationSessionIntegrationTests {

    // MARK: - NotePlayer Integration Tests

    @Test("PitchDiscriminationSession calls play twice per comparison")
    func callsPlayTwicePerComparison() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playCallCount == 2)
    }

    @Test("PitchDiscriminationSession plays correct frequencies")
    func playsCorrectFrequencies() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastFrequency != nil)
        #expect(f.mockPlayer.lastFrequency! > 0)
        #expect(f.mockPlayer.lastFrequency! >= 100 && f.mockPlayer.lastFrequency! <= 1200)
    }

    @Test("PitchDiscriminationSession passes correct duration to NotePlayer")
    func passesCorrectDuration() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastDuration == .seconds(1))
    }

    @Test("PitchDiscriminationSession passes correct velocity to NotePlayer")
    func passesCorrectVelocity() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastVelocity == 63)
    }

    @Test("PitchDiscriminationSession passes default amplitudeDB 0.0 to NotePlayer for both notes")
    func passesDefaultAmplitude() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }

    // MARK: - TrainingDataStore Integration Tests

    @Test("PitchDiscriminationSession records comparison on answer")
    func recordsComparisonOnAnswer() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.mockDataStore.saveCallCount == 1)
        #expect(f.mockDataStore.lastSavedRecord != nil)
    }

    @Test("PitchDiscriminationRecord contains correct note data")
    func comparisonRecordContainsCorrectData() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)

        let record = f.mockDataStore.lastSavedRecord!
        #expect(record.referenceNote == 60)
        #expect(record.targetNote == 60)
        #expect(record.centOffset == 100.0)
    }

    @Test("Data error does not stop training")
    func dataErrorDoesNotStopTraining() async throws {
        let f = makePitchDiscriminationSession()
        f.mockDataStore.shouldThrowError = true

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)

        #expect(f.session.state == .showingFeedback)

        await f.mockPlayer.waitForPlay(minCount: 3)

        #expect(f.mockPlayer.playCallCount >= 3)
    }

    // MARK: - PerceptualProfile Integration Tests (Story 4.1)

    @Test("Profile is updated incrementally when comparison is recorded")
    func profileUpdatesIncrementallyAfterComparison() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        #expect(f.session.state == .showingFeedback)

        try #require(f.mockDataStore.lastSavedRecord != nil, "No comparison was recorded")

        #expect(f.profile.comparisonMean(for: .prime) == 100.0)
    }

    @Test("Profile updates use unsigned centOffset for threshold measurement")
    func profileUsesUnsignedCentOffset() async {
        let f = makePitchDiscriminationSession()

        PitchDiscriminationProfileAdapter(profile: f.profile).pitchDiscriminationCompleted(CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(50.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))
        PitchDiscriminationProfileAdapter(profile: f.profile).pitchDiscriminationCompleted(CompletedPitchDiscriminationTrial(
            trial: PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(30.0))),
            userAnsweredHigher: true, tuningSystem: .equalTemperament
        ))

        #expect(f.profile.comparisonMean(for: .prime) == 40.0)
    }

    @Test("Profile statistics accumulate correctly over multiple comparisons")
    func profileAccumulatesMultipleComparisons() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: true)
        await f.mockPlayer.waitForPlay(minCount: 3)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)
        #expect(f.session.state == .showingFeedback)

        #expect(f.mockDataStore.savedRecords.count == 2)

        // Profile should have mean of both comparison offsets
        #expect(f.profile.comparisonMean(for: .prime) != nil)
    }

    @Test("Incorrect answer is recorded but does not update profile statistics")
    func incorrectAnswerDoesNotUpdateProfile() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        f.session.handleAnswer(isHigher: false)
        #expect(f.session.state == .showingFeedback)

        try #require(f.mockDataStore.lastSavedRecord != nil, "No comparison was recorded")

        #expect(f.profile.comparisonMean(for: .prime) == nil, "Incorrect answers should not contribute to profile statistics")
    }

    // MARK: - Profile Loading from DataStore (Story 4.3 AC#2)

    @Test("Profile loaded from pre-populated data store reflects stored records")
    func profileLoadedFromDataStore() async {
        let records = [
            PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 50.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: Date()),
            PitchDiscriminationRecord(referenceNote: 60, targetNote: 60, centOffset: 30.0, isCorrect: true, interval: 0, tuningSystem: "equalTemperament", timestamp: Date()),
            PitchDiscriminationRecord(referenceNote: 62, targetNote: 62, centOffset: -40.0, isCorrect: false, interval: 0, tuningSystem: "equalTemperament", timestamp: Date())
        ]

        let profile = PerceptualProfile { builder in
            MetricPointMapper.feedPitchDiscriminations(records, into: builder)
        }

        // Only correct answers contribute: mean of [50, 30] = 40.0
        #expect(profile.comparisonMean(for: .prime) == 40.0)
    }

    // MARK: - Cold Start (Story 4.3)

    @Test("Cold start with empty profile uses default difficulty")
    func coldStartWithEmptyProfile() async {
        let profile = PerceptualProfile()
        let strategy = KazezNoteStrategy()

        let comparison = strategy.nextPitchDiscriminationTrial(
            profile: profile,
            settings: PitchDiscriminationSettings(referencePitch: .concert440, intervals: [.prime]),
            lastTrial: nil,
            interval: .prime,
        )

        #expect(comparison.targetNote.offset.magnitude == 100.0)
        #expect(comparison.referenceNote >= 36 && comparison.referenceNote <= 84)
    }
}
