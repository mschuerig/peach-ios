import Foundation
import OSLog

@Observable
final class PerceptualProfile: TrainingProfile {

    private var statisticsStore: [StatisticsKey: TrainingDisciplineStatistics] = [:]

    private let logger = Logger(subsystem: "com.peach.app", category: "PerceptualProfile")

    // MARK: - Builder

    final class Builder {
        fileprivate var points: [StatisticsKey: [MetricPoint]] = [:]

        fileprivate init() {}

        /// Adds a metric point for the given statistics key.
        ///
        /// Points where `isCorrect` is false are silently skipped — only correct
        /// answers contribute to the profile. Matching modes always pass `true`
        /// (the default); comparison modes pass the record's correctness.
        func addPoint(_ point: MetricPoint, for key: StatisticsKey, isCorrect: Bool = true) {
            guard isCorrect else { return }
            points[key, default: []].append(point)
        }
    }

    // MARK: - Initialization

    init() {
        logger.info("PerceptualProfile initialized (cold start)")
    }

    init(build: (Builder) throws -> Void) rethrows {
        let builder = Builder()
        try build(builder)
        finalize(from: builder)
        logger.info("PerceptualProfile initialized via builder")
    }

    // MARK: - TrainingProfile

    func statistics(for key: StatisticsKey) -> StatisticalSummary? {
        guard let stats = statisticsStore[key], stats.recordCount > 0 else { return nil }
        return .continuous(stats)
    }

    // MARK: - Replace

    func replaceAll(build: (Builder) throws -> Void) rethrows {
        let builder = Builder()
        try build(builder)
        finalize(from: builder)
        logger.info("PerceptualProfile replaced via builder")
    }

    // MARK: - Reset

    func resetAll() {
        statisticsStore.removeAll()
        logger.info("PerceptualProfile fully reset to cold start")
    }

    // MARK: - Private

    func update(_ key: StatisticsKey, timestamp: Date, value: Double) {
        let point = MetricPoint(timestamp: timestamp, value: value)
        statisticsStore[key, default: TrainingDisciplineStatistics()]
            .addPoint(point, config: key.statisticsConfig)
    }

    private func finalize(from builder: Builder) {
        statisticsStore.removeAll()
        for (key, points) in builder.points where !points.isEmpty {
            var stats = TrainingDisciplineStatistics()
            stats.rebuild(from: points.sorted { $0.timestamp < $1.timestamp }, config: key.statisticsConfig)
            statisticsStore[key] = stats
        }
    }
}

// MARK: - ProfileUpdating

extension PerceptualProfile: ProfileUpdating {}

