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
    /// Localized name shown in UI cards, menus, and accessibility labels
    /// (e.g., "Compare Pitch").
    let displayName: String

    /// Localized short label used as a card title or button label
    /// (e.g., "Compare", "Match", "Fill the Gap").
    let shortLabel: String

    /// SF Symbol name for the discipline's card icon.
    let systemImageName: String

    /// Whether this discipline renders as the visually prominent "hero" card
    /// at the top of its category section on the StartScreen.
    let isHero: Bool

    /// Localized markdown description shown under "Training Disciplines"
    /// on the Info screen (one paragraph per discipline, generated at runtime).
    let helpDescription: String

    /// Localized unit label for metric values, spelled out for speech and
    /// chart axes (e.g., "cents", "ms").
    let unitLabel: String

    /// Localized compact unit symbol for metric values rendered next to a
    /// number in tight layouts such as the Start screen cards (e.g., "¢",
    /// "ms"). Distinct from ``unitLabel``, which is spoken in full.
    let unitSymbol: String

    /// Expert-level accuracy target shown as dashed baseline on charts.
    let optimalBaseline: Double

    /// Statistical parameters for EWMA and session bucketing.
    let statistics: StatisticsConfig

    var ewmaHalflife: Duration { statistics.ewmaHalflife }
    var sessionGap: Duration { statistics.sessionGap }
}
