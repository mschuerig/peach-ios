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

    @Test("rounds rather than truncating")
    func roundsRatherThanTruncating() async {
        let up = MetricValueFormatter.format(8.26)
        let down = MetricValueFormatter.format(8.24)
        #expect(up != down, "8.26 and 8.24 must not collapse to the same string")
        #expect(up.hasSuffix("3"), "got \(up)")
        #expect(down.hasSuffix("2"), "got \(down)")
    }

    @Test("uses NumberFormatter's default banker's rounding on exact halves")
    func roundsHalfEven() async {
        // Pinned deliberately: 8.25 is exactly representable in binary, so this
        // is a true half. NumberFormatter defaults to .halfEven, giving 8.2 and
        // not 8.3. Switching to .halfUp would shift displayed metrics by a
        // tenth across every discipline, which is the kind of change that
        // should break a test rather than surprise a user.
        #expect(MetricValueFormatter.format(8.25).hasSuffix("2"), "got \(MetricValueFormatter.format(8.25))")
    }

    @Test("formats negative values, which the signed cent domain produces")
    func formatsNegativeValues() async {
        let result = MetricValueFormatter.format(-8.25)
        // Minus may be U+002D or U+2212 depending on locale, so assert on the
        // digits and on it differing from the positive rendering.
        #expect(result.contains("8"), "got \(result)")
        #expect(result != MetricValueFormatter.format(8.25), "got \(result)")
    }

    @Test("Cents.formatted stays delegated to the shared formatter")
    func centsDelegates() async {
        // Not a tautology against today's one-line body — it is a regression
        // guard: if someone reimplements `Cents.formatted()` with its own
        // formatter, cent values would drift from every other metric surface.
        // `Cents.formatted()` was reimplemented in terms of this type; the two
        // must not drift apart.
        #expect(Cents(8.25).formatted() == MetricValueFormatter.format(8.25))
        #expect(Cents(0).formatted() == MetricValueFormatter.format(0))
    }
}
