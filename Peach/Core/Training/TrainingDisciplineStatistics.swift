import Foundation

/// Per-mode statistical state: Welford accumulator, EWMA, trend, and time-ordered metrics.
struct TrainingDisciplineStatistics: Sendable {
    private(set) var welford = WelfordAccumulator()
    private(set) var ewma: Double?
    private(set) var trend: Trend?
    private(set) var metrics: [MetricPoint] = []

    var recordCount: Int { welford.count }

    /// Appends a new data point, updating Welford, EWMA, and trend.
    mutating func addPoint(_ point: MetricPoint, config: StatisticsConfig) {
        welford.update(point.value)
        metrics.append(point)
        recomputeEWMA(config: config)
        recomputeTrend()
    }

    /// Rebuilds statistics from a sorted array of metric points.
    mutating func rebuild(from sortedMetrics: [MetricPoint], config: StatisticsConfig) {
        welford = WelfordAccumulator()
        metrics = sortedMetrics
        for metric in sortedMetrics {
            welford.update(metric.value)
        }
        recomputeEWMA(config: config)
        recomputeTrend()
    }

    // MARK: - EWMA

    /// Recomputes EWMA over session buckets derived from the metrics.
    ///
    /// The EWMA is computed over session-level groupings (not raw metrics)
    /// to match ProgressTimeline's existing behavior where each session bucket
    /// contributes one data point to the smoothing.
    private mutating func recomputeEWMA(config: StatisticsConfig) {
        guard !metrics.isEmpty else {
            ewma = nil
            return
        }

        let sessionGapSeconds = config.sessionGap / .seconds(1)
        let halflifeSeconds = config.ewmaHalflife / .seconds(1)

        // Group metrics into session buckets by sessionGap
        var sessionMeans: [(timestamp: Date, mean: Double)] = []
        var currentSum = 0.0
        var currentCount = 0
        var sessionStart = metrics[0].timestamp

        for (index, metric) in metrics.enumerated() {
            let isNewSession = index > 0 &&
                metric.timestamp.timeIntervalSince(metrics[index - 1].timestamp) >= sessionGapSeconds
            if isNewSession {
                sessionMeans.append((timestamp: sessionStart, mean: currentSum / Double(currentCount)))
                currentSum = 0.0
                currentCount = 0
                sessionStart = metric.timestamp
            }
            currentSum += metric.value
            currentCount += 1
        }
        // Final session
        sessionMeans.append((timestamp: sessionStart, mean: currentSum / Double(currentCount)))

        // Compute EWMA over session means
        var currentEWMA = sessionMeans[0].mean
        for i in 1..<sessionMeans.count {
            let dt = sessionMeans[i].timestamp.timeIntervalSince(sessionMeans[i - 1].timestamp)
            let alpha = 1.0 - exp(-log(2.0) * dt / halflifeSeconds)
            currentEWMA = alpha * sessionMeans[i].mean + (1.0 - alpha) * currentEWMA
        }
        ewma = currentEWMA
    }

    // MARK: - Trend

    private mutating func recomputeTrend() {
        guard recordCount >= 2,
              let stddev = welford.populationStdDev,
              let ewma = ewma,
              let latest = metrics.last else {
            trend = nil
            return
        }

        let value = latest.value
        if value > welford.mean + stddev {
            trend = .declining
        } else if value >= ewma {
            trend = .stable
        } else {
            trend = .improving
        }
    }
}
