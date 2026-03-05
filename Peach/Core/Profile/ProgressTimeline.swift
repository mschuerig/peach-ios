import Foundation

// MARK: - Trend

/// Direction of a user's detection threshold trend over time.
enum Trend: Equatable {
    /// Threshold decreasing — user can detect smaller differences.
    case improving
    /// No significant change in detection ability.
    case stable
    /// Threshold increasing — user detects larger differences than before.
    case declining
}

// MARK: - Supporting Types

/// The four training mode categories tracked independently.
enum TrainingMode: CaseIterable {
    case unisonComparison
    case intervalComparison
    case unisonMatching
    case intervalMatching

    var config: TrainingModeConfig {
        switch self {
        case .unisonComparison: .unisonComparison
        case .intervalComparison: .intervalComparison
        case .unisonMatching: .unisonMatching
        case .intervalMatching: .intervalMatching
        }
    }

    /// Extracts metric points for this mode from raw training records.
    func extractMetrics(
        comparisonRecords: [ComparisonRecord],
        pitchMatchingRecords: [PitchMatchingRecord]
    ) -> [(timestamp: Date, value: Double)] {
        switch self {
        case .unisonComparison:
            comparisonRecords.filter { $0.isCorrect && $0.interval == 0 }
                .map { (timestamp: $0.timestamp, value: abs($0.centOffset)) }
        case .intervalComparison:
            comparisonRecords.filter { $0.isCorrect && $0.interval != 0 }
                .map { (timestamp: $0.timestamp, value: abs($0.centOffset)) }
        case .unisonMatching:
            pitchMatchingRecords.filter { $0.interval == 0 }
                .map { (timestamp: $0.timestamp, value: abs($0.userCentError)) }
        case .intervalMatching:
            pitchMatchingRecords.filter { $0.interval != 0 }
                .map { (timestamp: $0.timestamp, value: abs($0.userCentError)) }
        }
    }

    /// Returns a metric if this completed comparison belongs to this mode, nil otherwise.
    func metric(from completed: CompletedComparison) -> (timestamp: Date, value: Double)? {
        guard completed.isCorrect else { return nil }
        let interval = (try? Interval.between(completed.comparison.referenceNote, completed.comparison.targetNote.note))?.rawValue ?? 0
        let isUnison = interval == 0
        switch self {
        case .unisonComparison where isUnison:
            return (timestamp: completed.timestamp, value: completed.comparison.targetNote.offset.magnitude)
        case .intervalComparison where !isUnison:
            return (timestamp: completed.timestamp, value: completed.comparison.targetNote.offset.magnitude)
        default:
            return nil
        }
    }

    /// Returns a metric if this completed pitch matching belongs to this mode, nil otherwise.
    func metric(from result: CompletedPitchMatching) -> (timestamp: Date, value: Double)? {
        let interval = (try? Interval.between(result.referenceNote, result.targetNote))?.rawValue ?? 0
        let isUnison = interval == 0
        switch self {
        case .unisonMatching where isUnison:
            return (timestamp: result.timestamp, value: abs(result.userCentError))
        case .intervalMatching where !isUnison:
            return (timestamp: result.timestamp, value: abs(result.userCentError))
        default:
            return nil
        }
    }
}

/// Whether a training mode has enough data for visualization.
enum TrainingModeState: Equatable {
    /// No records at all — card is hidden.
    case noData
    /// Some records but below the cold-start threshold — show encouragement message.
    case coldStart(recordsNeeded: Int)
    /// Enough data to render a full chart.
    case active
}

/// Adaptive time granularity for grouping metric points into chart buckets.
enum BucketSize {
    case session
    case day
    case week
    case month
}

/// A single aggregated data point on the progress chart.
///
/// Each bucket represents a time period (session, day, week, or month)
/// with the mean and standard deviation of all metric values in that period.
struct TimeBucket {
    let periodStart: Date
    var periodEnd: Date
    let bucketSize: BucketSize
    var mean: Double
    var stddev: Double
    var recordCount: Int
}

// MARK: - ProgressTimeline

/// Tracks per-mode training progress using EWMA smoothing and adaptive time bucketing.
///
/// `ProgressTimeline` is the central analytics engine for the Profile screen.
/// It receives training records (via `rebuild` or incrementally via observer conformances),
/// groups them into adaptive time buckets, computes an exponentially weighted moving average
/// (EWMA) for each mode, and determines trend direction.
///
/// Each training mode is tracked independently with its own
/// `TrainingModeConfig` controlling smoothing, thresholds, and bucketing.
@Observable
final class ProgressTimeline {

    private var modeData: [TrainingMode: ModeState] = [:]

