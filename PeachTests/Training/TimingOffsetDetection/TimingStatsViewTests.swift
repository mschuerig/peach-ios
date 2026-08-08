import Testing
@testable import Peach

@Suite("TimingStatsView Tests")
struct TimingStatsViewTests {

    @Test("trend symbols match expected SF Symbols")
    func trendSymbols() async {
        #expect(TimingStatsView.trendSymbol(.improving) == "arrow.down.right")
        #expect(TimingStatsView.trendSymbol(.stable) == "arrow.right")
        #expect(TimingStatsView.trendSymbol(.declining) == "arrow.up.right")
    }

    @Test("latest accessibility label speaks milliseconds, never percent")
    func latestAccessibilityLabelSpeaksMilliseconds() async {
        let label = TimingStatsView.latestAccessibilityLabel(38.0, trend: .improving)
        #expect(label.contains(TimingOffsetFormatter.spoken(38.0)))
        #expect(label.contains("%") == false)
    }

    @Test("latest accessibility label appends the trend")
    func latestAccessibilityLabelAppendsTrend() async {
        let withTrend = TimingStatsView.latestAccessibilityLabel(38.0, trend: .improving)
        let withoutTrend = TimingStatsView.latestAccessibilityLabel(38.0, trend: nil)
        #expect(withTrend.contains(TimingStatsView.trendLabel(.improving)))
        #expect(withTrend.count > withoutTrend.count)
        #expect(withoutTrend.isEmpty == false)
    }

    @Test("best accessibility label speaks milliseconds, never percent")
    func bestAccessibilityLabelSpeaksMilliseconds() async {
        let label = TimingStatsView.bestAccessibilityLabel(31.0)
        #expect(label.contains(TimingOffsetFormatter.spoken(31.0)))
        #expect(label.contains("%") == false)
    }

    // Latest and Best are distinct readouts; a label that failed to distinguish
    // them would leave VoiceOver users unable to tell which figure they heard.
    @Test("latest and best labels are distinguishable")
    func latestAndBestLabelsDiffer() async {
        let latest = TimingStatsView.latestAccessibilityLabel(38.0, trend: nil)
        let best = TimingStatsView.bestAccessibilityLabel(38.0)
        #expect(latest != best)
    }
}
