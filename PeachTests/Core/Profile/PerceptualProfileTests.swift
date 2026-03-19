import Testing
import Foundation
@testable import Peach

@Suite("PerceptualProfile Tests")
struct PerceptualProfileTests {

    // MARK: - Helpers

    private func makeComparisonCompleted(
        referenceNote: MIDINote = MIDINote(60),
        targetNote: MIDINote = MIDINote(60),
        centOffset: Cents,
        isCorrect: Bool = true
    ) -> CompletedPitchComparison {
        let isTargetHigher = centOffset > 0
        return CompletedPitchComparison(
            pitchComparison: PitchComparison(
                referenceNote: referenceNote,
                targetNote: DetunedMIDINote(note: targetNote, offset: centOffset)
            ),
            userAnsweredHigher: isCorrect ? isTargetHigher : !isTargetHigher,
            tuningSystem: .equalTemperament
        )
    }

    private func makeMatchingCompleted(
        referenceNote: MIDINote = MIDINote(60),
        targetNote: MIDINote = MIDINote(60),
        centError: Cents
    ) -> CompletedPitchMatching {
        CompletedPitchMatching(
            referenceNote: referenceNote,
            targetNote: targetNote,
            initialCentOffset: 50.0,
            userCentError: centError,
            tuningSystem: .equalTemperament
        )
    }

    // MARK: - Cold Start

    @Test("Cold start profile has no statistics")
    func coldStartProfile() async {
        let profile = PerceptualProfile()

        #expect(profile.comparisonMean(for: .prime) == nil)
        #expect(profile.matchingMean == nil)
        #expect(profile.matchingSampleCount == 0)
    }

    // MARK: - Comparison Statistics via Observer

