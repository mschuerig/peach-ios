import Testing
@testable import Peach

@Suite("PitchDiscriminationSession Loudness Variation Tests")
struct PitchDiscriminationSessionLoudnessTests {

    @Test("Both notes play at amplitudeDB 0.0 when varyLoudness is 0.0")
    func zeroVariationBothNotesAtZero() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }

    @Test("Reference always at 0.0 and target within ±10.0 dB at full slider")
    func fullVariationTargetHasOffset() async throws {
        let f = makePitchDiscriminationSession()

        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            varyLoudness: UnitInterval(1.0)
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)

        let targetAmplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(targetAmplitude >= -10.0)
        #expect(targetAmplitude <= 10.0)
    }

    @Test("Target amplitude varies across multiple comparisons at full slider")
    func fullVariationProducesVariation() async throws {
        let comparisons = (0..<10).map { i in
            PitchDiscriminationTrial(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(i % 2 == 0 ? 100.0 : -100.0)))
        }
        let f = makePitchDiscriminationSession(comparisons: comparisons)

        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            varyLoudness: UnitInterval(1.0)
        )
        f.session.start(settings: settings)
        for _ in 0..<5 {
            try await waitForState(f.session, .awaitingAnswer)
            f.session.handleAnswer(isHigher: true)
            await f.mockPlayer.waitForPlay(minCount: f.mockPlayer.playCallCount + 2)
        }

        let targetAmplitudes = stride(from: 1, to: f.mockPlayer.playHistory.count, by: 2)
            .map { f.mockPlayer.playHistory[$0].amplitudeDB }

        let referenceAmplitudes = stride(from: 0, to: f.mockPlayer.playHistory.count, by: 2)
            .map { f.mockPlayer.playHistory[$0].amplitudeDB }
        for amp in referenceAmplitudes {
            #expect(amp == 0.0)
        }

        let uniqueTarget = Set(targetAmplitudes)
        #expect(uniqueTarget.count > 1, "Expected varied target amplitudes, got all identical: \(targetAmplitudes)")
    }

    @Test("Target amplitude within ±5.0 dB at slider 0.5")
    func midSliderHalvesRange() async throws {
        let f = makePitchDiscriminationSession()

        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            varyLoudness: UnitInterval(0.5)
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)

        let targetAmplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(targetAmplitude >= -5.0)
        #expect(targetAmplitude <= 5.0)
    }

    @Test("Loudness offset is clamped within valid range")
    func offsetClampedToValidRange() async throws {
        let f = makePitchDiscriminationSession()

        let settings = PitchDiscriminationSettings(
            referencePitch: Frequency(440.0),
            intervals: [.prime],
            varyLoudness: UnitInterval(1.0)
        )
        f.session.start(settings: settings)
        try await waitForState(f.session, .awaitingAnswer)

        let targetAmplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(targetAmplitude >= -90.0)
        #expect(targetAmplitude <= 12.0)
    }

    @Test("Default settings passes varyLoudness 0.0")
    func defaultSettingsPassesZeroLoudness() async throws {
        let f = makePitchDiscriminationSession()

        f.session.start(settings: defaultTestSettings)
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }
}
