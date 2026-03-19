import Testing
import Foundation
@testable import Peach

@Suite("PerceptualProfile Tests")
struct PerceptualProfileTests {

    // MARK: - Cold Start

    @Test("Cold start profile has no statistics")
    func coldStartProfile() async throws {
        let profile = PerceptualProfile()

        #expect(profile.comparisonMean == nil)
        #expect(profile.comparisonStdDev == nil)
    }

    // MARK: - Aggregate Comparison Statistics

    @Test("Single update sets comparison mean")
    func singleUpdateSetsMean() async {
        let profile = PerceptualProfile()

        profile.updateComparison(note: 60, centOffset: 50, isCorrect: true)

        #expect(profile.comparisonMean == 50.0)
    }

    @Test("Multiple updates compute correct running mean")
    func multipleUpdatesComputeMean() async {
        let profile = PerceptualProfile()

        profile.updateComparison(note: 60, centOffset: 50, isCorrect: true)
        profile.updateComparison(note: 60, centOffset: 40, isCorrect: true)

        #expect(profile.comparisonMean == 45.0) // (50+40)/2
    }

    @Test("Overall mean across all samples")
    func comparisonMeanComputation() async {
        let profile = PerceptualProfile()

        profile.updateComparison(note: 60, centOffset: 50, isCorrect: true)
        profile.updateComparison(note: 62, centOffset: 30, isCorrect: true)
        profile.updateComparison(note: 64, centOffset: 40, isCorrect: true)

        #expect(profile.comparisonMean == 40.0) // (50+30+40)/3
    }

    @Test("Only correct answers contribute to comparison mean")
    func onlyCorrectAnswersContribute() async {
        let profile = PerceptualProfile()

        profile.updateComparison(note: 60, centOffset: 50, isCorrect: true)
        profile.updateComparison(note: 60, centOffset: 200, isCorrect: false)
        profile.updateComparison(note: 60, centOffset: 60, isCorrect: true)

        #expect(profile.comparisonMean == 55.0) // (50+60)/2, incorrect answer excluded
    }

    @Test("Standard deviation with identical values is zero")
    func comparisonStdDevZero() async {
        let profile = PerceptualProfile()

        profile.updateComparison(note: 60, centOffset: 50, isCorrect: true)
        profile.updateComparison(note: 62, centOffset: 50, isCorrect: true)
        profile.updateComparison(note: 64, centOffset: 50, isCorrect: true)

        #expect(profile.comparisonStdDev == 0.0)
    }

    @Test("Standard deviation with variance")
    func comparisonStdDevWithVariance() async {
        let profile = PerceptualProfile()

        profile.updateComparison(note: 60, centOffset: 40, isCorrect: true)
        profile.updateComparison(note: 60, centOffset: 50, isCorrect: true)
        profile.updateComparison(note: 60, centOffset: 60, isCorrect: true)

        // Sample stdDev = sqrt(((40-50)^2 + (50-50)^2 + (60-50)^2) / 2) = sqrt(100) = 10.0
        let stdDev = profile.comparisonStdDev!
        #expect(abs(stdDev.rawValue - 10.0) < 0.01)
    }

    @Test("Single sample returns nil stdDev")
    func singleSampleStdDev() async {
        let profile = PerceptualProfile()

        profile.updateComparison(note: 60, centOffset: 50, isCorrect: true)

        #expect(profile.comparisonStdDev == nil)
    }

    // MARK: - Observer Integration

    @Test("PitchComparisonObserver uses referenceNote as profile key when interval is non-prime")
    func comparisonObserverUsesReferenceNoteWithInterval() async throws {
        let profile = PerceptualProfile()

        let pitchComparison = PitchComparison(
            referenceNote: MIDINote(60),
            targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(25.0))
        )
        let completed = CompletedPitchComparison(
            pitchComparison: pitchComparison,
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )

        profile.pitchComparisonCompleted(completed)

        #expect(profile.comparisonMean == 25.0)
    }

    @Test("PitchMatchingObserver records centError correctly for non-prime interval")
    func pitchMatchingObserverRecordsCentErrorWithInterval() async throws {
        let profile = PerceptualProfile()

        let completed = CompletedPitchMatching(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(60).transposed(by: .up(.perfectFifth)),
            initialCentOffset: 30.0,
            userCentError: -12.3,
            tuningSystem: .equalTemperament
        )

        profile.pitchMatchingCompleted(completed)

        #expect(profile.matchingSampleCount == 1)
        let mean = try #require(profile.matchingMean)
        #expect(abs(mean.rawValue - 12.3) < 0.01)
    }
}
