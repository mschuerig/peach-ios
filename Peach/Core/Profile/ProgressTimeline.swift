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

/// Whether a training discipline has data for visualization.
enum TrainingDisciplineState: Equatable {
    /// No records at all — card is hidden.
    case noData
    /// Has data — show chart/sparkline.
    case active
}

/// Adaptive time granularity for grouping metric points into chart buckets.
enum BucketSize {
    case session
    case day
    case month
}

/// A single aggregated data point on the progress chart.
///
/// Each bucket represents a time period (session, day, or month)
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

/// Pure presentation layer for per-mode training progress charts.
///
/// `ProgressTimeline` reads metrics and statistics from `PerceptualProfile`
/// and formats them into adaptive time buckets for the Profile screen.
/// It contains no statistical computation of its own — all EWMA, trend,
/// and record count queries delegate to the profile.
@Observable
final class ProgressTimeline {

    private static let secondsPerDay: Duration = .seconds(86400)

    /// Number of calendar days in the day zone (before today).
    private static let dayZoneDays = 7

    private let profile: PerceptualProfile

    init(profile: PerceptualProfile = PerceptualProfile()) {
        self.profile = profile
    }

    // MARK: - Delegated to Profile

    /// Returns the display state for a training discipline (no data or active).
    func state(for mode: TrainingDisciplineID) -> TrainingDisciplineState {
        profile.mergedStatistics(for: mode.statisticsKeys) != nil ? .active : .noData
    }

    /// Returns the current EWMA value for a mode, or nil if no data.
    func currentEWMA(for mode: TrainingDisciplineID) -> Double? {
        profile.mergedStatistics(for: mode.statisticsKeys)?.ewma
    }

    /// Returns the total number of records ingested for a mode.
    func recordCount(for mode: TrainingDisciplineID) -> Int {
        profile.mergedStatistics(for: mode.statisticsKeys)?.recordCount ?? 0
    }

    /// Returns the trend direction for a mode, or nil if insufficient data.
    func trend(for mode: TrainingDisciplineID) -> Trend? {
        profile.mergedStatistics(for: mode.statisticsKeys)?.trend
    }

    // MARK: - Bucketing (presentation-only)

    /// Returns the adaptive time buckets for charting a mode's progress.
    func buckets(for mode: TrainingDisciplineID) -> [TimeBucket] {
        allGranularityBuckets(for: mode)
    }

    /// Returns concatenated multi-granularity buckets ordered chronologically.
    ///
    /// Zone boundaries snap to calendar days:
    /// - **Session zone**: `timestamp >= startOfDay(now)` — today's sessions from midnight
    /// - **Day zone**: previous 7 calendar days before today
    /// - **Month zone**: everything older, with the last monthly bucket truncated at the day zone start
    ///
    /// Only three granularity tiers are used: month, day, and session.
    func allGranularityBuckets(for mode: TrainingDisciplineID) -> [TimeBucket] {
        guard let summary = profile.mergedStatistics(for: mode.statisticsKeys),
              !summary.metrics.isEmpty else { return [] }
        let now = Date()
        let calendar = Calendar.current
        return assignMultiGranularityBuckets(summary.metrics, now: now, calendar: calendar, sessionGap: mode.config.sessionGap)
    }

    /// Returns sub-buckets at finer granularity for a given parent bucket.
    ///
    /// Splits a month bucket into days, or a day into sessions.
    /// Returns an empty array for session buckets (finest granularity).
    func subBuckets(for mode: TrainingDisciplineID, expanding bucket: TimeBucket) -> [TimeBucket] {
        guard bucket.bucketSize != .session else { return [] }
        guard let summary = profile.mergedStatistics(for: mode.statisticsKeys) else { return [] }

        let metrics = summary.metrics.filter {
            $0.timestamp >= bucket.periodStart && $0.timestamp < bucket.periodEnd
        }
        guard !metrics.isEmpty else { return [] }

        return assignSubBuckets(metrics, parentSize: bucket.bucketSize, sessionGap: mode.config.sessionGap)
    }

