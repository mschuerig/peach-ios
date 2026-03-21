/// The statistical summary returned from profile queries.
///
/// Each case wraps measurement-appropriate statistics. Most consumers
/// use the common computed properties and never need to pattern match.
/// Only consumers that need continuous-specific data (e.g., `welford.mean`
/// for adaptive difficulty) match on `.continuous(let stats)`.
enum StatisticalSummary: Sendable {
    /// Statistics for continuous numeric measurements (cents, milliseconds).
    case continuous(TrainingModeStatistics)

    var recordCount: Int {
        switch self { case .continuous(let s): s.recordCount }
    }

    var trend: Trend? {
        switch self { case .continuous(let s): s.trend }
    }

    var ewma: Double? {
        switch self { case .continuous(let s): s.ewma }
    }

    var metrics: [MetricPoint] {
        switch self { case .continuous(let s): s.metrics }
    }
}
