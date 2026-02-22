import Testing
import Foundation
@testable import Peach

/// Tests for TrainingSession live settings via UserDefaults (Story 6.2)
@Suite("TrainingSession UserDefaults Settings Tests", .serialized)
struct TrainingSessionUserDefaultsTests {

    func cleanUpSettingsDefaults() {
        let keys = [
            SettingsKeys.naturalVsMechanical,
            SettingsKeys.noteRangeMin,
            SettingsKeys.noteRangeMax,
            SettingsKeys.noteDuration,
            SettingsKeys.referencePitch,
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - UserDefaults Settings Tests

    @MainActor
    @Test("Changing UserDefaults values changes TrainingSettings built by TrainingSession")
    func userDefaultsChangesAffectSettings() async throws {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        UserDefaults.standard.set(0.8, forKey: SettingsKeys.naturalVsMechanical)
        UserDefaults.standard.set(50, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(70, forKey: SettingsKeys.noteRangeMax)
        UserDefaults.standard.set(432.0, forKey: SettingsKeys.referencePitch)

        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 50)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 70)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.8)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 432.0)

        session.stop()
    }

    @MainActor
    @Test("Note duration from UserDefaults is passed to NotePlayer")
    func noteDurationFromUserDefaultsPassedToPlayer() async throws {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        UserDefaults.standard.set(2.5, forKey: SettingsKeys.noteDuration)

        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.lastDuration == 2.5)

        session.stop()
    }

    @MainActor
    @Test("Reference pitch from UserDefaults is passed to frequency calculation")
    func referencePitchFromUserDefaultsAffectsFrequency() async throws {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: [
            Comparison(note1: 69, note2: 69, centDifference: 100.0, isSecondNoteHigher: true)
        ])

        UserDefaults.standard.set(432.0, forKey: SettingsKeys.referencePitch)

        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.playHistory.count >= 1)
        let note1Freq = mockPlayer.playHistory[0].frequency
        #expect(abs(note1Freq - 432.0) < 0.01)

        session.stop()
    }

    @MainActor
    @Test("Settings persist across simulated app restart")
    func settingsPersistAcrossRestart() async throws {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        UserDefaults.standard.set(0.9, forKey: SettingsKeys.naturalVsMechanical)
        UserDefaults.standard.set(55, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(75, forKey: SettingsKeys.noteRangeMax)
        UserDefaults.standard.set(1.5, forKey: SettingsKeys.noteDuration)
        UserDefaults.standard.set(415.0, forKey: SettingsKeys.referencePitch)

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy()

        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 55)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 75)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.9)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 415.0)
        #expect(mockPlayer.lastDuration == 1.5)

        session.stop()
    }

    @MainActor
    @Test("Settings changed mid-training take effect on next comparison")
    func settingsChangedMidTrainingTakeEffect() async throws {
        cleanUpSettingsDefaults()
        defer { cleanUpSettingsDefaults() }

        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextNoteStrategy(comparisons: [
            Comparison(note1: 60, note2: 60, centDifference: 100.0, isSecondNoteHigher: true),
            Comparison(note1: 62, note2: 62, centDifference: 95.0, isSecondNoteHigher: false)
        ])

        let session = TrainingSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, profile]
        )

        session.startTraining()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == SettingsKeys.defaultNoteRangeMin)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == SettingsKeys.defaultNaturalVsMechanical)

        UserDefaults.standard.set(50, forKey: SettingsKeys.noteRangeMin)
        UserDefaults.standard.set(70, forKey: SettingsKeys.noteRangeMax)
        UserDefaults.standard.set(0.9, forKey: SettingsKeys.naturalVsMechanical)
        UserDefaults.standard.set(2.0, forKey: SettingsKeys.noteDuration)

        session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(mockPlayer, 3)

        #expect(mockStrategy.callCount == 2, "Second comparison should have been requested")
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 50)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 70)
        #expect(mockStrategy.lastReceivedSettings?.naturalVsMechanical == 0.9)
        #expect(mockPlayer.lastDuration == 2.0)

        session.stop()
    }
}
