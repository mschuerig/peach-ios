import Testing
@testable import Peach

#if PEACH_RESEARCH
@Suite("ContinuousRhythmMatchingScreen")
struct ContinuousRhythmMatchingScreenTests {

    // MARK: - Layout Parameters

    @Test("compact button min height is smaller than regular")
    func compactButtonMinHeight() async {
        #expect(ContinuousRhythmMatchingScreen.buttonMinHeight(isCompact: true) <
                ContinuousRhythmMatchingScreen.buttonMinHeight(isCompact: false))
    }

    @Test("compact button text font differs from regular")
    func compactButtonTextFont() async {
        #expect(ContinuousRhythmMatchingScreen.buttonTextFont(isCompact: true) !=
                ContinuousRhythmMatchingScreen.buttonTextFont(isCompact: false))
    }

    // MARK: - Help Sections

    @Test("has three help sections")
    func helpSectionCount() async {
        #expect(ContinuousRhythmMatchingHelp.trainingScreen.count == 3)
    }

    @Test("help sections have Goal, Controls, Feedback titles")
    func helpSectionTitles() async {
        let titles = ContinuousRhythmMatchingHelp.trainingScreen.map(\.title)
        #expect(titles.contains(String(localized: "Goal")))
        #expect(titles.contains(String(localized: "Controls")))
        #expect(titles.contains(String(localized: "Feedback")))
    }

    // MARK: - Stats Formatting

    @Test("cycleProgressText shows count out of 16")
    func cycleProgressText() async {
        #expect(ContinuousRhythmMatchingScreen.cycleProgressText(4) == "4/16")
    }

    // Story 83.6 moved this formatting out of `TimingStatsView.percentageText`,
    // whose tests were deleted with it. Continuous Rhythm Matching is
    // research-only and deliberately still reports percent-of-a-sixteenth, so
    // these pin the output the transplant was required to preserve exactly.
    @Test("meanOffsetText renders percent with milliseconds in parentheses")
    func meanOffsetTextFormat() async {
        #expect(ContinuousRhythmMatchingScreen.meanOffsetText(8.0, ms: 12.0) == "8% (12 \(String(localized: "ms")))")
    }

    @Test("meanOffsetText rounds both figures half-up")
    func meanOffsetTextRounding() async {
        #expect(ContinuousRhythmMatchingScreen.meanOffsetText(12.6, ms: 12.4) == "13% (12 \(String(localized: "ms")))")
        #expect(ContinuousRhythmMatchingScreen.meanOffsetText(0.7, ms: 12.6) == "1% (13 \(String(localized: "ms")))")
    }

    @Test("meanOffsetText keeps the percentage, which this discipline still reports")
    func meanOffsetTextKeepsPercent() async {
        #expect(ContinuousRhythmMatchingScreen.meanOffsetText(15.0, ms: 37.0).contains("%"))
    }
}
#endif
