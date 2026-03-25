/// Unified protocol for querying training statistics across all modes.
///
/// Returns `StatisticalSummary` — a sum type where each case wraps
/// measurement-appropriate statistics. Most consumers use the common
/// computed properties and never need to pattern match.
protocol TrainingProfile: AnyObject {
    func statistics(for key: StatisticsKey) -> StatisticalSummary?
}

extension TrainingProfile {
    /// Merges statistics from multiple keys into a single summary.
    ///
    /// Collects all metric points from the given keys, sorts them
    /// chronologically, and rebuilds a unified `StatisticalSummary`.
    /// Returns `nil` if none of the keys have data.
    func mergedStatistics(for keys: [StatisticsKey]) -> StatisticalSummary? {
        let allMetrics = keys.compactMap { statistics(for: $0) }
            .flatMap { $0.metrics }
            .sorted { $0.timestamp < $1.timestamp }
        guard !allMetrics.isEmpty,
              let config = keys.first?.statisticsConfig else { return nil }
        var stats = TrainingDisciplineStatistics()
        stats.rebuild(from: allMetrics, config: config)
        return .continuous(stats)
    }
}
