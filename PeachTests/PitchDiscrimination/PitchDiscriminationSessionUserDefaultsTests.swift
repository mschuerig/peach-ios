import Testing
import Foundation
@testable import Peach

@Suite("PitchDiscriminationSession Settings Snapshot Tests")
struct PitchDiscriminationSessionUserDefaultsTests {

    @Test("Settings values are passed to strategy")
    func settingsValuesPassedToStrategy() async throws {
        let f = makePitchDiscriminationSession()

        let settings = PitchDiscriminationSettings(
            noteRange: NoteRange(lowerBound: MIDINote(50), upperBound: MIDINote(70)),
            referencePitch: Frequency(432.0),
            intervals: [.prime]
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockStrategy.lastReceivedSettings?.noteRange.lowerBound == MIDINote(50))
        #expect(f.mockStrategy.lastReceivedSettings?.noteRange.upperBound == MIDINote(70))
        #expect(f.mockStrategy.lastReceivedSettings?.referencePitch == Frequency(432.0))

        f.session.stop()
    }

    @Test("Note duration from settings is passed to NotePlayer")
    func noteDurationPassedToPlayer() async throws {
        let f = makePitchDiscriminationSession()

        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            noteDuration: NoteDuration(2.5)
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.lastDuration == .milliseconds(2500))

        f.session.stop()
    }

    @Test("Reference pitch from settings affects frequency calculation")
    func referencePitchAffectsFrequency() async throws {
        let mockPlayer = MockNotePlayer()
        let mockDataStore = MockTrainingDataStore()
        let profile = PerceptualProfile()
        let mockStrategy = MockNextPitchDiscriminationStrategy(comparisons: [
            PitchDiscriminationTrial(referenceNote: 69, targetNote: DetunedMIDINote(note: 69, offset: Cents(100.0)))
        ])

        let session = PitchDiscriminationSession(
            notePlayer: mockPlayer,
            strategy: mockStrategy,
            profile: profile,
            observers: [mockDataStore, PitchDiscriminationProfileAdapter(profile: profile)],
            audioInterruptionObserver: NoOpAudioInterruptionObserver()
        )

        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(432.0),
            intervals: [.prime]
        )
        session.start(settings: settings)
        try await waitForState(session, .awaitingAnswer)

        #expect(mockPlayer.playHistory.count >= 1)
        let referenceFreq = mockPlayer.playHistory[0].frequency
        #expect(abs(referenceFreq - 432.0) < 0.01)

        session.stop()
    }
}
