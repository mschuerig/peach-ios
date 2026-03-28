import Foundation

// MARK: - Thresholds

/// Parameterized color thresholds for spectrogram cells (UX-DR4).
///
/// Uses a hybrid model: base percentages of the sixteenth note duration,
/// clamped to absolute floor/ceiling values in milliseconds. This ensures
/// thresholds remain musically meaningful and physically achievable across
/// the full 40–200 BPM range.
struct SpectrogramThresholds: Sendable {
    /// Base percentage of sixteenth note duration for "precise" boundary.
    let preciseBasePercent: Double
    /// Base percentage of sixteenth note duration for "moderate" boundary.
    let moderateBasePercent: Double
    /// Absolute floor in ms — precise threshold never goes below this.
    let preciseFloorMs: Double
    /// Absolute floor in ms — moderate threshold never goes below this.
    let moderateFloorMs: Double
    /// Absolute ceiling in ms — precise threshold never exceeds this.
    let preciseCeilingMs: Double
    /// Absolute ceiling in ms — moderate threshold never exceeds this.
    let moderateCeilingMs: Double

    static let `default` = SpectrogramThresholds(
        preciseBasePercent: 8.0,
        moderateBasePercent: 20.0,
        preciseFloorMs: 12.0,
        moderateFloorMs: 25.0,
        preciseCeilingMs: 30.0,
        moderateCeilingMs: 50.0
    )

    func accuracyLevel(for percentage: Double?, tempoRange: TempoRange) -> SpectrogramAccuracyLevel? {
        guard let percentage else { return nil }
        let sixteenthMs = tempoRange.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        let preciseMs = min(max(sixteenthMs * preciseBasePercent / 100.0, preciseFloorMs), preciseCeilingMs)
        let moderateMs = min(max(sixteenthMs * moderateBasePercent / 100.0, moderateFloorMs), moderateCeilingMs)
        let effectivePrecisePercent = (preciseMs / sixteenthMs) * 100.0
        let effectiveModeratePercent = (moderateMs / sixteenthMs) * 100.0
        if percentage <= effectivePrecisePercent { return .precise }
        if percentage <= effectiveModeratePercent { return .moderate }
        return .erratic
    }
}

/// Visual accuracy classification for spectrogram heat map cells.
enum SpectrogramAccuracyLevel: Sendable {
    case precise
    case moderate
    case erratic
}

// MARK: - Cell Stats

/// Directional statistics for a spectrogram cell's early or late hits.
struct SpectrogramCellStats: Sendable {
    let meanPercent: Double
    let stdDevPercent: Double
    let count: Int
}

// MARK: - Cell

/// A single cell in the spectrogram grid: one tempo range × one time bucket.
struct SpectrogramCell: Sendable {
    let tempoRange: TempoRange
    let columnIndex: Int
    let meanAccuracyPercent: Double?
    let earlyStats: SpectrogramCellStats?
    let lateStats: SpectrogramCellStats?
}

// MARK: - Column

/// A vertical slice of the spectrogram grid representing one time bucket.
struct SpectrogramColumn: Sendable, Identifiable {
    let index: Int
    let date: Date
    let bucketSize: BucketSize
    let cells: [SpectrogramCell]

    var id: Date { date }
}

// MARK: - SpectrogramData

/// Computed spectrogram grid data for a rhythm training discipline.
///
/// The X-axis is time (from `ProgressTimeline` bucketing), the Y-axis is
/// `TempoRange` (slow/medium/fast). Each cell's accuracy is expressed as
/// percentage of one sixteenth note at the range's midpoint tempo.
struct SpectrogramData: Sendable {
    let columns: [SpectrogramColumn]
    let trainedRanges: [TempoRange]

