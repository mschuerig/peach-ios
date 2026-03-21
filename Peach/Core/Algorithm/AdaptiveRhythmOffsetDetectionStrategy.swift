import Foundation
import OSLog

final class AdaptiveRhythmOffsetDetectionStrategy: NextRhythmOffsetDetectionStrategy {

    // MARK: - Algorithm Parameters

    private static let narrowingCoefficient: Double = 0.05
    private static let wideningCoefficient: Double = 0.09

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.peach.app", category: "AdaptiveRhythmOffsetDetectionStrategy")

    // MARK: - NextRhythmOffsetDetectionStrategy Protocol

    func nextRhythmOffsetDetectionTrial(
        profile: TrainingProfile,
        settings: RhythmOffsetDetectionSettings,
        lastResult: CompletedRhythmOffsetDetectionTrial?
    ) -> RhythmOffsetDetectionTrial {
        let direction = chooseDirection(profile: profile, settings: settings)
        let percentage = choosePercentage(
            direction: direction,
            profile: profile,
            settings: settings,
            lastResult: lastResult
        )

        let sixteenthDuration = settings.tempo.sixteenthNoteDuration
        let offsetDuration = sixteenthDuration * (percentage / 100.0)
        let signedDuration = direction == .early ? .zero - offsetDuration : offsetDuration
        let offset = RhythmOffset(signedDuration)

        logger.info("direction=\(String(describing: direction)), percentage=\(percentage, format: .fixed(precision: 1)), tempo=\(settings.tempo.value)")

        return RhythmOffsetDetectionTrial(tempo: settings.tempo, offset: offset)
    }

    // MARK: - Direction Selection

    private func chooseDirection(profile: TrainingProfile, settings: RhythmOffsetDetectionSettings) -> RhythmDirection {
        guard let tempoRange = TempoRange.range(for: settings.tempo) else {
            return Bool.random() ? .early : .late
        }

        let earlyStats = profile.statistics(for: .rhythm(.rhythmOffsetDetection, tempoRange, .early))
        let lateStats = profile.statistics(for: .rhythm(.rhythmOffsetDetection, tempoRange, .late))

        switch (earlyStats, lateStats) {
        case (nil, nil):
            return Bool.random() ? .early : .late
        case (nil, .some):
            return .early
        case (.some, nil):
            return .late
        case (.some(let early), .some(let late)):
            let earlyCount = early.recordCount
            let lateCount = late.recordCount
            if earlyCount < lateCount {
                return .early
            } else if lateCount < earlyCount {
                return .late
            }
            return Bool.random() ? .early : .late
        }
    }

    // MARK: - Percentage Calculation

    private func choosePercentage(
        direction: RhythmDirection,
        profile: TrainingProfile,
        settings: RhythmOffsetDetectionSettings,
        lastResult: CompletedRhythmOffsetDetectionTrial?
    ) -> Double {
        let difficultyRange = settings.minOffsetPercentage...settings.maxOffsetPercentage

        if let last = lastResult {
            let lastPercentage = last.offset.percentageOfSixteenthNote(at: last.tempo)
            let adjusted = last.isCorrect
                ? kazezNarrow(p: lastPercentage)
                : kazezWiden(p: lastPercentage)
            return adjusted.clamped(to: difficultyRange)
        }

        guard let tempoRange = TempoRange.range(for: settings.tempo) else {
            return settings.maxOffsetPercentage
        }

        if case .continuous(let stats) = profile.statistics(for: .rhythm(.rhythmOffsetDetection, tempoRange, direction)) {
            // Profile mean is in milliseconds — convert to percentage of sixteenth note
            let meanMs = stats.welford.mean
            let sixteenthMs = settings.tempo.sixteenthNoteDuration / .milliseconds(1)
            let percentage = (meanMs / sixteenthMs) * 100.0
            return percentage.clamped(to: difficultyRange)
        }

        return settings.maxOffsetPercentage
    }

    // MARK: - Kazez Formulas

    private func kazezNarrow(p: Double) -> Double {
        p * (1.0 - Self.narrowingCoefficient * p.squareRoot())
    }

    private func kazezWiden(p: Double) -> Double {
        p * (1.0 + Self.wideningCoefficient * p.squareRoot())
    }
}
