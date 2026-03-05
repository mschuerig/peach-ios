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
    /// EWMA half-life shared across all training modes (7 days).
    private static let defaultEWMAHalflife: Duration = .seconds(7 * 86400)

    /// Maximum gap between consecutive records within one session (30 minutes).
    private static let defaultSessionGap: Duration = .seconds(1800)

    static let unisonPitchComparison = TrainingModeConfig(
        displayName: String(localized: "Hear & Compare – Single Notes"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(8.0),
        ewmaHalflife: defaultEWMAHalflife,
        sessionGap: defaultSessionGap
    )

    static let intervalPitchComparison = TrainingModeConfig(
        displayName: String(localized: "Hear & Compare – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(12.0),
        ewmaHalflife: defaultEWMAHalflife,
        sessionGap: defaultSessionGap
    )

    static let unisonMatching = TrainingModeConfig(
        displayName: String(localized: "Tune & Match – Single Notes"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(5.0),
        ewmaHalflife: defaultEWMAHalflife,
        sessionGap: defaultSessionGap
    )

    static let intervalMatching = TrainingModeConfig(
        displayName: String(localized: "Tune & Match – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(8.0),
        ewmaHalflife: defaultEWMAHalflife,
        sessionGap: defaultSessionGap
    )
}
