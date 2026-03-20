import Testing
import Foundation
@testable import Peach

@Suite("TrainingModeStatistics Tests")
struct TrainingModeStatisticsTests {

    private let config = TrainingModeConfig.unisonPitchComparison.statistics

    // MARK: - Welford Correctness

    @Test("empty statistics has zero record count")
    func emptyStatistics() async {
        let stats = TrainingModeStatistics()
        #expect(stats.recordCount == 0)
        #expect(stats.ewma == nil)
        #expect(stats.trend == nil)
    }

    @Test("single point sets Welford mean")
    func singlePoint() async {
        var stats = TrainingModeStatistics()
        stats.addPoint(MetricPoint(timestamp: Date(), value: 10.0), config: config)

        #expect(stats.recordCount == 1)
        #expect(stats.welford.mean == 10.0)
    }

    @Test("multiple points compute correct Welford running mean")
    func welfordMean() async {
        var stats = TrainingModeStatistics()
        let now = Date()
        stats.addPoint(MetricPoint(timestamp: now, value: 10.0), config: config)
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20.0), config: config)
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(2), value: 30.0), config: config)

        #expect(abs(stats.welford.mean - 20.0) < 0.01)
        #expect(stats.recordCount == 3)
    }

    @Test("Welford population stddev matches expected value")
    func welfordStdDev() async throws {
        var stats = TrainingModeStatistics()
        let now = Date()
        stats.addPoint(MetricPoint(timestamp: now, value: 10.0), config: config)
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(1), value: 20.0), config: config)
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(2), value: 30.0), config: config)

        // Population stddev of [10, 20, 30]: sqrt(((10-20)^2 + (20-20)^2 + (30-20)^2) / 3) = sqrt(200/3) ≈ 8.165
        let stddev = try #require(stats.welford.populationStdDev)
        #expect(abs(stddev - 8.165) < 0.01)
    }

    // MARK: - EWMA Computation

    @Test("EWMA equals single point value")
    func ewmaSinglePoint() async throws {
        var stats = TrainingModeStatistics()
        stats.addPoint(MetricPoint(timestamp: Date(), value: 15.0), config: config)

        let ewma = try #require(stats.ewma)
        #expect(abs(ewma - 15.0) < 0.01)
    }

    @Test("EWMA with halflife gives 50% weight")
    func ewmaHalflife() async throws {
        var stats = TrainingModeStatistics()
        let now = Date()
        // First session
        stats.addPoint(MetricPoint(timestamp: now, value: 20.0), config: config)
        // Second session 7 days later (= halflife)
        let halflifeSeconds = config.ewmaHalflife / .seconds(1)
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(halflifeSeconds), value: 10.0), config: config)

        let ewma = try #require(stats.ewma)
        // alpha = 0.5 → EWMA = 0.5 * 10 + 0.5 * 20 = 15.0
        #expect(abs(ewma - 15.0) < 0.01)
    }

    // MARK: - Trend Detection

    @Test("no trend with single record")
    func noTrendSingleRecord() async {
        var stats = TrainingModeStatistics()
        stats.addPoint(MetricPoint(timestamp: Date(), value: 10.0), config: config)
        #expect(stats.trend == nil)
    }

    @Test("stable trend with constant values")
    func stableTrend() async {
        var stats = TrainingModeStatistics()
        let now = Date()
        for i in 0..<5 {
            stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(Double(i)), value: 10.0), config: config)
        }
        #expect(stats.trend == .stable)
    }

    @Test("improving trend when latest is below EWMA")
    func improvingTrend() async {
        var stats = TrainingModeStatistics()
        let now = Date()
        for i in 0..<10 {
            stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 3600), value: 20.0), config: config)
        }
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(11 * 3600), value: 5.0), config: config)
        #expect(stats.trend == .improving)
    }

    @Test("declining trend when latest is above mean + stddev")
    func decliningTrend() async {
        var stats = TrainingModeStatistics()
        let now = Date()
        for i in 0..<10 {
            stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 3600), value: 10.0), config: config)
        }
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(11 * 3600), value: 50.0), config: config)
        #expect(stats.trend == .declining)
    }

    // MARK: - Rebuild

    @Test("rebuild produces same statistics as incremental adds")
    func rebuildMatchesIncremental() async {
        let now = Date()
        let points = (0..<5).map { i in
            MetricPoint(timestamp: now.addingTimeInterval(Double(i) * 3600), value: Double(i * 10 + 5))
        }

        var incremental = TrainingModeStatistics()
        for point in points {
            incremental.addPoint(point, config: config)
        }

        var rebuilt = TrainingModeStatistics()
        rebuilt.rebuild(from: points, config: config)

        #expect(rebuilt.recordCount == incremental.recordCount)
        #expect(abs(rebuilt.welford.mean - incremental.welford.mean) < 0.01)
        #expect(rebuilt.trend == incremental.trend)
        if let rebuiltEWMA = rebuilt.ewma, let incrementalEWMA = incremental.ewma {
            #expect(abs(rebuiltEWMA - incrementalEWMA) < 0.01)
        }
    }

    @Test("metrics are preserved after rebuild")
    func rebuildPreservesMetrics() async {
        let now = Date()
        let points = (0..<3).map { i in
            MetricPoint(timestamp: now.addingTimeInterval(Double(i)), value: Double(i + 1))
        }

        var stats = TrainingModeStatistics()
        stats.rebuild(from: points, config: config)

        #expect(stats.metrics.count == 3)
        #expect(stats.metrics[0].value == 1.0)
        #expect(stats.metrics[2].value == 3.0)
    }
}