    init(
        comparisonRecords: [ComparisonRecord] = [],
        pitchMatchingRecords: [PitchMatchingRecord] = []
    ) {
        for mode in TrainingMode.allCases {
            modeData[mode] = ModeState()
        }
        rebuild(comparisonRecords: comparisonRecords, pitchMatchingRecords: pitchMatchingRecords)
    }

    // MARK: - Public API

    /// Returns the display state for a training mode (no data, cold start, or active).
    func state(for mode: TrainingMode) -> TrainingModeState {
        guard let data = modeData[mode] else { return .noData }
        let count = data.recordCount
        let threshold = mode.config.coldStartThreshold
        if count == 0 { return .noData }
        if count < threshold { return .coldStart(recordsNeeded: threshold - count) }
        return .active
    }

    /// Returns the adaptive time buckets for charting a mode's progress.
    func buckets(for mode: TrainingMode) -> [TimeBucket] {
        modeData[mode]?.buckets ?? []
    }

    /// Returns the current EWMA value for a mode, or nil if no data.
    func currentEWMA(for mode: TrainingMode) -> Double? {
        modeData[mode]?.ewma
    }

    /// Returns the trend direction for a mode, or nil if below the trend threshold.
    func trend(for mode: TrainingMode) -> Trend? {
        guard let data = modeData[mode] else { return nil }
        let count = data.recordCount
        guard count >= mode.config.trendThreshold else { return nil }
        return data.computedTrend
    }

    // MARK: - Rebuild

    /// Replaces all data and recomputes statistics from the given records.
    func rebuild(comparisonRecords: [ComparisonRecord], pitchMatchingRecords: [PitchMatchingRecord]) {
        let now = Date()
        for mode in TrainingMode.allCases {
            let metrics = mode.extractMetrics(
                comparisonRecords: comparisonRecords,
                pitchMatchingRecords: pitchMatchingRecords
            ).map { MetricPoint(timestamp: $0.timestamp, value: $0.value) }
            modeData[mode] = buildModeState(from: metrics, config: mode.config, now: now)
        }
    }

    // MARK: - Incremental Updates

    private func addMetric(_ point: MetricPoint, to mode: TrainingMode) {
        guard var data = modeData[mode] else { return }
        data.addPoint(point, config: mode.config)
        modeData[mode] = data
    }

    // MARK: - Internal State

    private struct MetricPoint {
        let timestamp: Date
        let value: Double
    }

    private struct ModeState {
        var buckets: [TimeBucket] = []
        var ewma: Double?
        var recordCount: Int = 0
        var computedTrend: Trend?
        var allValues: [Double] = []

        mutating func addPoint(_ point: MetricPoint, config: TrainingModeConfig) {
            recordCount += 1
            allValues.append(point.value)

            let sessionGapSeconds = config.sessionGap.timeIntervalSeconds

            if let lastIndex = buckets.indices.last,
               buckets[lastIndex].bucketSize == .session,
               point.timestamp.timeIntervalSince(buckets[lastIndex].periodEnd) < sessionGapSeconds {
                updateBucket(at: lastIndex, with: point.value)
                buckets[lastIndex].periodEnd = point.timestamp
            } else {
                let bucket = TimeBucket(
                    periodStart: point.timestamp,
                    periodEnd: point.timestamp,
                    bucketSize: .session,
                    mean: point.value,
                    stddev: 0,
                    recordCount: 1
                )
                buckets.append(bucket)
            }

            recomputeEWMA(config: config)
            recomputeTrend(config: config)
        }

        private mutating func updateBucket(at index: Int, with value: Double) {
            var bucket = buckets[index]
            let oldCount = Double(bucket.recordCount)
            let newCount = oldCount + 1
            let oldMean = bucket.mean
            let newMean = oldMean + (value - oldMean) / newCount
            // Welford's online algorithm for variance
            let oldM2 = bucket.stddev * bucket.stddev * oldCount
            let newM2 = oldM2 + (value - oldMean) * (value - newMean)
            bucket.mean = newMean
            bucket.stddev = newCount > 1 ? sqrt(newM2 / newCount) : 0
            bucket.recordCount = Int(newCount)
            buckets[index] = bucket
        }

        mutating func recomputeEWMA(config: TrainingModeConfig) {
            guard !buckets.isEmpty else {
                ewma = nil
                return
            }
            let halflifeSeconds = config.ewmaHalflife.timeIntervalSeconds
            var currentEWMA = buckets[0].mean
            for i in 1..<buckets.count {
                let dt = buckets[i].periodStart.timeIntervalSince(buckets[i - 1].periodStart)
                let alpha = 1.0 - exp(-log(2.0) * dt / halflifeSeconds)
                currentEWMA = alpha * buckets[i].mean + (1.0 - alpha) * currentEWMA
            }
            ewma = currentEWMA
        }

