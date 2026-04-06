import Testing
@testable import Peach

@Suite("RhythmStatsView Tests")
struct RhythmStatsViewTests {

    @Test("percentageText formats with no decimal places")
    func percentageTextFormatting() async {
        #expect(RhythmStatsView.percentageText(4.0) == "4%")
        #expect(RhythmStatsView.percentageText(12.6) == "13%")
        #expect(RhythmStatsView.percentageText(0.7) == "1%")
    }

    @Test("percentageText includes ms when provided")
    func percentageTextWithMs() async {
        #expect(RhythmStatsView.percentageText(8.0, ms: 12.0) == "8% (12 ms)")
    }

    @Test("percentageText omits ms when nil")
    func percentageTextWithoutMs() async {
        #expect(RhythmStatsView.percentageText(8.0, ms: nil) == "8%")
    }

    @Test("msText rounds and appends unit")
    func msTextFormatting() async {
        #expect(RhythmStatsView.msText(12.4) == "12 ms")
        #expect(RhythmStatsView.msText(12.6) == "13 ms")
        #expect(RhythmStatsView.msText(0.0) == "0 ms")
    }

    @Test("trend symbols match expected SF Symbols")
    func trendSymbols() async {
        #expect(RhythmStatsView.trendSymbol(.improving) == "arrow.down.right")
        #expect(RhythmStatsView.trendSymbol(.stable) == "arrow.right")
        #expect(RhythmStatsView.trendSymbol(.declining) == "arrow.up.right")
    }

    @Test("latest accessibility label is non-empty and contains percentage")
    func latestAccessibilityLabel() async {
        let label = RhythmStatsView.latestAccessibilityLabel(4.0, trend: .improving)
        #expect(!label.isEmpty)
        #expect(label.contains("4%"))
    }

    @Test("best accessibility label is non-empty and contains percentage")
    func bestAccessibilityLabel() async {
        let label = RhythmStatsView.bestAccessibilityLabel(2.0)
        #expect(!label.isEmpty)
        #expect(label.contains("2%"))
    }

    @Test("latest accessibility label without trend is non-empty")
    func latestAccessibilityLabelNoTrend() async {
        let label = RhythmStatsView.latestAccessibilityLabel(10.0, trend: nil)
        #expect(!label.isEmpty)
        #expect(label.contains("10%"))
    }
}
