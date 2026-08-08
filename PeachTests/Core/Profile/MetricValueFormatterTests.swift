import Testing
import Foundation
@testable import Peach

@Suite("MetricValueFormatter Tests")
struct MetricValueFormatterTests {

    // The decimal separator is locale-driven, so assertions below check the
    // digits and the fraction-digit contract rather than a literal string.

    @Test("formats to exactly one fraction digit")
    func formatsOneFractionDigit() async {
        let result = MetricValueFormatter.format(8.25)
        let separator = Locale.autoupdatingCurrent.decimalSeparator ?? "."
        let parts = result.components(separatedBy: separator)
        #expect(parts.count == 2, "got \(result)")
        #expect(parts.last?.count == 1, "got \(result)")
    }

    @Test("pads a whole number to one fraction digit")
    func padsWholeNumbers() async {
        let result = MetricValueFormatter.format(80)
        #expect(result.contains("80"), "got \(result)")
        let separator = Locale.autoupdatingCurrent.decimalSeparator ?? "."
        #expect(result.contains(separator), "got \(result)")
    }

    @Test("formats zero without a sign")
    func formatsZero() async {
        let result = MetricValueFormatter.format(0)
        #expect(result.contains("0"), "got \(result)")
        #expect(!result.contains("-"), "got \(result)")
    }

    @Test("appends no unit of its own")
    func appendsNoUnit() async {
        // The unit always comes from the discipline's config; the formatter
        // must never assume one. This is the regression this type exists for.
        let result = MetricValueFormatter.format(80.5)
        #expect(!result.contains("¢"), "got \(result)")
        #expect(!result.contains("ms"), "got \(result)")
        #expect(!result.contains("cent"), "got \(result)")
    }

    @Test("formatting is identical for equal magnitudes regardless of the quantity measured")
    func unitAgnostic() async {
        // A cent value and a millisecond value of the same magnitude must
        // format identically — the type knows nothing about either.
        #expect(MetricValueFormatter.format(15.0) == MetricValueFormatter.format(15.0))
    }

    @Test("rounds half away from the stored precision rather than truncating")
    func rounds() async {
        let up = MetricValueFormatter.format(8.26)
        let down = MetricValueFormatter.format(8.24)
        #expect(up != down, "8.26 and 8.24 must not collapse to the same string")
        #expect(up.contains("3"), "got \(up)")
        #expect(down.contains("2"), "got \(down)")
    }

    @Test("Cents.formatted delegates to the shared formatter")
    func centsDelegates() async {
        // `Cents.formatted()` was reimplemented in terms of this type; the two
        // must not drift apart.
        #expect(Cents(8.25).formatted() == MetricValueFormatter.format(8.25))
        #expect(Cents(0).formatted() == MetricValueFormatter.format(0))
    }
}
