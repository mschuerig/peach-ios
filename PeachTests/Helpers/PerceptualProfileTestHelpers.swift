import Foundation
@testable import Peach

// MARK: - Test-Only Convenience Extensions

/// Thin wrappers around the domain-agnostic StatisticalSummary API.
/// These keep test assertions readable — tests verify observer behavior,
/// not the profile query surface.
extension StatisticalSummary {

    /// Welford mean — test-only shortcut to avoid pattern matching in assertions.
    var welfordMean: Double? {
        switch self {
        case .continuous(let stats):
            stats.recordCount > 0 ? stats.welford.mean : nil
        }
    }
}

extension PerceptualProfile {

    func comparisonMean(for interval: DirectedInterval) -> Cents? {
        let mode: TrainingDiscipline = interval == .prime ? .unisonPitchDiscrimination : .intervalPitchDiscrimination
        guard case .continuous(let stats) = statistics(for: .pitch(mode)) else { return nil }
        return Cents(stats.welford.mean)
    }

    var matchingMean: Cents? {
        let unisonCount = statistics(for: .pitch(.unisonPitchMatching))?.recordCount ?? 0
        let intervalCount = statistics(for: .pitch(.intervalPitchMatching))?.recordCount ?? 0
        let total = unisonCount + intervalCount
        guard total > 0 else { return nil }

        var sum = 0.0
        if case .continuous(let s) = statistics(for: .pitch(.unisonPitchMatching)) {
            sum += s.welford.mean * Double(unisonCount)
        }
        if case .continuous(let s) = statistics(for: .pitch(.intervalPitchMatching)) {
            sum += s.welford.mean * Double(intervalCount)
        }
        return Cents(sum / Double(total))
    }

    var matchingStdDev: Cents? {
        let unisonCount = statistics(for: .pitch(.unisonPitchMatching))?.recordCount ?? 0
        let intervalCount = statistics(for: .pitch(.intervalPitchMatching))?.recordCount ?? 0
        let total = unisonCount + intervalCount
        guard total >= 2 else { return nil }

        var combinedM2 = 0.0
        var combinedMean = 0.0
        var combinedCount = 0

        for mode in [TrainingDiscipline.unisonPitchMatching, .intervalPitchMatching] {
            guard case .continuous(let stats) = statistics(for: .pitch(mode)),
                  stats.recordCount > 0 else { continue }
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
        (statistics(for: .pitch(.unisonPitchMatching))?.recordCount ?? 0)
            + (statistics(for: .pitch(.intervalPitchMatching))?.recordCount ?? 0)
    }

    func hasData(for mode: TrainingDiscipline) -> Bool {
        statistics(for: .pitch(mode)) != nil
    }

    func recordCount(for mode: TrainingDiscipline) -> Int {
        statistics(for: .pitch(mode))?.recordCount ?? 0
    }

    func trend(for mode: TrainingDiscipline) -> Trend? {
        statistics(for: .pitch(mode))?.trend
    }

    func currentEWMA(for mode: TrainingDiscipline) -> Double? {
        statistics(for: .pitch(mode))?.ewma
    }

    var trainedTempoRanges: [TempoRange] {
        var ranges = Set<TempoRange>()
        for range in TempoRange.defaultRanges {
            for direction in RhythmDirection.allCases {
                for mode in [TrainingDiscipline.rhythmOffsetDetection, .rhythmMatching, .continuousRhythmMatching] {
                    if statistics(for: .rhythm(mode, range, direction)) != nil {
                        ranges.insert(range)
                    }
                }
            }
        }
        return Array(ranges)
    }

    var rhythmOverallAccuracy: Double? {
        var totalCount = 0
        var weightedSum = 0.0
        for range in TempoRange.defaultRanges {
            for direction in RhythmDirection.allCases {
                for mode in [TrainingDiscipline.rhythmOffsetDetection, .rhythmMatching, .continuousRhythmMatching] {
                    if case .continuous(let stats) = statistics(for: .rhythm(mode, range, direction)),
                       stats.recordCount > 0 {
                        totalCount += stats.recordCount
                        weightedSum += stats.welford.mean * Double(stats.recordCount)
                    }
                }
            }
        }
        guard totalCount > 0 else { return nil }
        return weightedSum / Double(totalCount)
    }
}
