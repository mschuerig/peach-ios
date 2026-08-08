import Foundation

/// Renders a Compare Timing offset for display.
///
/// Timing Offset Detection measures milliseconds — settled by story 83.2, which
/// rejected tempo-normalized percent-of-a-sixteenth because milliseconds are the
/// measured quantity and percent is derived. The number is formatted by
/// `MetricValueFormatter` so it follows the user's locale.
///
/// The unit is always supplied by the caller from the discipline's
/// `TrainingDisciplineConfig` — `unitSymbol` when rendered, `unitLabel` when
/// spoken — never assumed here. That keeps the discipline's declaration the one
/// place a unit changes, which is the contract `MetricValueFormatter` documents
/// and `RhythmProfileCardView` already follows.
enum TimingOffsetFormatter {
    static func compact(_ ms: Double, unitSymbol: String) -> String {
        MetricValueFormatter.format(ms) + " " + unitSymbol
    }

    static func spoken(_ ms: Double, unitLabel: String) -> String {
        MetricValueFormatter.format(ms) + " " + unitLabel
    }
}
