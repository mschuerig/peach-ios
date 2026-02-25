import Testing
@testable import Peach

@Suite("PitchMatchingProfile")
struct PitchMatchingProfileTests {

    @Test("PerceptualProfile conforms to PitchMatchingProfile")
    func conformsToPitchMatchingProfile() async {
        let profile = PerceptualProfile()
        let _: PitchMatchingProfile = profile
        #expect(profile is PitchMatchingProfile)
    }

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
        profile.updateMatching(note: 60, centError: 10.0)
        profile.updateMatching(note: 60, centError: -20.0) // abs = 20
        #expect(profile.matchingMean == 15.0) // (10 + 20) / 2
        #expect(profile.matchingSampleCount == 2)
    }

    @Test("matching stdDev computed from absolute errors")
    func matchingStdDev() async throws {
        let profile = PerceptualProfile()
        profile.updateMatching(note: 60, centError: 10.0)
        profile.updateMatching(note: 60, centError: -20.0) // abs = 20
        // stdDev of [10, 20] = sqrt(50) ≈ 7.071
        let stdDev = try #require(profile.matchingStdDev)
        #expect(abs(stdDev - 7.0710678) < 0.001)
    }

    @Test("single sample returns nil stdDev")
    func singleSampleStdDev() async {
        let profile = PerceptualProfile()
        profile.updateMatching(note: 60, centError: 10.0)
        #expect(profile.matchingMean == 10.0)
        #expect(profile.matchingStdDev == nil)
        #expect(profile.matchingSampleCount == 1)
    }

    @Test("resetMatching clears matching but preserves discrimination")
    func resetMatchingIndependence() async {
        let profile = PerceptualProfile()
        profile.update(note: 60, centOffset: 50.0, isCorrect: true)
        profile.updateMatching(note: 60, centError: 10.0)
        profile.resetMatching()
        #expect(profile.matchingMean == nil)
        #expect(profile.matchingSampleCount == 0)
        #expect(profile.statsForNote(60).sampleCount == 1) // discrimination preserved
    }

    @Test("reset clears discrimination but preserves matching")
    func resetDiscriminationIndependence() async {
        let profile = PerceptualProfile()
        profile.update(note: 60, centOffset: 50.0, isCorrect: true)
        profile.updateMatching(note: 60, centError: 10.0)
        profile.reset()
        #expect(profile.statsForNote(60).sampleCount == 0) // discrimination cleared
        #expect(profile.matchingMean == 10.0) // matching preserved
        #expect(profile.matchingSampleCount == 1)
    }

    @Test("pitchMatchingCompleted updates matching statistics")
    func observerUpdatesStats() async {
        let profile = PerceptualProfile()
        let result = CompletedPitchMatching(referenceNote: 60, initialCentOffset: 50.0, userCentError: 15.0)
        profile.pitchMatchingCompleted(result)
        #expect(profile.matchingSampleCount == 1)
        #expect(profile.matchingMean == 15.0)
    }
}
