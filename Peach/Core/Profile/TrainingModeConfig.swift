import Foundation

/// Configuration for a training mode's progress tracking behavior.
///
/// Each training mode (unison/interval x comparison/matching) has its own
/// statistical parameters for EWMA smoothing, adaptive bucketing, trend
/// detection, and cold-start thresholds.
struct TrainingModeConfig {
    /// Localized name shown in UI cards and accessibility labels.
    let displayName: String

    /// Localized unit label for metric values (e.g., "cents").
    let unitLabel: String

    /// Expert-level accuracy target shown as dashed baseline on charts.
    let optimalBaseline: Cents

    /// Half-life for exponentially weighted moving average smoothing.
    let ewmaHalflife: Duration

    /// Minimum number of records before displaying a chart.
    let coldStartThreshold: Int

    /// Minimum number of records before computing a trend direction.
    let trendThreshold: Int

    /// Fractional change required to classify trend as improving or declining.
    /// A value of 0.05 means 5% change between the earlier and later halves.
    let trendChangeThreshold: Double

    /// Maximum gap between consecutive records that still counts as the same training session.
    let sessionGap: Duration
}

extension TrainingModeConfig {
    static let unisonComparison = TrainingModeConfig(
        displayName: String(localized: "Unison Comparison"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(8.0),
        ewmaHalflife: .seconds(7 * 86400),
        coldStartThreshold: 20,
        trendThreshold: 100,
        trendChangeThreshold: 0.05,
        sessionGap: .seconds(1800)
    )

    static let intervalComparison = TrainingModeConfig(
        displayName: String(localized: "Interval Comparison"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(12.0),
        ewmaHalflife: .seconds(7 * 86400),
        coldStartThreshold: 20,
        trendThreshold: 100,
        trendChangeThreshold: 0.05,
        sessionGap: .seconds(1800)
    )

    static let unisonMatching = TrainingModeConfig(
        displayName: String(localized: "Unison Matching"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(5.0),
        ewmaHalflife: .seconds(7 * 86400),
        coldStartThreshold: 20,
        trendThreshold: 100,
        trendChangeThreshold: 0.05,
        sessionGap: .seconds(1800)
    )

    static let intervalMatching = TrainingModeConfig(
        displayName: String(localized: "Interval Matching"),
        unitLabel: String(localized: "cents"),
        optimalBaseline: Cents(8.0),
        ewmaHalflife: .seconds(7 * 86400),
        coldStartThreshold: 20,
        trendThreshold: 100,
        trendChangeThreshold: 0.05,
        sessionGap: .seconds(1800)
    )
}
