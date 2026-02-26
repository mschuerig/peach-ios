import Testing
@testable import Peach

@Suite("MatchingStatisticsView Tests")
struct MatchingStatisticsViewTests {

    // MARK: - Stats Computation

    @Test("computes matching stats from profile with data")
    func computeStatsWithData() async {
        let profile = PerceptualProfile()
        profile.updateMatching(note: 60, centError: 10.0)
        profile.updateMatching(note: 62, centError: 20.0)
        profile.updateMatching(note: 64, centError: 15.0)

        let stats = MatchingStatisticsView.computeMatchingStats(from: profile)

        #expect(stats != nil)
        #expect(stats!.meanError > 0)
        #expect(stats!.stdDev != nil)
        #expect(stats!.sampleCount == 3)
    }

    @Test("returns nil stats when no matching data")
    func computeStatsReturnsNilWhenEmpty() async {
        let profile = PerceptualProfile()

        let stats = MatchingStatisticsView.computeMatchingStats(from: profile)

        #expect(stats == nil)
    }

    @Test("mean error matches profile matchingMean")
    func meanErrorMatchesProfile() async {
        let profile = PerceptualProfile()
        profile.updateMatching(note: 60, centError: 12.0)
        profile.updateMatching(note: 62, centError: 18.0)

        let stats = MatchingStatisticsView.computeMatchingStats(from: profile)

        #expect(stats != nil)
        // Mean of abs errors: (12 + 18) / 2 = 15
        #expect(stats!.meanError == 15.0)
    }

    @Test("stdDev is nil with fewer than 2 samples")
    func stdDevNilWithOneSample() async {
        let profile = PerceptualProfile()
        profile.updateMatching(note: 60, centError: 10.0)

        let stats = MatchingStatisticsView.computeMatchingStats(from: profile)

        #expect(stats != nil)
        #expect(stats!.meanError == 10.0)
        #expect(stats!.stdDev == nil)
        #expect(stats!.sampleCount == 1)
    }

    // MARK: - Formatting

    @Test("formats mean error with one decimal place")
    func formatMeanError() async {
        let result = MatchingStatisticsView.formatMeanError(12.34)
        let expected = 12.3.formatted(.number.precision(.fractionLength(1)))
        #expect(result.contains(expected))
    }

    @Test("formats mean error nil as dash")
    func formatMeanErrorNil() async {
        #expect(MatchingStatisticsView.formatMeanError(nil) == "—")
    }

    @Test("formats stdDev with one decimal place and ± prefix")
    func formatStdDev() async {
        let result = MatchingStatisticsView.formatStdDev(5.67)
        let expected = 5.7.formatted(.number.precision(.fractionLength(1)))
        #expect(result.contains("±"))
        #expect(result.contains(expected))
    }

    @Test("formats stdDev nil as dash")
    func formatStdDevNil() async {
        #expect(MatchingStatisticsView.formatStdDev(nil) == "—")
    }

    @Test("formats sample count as plain integer string")
    func formatSampleCount() async {
        #expect(MatchingStatisticsView.formatSampleCount(42) == "42")
    }

    @Test("formats zero sample count")
    func formatZeroSampleCount() async {
        #expect(MatchingStatisticsView.formatSampleCount(0) == "0")
    }

    // MARK: - Accessibility

    @Test("accessibility label for mean error includes value")
    func accessibilityMeanError() async {
        let label = MatchingStatisticsView.accessibilityMeanError(12.3)
        let expected = 12.3.formatted(.number.precision(.fractionLength(1)))
        #expect(!label.isEmpty)
        #expect(label.contains(expected))
    }

    @Test("accessibility label for mean error nil describes empty state")
    func accessibilityMeanErrorNil() async {
        let label = MatchingStatisticsView.accessibilityMeanError(nil)
        #expect(!label.isEmpty)
    }

    @Test("accessibility label for samples includes count")
    func accessibilitySamples() async {
        let label = MatchingStatisticsView.accessibilitySamples(15)
        #expect(!label.isEmpty)
        #expect(label.contains("15"))
    }
}
