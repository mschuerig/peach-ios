import Testing
@testable import Peach

@Suite("PitchMatchingProfile Legacy API")
struct PitchMatchingProfileTests {

    @Test("cold start returns nil mean and stdDev, zero sample count")
    func coldStart() async {
        let profile = PerceptualProfile()
        #expect(profile.matchingMean == nil)
        #expect(profile.matchingStdDev == nil)
        #expect(profile.matchingSampleCount == 0)
    }

    @Test("matching mean tracks absolute cent error")
    func matchingMean() async {
        let profile = PerceptualProfile()
        profile.pitchMatchingCompleted(CompletedPitchMatching(referenceNote: 60, targetNote: 60, initialCentOffset: 50.0, userCentError: 10.0, tuningSystem: .equalTemperament))
        profile.pitchMatchingCompleted(CompletedPitchMatching(referenceNote: 60, targetNote: 60, initialCentOffset: 50.0, userCentError: -20.0, tuningSystem: .equalTemperament))
        #expect(profile.matchingMean == 15.0) // (10 + 20) / 2
        #expect(profile.matchingSampleCount == 2)
    }

    @Test("matching stdDev computed from absolute errors")
    func matchingStdDev() async throws {
        let profile = PerceptualProfile()
        profile.pitchMatchingCompleted(CompletedPitchMatching(referenceNote: 60, targetNote: 60, initialCentOffset: 50.0, userCentError: 10.0, tuningSystem: .equalTemperament))
        profile.pitchMatchingCompleted(CompletedPitchMatching(referenceNote: 60, targetNote: 60, initialCentOffset: 50.0, userCentError: -20.0, tuningSystem: .equalTemperament))
        // stdDev of [10, 20] = sqrt(50) ≈ 7.071
        let stdDev = try #require(profile.matchingStdDev)
        #expect(abs(stdDev.rawValue - 7.0710678) < 0.001)
    }

    @Test("single sample returns nil stdDev")
    func singleSampleStdDev() async {
        let profile = PerceptualProfile()
        profile.pitchMatchingCompleted(CompletedPitchMatching(referenceNote: 60, targetNote: 60, initialCentOffset: 50.0, userCentError: 10.0, tuningSystem: .equalTemperament))
        #expect(profile.matchingMean == 10.0)
        #expect(profile.matchingStdDev == nil)
        #expect(profile.matchingSampleCount == 1)
    }

    @Test("resetAll clears both comparison and matching")
    func resetAllClearsBoth() async {
        let profile = PerceptualProfile()
        profile.pitchComparisonCompleted(CompletedPitchComparison(
            pitchComparison: PitchComparison(
                referenceNote: MIDINote(60),
                targetNote: DetunedMIDINote(note: MIDINote(60), offset: Cents(50.0))
            ),
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        ))
        profile.pitchMatchingCompleted(CompletedPitchMatching(referenceNote: 60, targetNote: 60, initialCentOffset: 50.0, userCentError: 10.0, tuningSystem: .equalTemperament))
        profile.resetAll()
        #expect(profile.comparisonMean(for: .prime) == nil)
        #expect(profile.matchingMean == nil)
        #expect(profile.matchingSampleCount == 0)
    }

    @Test("pitchMatchingCompleted updates matching statistics")
    func observerUpdatesStats() async {
        let profile = PerceptualProfile()
        let result = CompletedPitchMatching(referenceNote: 60, targetNote: 60, initialCentOffset: 50.0, userCentError: 15.0, tuningSystem: .equalTemperament)
        profile.pitchMatchingCompleted(result)
        #expect(profile.matchingSampleCount == 1)
        #expect(profile.matchingMean == 15.0)
    }
}
