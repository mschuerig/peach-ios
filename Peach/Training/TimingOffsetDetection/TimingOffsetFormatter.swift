import Foundation

/// Renders a Compare Timing offset for display.
///
/// Timing Offset Detection measures milliseconds — settled by story 83.2, which
/// rejected tempo-normalized percent-of-a-sixteenth because milliseconds are the
/// measured quantity and percent is derived. The number is formatted by
/// `MetricValueFormatter` so it follows the user's locale, and the unit comes in
/// the two forms story 83.5 established: abbreviated when rendered, spelled out
/// when spoken.
enum TimingOffsetFormatter {
    static func compact(_ ms: Double) -> String {
        MetricValueFormatter.format(ms) + " " + String(localized: "ms")
    }

    static func spoken(_ ms: Double) -> String {
        MetricValueFormatter.format(ms) + " " + String(localized: "milliseconds")
    }
}
