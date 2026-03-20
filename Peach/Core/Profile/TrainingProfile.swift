/// Unified protocol for querying training statistics across all modes.
///
/// Replaces the separate `PitchComparisonProfile`, `PitchMatchingProfile`,
/// `RhythmComparisonProfile`, and `RhythmMatchingProfile` protocols with
/// a single key-based lookup.
protocol TrainingProfile: AnyObject {
    func statistics(for key: StatisticsKey) -> TrainingModeStatistics?
}
