import Testing
import Foundation
@testable import Peach

/// Tests for ComparisonSession settings via UserSettings protocol (Story 19.3, originally Story 6.2)
@Suite("ComparisonSession UserSettings Tests")
struct ComparisonSessionUserDefaultsTests {

    // MARK: - UserSettings Tests

    @Test("Changing UserSettings values changes TrainingSettings built by ComparisonSession")
    func userSettingsChangesAffectSettings() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(50)
        mockSettings.noteRangeMax = MIDINote(70)
        mockSettings.referencePitch = 432.0

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextComparisonStrategy()

        let session = ComparisonSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            userSettings: mockSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 50)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 70)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 432.0)

        session.stop()
    }

    @Test("Note duration from UserSettings is passed to NotePlayer")
    func noteDurationFromUserSettingsPassedToPlayer() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteDuration = 2.5

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextComparisonStrategy()

        let session = ComparisonSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            userSettings: mockSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.lastDuration == 2.5)

        session.stop()
    }

    @Test("Reference pitch from UserSettings is passed to frequency calculation")
    func referencePitchFromUserSettingsAffectsFrequency() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.referencePitch = 432.0

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextComparisonStrategy(comparisons: [
            Comparison(referenceNote: 69, targetNote: DetunedMIDINote(note: 69, offset: Cents(100.0)))
        ])

        let session = ComparisonSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            userSettings: mockSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.playHistory.count >= 1)
        let referenceFreq = mockPlayer.playHistory[0].frequency
        #expect(abs(referenceFreq - 432.0) < 0.01)

        session.stop()
    }

    @Test("Settings changed mid-training take effect on next comparison")
    func settingsChangedMidTrainingTakeEffect() async throws {
        let mockSettings = MockUserSettings()

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextComparisonStrategy(comparisons: [
            Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(100.0))),
            Comparison(referenceNote: 62, targetNote: DetunedMIDINote(note: 62, offset: Cents(-95.0)))
        ])

        let session = ComparisonSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            userSettings: mockSettings,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin.rawValue == SettingsKeys.defaultNoteRangeMin)

        mockSettings.noteRangeMin = MIDINote(50)
        mockSettings.noteRangeMax = MIDINote(70)
        mockSettings.noteDuration = 2.0

        session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(mockPlayer, 3)

        #expect(mockStrategy.callCount == 2, "Second comparison should have been requested")
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 50)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 70)
        #expect(mockPlayer.lastDuration == 2.0)

        session.stop()
    }
}
