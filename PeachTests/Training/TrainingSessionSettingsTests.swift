import Testing
import Foundation
@testable import Peach

/// Tests for TrainingSession settings propagation and overrides (Stories 4.3, 6.2)
@Suite("TrainingSession Settings Tests")
struct TrainingSessionSettingsTests {

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

    // MARK: - Settings Propagation Tests (Story 4.3)

    @MainActor
    @Test("Strategy receives correct settings")
    func strategyReceivesCorrectSettings() async throws {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()
        let customSettings = TrainingSettings(
            noteRangeMin: 48,
            noteRangeMax: 72,
            naturalVsMechanical: 0.8
        )
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: customSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 72)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.8)
    }

    @MainActor
    @Test("Strategy receives updated profile after answer")
    func strategyReceivesUpdatedProfileAfterAnswer() async throws {
        let (session, mockPlayer, _, profile, mockStrategy) = makeTrainingSession()

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.callCount == 1)

        session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(mockPlayer, 3)

        #expect(mockStrategy.callCount == 2)
        #expect(mockStrategy.lastReceivedProfile === profile)

        let stats = profile.statsForNote(60)
        #expect(stats.sampleCount == 1)
    }

    // MARK: - Settings Override Tests (Story 6.2)

    @MainActor
    @Test("TrainingSession with settingsOverride uses override values")
    func settingsOverrideUsesOverrideValues() async throws {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()
        let overrideSettings = TrainingSettings(
            noteRangeMin: 48,
            noteRangeMax: 72,
            naturalVsMechanical: 0.3,
            referencePitch: 432.0
        )
        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: overrideSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 72)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.3)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 432.0)
    }

    @MainActor
    @Test("noteDurationOverride takes precedence over UserDefaults")
    func noteDurationOverrideTakesPrecedence() async throws {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            settingsOverride: TrainingSettings(),
            noteDurationOverride: 0.5,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.lastDuration == 0.5)
    }
}
