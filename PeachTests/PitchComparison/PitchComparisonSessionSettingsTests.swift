import Testing
@testable import Peach

@Suite("PitchComparisonSession Settings Tests")
struct PitchComparisonSessionSettingsTests {

    @Test("Strategy receives correct settings")
    func strategyReceivesCorrectSettings() async throws {
        let f = makePitchComparisonSession()

        let settings = PitchComparisonTrainingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72)),
            referencePitch: Frequency(440.0),
            intervals: [.prime]
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.lastReceivedSettings?.noteRange.lowerBound == MIDINote(48))
        #expect(f.mockStrategy.lastReceivedSettings?.noteRange.upperBound == MIDINote(72))
    }

    @Test("Strategy receives updated profile after answer")
    func strategyReceivesUpdatedProfileAfterAnswer() async throws {
        let f = makePitchComparisonSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.callCount == 1)

        f.session.handleAnswer(isHigher: true)
        await f.mockPlayer.waitForPlay(minCount: 3)

        #expect(f.mockStrategy.callCount == 2)
        #expect(f.mockStrategy.lastReceivedProfile === f.profile)

        let stats = f.profile.statsForNote(60)
        #expect(stats.sampleCount == 1)
    }

    @Test("PitchComparisonSession with custom settings uses those values")
    func customSettingsUsesValues() async throws {
        let f = makePitchComparisonSession()

        let settings = PitchComparisonTrainingSettings(
            noteRange: NoteRange(lowerBound: MIDINote(48), upperBound: MIDINote(72)),
            referencePitch: Frequency(432.0),
            intervals: [.prime]
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.lastReceivedSettings?.noteRange.lowerBound == MIDINote(48))
        #expect(f.mockStrategy.lastReceivedSettings?.noteRange.upperBound == MIDINote(72))
        #expect(f.mockStrategy.lastReceivedSettings?.referencePitch == Frequency(432.0))
    }

    @Test("noteDuration from settings takes effect")
    func noteDurationFromSettingsTakesEffect() async throws {
        let f = makePitchComparisonSession()

        let settings = PitchComparisonTrainingSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(0.5)
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastDuration == 0.5)
    }
}
