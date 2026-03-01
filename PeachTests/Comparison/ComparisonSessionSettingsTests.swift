import Testing
@testable import Peach

/// Tests for ComparisonSession settings propagation via UserSettings (Stories 4.3, 6.2, 19.3)
@Suite("ComparisonSession Settings Tests")
struct ComparisonSessionSettingsTests {

    // MARK: - Settings Propagation Tests (Story 4.3)

    @Test("Strategy receives correct settings")
    func strategyReceivesCorrectSettings() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(48)
        mockSettings.noteRangeMax = MIDINote(72)

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

        session.start()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 72)
    }

    @Test("Strategy receives updated profile after answer")
    func strategyReceivesUpdatedProfileAfterAnswer() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.callCount == 1)

        f.session.handleAnswer(isHigher: true)
        try await waitForPlayCallCount(f.mockPlayer, 3)

        #expect(f.mockStrategy.callCount == 2)
        #expect(f.mockStrategy.lastReceivedProfile === f.profile)

        let stats = f.profile.statsForNote(60)
        #expect(stats.sampleCount == 1)
    }

    // MARK: - Settings Override Tests (Story 19.3)

    @Test("ComparisonSession with custom UserSettings uses those values")
    func customUserSettingsUsesValues() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteRangeMin = MIDINote(48)
        mockSettings.noteRangeMax = MIDINote(72)
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

        session.start()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockStrategy.lastReceivedSettings?.noteRangeMin == 48)
        #expect(mockStrategy.lastReceivedSettings?.noteRangeMax == 72)
        #expect(mockStrategy.lastReceivedSettings?.referencePitch == 432.0)
    }

    @Test("noteDuration from UserSettings takes effect")
    func noteDurationFromUserSettingsTakesEffect() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.noteDuration = 0.5

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

        session.start()
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.lastDuration == 0.5)
    }
}