    @Test("Single correct comparison sets comparison mean")
    func singleUpdateSetsMean() async {
        let profile = PerceptualProfile()

        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 50))

        #expect(profile.comparisonMean(for: .prime) == 50.0)
    }

    @Test("Multiple correct comparisons compute correct running mean")
    func multipleUpdatesComputeMean() async {
        let profile = PerceptualProfile()

        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 50))
        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 40))

        #expect(profile.comparisonMean(for: .prime) == 45.0) // (50+40)/2
    }

    @Test("Overall mean across all samples")
    func comparisonMeanComputation() async {
        let profile = PerceptualProfile()

        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 50))
        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 30))
        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 40))

        #expect(profile.comparisonMean(for: .prime) == 40.0) // (50+30+40)/3
    }

    @Test("Only correct answers contribute to comparison mean")
    func onlyCorrectAnswersContribute() async {
        let profile = PerceptualProfile()

        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 50, isCorrect: true))
        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 200, isCorrect: false))
        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 60, isCorrect: true))

        #expect(profile.comparisonMean(for: .prime) == 55.0) // (50+60)/2, incorrect answer excluded
    }

    // MARK: - Observer Integration

    @Test("PitchComparisonObserver routes interval comparison to correct mode")
    func comparisonObserverRoutesIntervalCorrectly() async {
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

        #expect(profile.comparisonMean(for: .up(.perfectFifth)) == 25.0)
        #expect(profile.hasData(for: .intervalPitchComparison))
        #expect(!profile.hasData(for: .unisonPitchComparison))
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
        #expect(profile.hasData(for: .intervalMatching))
        #expect(!profile.hasData(for: .unisonMatching))
    }

    // MARK: - Per-Mode Query API

    @Test("hasData returns false for empty modes")
    func hasDataEmptyProfile() async {
        let profile = PerceptualProfile()
        for mode in TrainingMode.allCases {
            #expect(!profile.hasData(for: mode))
        }
    }

    @Test("per-mode statistics accessible after observer updates")
    func perModeStatisticsViaObserver() async {
        let profile = PerceptualProfile()

        // Unison comparison
        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 10))
        // Interval comparison
        let intervalComparison = CompletedPitchComparison(
            pitchComparison: PitchComparison(
                referenceNote: MIDINote(60),
                targetNote: DetunedMIDINote(note: MIDINote(67), offset: Cents(20.0))
            ),
            userAnsweredHigher: true,
            tuningSystem: .equalTemperament
        )
        profile.pitchComparisonCompleted(intervalComparison)

        #expect(profile.recordCount(for: .unisonPitchComparison) == 1)
        #expect(profile.recordCount(for: .intervalPitchComparison) == 1)
    }

    // MARK: - Builder Init

    @Test("init(build:) from metric points produces correct per-mode data")
    func builderFromMetrics() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 10), for: .unisonPitchComparison)
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20), for: .unisonPitchComparison)
            builder.addPoint(MetricPoint(timestamp: now, value: 5), for: .intervalMatching)
        }

        #expect(profile.recordCount(for: .unisonPitchComparison) == 2)
        #expect(profile.recordCount(for: .intervalMatching) == 1)
        #expect(profile.recordCount(for: .intervalPitchComparison) == 0)
        #expect(profile.recordCount(for: .unisonMatching) == 0)
    }

    // MARK: - Reset

    @Test("resetAll clears all modes")
    func resetAllClearsAllModes() async {
        let profile = PerceptualProfile()

        profile.pitchComparisonCompleted(makeComparisonCompleted(centOffset: 10))
        profile.pitchMatchingCompleted(makeMatchingCompleted(centError: 5))

        profile.resetAll()

        for mode in TrainingMode.allCases {
            #expect(!profile.hasData(for: mode))
        }
        #expect(profile.comparisonMean(for: .prime) == nil)
        #expect(profile.matchingMean == nil)
    }

    // MARK: - Matching Sample Count

    @Test("matching sample count sums across both matching modes")
    func matchingSampleCountSumsAcrossModes() async {
        let profile = PerceptualProfile()

        // 2 unison matching
        profile.pitchMatchingCompleted(makeMatchingCompleted(centError: 5))
        profile.pitchMatchingCompleted(makeMatchingCompleted(centError: 3))

        // 1 interval matching
        profile.pitchMatchingCompleted(makeMatchingCompleted(
            referenceNote: MIDINote(60),
            targetNote: MIDINote(67),
            centError: 8
        ))

        #expect(profile.matchingSampleCount == 3)
    }

    // MARK: - Builder-Based Init

    @Test("init(build:) produces correct per-mode data")
    func initWithBuilder() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 10), for: .unisonPitchComparison)
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20), for: .unisonPitchComparison)
            builder.addPoint(MetricPoint(timestamp: now, value: 5), for: .intervalMatching)
        }

        #expect(profile.recordCount(for: .unisonPitchComparison) == 2)
        #expect(profile.recordCount(for: .intervalMatching) == 1)
        #expect(profile.recordCount(for: .intervalPitchComparison) == 0)
        #expect(profile.recordCount(for: .unisonMatching) == 0)
    }

    @Test("init(build:) computes correct statistics for multiple points")
    func builderComputesCorrectStatistics() async {
        let now = Date()

        let profile = PerceptualProfile { builder in
            for i in 0..<5 {
                builder.addPoint(
                    MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 3600), value: Cents(Double(i * 10 + 5))),
                    for: .unisonPitchComparison
                )
            }
        }

        #expect(profile.recordCount(for: .unisonPitchComparison) == 5)
        // Mean of [5, 15, 25, 35, 45] = 25.0
        #expect(profile.comparisonMean(for: .prime) == 25.0)
        #expect(profile.trend(for: .unisonPitchComparison) != nil)
    }

    @Test("Builder is received via closure, not constructed directly")
    func builderViaInit() async {
        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: Date(), value: 10.0), for: .unisonPitchComparison)
        }
        #expect(profile.recordCount(for: .unisonPitchComparison) == 1)
    }

    @Test("replaceAll updates same instance with new data")
    func replaceAllUpdatesInstance() async {
        let now = Date()
        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 50.0), for: .unisonPitchComparison)
        }

        #expect(profile.comparisonMean(for: .prime) == 50.0)

        profile.replaceAll { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 10.0), for: .unisonPitchComparison)
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20.0), for: .unisonPitchComparison)
        }

        #expect(profile.comparisonMean(for: .prime) == 15.0)
        #expect(profile.recordCount(for: .unisonPitchComparison) == 2)
    }

    @Test("Builder skips incorrect comparison points")
    func builderSkipsIncorrect() async {
        let now = Date()
        let profile = PerceptualProfile { builder in
            builder.addPoint(MetricPoint(timestamp: now, value: 50.0), for: .unisonPitchComparison, isCorrect: true)
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 200.0), for: .unisonPitchComparison, isCorrect: false)
            builder.addPoint(MetricPoint(timestamp: now.addingTimeInterval(2), value: 30.0), for: .unisonPitchComparison, isCorrect: true)
        }

        #expect(profile.recordCount(for: .unisonPitchComparison) == 2)
        #expect(profile.comparisonMean(for: .prime) == 40.0) // (50+30)/2
    }
}
