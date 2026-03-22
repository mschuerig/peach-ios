import Foundation

/// Statistical parameters shared by all training disciplines (pitch and rhythm).
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

/// Configuration for a training discipline's progress tracking behavior.
///
/// Each training discipline (unison/interval x comparison/matching) has its own
/// statistical parameters for EWMA smoothing, adaptive bucketing, and trend
/// detection.
struct TrainingDisciplineConfig {
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
