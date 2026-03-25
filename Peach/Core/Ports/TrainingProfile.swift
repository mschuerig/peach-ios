/// Unified protocol for querying training statistics across all modes.
///
/// Returns `StatisticalSummary` — a sum type where each case wraps
/// measurement-appropriate statistics. Most consumers use the common
/// computed properties and never need to pattern match.
protocol TrainingProfile: AnyObject {
    func statistics(for key: StatisticsKey) -> StatisticalSummary?
}
