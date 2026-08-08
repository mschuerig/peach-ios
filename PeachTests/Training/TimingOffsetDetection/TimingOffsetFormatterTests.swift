import Testing
@testable import Peach

@Suite("TimingOffsetFormatter Tests")
struct TimingOffsetFormatterTests {

    @Test("compact form carries the locale-formatted number")
    func compactUsesLocaleFormattedNumber() async {
        #expect(TimingOffsetFormatter.compact(38.0).contains(MetricValueFormatter.format(38.0)))
        #expect(TimingOffsetFormatter.compact(7.5).contains(MetricValueFormatter.format(7.5)))
    }

    @Test("spoken form carries the locale-formatted number")
    func spokenUsesLocaleFormattedNumber() async {
        #expect(TimingOffsetFormatter.spoken(38.0).contains(MetricValueFormatter.format(38.0)))
    }

    // The whole point of story 83.6: percent-of-a-sixteenth was rejected by story
    // 83.2 and must not reach any user-facing timing surface.
    @Test("neither form renders a percentage")
    func neverRendersPercent() async {
        for ms in [0.0, 7.5, 38.0, 120.4] {
            #expect(TimingOffsetFormatter.compact(ms).contains("%") == false)
            #expect(TimingOffsetFormatter.spoken(ms).contains("%") == false)
        }
    }

    // Guards the unitSymbol / unitLabel distinction story 83.5 established: the
    // abbreviated form is rendered, the spelled-out form is spoken. Comparing the
    // two forms to each other rather than to English literals keeps this
    // meaningful in German ("ms" vs "Millisekunden").
    @Test("spoken form is spelled out, compact form is abbreviated")
    func spokenIsDistinctFromCompact() async {
        let compact = TimingOffsetFormatter.compact(38.0)
        let spoken = TimingOffsetFormatter.spoken(38.0)
        #expect(compact != spoken)
        #expect(spoken.count > compact.count)
    }

    @Test("zero renders without a sign artifact")
    func zeroRendersCleanly() async {
        let text = TimingOffsetFormatter.compact(0.0)
        #expect(text.contains("-") == false)
        #expect(text.isEmpty == false)
    }
}
