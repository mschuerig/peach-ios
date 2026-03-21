import Foundation
import OSLog

@Observable
final class PerceptualProfile: TrainingProfile {

    private var statisticsStore: [StatisticsKey: TrainingModeStatistics] = [:]

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

    private func update(_ key: StatisticsKey, timestamp: Date, value: Double) {
        let point = MetricPoint(timestamp: timestamp, value: value)
        statisticsStore[key, default: TrainingModeStatistics()]
            .addPoint(point, config: key.statisticsConfig)
    }

    private func finalize(from builder: Builder) {
        statisticsStore.removeAll()
        for (key, points) in builder.points where !points.isEmpty {
            var stats = TrainingModeStatistics()
            stats.rebuild(from: points.sorted { $0.timestamp < $1.timestamp }, config: key.statisticsConfig)
            statisticsStore[key] = stats
        }
    }
}

// MARK: - PitchComparisonObserver

extension PerceptualProfile: PitchComparisonObserver {
    func pitchComparisonCompleted(_ completed: CompletedPitchComparison) {
        let pc = completed.pitchComparison
        let interval = (try? Interval.between(pc.referenceNote, pc.targetNote.note))?.rawValue ?? 0
        let isUnison = interval == 0
        let mode: TrainingMode = isUnison ? .unisonPitchComparison : .intervalPitchComparison

        guard completed.isCorrect else { return }

        update(.pitch(mode), timestamp: completed.timestamp, value: pc.targetNote.offset.magnitude)
    }
}

// MARK: - PitchMatchingObserver

extension PerceptualProfile: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        let interval = (try? Interval.between(result.referenceNote, result.targetNote))?.rawValue ?? 0
        let isUnison = interval == 0
        let mode: TrainingMode = isUnison ? .unisonMatching : .intervalMatching

        update(.pitch(mode), timestamp: result.timestamp, value: result.userCentError.magnitude)
    }
}

// MARK: - RhythmComparisonObserver

extension PerceptualProfile: RhythmComparisonObserver {
    func rhythmComparisonCompleted(_ result: CompletedRhythmComparison) {
        guard result.isCorrect else { return }
        guard let range = TempoRange.range(for: result.tempo) else { return }
        update(.rhythm(.rhythmComparison, range, result.offset.direction),
               timestamp: result.timestamp,
               value: abs(result.offset.statisticalValue))
    }
}

// MARK: - RhythmMatchingObserver

extension PerceptualProfile: RhythmMatchingObserver {
    func rhythmMatchingCompleted(_ result: CompletedRhythmMatching) {
        guard let range = TempoRange.range(for: result.tempo) else { return }
        update(.rhythm(.rhythmMatching, range, result.userOffset.direction),
               timestamp: result.timestamp,
               value: abs(result.userOffset.statisticalValue))
    }
}
