import Foundation

/// Configuration for a training mode's progress tracking behavior.
///
/// Each training mode (unison/interval x comparison/matching) has its own
/// statistical parameters for EWMA smoothing, adaptive bucketing, and trend
/// detection.
struct TrainingModeConfig {
    /// Localized name shown in UI cards and accessibility labels.
    let displayName: String

    /// Localized unit label for metric values (e.g., "cents").
    let unitLabel: String

    /// Expert-level accuracy target shown as dashed baseline on charts.
    let optimalBaseline: Cents

    /// Half-life for exponentially weighted moving average smoothing.
    let ewmaHalflife: Duration

    /// Maximum gap between consecutive records that still counts as the same training session.
    let sessionGap: Duration
}

extension TrainingModeConfig {
    static let unisonComparison = TrainingModeConfig(
        displayName: String(localized: "Hear & Compare – Single Notes"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(8.0),
        ewmaHalflife: .seconds(7 * 86400),
        sessionGap: .seconds(1800)
    )

    static let intervalComparison = TrainingModeConfig(
        displayName: String(localized: "Hear & Compare – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(12.0),
        ewmaHalflife: .seconds(7 * 86400),
        sessionGap: .seconds(1800)
    )

    static let unisonMatching = TrainingModeConfig(
        displayName: String(localized: "Tune & Match – Single Notes"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(5.0),
        ewmaHalflife: .seconds(7 * 86400),
        sessionGap: .seconds(1800)
    )

    static let intervalMatching = TrainingModeConfig(
        displayName: String(localized: "Tune & Match – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(8.0),
        ewmaHalflife: .seconds(7 * 86400),
        sessionGap: .seconds(1800)
    )
}
