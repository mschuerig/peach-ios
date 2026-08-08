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

    // Sentinel units pin the rendered lines the screen actually shows. Dropping
    // the unit, swapping the compact form for the spoken one, or losing the
    // "Latest:" / "Best:" prefix all fail here.
    @Test("latest line renders the label, the number and the unit symbol")
    func latestLineRendersFully() async {
        let text = TimingStatsView.latestText(38.0, unitSymbol: "UNIT")
        #expect(text.contains(MetricValueFormatter.format(38.0)))
        #expect(text.hasSuffix(" UNIT"))
        #expect(text != TimingOffsetFormatter.compact(38.0, unitSymbol: "UNIT"), "the line must carry its label, not just the value")
    }

    @Test("best line renders the label, the number and the unit symbol")
    func bestLineRendersFully() async {
        let text = TimingStatsView.bestText(31.0, unitSymbol: "UNIT")
        #expect(text.contains(MetricValueFormatter.format(31.0)))
        #expect(text.hasSuffix(" UNIT"))
        #expect(text != TimingOffsetFormatter.compact(31.0, unitSymbol: "UNIT"), "the line must carry its label, not just the value")
    }

    @Test("latest and best lines are distinguishable")
    func latestAndBestLinesDiffer() async {
        #expect(TimingStatsView.latestText(38.0, unitSymbol: "UNIT") != TimingStatsView.bestText(38.0, unitSymbol: "UNIT"))
    }

    @Test("neither rendered line contains a percentage")
    func renderedLinesNeverShowPercent() async {
        #expect(TimingStatsView.latestText(38.0, unitSymbol: "UNIT").contains("%") == false)
        #expect(TimingStatsView.bestText(38.0, unitSymbol: "UNIT").contains("%") == false)
    }

    @Test("latest accessibility label speaks the spelled-out unit, never percent")
    func latestAccessibilityLabelSpeaksMilliseconds() async {
        let label = TimingStatsView.latestAccessibilityLabel(38.0, unitLabel: "SPELLED", trend: .improving)
        #expect(label.contains("SPELLED"))
        #expect(label.contains(MetricValueFormatter.format(38.0)))
        #expect(label.contains("%") == false)
    }

    @Test("latest accessibility label appends the trend")
    func latestAccessibilityLabelAppendsTrend() async {
        let withTrend = TimingStatsView.latestAccessibilityLabel(38.0, unitLabel: "SPELLED", trend: .improving)
        let withoutTrend = TimingStatsView.latestAccessibilityLabel(38.0, unitLabel: "SPELLED", trend: nil)
        #expect(withTrend.contains(TimingStatsView.trendLabel(.improving)))
        #expect(withTrend.count > withoutTrend.count)
        #expect(withoutTrend.isEmpty == false)
    }

    @Test("best accessibility label speaks the spelled-out unit, never percent")
    func bestAccessibilityLabelSpeaksMilliseconds() async {
        let label = TimingStatsView.bestAccessibilityLabel(31.0, unitLabel: "SPELLED")
        #expect(label.contains("SPELLED"))
        #expect(label.contains(MetricValueFormatter.format(31.0)))
        #expect(label.contains("%") == false)
    }

    // Latest and Best are distinct readouts; a label that failed to distinguish
    // them would leave VoiceOver users unable to tell which figure they heard.
    @Test("latest and best labels are distinguishable")
    func latestAndBestLabelsDiffer() async {
        let latest = TimingStatsView.latestAccessibilityLabel(38.0, unitLabel: "SPELLED", trend: nil)
        let best = TimingStatsView.bestAccessibilityLabel(38.0, unitLabel: "SPELLED")
        #expect(latest != best)
    }

    // The spoken form must not be the abbreviation: VoiceOver should say
    // "milliseconds", not "ms". Guards the unitLabel / unitSymbol split.
    @Test("the accessibility label uses the spoken unit, not the compact one")
    func accessibilityUsesSpokenUnit() async {
        let config = TrainingDisciplineID.timingOffsetDetection.config
        let label = TimingStatsView.latestAccessibilityLabel(38.0, unitLabel: config.unitLabel, trend: nil)
        #expect(label.contains(config.unitLabel))
        #expect(label.hasSuffix(config.unitSymbol) == false)
    }
}