    // MARK: - Multi-Granularity Bucket Assignment

    private func assignMultiGranularityBuckets(
        _ metrics: [MetricPoint],
        now: Date,
        calendar: Calendar,
        sessionGap: Duration
    ) -> [TimeBucket] {
        // Calendar-snapped zone boundaries
        let sessionStart = calendar.startOfDay(for: now)
        guard let dayStart = calendar.date(byAdding: .day, value: -Self.dayZoneDays, to: sessionStart) else {
            return []
        }

        let sessionGapSeconds = sessionGap / .seconds(1)
        var groups: [(key: Date, end: Date, size: BucketSize, points: [Double])] = []

        for metric in metrics {
            let bucketInfo: (key: Date, end: Date, size: BucketSize)

            if metric.timestamp >= sessionStart {
                // Session zone: merge records within sessionGap
                if let lastGroup = groups.last,
                   lastGroup.size == .session,
                   metric.timestamp.timeIntervalSince(lastGroup.end) < sessionGapSeconds {
                    groups[groups.count - 1].points.append(metric.value)
                    groups[groups.count - 1].end = metric.timestamp
                    continue
                }
                bucketInfo = (key: metric.timestamp, end: metric.timestamp, size: .session)
            } else if metric.timestamp >= dayStart {
                // Day zone: 7 calendar days before today
                let bucketDay = calendar.startOfDay(for: metric.timestamp)
                let dayEnd = bucketDay.addingTimeInterval(Self.secondsPerDay / .seconds(1))
                bucketInfo = (key: bucketDay, end: dayEnd, size: .day)
            } else {
                // Month zone: truncate last monthly bucket at dayStart
                if let monthInterval = calendar.dateInterval(of: .month, for: metric.timestamp) {
                    let truncatedEnd = min(monthInterval.end, dayStart)
                    bucketInfo = (key: monthInterval.start, end: truncatedEnd, size: .month)
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
            Self.makeBucket(periodStart: group.key, periodEnd: group.end, bucketSize: group.size, points: group.points)
        }
    }

    // MARK: - Bucket Aggregation

    private static func makeBucket(periodStart: Date, periodEnd: Date, bucketSize: BucketSize, points: [Double]) -> TimeBucket {
        let mean = points.reduce(0.0, +) / Double(points.count)
        let stddev: Double
        if points.count > 1 {
            let variance = points.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(points.count)
            stddev = sqrt(variance)
        } else {
            stddev = 0
        }
        return TimeBucket(
            periodStart: periodStart,
            periodEnd: periodEnd,
            bucketSize: bucketSize,
            mean: mean,
            stddev: stddev,
            recordCount: points.count
        )
    }

    // MARK: - Sub-Bucket Assignment

    private func assignSubBuckets(_ metrics: [MetricPoint], parentSize: BucketSize, sessionGap: Duration) -> [TimeBucket] {
        let calendar = Calendar.current
        let sessionGapSeconds = sessionGap / .seconds(1)
        let childSize: BucketSize
        switch parentSize {
        case .month: childSize = .day
        case .day: childSize = .session
        case .session: return []
        }

        var groups: [(key: Date, end: Date, points: [Double])] = []

        for metric in metrics {
            let groupInfo: (key: Date, end: Date)

            switch childSize {
            case .day:
                let dayStart = calendar.startOfDay(for: metric.timestamp)
                groupInfo = (key: dayStart, end: dayStart.addingTimeInterval(Self.secondsPerDay / .seconds(1)))
            case .session:
                if let lastGroup = groups.last,
                   metric.timestamp.timeIntervalSince(lastGroup.key) < sessionGapSeconds {
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
            Self.makeBucket(periodStart: group.key, periodEnd: group.end, bucketSize: childSize, points: group.points)
        }
    }
}
