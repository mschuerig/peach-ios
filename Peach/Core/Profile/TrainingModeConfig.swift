import Foundation

/// Statistical parameters shared by all training modes (pitch and rhythm).
struct StatisticsConfig: Sendable {
    /// Half-life for exponentially weighted moving average smoothing.
    let ewmaHalflife: Duration

    /// Maximum gap between consecutive records that still counts as the same training session.
    let sessionGap: Duration

    static let `default` = StatisticsConfig(
        ewmaHalflife: .seconds(7 * 86400),
        sessionGap: .seconds(1800)
    )
}

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
    let optimalBaseline: Double

    /// Statistical parameters for EWMA and session bucketing.
    let statistics: StatisticsConfig

    var ewmaHalflife: Duration { statistics.ewmaHalflife }
    var sessionGap: Duration { statistics.sessionGap }
}

extension TrainingModeConfig {
    static let unisonPitchComparison = TrainingModeConfig(
        displayName: String(localized: "Hear & Compare – Single Notes"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 8.0,
        statistics: .default
    )

    static let intervalPitchComparison = TrainingModeConfig(
        displayName: String(localized: "Hear & Compare – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 12.0,
        statistics: .default
    )

    static let unisonMatching = TrainingModeConfig(
        displayName: String(localized: "Tune & Match – Single Notes"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 5.0,
        statistics: .default
    )

    static let intervalMatching = TrainingModeConfig(
        displayName: String(localized: "Tune & Match – Intervals"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: 8.0,
        statistics: .default
    )

    static let rhythmComparison = TrainingModeConfig(
        displayName: String(localized: "Hear & Compare – Rhythm"),
        unitLabel: String(localized: "ms"),
        optimalBaseline: 15.0,
        statistics: .default
    )

    static let rhythmMatching = TrainingModeConfig(
        displayName: String(localized: "Tap & Match – Rhythm"),
        unitLabel: String(localized: "ms"),
        optimalBaseline: 20.0,
        statistics: .default
    )
}
