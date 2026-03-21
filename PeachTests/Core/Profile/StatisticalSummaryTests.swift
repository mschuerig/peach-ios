import Testing
import Foundation
@testable import Peach

@Suite("StatisticalSummary Tests")
struct StatisticalSummaryTests {

    @Test("recordCount delegates to TrainingModeStatistics")
    func recordCountDelegates() async {
        var stats = TrainingModeStatistics()
        stats.addPoint(MetricPoint(timestamp: Date(), value: 10.0), config: .default)
        stats.addPoint(MetricPoint(timestamp: Date(), value: 20.0), config: .default)

        let summary = StatisticalSummary.continuous(stats)
        #expect(summary.recordCount == 2)
    }

    @Test("trend delegates to TrainingModeStatistics")
    func trendDelegates() async {
        var stats = TrainingModeStatistics()
        let now = Date()
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(-2), value: 50.0), config: .default)
        stats.addPoint(MetricPoint(timestamp: now.addingTimeInterval(-1), value: 10.0), config: .default)

        let summary = StatisticalSummary.continuous(stats)
        #expect(summary.trend != nil)
    }

    @Test("ewma delegates to TrainingModeStatistics")
    func ewmaDelegates() async {
        var stats = TrainingModeStatistics()
        stats.addPoint(MetricPoint(timestamp: Date(), value: 15.0), config: .default)

        let summary = StatisticalSummary.continuous(stats)
        #expect(summary.ewma != nil)
    }

    @Test("metrics delegates to TrainingModeStatistics")
    func metricsDelegates() async {
        var stats = TrainingModeStatistics()
        let point = MetricPoint(timestamp: Date(), value: 42.0)
        stats.addPoint(point, config: .default)

        let summary = StatisticalSummary.continuous(stats)
        #expect(summary.metrics.count == 1)
        #expect(summary.metrics[0].value == 42.0)
    }

    @Test("empty statistics returns zero recordCount")
    func emptyStatistics() async {
        let summary = StatisticalSummary.continuous(TrainingModeStatistics())
        #expect(summary.recordCount == 0)
        #expect(summary.trend == nil)
        #expect(summary.ewma == nil)
        #expect(summary.metrics.isEmpty)
    }
}