        mutating func recomputeTrend(config: TrainingModeConfig) {
            guard recordCount >= config.trendThreshold else {
                computedTrend = nil
                return
            }

            let midpoint = allValues.count / 2
            let earlierHalf = allValues[..<midpoint]
            let laterHalf = allValues[midpoint...]

            let earlierMean = earlierHalf.reduce(0.0, +) / Double(earlierHalf.count)
            let laterMean = laterHalf.reduce(0.0, +) / Double(laterHalf.count)

            guard earlierMean > 0 else {
                computedTrend = .stable
                return
            }

            let changeRatio = (laterMean - earlierMean) / earlierMean
            if changeRatio < -config.trendChangeThreshold {
                computedTrend = .improving
            } else if changeRatio > config.trendChangeThreshold {
                computedTrend = .declining
            } else {
                computedTrend = .stable
            }
        }
    }

    private func buildModeState(from metrics: [MetricPoint], config: TrainingModeConfig, now: Date) -> ModeState {
        var state = ModeState()
        guard !metrics.isEmpty else { return state }

        let sorted = metrics.sorted { $0.timestamp < $1.timestamp }
        state.recordCount = sorted.count
        state.allValues = sorted.map(\.value)
        state.buckets = assignBuckets(sorted, now: now, sessionGap: config.sessionGap.timeIntervalSeconds)
        state.recomputeEWMA(config: config)
        state.recomputeTrend(config: config)

        return state
    }

    // MARK: - Bucket Assignment

    private func assignBuckets(_ metrics: [MetricPoint], now: Date, sessionGap: TimeInterval) -> [TimeBucket] {
        let calendar = Calendar.current
        var groups: [(key: Date, end: Date, size: BucketSize, points: [Double])] = []

        for metric in metrics {
            let age = now.timeIntervalSince(metric.timestamp)
            let bucketInfo: (key: Date, end: Date, size: BucketSize)

            if age < 24 * 3600 {
                if let lastGroup = groups.last,
                   lastGroup.size == .session,
                   metric.timestamp.timeIntervalSince(lastGroup.key) < sessionGap {
                    groups[groups.count - 1].points.append(metric.value)
                    groups[groups.count - 1].end = metric.timestamp
                    continue
                }
                bucketInfo = (key: metric.timestamp, end: metric.timestamp, size: .session)
            } else if age < 7 * 86400 {
                let dayStart = calendar.startOfDay(for: metric.timestamp)
                let dayEnd = dayStart.addingTimeInterval(86400)
                bucketInfo = (key: dayStart, end: dayEnd, size: .day)
            } else if age < 30 * 86400 {
                if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: metric.timestamp) {
                    bucketInfo = (key: weekInterval.start, end: weekInterval.end, size: .week)
                } else {
                    continue
                }
            } else {
                if let monthInterval = calendar.dateInterval(of: .month, for: metric.timestamp) {
                    bucketInfo = (key: monthInterval.start, end: monthInterval.end, size: .month)
                } else {
                    continue
                }
            }

            if let idx = groups.firstIndex(where: { $0.key == bucketInfo.key && $0.size == bucketInfo.size }) {
                groups[idx].points.append(metric.value)
            } else {
                groups.append((key: bucketInfo.key, end: bucketInfo.end, size: bucketInfo.size, points: [metric.value]))
            }
        }

        return groups.sorted { $0.key < $1.key }.map { group in
            let mean = group.points.reduce(0.0, +) / Double(group.points.count)
            let stddev: Double
            if group.points.count > 1 {
                let variance = group.points.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(group.points.count)
                stddev = sqrt(variance)
            } else {
                stddev = 0
            }
            return TimeBucket(
                periodStart: group.key,
                periodEnd: group.end,
                bucketSize: group.size,
                mean: mean,
                stddev: stddev,
                recordCount: group.points.count
            )
        }
    }
}

// MARK: - Duration Conversion

private extension Duration {
    var timeIntervalSeconds: TimeInterval {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
    }
}

// MARK: - ComparisonObserver Conformance

extension ProgressTimeline: ComparisonObserver {
    func comparisonCompleted(_ completed: CompletedComparison) {
        for mode in TrainingMode.allCases {
            if let metric = mode.metric(from: completed) {
                addMetric(MetricPoint(timestamp: metric.timestamp, value: metric.value), to: mode)
            }
        }
    }
}

// MARK: - PitchMatchingObserver Conformance

extension ProgressTimeline: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        for mode in TrainingMode.allCases {
            if let metric = mode.metric(from: result) {
                addMetric(MetricPoint(timestamp: metric.timestamp, value: metric.value), to: mode)
            }
        }
    }
}

// MARK: - Resettable Conformance

extension ProgressTimeline: Resettable {
    func reset() {
        for mode in TrainingMode.allCases {
            modeData[mode] = ModeState()
        }
    }
}
