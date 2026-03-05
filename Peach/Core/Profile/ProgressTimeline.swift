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
    case unisonPitchComparison
    case intervalPitchComparison
    case unisonMatching
    case intervalMatching

    var config: TrainingModeConfig {
        switch self {
        case .unisonPitchComparison: .unisonPitchComparison
        case .intervalPitchComparison: .intervalPitchComparison
        case .unisonMatching: .unisonMatching
        case .intervalMatching: .intervalMatching
        }
    }

    /// Extracts metric points for this mode from raw training records.
    func extractMetrics(
        pitchComparisonRecords: [PitchComparisonRecord],
        pitchMatchingRecords: [PitchMatchingRecord]
    ) -> [(timestamp: Date, value: Double)] {
        switch self {
        case .unisonPitchComparison:
            pitchComparisonRecords.filter { $0.interval == 0 }
                .map { (timestamp: $0.timestamp, value: abs($0.centOffset)) }
        case .intervalPitchComparison:
            pitchComparisonRecords.filter { $0.interval != 0 }
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
    func metric(from completed: CompletedPitchComparison) -> (timestamp: Date, value: Double)? {
        let interval = (try? Interval.between(completed.pitchComparison.referenceNote, completed.pitchComparison.targetNote.note))?.rawValue ?? 0
        let isUnison = interval == 0
        switch self {
        case .unisonPitchComparison where isUnison:
            return (timestamp: completed.timestamp, value: completed.pitchComparison.targetNote.offset.magnitude)
        case .intervalPitchComparison where !isUnison:
            return (timestamp: completed.timestamp, value: completed.pitchComparison.targetNote.offset.magnitude)
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
            return (timestamp: result.timestamp, value: result.userCentError.magnitude)
        case .intervalMatching where !isUnison:
            return (timestamp: result.timestamp, value: result.userCentError.magnitude)
        default:
            return nil
        }
    }
}

/// Whether a training mode has data for visualization.
enum TrainingModeState: Equatable {
    /// No records at all — card is hidden.
    case noData
    /// Has data — show chart/sparkline.
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

    // MARK: - Bucket Age Thresholds

    /// Records younger than this are bucketed per training session.
    private static let recentThreshold: TimeInterval = 24 * 3600

    /// Records younger than this (but older than recentThreshold) are bucketed per day.
    private static let weekThreshold: TimeInterval = 7 * 86400

    /// Records younger than this (but older than weekThreshold) are bucketed per week.
    /// Older records are bucketed per month.
    private static let monthThreshold: TimeInterval = 30 * 86400

    private static let secondsPerDay: TimeInterval = 86400

    private var modeData: [TrainingMode: ModeState] = [:]

    init(
        pitchComparisonRecords: [PitchComparisonRecord] = [],
        pitchMatchingRecords: [PitchMatchingRecord] = []
    ) {
        for mode in TrainingMode.allCases {
            modeData[mode] = ModeState()
        }
        rebuild(pitchComparisonRecords: pitchComparisonRecords, pitchMatchingRecords: pitchMatchingRecords)
    }

    // MARK: - Public API

    /// Returns the display state for a training mode (no data or active).
    func state(for mode: TrainingMode) -> TrainingModeState {
        guard let data = modeData[mode], data.recordCount > 0 else { return .noData }
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

    /// Returns sub-buckets at finer granularity for a given parent bucket.
    ///
    /// Splits a month bucket into weeks, a week into days, or a day into sessions.
    /// Returns an empty array for session buckets (finest granularity).
    func subBuckets(for mode: TrainingMode, expanding bucket: TimeBucket) -> [TimeBucket] {
        guard bucket.bucketSize != .session else { return [] }
        guard let data = modeData[mode] else { return [] }

        let metrics = data.allMetrics.filter {
            $0.timestamp >= bucket.periodStart && $0.timestamp < bucket.periodEnd
        }
        guard !metrics.isEmpty else { return [] }

        let sessionGap = mode.config.sessionGap.timeIntervalSeconds
        return assignSubBuckets(metrics, parentSize: bucket.bucketSize, sessionGap: sessionGap)
    }

    /// Returns the trend direction for a mode, or nil if insufficient data.
    func trend(for mode: TrainingMode) -> Trend? {
        guard let data = modeData[mode], data.recordCount >= 2 else { return nil }
        return data.computedTrend
    }

    // MARK: - Rebuild

    /// Replaces all data and recomputes statistics from the given records.
    func rebuild(pitchComparisonRecords: [PitchComparisonRecord], pitchMatchingRecords: [PitchMatchingRecord]) {
        let now = Date()
        for mode in TrainingMode.allCases {
            let metrics = mode.extractMetrics(
                pitchComparisonRecords: pitchComparisonRecords,
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
        var allMetrics: [MetricPoint] = []
        var runningMean: Double = 0
        var runningM2: Double = 0

        var runningStddev: Double? {
            recordCount >= 2 ? sqrt(runningM2 / Double(recordCount)) : nil
        }

        mutating func addPoint(_ point: MetricPoint, config: TrainingModeConfig) {
            recordCount += 1
            allMetrics.append(point)

            let delta = point.value - runningMean
            runningMean += delta / Double(recordCount)
            let delta2 = point.value - runningMean
            runningM2 += delta * delta2

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
            recomputeTrend()
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

        mutating func recomputeTrend() {
            guard recordCount >= 2,
                  let stddev = runningStddev,
                  let ewma = ewma,
                  let latest = allMetrics.last else {
                computedTrend = nil
                return
            }

            let value = latest.value
            if value > runningMean + stddev {
                computedTrend = .declining
            } else if value >= ewma {
                computedTrend = .stable
            } else {
                computedTrend = .improving
            }
        }
    }

    private func buildModeState(from metrics: [MetricPoint], config: TrainingModeConfig, now: Date) -> ModeState {
        var state = ModeState()
        guard !metrics.isEmpty else { return state }

        let sorted = metrics.sorted { $0.timestamp < $1.timestamp }
        state.allMetrics = sorted
        for metric in sorted {
            state.recordCount += 1
            let delta = metric.value - state.runningMean
            state.runningMean += delta / Double(state.recordCount)
            let delta2 = metric.value - state.runningMean
            state.runningM2 += delta * delta2
        }
        state.buckets = assignBuckets(sorted, now: now, sessionGap: config.sessionGap.timeIntervalSeconds)
        state.recomputeEWMA(config: config)
        state.recomputeTrend()

        return state
    }

    // MARK: - Bucket Assignment

    private func assignBuckets(_ metrics: [MetricPoint], now: Date, sessionGap: TimeInterval) -> [TimeBucket] {
        let calendar = Calendar.current
        var groups: [(key: Date, end: Date, size: BucketSize, points: [Double])] = []

        for metric in metrics {
            let age = now.timeIntervalSince(metric.timestamp)
            let bucketInfo: (key: Date, end: Date, size: BucketSize)

            if age < Self.recentThreshold {
                if let lastGroup = groups.last,
                   lastGroup.size == .session,
                   metric.timestamp.timeIntervalSince(lastGroup.key) < sessionGap {
                    groups[groups.count - 1].points.append(metric.value)
                    groups[groups.count - 1].end = metric.timestamp
                    continue
                }
                bucketInfo = (key: metric.timestamp, end: metric.timestamp, size: .session)
            } else if age < Self.weekThreshold {
                let dayStart = calendar.startOfDay(for: metric.timestamp)
                let dayEnd = dayStart.addingTimeInterval(Self.secondsPerDay)
                bucketInfo = (key: dayStart, end: dayEnd, size: .day)
            } else if age < Self.monthThreshold {
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

    // MARK: - Sub-Bucket Assignment

    private func assignSubBuckets(_ metrics: [MetricPoint], parentSize: BucketSize, sessionGap: TimeInterval) -> [TimeBucket] {
        let calendar = Calendar.current
        let childSize: BucketSize
        switch parentSize {
        case .month: childSize = .week
        case .week: childSize = .day
        case .day: childSize = .session
        case .session: return []
        }

        var groups: [(key: Date, end: Date, points: [Double])] = []

        for metric in metrics {
            let groupInfo: (key: Date, end: Date)

            switch childSize {
            case .week:
                if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: metric.timestamp) {
                    groupInfo = (key: weekInterval.start, end: weekInterval.end)
                } else {
                    continue
                }
            case .day:
                let dayStart = calendar.startOfDay(for: metric.timestamp)
                groupInfo = (key: dayStart, end: dayStart.addingTimeInterval(Self.secondsPerDay))
            case .session:
                if let lastGroup = groups.last,
                   metric.timestamp.timeIntervalSince(lastGroup.key) < sessionGap {
                    groups[groups.count - 1].points.append(metric.value)
                    groups[groups.count - 1].end = metric.timestamp
                    continue
                }
                groupInfo = (key: metric.timestamp, end: metric.timestamp)
            case .month:
                return []
            }

            if let idx = groups.firstIndex(where: { $0.key == groupInfo.key }) {
                groups[idx].points.append(metric.value)
            } else {
                groups.append((key: groupInfo.key, end: groupInfo.end, points: [metric.value]))
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
                bucketSize: childSize,
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

// MARK: - PitchComparisonObserver Conformance

extension ProgressTimeline: PitchComparisonObserver {
    func pitchComparisonCompleted(_ completed: CompletedPitchComparison) {
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
