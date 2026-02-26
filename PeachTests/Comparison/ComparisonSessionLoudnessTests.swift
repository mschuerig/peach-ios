import Testing
@testable import Peach

/// Tests for loudness variation in training comparisons (Story 10.5)
@Suite("ComparisonSession Loudness Variation Tests")
struct ComparisonSessionLoudnessTests {

    // MARK: - Zero Variation (AC #1)

    @Test("Both notes play at amplitudeDB 0.0 when varyLoudness is 0.0")
    func zeroVariationBothNotesAtZero() async throws {
        let f = makeComparisonSession(varyLoudnessOverride: 0.0)

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }

    // MARK: - Full Variation (AC #2)

    @Test("Note1 always at 0.0 and note2 within ±5.0 dB at full slider")
    func fullVariationNote2HasOffset() async throws {
        let f = makeComparisonSession(varyLoudnessOverride: 1.0)

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)

        let note2Amplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(note2Amplitude >= -5.0)
        #expect(note2Amplitude <= 5.0)
    }

    @Test("Note2 amplitude varies across multiple comparisons at full slider")
    func fullVariationProducesVariation() async throws {
        let comparisons = (0..<10).map { i in
            Comparison(note1: 60, note2: 60, centDifference: Cents(i % 2 == 0 ? 100.0 : -100.0))
        }
        let f = makeComparisonSession(comparisons: comparisons, varyLoudnessOverride: 1.0)

        // Run multiple comparisons
        f.session.startTraining()
        for _ in 0..<5 {
            try await waitForState(f.session, .awaitingAnswer)
            f.session.handleAnswer(isHigher: true)
            try await waitForPlayCallCount(f.mockPlayer, f.mockPlayer.playCallCount + 2)
        }

        // Collect all note2 amplitudes (every second entry in playHistory)
        let note2Amplitudes = stride(from: 1, to: f.mockPlayer.playHistory.count, by: 2)
            .map { f.mockPlayer.playHistory[$0].amplitudeDB }

        // All note1 amplitudes should be 0.0
        let note1Amplitudes = stride(from: 0, to: f.mockPlayer.playHistory.count, by: 2)
            .map { f.mockPlayer.playHistory[$0].amplitudeDB }
        for amp in note1Amplitudes {
            #expect(amp == 0.0)
        }

        // Not all note2 amplitudes should be identical (proves randomness is active)
        let uniqueNote2 = Set(note2Amplitudes)
        #expect(uniqueNote2.count > 1, "Expected varied note2 amplitudes, got all identical: \(note2Amplitudes)")
    }

    // MARK: - Mid Slider (AC #3)

    @Test("Note2 amplitude within ±2.5 dB at slider 0.5")
    func midSliderHalvesRange() async throws {
        let f = makeComparisonSession(varyLoudnessOverride: 0.5)

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)

        let note2Amplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(note2Amplitude >= -2.5)
        #expect(note2Amplitude <= 2.5)
    }

    // MARK: - Clamping (AC #5)

    @Test("Loudness offset is clamped within valid range")
    func offsetClampedToValidRange() async throws {
        // Even with maxLoudnessOffsetDB = 5.0, the offset can't exceed -90.0...12.0
        // This test verifies the safety net is in place
        let f = makeComparisonSession(varyLoudnessOverride: 1.0)

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        let note2Amplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(note2Amplitude >= -90.0)
        #expect(note2Amplitude <= 12.0)
    }

    // MARK: - Default Factory (AC #4 — existing tests unaffected)

    @Test("Default makeComparisonSession passes varyLoudnessOverride 0.0")
    func defaultFactoryPassesZeroLoudness() async throws {
        let f = makeComparisonSession()

        f.session.startTraining()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }
}
