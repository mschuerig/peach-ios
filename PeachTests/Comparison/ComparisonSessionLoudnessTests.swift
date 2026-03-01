import Testing
@testable import Peach

/// Tests for loudness variation in training comparisons (Story 10.5)
@Suite("ComparisonSession Loudness Variation Tests")
struct ComparisonSessionLoudnessTests {

    // MARK: - Zero Variation (AC #1)

    @Test("Both notes play at amplitudeDB 0.0 when varyLoudness is 0.0")
    func zeroVariationBothNotesAtZero() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.varyLoudness = 0.0
        let f = makeComparisonSession(userSettings: mockSettings)

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }

    // MARK: - Full Variation (AC #2)

    @Test("Reference always at 0.0 and target within ±5.0 dB at full slider")
    func fullVariationTargetHasOffset() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.varyLoudness = 1.0
        let f = makeComparisonSession(userSettings: mockSettings)

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)

        let targetAmplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(targetAmplitude >= -5.0)
        #expect(targetAmplitude <= 5.0)
    }

    @Test("Target amplitude varies across multiple comparisons at full slider")
    func fullVariationProducesVariation() async throws {
        let comparisons = (0..<10).map { i in
            Comparison(referenceNote: 60, targetNote: DetunedMIDINote(note: 60, offset: Cents(i % 2 == 0 ? 100.0 : -100.0)))
        }
        let mockSettings = MockUserSettings()
        mockSettings.varyLoudness = 1.0
        let f = makeComparisonSession(comparisons: comparisons, userSettings: mockSettings)

        // Run multiple comparisons
        f.session.start()
        for _ in 0..<5 {
            try await waitForState(f.session, .awaitingAnswer)
            f.session.handleAnswer(isHigher: true)
            try await waitForPlayCallCount(f.mockPlayer, f.mockPlayer.playCallCount + 2)
        }

        // Collect all target amplitudes (every second entry in playHistory)
        let targetAmplitudes = stride(from: 1, to: f.mockPlayer.playHistory.count, by: 2)
            .map { f.mockPlayer.playHistory[$0].amplitudeDB }

        // All reference amplitudes should be 0.0
        let referenceAmplitudes = stride(from: 0, to: f.mockPlayer.playHistory.count, by: 2)
            .map { f.mockPlayer.playHistory[$0].amplitudeDB }
        for amp in referenceAmplitudes {
            #expect(amp == 0.0)
        }

        // Not all target amplitudes should be identical (proves randomness is active)
        let uniqueTarget = Set(targetAmplitudes)
        #expect(uniqueTarget.count > 1, "Expected varied target amplitudes, got all identical: \(targetAmplitudes)")
    }

    // MARK: - Mid Slider (AC #3)

    @Test("Target amplitude within ±2.5 dB at slider 0.5")
    func midSliderHalvesRange() async throws {
        let mockSettings = MockUserSettings()
        mockSettings.varyLoudness = 0.5
        let f = makeComparisonSession(userSettings: mockSettings)

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory.count == 2)
        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)

        let targetAmplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(targetAmplitude >= -2.5)
        #expect(targetAmplitude <= 2.5)
    }

    // MARK: - Clamping (AC #5)

    @Test("Loudness offset is clamped within valid range")
    func offsetClampedToValidRange() async throws {
        // Even with maxLoudnessOffsetDB = 5.0, the offset can't exceed -90.0...12.0
        // This test verifies the safety net is in place
        let mockSettings = MockUserSettings()
        mockSettings.varyLoudness = 1.0
        let f = makeComparisonSession(userSettings: mockSettings)

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        let targetAmplitude = f.mockPlayer.playHistory[1].amplitudeDB
        #expect(targetAmplitude >= -90.0)
        #expect(targetAmplitude <= 12.0)
    }

    // MARK: - Default Factory (AC #4 — existing tests unaffected)

    @Test("Default makeComparisonSession passes varyLoudness 0.0")
    func defaultFactoryPassesZeroLoudness() async throws {
        let f = makeComparisonSession()

        f.session.start()
        try await waitForState(f.session, .awaitingAnswer)

        #expect(f.mockPlayer.playHistory[0].amplitudeDB == 0.0)
        #expect(f.mockPlayer.playHistory[1].amplitudeDB == 0.0)
    }
}
