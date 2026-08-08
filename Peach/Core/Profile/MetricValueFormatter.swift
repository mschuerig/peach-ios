import Foundation

/// Formats a training metric value for display.
///
/// Metric values are discipline-agnostic: pitch disciplines measure cents,
/// rhythm disciplines measure milliseconds. The number is formatted here; the
/// unit always comes from the discipline's `TrainingDisciplineConfig`
/// (`unitLabel` when spoken, `unitSymbol` when rendered compactly) and is
/// never assumed by the formatter.
enum MetricValueFormatter {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        // A NumberFormatter snapshots its locale at construction. Because this
        // instance is a shared `static let` that outlives a Region change made
        // while the app is resident, it must track the current locale rather
        // than the one that happened to be active at first use.
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()

    static func format(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}
