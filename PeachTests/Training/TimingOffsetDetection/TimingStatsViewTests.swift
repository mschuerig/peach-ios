import Testing
@testable import Peach

@Suite("TimingStatsView Tests")
struct TimingStatsViewTests {

    @Test("percentageText formats with no decimal places")
    func percentageTextFormatting() async {
        #expect(TimingStatsView.percentageText(4.0) == "4%")
        #expect(TimingStatsView.percentageText(12.6) == "13%")
        #expect(TimingStatsView.percentageText(0.7) == "1%")
    }

    @Test("percentageText includes ms when provided")
    func percentageTextWithMs() async {
        #expect(TimingStatsView.percentageText(8.0, ms: 12.0) == "8% (12 ms)")
    }

    @Test("percentageText omits ms when nil")
    func percentageTextWithoutMs() async {
        #expect(TimingStatsView.percentageText(8.0, ms: nil) == "8%")
    }

    @Test("msText rounds and appends unit")
    func msTextFormatting() async {
        #expect(TimingStatsView.msText(12.4) == "12 ms")
        #expect(TimingStatsView.msText(12.6) == "13 ms")
        #expect(TimingStatsView.msText(0.0) == "0 ms")
    }

    @Test("trend symbols match expected SF Symbols")
    func trendSymbols() async {
        #expect(TimingStatsView.trendSymbol(.improving) == "arrow.down.right")
        #expect(TimingStatsView.trendSymbol(.stable) == "arrow.right")
        #expect(TimingStatsView.trendSymbol(.declining) == "arrow.up.right")
    }

    @Test("latest accessibility label is non-empty and contains percentage")
    func latestAccessibilityLabel() async {
        let label = TimingStatsView.latestAccessibilityLabel(4.0, trend: .improving)
        #expect(!label.isEmpty)
        #expect(label.contains("4%"))
    }

    @Test("best accessibility label is non-empty and contains percentage")
    func bestAccessibilityLabel() async {
        let label = TimingStatsView.bestAccessibilityLabel(2.0)
        #expect(!label.isEmpty)
        #expect(label.contains("2%"))
    }

    @Test("latest accessibility label without trend is non-empty")
    func latestAccessibilityLabelNoTrend() async {
        let label = TimingStatsView.latestAccessibilityLabel(10.0, trend: nil)
        #expect(!label.isEmpty)
        #expect(label.contains("10%"))
    }
}
