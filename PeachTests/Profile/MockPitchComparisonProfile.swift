import Foundation
@testable import Peach

final class MockTrainingProfile: TrainingProfile {
    // MARK: - Test State

    private var stubbedStatistics: [StatisticsKey: TrainingModeStatistics] = [:]

    // MARK: - TrainingProfile Protocol

    func statistics(for key: StatisticsKey) -> TrainingModeStatistics? {
        stubbedStatistics[key]
    }

    // MARK: - Test Helpers

    func stub(_ key: StatisticsKey, mean: Double, count: Int = 1) {
        var stats = TrainingModeStatistics()
        for i in 0..<count {
            stats.addPoint(
                MetricPoint(timestamp: Date().addingTimeInterval(Double(i)), value: mean),
                config: key.statisticsConfig
            )
        }
        stubbedStatistics[key] = stats
    }
}