    static func compute(
        mode: TrainingDisciplineID,
        profile: TrainingProfile,
        timeBuckets: [TimeBucket]
    ) -> SpectrogramData {
        guard !timeBuckets.isEmpty else {
            return SpectrogramData(columns: [], trainedRanges: [])
        }

        // Collect all metrics per (TempoRange, Direction)
        var metricsMap: [TempoRange: [RhythmDirection: [MetricPoint]]] = [:]
        for range in TempoRange.defaultRanges {
            for direction in RhythmDirection.allCases {
                let key = StatisticsKey.rhythm(mode, range, direction)
                if let summary = profile.statistics(for: key) {
                    let metrics = summary.metrics
                    if !metrics.isEmpty {
                        metricsMap[range, default: [:]][direction] = metrics
                    }
                }
            }
        }

        let trainedRanges = TempoRange.defaultRanges.filter { metricsMap[$0] != nil }
        guard !trainedRanges.isEmpty else {
            return SpectrogramData(columns: [], trainedRanges: [])
        }

        // Build columns
        let columns = timeBuckets.enumerated().map { columnIndex, bucket in
            let cells = trainedRanges.map { range in
                makeCell(
                    range: range,
                    columnIndex: columnIndex,
                    bucket: bucket,
                    earlyMetrics: metricsMap[range]?[.early] ?? [],
                    lateMetrics: metricsMap[range]?[.late] ?? []
                )
            }
            return SpectrogramColumn(index: columnIndex, date: bucket.periodStart, bucketSize: bucket.bucketSize, cells: cells)
        }

        return SpectrogramData(columns: columns, trainedRanges: trainedRanges)
    }

    // MARK: - Private

    private static func makeCell(
        range: TempoRange,
        columnIndex: Int,
        bucket: TimeBucket,
        earlyMetrics: [MetricPoint],
        lateMetrics: [MetricPoint]
    ) -> SpectrogramCell {
        let earlyInBucket = filterToBucket(earlyMetrics, bucket: bucket)
        let lateInBucket = filterToBucket(lateMetrics, bucket: bucket)

        let sixteenthMs = range.midpointTempo.sixteenthNoteDuration / .milliseconds(1)

        let earlyStats = computeStats(earlyInBucket, sixteenthMs: sixteenthMs)
        let lateStats = computeStats(lateInBucket, sixteenthMs: sixteenthMs)

        let meanAccuracy = combinedMeanPercent(
            earlyMs: earlyInBucket.map(\.value),
            lateMs: lateInBucket.map(\.value),
            sixteenthMs: sixteenthMs
        )

        return SpectrogramCell(
            tempoRange: range,
            columnIndex: columnIndex,
            meanAccuracyPercent: meanAccuracy,
            earlyStats: earlyStats,
            lateStats: lateStats
        )
    }

    private static func filterToBucket(_ metrics: [MetricPoint], bucket: TimeBucket) -> [MetricPoint] {
        // Session buckets: periodEnd is the last metric's timestamp (inclusive).
        // Day/month buckets: periodEnd is the next period start (exclusive).
        let useInclusiveEnd = bucket.bucketSize == .session
        return metrics.filter {
            $0.timestamp >= bucket.periodStart &&
            (useInclusiveEnd ? $0.timestamp <= bucket.periodEnd : $0.timestamp < bucket.periodEnd)
        }
    }

    private static func computeStats(_ metrics: [MetricPoint], sixteenthMs: Double) -> SpectrogramCellStats? {
        guard !metrics.isEmpty else { return nil }
        let accumulator = WelfordAccumulator(metrics.map(\.value))
        return SpectrogramCellStats(
            meanPercent: msToPercent(accumulator.mean, sixteenthMs: sixteenthMs),
            stdDevPercent: msToPercent(accumulator.sampleStdDev ?? 0, sixteenthMs: sixteenthMs),
            count: accumulator.count
        )
    }

    private static func combinedMeanPercent(
        earlyMs: [Double],
        lateMs: [Double],
        sixteenthMs: Double
    ) -> Double? {
        let all = earlyMs.map { abs($0) } + lateMs.map { abs($0) }
        guard !all.isEmpty else { return nil }
        let mean = all.reduce(0.0, +) / Double(all.count)
        return msToPercent(mean, sixteenthMs: sixteenthMs)
    }

    private static func msToPercent(_ ms: Double, sixteenthMs: Double) -> Double {
        (ms / sixteenthMs) * 100.0
    }
}
