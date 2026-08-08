import Testing
@testable import Peach

@Suite("TimingOffsetFormatter Tests")
struct TimingOffsetFormatterTests {

    // A sentinel unit breaks the self-reference: the formatter cannot produce
    // "UNIT" from anything it computes internally, so these assertions fail if
    // the unit is dropped, reordered, or the separator changes. Comparing
    // against `String(localized: "ms")` instead would pass while rendering
    // nothing at all.
    @Test("compact renders '<number> <symbol>'")
    func compactRendersNumberThenSymbol() async {
        #expect(TimingOffsetFormatter.compact(38.0, unitSymbol: "UNIT") == "\(MetricValueFormatter.format(38.0)) UNIT")
        #expect(TimingOffsetFormatter.compact(7.5, unitSymbol: "UNIT") == "\(MetricValueFormatter.format(7.5)) UNIT")
    }

    @Test("spoken renders '<number> <label>'")
    func spokenRendersNumberThenLabel() async {
        #expect(TimingOffsetFormatter.spoken(38.0, unitLabel: "SPELLED") == "\(MetricValueFormatter.format(38.0)) SPELLED")
    }

    @Test("the unit is always emitted")
    func unitIsAlwaysEmitted() async {
        for ms in [0.0, 7.5, 38.0, 120.4] {
            #expect(TimingOffsetFormatter.compact(ms, unitSymbol: "UNIT").hasSuffix(" UNIT"))
            #expect(TimingOffsetFormatter.spoken(ms, unitLabel: "SPELLED").hasSuffix(" SPELLED"))
        }
    }

    // The whole point of story 83.6: percent-of-a-sixteenth was rejected by
    // story 83.2 and must not reach any user-facing timing surface.
    @Test("neither form renders a percentage")
    func neverRendersPercent() async {
        for ms in [0.0, 7.5, 38.0, 120.4] {
            #expect(TimingOffsetFormatter.compact(ms, unitSymbol: "UNIT").contains("%") == false)
            #expect(TimingOffsetFormatter.spoken(ms, unitLabel: "SPELLED").contains("%") == false)
        }
    }

    // The unit comes from the discipline's config, so changing that declaration
    // must change what the training screen renders -- the single-source-of-truth
    // contract `MetricValueFormatter` documents.
    @Test("the discipline supplies distinct rendered and spoken units")
    func disciplineSuppliesBothUnitForms() async {
        let config = TrainingDisciplineID.timingOffsetDetection.config
        #expect(config.unitSymbol != config.unitLabel)
        #expect(TimingOffsetFormatter.compact(38.0, unitSymbol: config.unitSymbol).hasSuffix(config.unitSymbol))
        #expect(TimingOffsetFormatter.spoken(38.0, unitLabel: config.unitLabel).hasSuffix(config.unitLabel))
    }

    @Test("zero renders without a sign artifact")
    func zeroRendersCleanly() async {
        let text = TimingOffsetFormatter.compact(0.0, unitSymbol: "UNIT")
        #expect(text.contains("-") == false)
        #expect(text == "\(MetricValueFormatter.format(0.0)) UNIT")
    }
}
