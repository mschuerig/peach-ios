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

    // MARK: - Unified Query API

    func statistics(for key: StatisticsKey) -> TrainingModeStatistics? {
        let stats = statisticsStore[key]
        return (stats?.recordCount ?? 0) > 0 ? stats : nil
    }

    func hasData(for key: StatisticsKey) -> Bool {
        (statisticsStore[key]?.recordCount ?? 0) > 0
    }

    func trend(for key: StatisticsKey) -> Trend? {
        statisticsStore[key]?.trend
    }

    func currentEWMA(for key: StatisticsKey) -> Double? {
        statisticsStore[key]?.ewma
    }

    func recordCount(for key: StatisticsKey) -> Int {
        statisticsStore[key]?.recordCount ?? 0
    }

    // MARK: - Pitch Convenience (TrainingMode-based)

    func statistics(for mode: TrainingMode) -> TrainingModeStatistics? {
        statistics(for: .pitch(mode))
    }

    func hasData(for mode: TrainingMode) -> Bool {
        hasData(for: .pitch(mode))
    }

    func trend(for mode: TrainingMode) -> Trend? {
        trend(for: .pitch(mode))
    }

    func currentEWMA(for mode: TrainingMode) -> Double? {
        currentEWMA(for: .pitch(mode))
    }

    func recordCount(for mode: TrainingMode) -> Int {
        recordCount(for: .pitch(mode))
    }

    // MARK: - PitchComparisonProfile Legacy API

    func comparisonMean(for interval: DirectedInterval) -> Cents? {
        let mode: TrainingMode = interval == .prime ? .unisonPitchComparison : .intervalPitchComparison
        guard let stats = statistics(for: mode) else { return nil }
        return Cents(stats.welford.mean)
    }

    // MARK: - PitchMatchingProfile Legacy API

    var matchingMean: Cents? {
        let unisonCount = recordCount(for: .unisonMatching)
        let intervalCount = recordCount(for: .intervalMatching)
        let total = unisonCount + intervalCount
        guard total > 0 else { return nil }
        let sum = (statisticsStore[.pitch(.unisonMatching)]?.welford.mean ?? 0) * Double(unisonCount)
            + (statisticsStore[.pitch(.intervalMatching)]?.welford.mean ?? 0) * Double(intervalCount)
        return Cents(sum / Double(total))
    }

    var matchingStdDev: Cents? {
        let unisonCount = recordCount(for: .unisonMatching)
        let intervalCount = recordCount(for: .intervalMatching)
        let total = unisonCount + intervalCount
        guard total >= 2 else { return nil }

        var combinedM2 = 0.0
        var combinedMean = 0.0
        var combinedCount = 0

        for mode in [TrainingMode.unisonMatching, .intervalMatching] {
            guard let stats = statisticsStore[.pitch(mode)], stats.recordCount > 0 else { continue }
            let n = stats.recordCount
            let mean = stats.welford.mean

            if combinedCount == 0 {
                combinedCount = n
                combinedMean = mean
                if let stdDev = stats.welford.sampleStdDev {
                    combinedM2 = stdDev * stdDev * Double(n - 1)
                }
            } else {
                let delta = mean - combinedMean
                let newTotal = combinedCount + n
                let newMean = (combinedMean * Double(combinedCount) + mean * Double(n)) / Double(newTotal)
                if let stdDev = stats.welford.sampleStdDev {
                    let m2B = stdDev * stdDev * Double(n - 1)
                    combinedM2 += m2B + delta * delta * Double(combinedCount) * Double(n) / Double(newTotal)
                } else {
                    combinedM2 += delta * delta * Double(combinedCount) * Double(n) / Double(newTotal)
                }
                combinedMean = newMean
                combinedCount = newTotal
            }
        }

        guard combinedCount >= 2 else { return nil }
        return Cents(sqrt(combinedM2 / Double(combinedCount - 1)))
    }

    var matchingSampleCount: Int {
        recordCount(for: .unisonMatching) + recordCount(for: .intervalMatching)
    }

    // MARK: - Rhythm Aggregate Queries

    var trainedTempoRanges: [TempoRange] {
        var ranges = Set<TempoRange>()
        for key in statisticsStore.keys {
            if case .rhythm(_, let range, _) = key,
               (statisticsStore[key]?.recordCount ?? 0) > 0 {
                ranges.insert(range)
            }
        }
        return Array(ranges)
    }

    var rhythmOverallAccuracy: Double? {
        var totalCount = 0
        var weightedSum = 0.0
        for (key, stats) in statisticsStore {
            if case .rhythm = key, stats.recordCount > 0 {
                totalCount += stats.recordCount
                weightedSum += stats.welford.mean * Double(stats.recordCount)
            }
        }
        guard totalCount > 0 else { return nil }
        return weightedSum / Double(totalCount)
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
