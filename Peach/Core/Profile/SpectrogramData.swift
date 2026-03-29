import Foundation

// MARK: - Thresholds

/// Parameterized color thresholds for spectrogram cells.
///
/// Uses a hybrid model: base percentages of the sixteenth note duration,
/// clamped to absolute floor/ceiling values in milliseconds. This ensures
/// thresholds remain musically meaningful and physically achievable across
/// the full 40–200 BPM range. Four boundaries yield five accuracy levels.
struct SpectrogramThresholds: Sendable {
    struct Boundary: Sendable {
        let basePercent: Double
        let floorMs: Double
        let ceilingMs: Double
    }

    let excellent: Boundary
    let precise: Boundary
    let moderate: Boundary
    let loose: Boundary

    static let `default` = SpectrogramThresholds(
        excellent: Boundary(basePercent: 4.0, floorMs: 8.0, ceilingMs: 15.0),
        precise: Boundary(basePercent: 8.0, floorMs: 12.0, ceilingMs: 30.0),
        moderate: Boundary(basePercent: 15.0, floorMs: 20.0, ceilingMs: 40.0),
        loose: Boundary(basePercent: 25.0, floorMs: 30.0, ceilingMs: 55.0)
    )

    func accuracyLevel(for percentage: Double?, tempoRange: TempoRange) -> SpectrogramAccuracyLevel? {
        guard let percentage else { return nil }
        let sixteenthMs = tempoRange.midpointTempo.sixteenthNoteDuration / .milliseconds(1)
        if percentage <= effectivePercent(boundary: excellent, sixteenthMs: sixteenthMs) { return .excellent }
        if percentage <= effectivePercent(boundary: precise, sixteenthMs: sixteenthMs) { return .precise }
        if percentage <= effectivePercent(boundary: moderate, sixteenthMs: sixteenthMs) { return .moderate }
        if percentage <= effectivePercent(boundary: loose, sixteenthMs: sixteenthMs) { return .loose }
        return .erratic
    }

    private func effectivePercent(boundary: Boundary, sixteenthMs: Double) -> Double {
        let effectiveMs = min(max(sixteenthMs * boundary.basePercent / 100.0, boundary.floorMs), boundary.ceilingMs)
        return (effectiveMs / sixteenthMs) * 100.0
    }
}

/// Visual accuracy classification for spectrogram heat map cells.
enum SpectrogramAccuracyLevel: Sendable {
    case excellent
    case precise
    case moderate
    case loose
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

        // Collect all metrics per coarse (default) TempoRange × Direction
        var coarseMetrics: [TempoRange: [RhythmDirection: [MetricPoint]]] = [:]
        for range in TempoRange.defaultRanges {
            for direction in RhythmDirection.allCases {
                let key = StatisticsKey.rhythm(mode, range, direction)
                if let summary = profile.statistics(for: key) {
                    let metrics = summary.metrics
                    if !metrics.isEmpty {
                        coarseMetrics[range, default: [:]][direction] = metrics
                    }
                }
            }
        }

        // Map fine spectrogram ranges to coarse ranges; include only those with data
        let trainedRanges = TempoRange.spectrogramRanges.filter { fine in
            guard let coarse = fine.enclosingDefaultRange else { return false }
            return coarseMetrics[coarse] != nil
        }
        guard !trainedRanges.isEmpty else {
            return SpectrogramData(columns: [], trainedRanges: [])
        }

        // Build columns — each fine range uses its enclosing coarse range's metrics
        let columns = timeBuckets.enumerated().map { columnIndex, bucket in
            let cells = trainedRanges.map { fineRange in
                let coarse = fineRange.enclosingDefaultRange ?? fineRange
                return makeCell(
                    range: fineRange,
                    columnIndex: columnIndex,
                    bucket: bucket,
                    earlyMetrics: coarseMetrics[coarse]?[.early] ?? [],
                    lateMetrics: coarseMetrics[coarse]?[.late] ?? []
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
