import Foundation
import OSLog

@Observable
final class PerceptualProfile: PitchComparisonProfile, PitchMatchingProfile {

    private var modes: [TrainingMode: TrainingModeStatistics] = [:]

    private let logger = Logger(subsystem: "com.peach.app", category: "PerceptualProfile")

    // MARK: - Builder

    final class Builder {
        fileprivate var points: [TrainingMode: [MetricPoint<Cents>]] = [:]

        fileprivate init() {}

        /// Adds a metric point for the given training mode.
        ///
        /// Points where `isCorrect` is false are silently skipped — only correct
        /// answers contribute to the profile. Matching modes always pass `true`
        /// (the default); comparison modes pass the record's correctness.
        func addPoint(_ point: MetricPoint<Cents>, for mode: TrainingMode, isCorrect: Bool = true) {
            guard isCorrect else { return }
            points[mode, default: []].append(point)
        }
    }

    // MARK: - Initialization

    init() {
        for mode in TrainingMode.allCases {
            modes[mode] = TrainingModeStatistics()
        }
        logger.info("PerceptualProfile initialized (cold start)")
    }

    init(build: (Builder) throws -> Void) rethrows {
        let builder = Builder()
        try build(builder)
        finalize(from: builder)
        logger.info("PerceptualProfile initialized via builder")
    }

    // MARK: - Per-Mode Query API

    func statistics(for mode: TrainingMode) -> TrainingModeStatistics? {
        modes[mode]
    }

    func hasData(for mode: TrainingMode) -> Bool {
        (modes[mode]?.recordCount ?? 0) > 0
    }

    func trend(for mode: TrainingMode) -> Trend? {
        modes[mode]?.trend
    }

    func currentEWMA(for mode: TrainingMode) -> Double? {
        modes[mode]?.ewma
    }

    func recordCount(for mode: TrainingMode) -> Int {
        modes[mode]?.recordCount ?? 0
    }

    // MARK: - PitchComparisonProfile

    func comparisonMean(for interval: DirectedInterval) -> Cents? {
        let mode: TrainingMode = interval == .prime ? .unisonPitchComparison : .intervalPitchComparison
        guard let stats = modes[mode], stats.recordCount > 0 else { return nil }
        return Cents(stats.welford.mean)
    }

    // MARK: - PitchMatchingProfile

    var matchingMean: Cents? {
        let unisonCount = modes[.unisonMatching]?.recordCount ?? 0
        let intervalCount = modes[.intervalMatching]?.recordCount ?? 0
        let total = unisonCount + intervalCount
        guard total > 0 else { return nil }
        let sum = (modes[.unisonMatching]?.welford.mean ?? 0) * Double(unisonCount)
            + (modes[.intervalMatching]?.welford.mean ?? 0) * Double(intervalCount)
        return Cents(sum / Double(total))
    }

    var matchingStdDev: Cents? {
        let unisonCount = modes[.unisonMatching]?.recordCount ?? 0
        let intervalCount = modes[.intervalMatching]?.recordCount ?? 0
        let total = unisonCount + intervalCount
        guard total >= 2 else { return nil }

        var combinedM2 = 0.0
        var combinedMean = 0.0
        var combinedCount = 0

        for mode in [TrainingMode.unisonMatching, .intervalMatching] {
            guard let stats = modes[mode], stats.recordCount > 0 else { continue }
            let n = stats.recordCount
            let mean = stats.welford.mean

            if combinedCount == 0 {
                combinedCount = n
                combinedMean = mean
                if let stdDev = stats.welford.typedStdDev {
                    combinedM2 = stdDev.rawValue * stdDev.rawValue * Double(n - 1)
                }
            } else {
                let delta = mean - combinedMean
                let newTotal = combinedCount + n
                let newMean = (combinedMean * Double(combinedCount) + mean * Double(n)) / Double(newTotal)
                if let stdDev = stats.welford.typedStdDev {
                    let m2B = stdDev.rawValue * stdDev.rawValue * Double(n - 1)
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
        (modes[.unisonMatching]?.recordCount ?? 0) +
        (modes[.intervalMatching]?.recordCount ?? 0)
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
        for mode in TrainingMode.allCases {
            modes[mode] = TrainingModeStatistics()
        }
        logger.info("PerceptualProfile fully reset to cold start")
    }

    // MARK: - Private

    private func finalize(from builder: Builder) {
        for mode in TrainingMode.allCases {
            var stats = TrainingModeStatistics()
            if let points = builder.points[mode], !points.isEmpty {
                let sorted = points.sorted { $0.timestamp < $1.timestamp }
                stats.rebuild(from: sorted, config: mode.config)
            }
            modes[mode] = stats
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

        let point = MetricPoint(
            timestamp: completed.timestamp,
            value: Cents(pc.targetNote.offset.magnitude)
        )
        modes[mode]?.addPoint(point, config: mode.config)
    }
}

// MARK: - PitchMatchingObserver

extension PerceptualProfile: PitchMatchingObserver {
    func pitchMatchingCompleted(_ result: CompletedPitchMatching) {
        let interval = (try? Interval.between(result.referenceNote, result.targetNote))?.rawValue ?? 0
        let isUnison = interval == 0
        let mode: TrainingMode = isUnison ? .unisonMatching : .intervalMatching

        let point = MetricPoint(
            timestamp: result.timestamp,
            value: Cents(result.userCentError.magnitude)
        )
        modes[mode]?.addPoint(point, config: mode.config)
    }
}
