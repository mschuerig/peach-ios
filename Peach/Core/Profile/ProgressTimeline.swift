import Foundation

// MARK: - Supporting Types

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
}

enum TrainingModeState: Equatable {
    case noData
    case coldStart(recordsNeeded: Int)
    case active
}

enum BucketSize {
    case session
    case day
    case week
    case month
}

struct TimeBucket {
    let periodStart: Date
    var periodEnd: Date
    let bucketSize: BucketSize
    var mean: Double
    var stddev: Double
    var recordCount: Int
}

// MARK: - ProgressTimeline

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

    func state(for mode: TrainingMode) -> TrainingModeState {
        guard let data = modeData[mode] else { return .noData }
        let count = data.recordCount
        let threshold = mode.config.coldStartThreshold
        if count == 0 { return .noData }
        if count < threshold { return .coldStart(recordsNeeded: threshold - count) }
        return .active
    }

    func buckets(for mode: TrainingMode) -> [TimeBucket] {
        modeData[mode]?.buckets ?? []
    }

    func currentEWMA(for mode: TrainingMode) -> Double? {
        modeData[mode]?.ewma
    }

    func trend(for mode: TrainingMode) -> Trend? {
        guard let data = modeData[mode] else { return nil }
        let count = data.recordCount
        guard count >= mode.config.trendThreshold else { return nil }
        return data.computedTrend
    }

    // MARK: - Rebuild

    private func rebuild(comparisonRecords: [ComparisonRecord], pitchMatchingRecords: [PitchMatchingRecord]) {
        let now = Date()

        // Comparison records: correct only, metric = abs(centOffset)
        let correctComparisons = comparisonRecords.filter(\.isCorrect)
        let unisonDiscMetrics = correctComparisons.filter { $0.interval == 0 }
            .map { MetricPoint(timestamp: $0.timestamp, value: abs($0.centOffset)) }
        let intervalDiscMetrics = correctComparisons.filter { $0.interval != 0 }
            .map { MetricPoint(timestamp: $0.timestamp, value: abs($0.centOffset)) }

        // Matching records: all records, metric = abs(userCentError)
        let unisonMatchMetrics = pitchMatchingRecords.filter { $0.interval == 0 }
            .map { MetricPoint(timestamp: $0.timestamp, value: abs($0.userCentError)) }
        let intervalMatchMetrics = pitchMatchingRecords.filter { $0.interval != 0 }
            .map { MetricPoint(timestamp: $0.timestamp, value: abs($0.userCentError)) }

        modeData[.unisonComparison] = buildModeState(from: unisonDiscMetrics, config: .unisonComparison, now: now)
        modeData[.intervalComparison] = buildModeState(from: intervalDiscMetrics, config: .intervalComparison, now: now)
        modeData[.unisonMatching] = buildModeState(from: unisonMatchMetrics, config: .unisonMatching, now: now)
        modeData[.intervalMatching] = buildModeState(from: intervalMatchMetrics, config: .intervalMatching, now: now)
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

            // Merge into current session bucket if within session gap, otherwise create new bucket
            if let lastIndex = buckets.indices.last,
               buckets[lastIndex].bucketSize == .session,
               point.timestamp.timeIntervalSince(buckets[lastIndex].periodEnd) < config.sessionGapSeconds {
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
            // Welford's update for stddev
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
            var currentEWMA = buckets[0].mean
            for i in 1..<buckets.count {
                let dt = buckets[i].periodStart.timeIntervalSince(buckets[i - 1].periodStart) / 86400.0
                let alpha = 1.0 - exp(-log(2.0) * dt / config.ewmaHalflifeDays)
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
        state.buckets = assignBuckets(sorted, now: now, sessionGap: config.sessionGapSeconds)
        state.recomputeEWMA(config: config)
        state.recomputeTrend(config: config)

        return state
    }

    // MARK: - Bucket Assignment

    private func assignBuckets(_ metrics: [MetricPoint], now: Date, sessionGap: TimeInterval = 1800) -> [TimeBucket] {
        let calendar = Calendar.current
        var groups: [(key: Date, end: Date, size: BucketSize, points: [Double])] = []

        for metric in metrics {
            let age = now.timeIntervalSince(metric.timestamp)
            let bucketInfo: (key: Date, end: Date, size: BucketSize)

            if age < 24 * 3600 {
                // Per-session: group by proximity
                if let lastGroup = groups.last,
                   lastGroup.size == .session,
                   metric.timestamp.timeIntervalSince(lastGroup.key) < sessionGap {
                    // Add to existing session group
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

            // Find existing group with matching key and size
            if let idx = groups.firstIndex(where: { $0.key == bucketInfo.key && $0.size == bucketInfo.size }) {
                groups[idx].points.append(metric.value)
            } else {
                groups.append((key: bucketInfo.key, end: bucketInfo.end, size: bucketInfo.size, points: [metric.value]))
            }
        }

        // Convert groups to TimeBucket with mean and stddev
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

// MARK: - ComparisonObserver Conformance

extension ProgressTimeline: ComparisonObserver {
    func comparisonCompleted(_ completed: CompletedComparison) {
        // Only correct answers count for comparison metric
        guard completed.isCorrect else { return }

        let centValue = completed.comparison.targetNote.offset.magnitude
        let interval = (try? Interval.between(completed.comparison.referenceNote, completed.comparison.targetNote.note))?.rawValue ?? 0
        let mode: TrainingMode = interval == 0 ? .unisonComparison : .intervalComparison
        let point = MetricPoint(timestamp: completed.timestamp, value: centValue)
        addMetric(point, to: mode)
    }
}

// MARK: - PitchMatchingObserver Conformance

extension ProgressTimeline: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        let centValue = abs(result.userCentError)
        let interval = (try? Interval.between(result.referenceNote, result.targetNote))?.rawValue ?? 0
        let mode: TrainingMode = interval == 0 ? .unisonMatching : .intervalMatching
        let point = MetricPoint(timestamp: result.timestamp, value: centValue)
        addMetric(point, to: mode)
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
