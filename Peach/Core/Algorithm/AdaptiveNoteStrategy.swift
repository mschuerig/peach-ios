import Foundation
import OSLog

final class AdaptiveNoteStrategy: NextComparisonStrategy {

    // MARK: - Difficulty Parameters

    private enum DifficultyParameters {
        static let regionalRange: Int = 12
        static let defaultDifficulty: Double = 100.0
        static let maxNeighbors: Int = 5
        static let correctNarrowingCoefficient: Double = 0.08
        static let incorrectWideningCoefficient: Double = 0.09
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.peach.app", category: "AdaptiveNoteStrategy")

    // MARK: - Initialization

    init() {
        logger.info("AdaptiveNoteStrategy initialized (stateless)")
    }

    // MARK: - NextComparisonStrategy Protocol

    func nextComparison(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> Comparison {
        let selectedNote = selectNote(
            profile: profile,
            settings: settings,
            lastComparison: lastComparison
        )

        let magnitude = determineCentDifference(
            for: selectedNote,
            profile: profile,
            settings: settings,
            lastComparison: lastComparison
        )

        let signed = Bool.random() ? magnitude : -magnitude

        logger.info("Selected note=\(selectedNote.rawValue), centDiff=\(magnitude)")

        return Comparison(
            note1: selectedNote,
            note2: selectedNote,
            centDifference: Cents(signed)
        )
    }

    // MARK: - Private Implementation

    private func selectNote(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> MIDINote {
        let mechanicalRatio = settings.naturalVsMechanical

        if Double.random(in: 0...1) < mechanicalRatio {
            return selectWeakSpot(profile: profile, settings: settings)
        } else {
            if let lastNote = lastComparison?.comparison.note1 {
                return selectNearbyNote(around: lastNote, settings: settings)
            } else {
                return selectWeakSpot(profile: profile, settings: settings)
            }
        }
    }

    private func selectWeakSpot(profile: PitchDiscriminationProfile, settings: TrainingSettings) -> MIDINote {
        let weakSpots = profile.weakSpots(count: 10)
        let filtered = weakSpots.filter { settings.isInRange($0) }

        if let selected = filtered.randomElement() {
            logger.debug("Selected weak spot: \(selected.rawValue)")
            return selected
        } else {
            logger.debug("No weak spots in range, using random selection")
            return MIDINote.random(in: settings.noteRangeMin...settings.noteRangeMax)
        }
    }

    private func selectNearbyNote(around note: MIDINote, settings: TrainingSettings) -> MIDINote {
        let minNearby = max(settings.noteRangeMin.rawValue, note.rawValue - DifficultyParameters.regionalRange)
        let maxNearby = min(settings.noteRangeMax.rawValue, note.rawValue + DifficultyParameters.regionalRange)

        let actualMin = min(minNearby, settings.noteRangeMax.rawValue)
        let actualMax = max(maxNearby, settings.noteRangeMin.rawValue)

        let selected = MIDINote(Int.random(in: actualMin...actualMax))
        logger.debug("Selected nearby note: \(selected.rawValue) (near \(note.rawValue))")
        return selected
    }

    private func determineCentDifference(
        for note: MIDINote,
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> Double {
        let difficultyRange = settings.minCentDifference.rawValue...settings.maxCentDifference.rawValue

        guard let last = lastComparison else {
            let effective = weightedEffectiveDifficulty(for: note, profile: profile, settings: settings)
            return effective.clamped(to: difficultyRange)
        }

        let p = last.comparison.centDifference.magnitude
        let rawDiff = last.isCorrect
            ? p * (1.0 - DifficultyParameters.correctNarrowingCoefficient * p.squareRoot())
            : p * (1.0 + DifficultyParameters.incorrectWideningCoefficient * p.squareRoot())
        let adjustedDiff = rawDiff.clamped(to: difficultyRange)

        profile.setDifficulty(note: note, difficulty: adjustedDiff)
        logger.debug("Difficulty for note \(note.rawValue): \(last.isCorrect ? "correct" : "incorrect") → \(adjustedDiff) cents")
        return adjustedDiff
    }

    private func weightedEffectiveDifficulty(
        for note: MIDINote,
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings
    ) -> Double {
        let range = settings.noteRangeMin.rawValue...settings.noteRangeMax.rawValue

        var candidates: [(distance: Int, difficulty: Double)] = []
        let currentStats = profile.statsForNote(note)
        if currentStats.sampleCount > 0
            || currentStats.currentDifficulty != DifficultyParameters.defaultDifficulty {
            candidates.append((distance: 0, difficulty: currentStats.currentDifficulty))
        }

        var leftCount = 0
        for i in stride(from: note.rawValue - 1, through: range.lowerBound, by: -1) {
            guard leftCount < DifficultyParameters.maxNeighbors else { break }
            let stats = profile.statsForNote(MIDINote(i))
            if stats.sampleCount > 0
                && stats.currentDifficulty != DifficultyParameters.defaultDifficulty {
                candidates.append((distance: note.rawValue - i, difficulty: stats.currentDifficulty))
                leftCount += 1
            }
        }

        var rightCount = 0
        for i in stride(from: note.rawValue + 1, through: range.upperBound, by: 1) {
            guard rightCount < DifficultyParameters.maxNeighbors else { break }
            let stats = profile.statsForNote(MIDINote(i))
            if stats.sampleCount > 0
                && stats.currentDifficulty != DifficultyParameters.defaultDifficulty {
                candidates.append((distance: i - note.rawValue, difficulty: stats.currentDifficulty))
                rightCount += 1
            }
        }

        guard !candidates.isEmpty else {
            return DifficultyParameters.defaultDifficulty
        }

        var weightSum = 0.0
        var weightedSum = 0.0
        for candidate in candidates {
            let w = 1.0 / (1.0 + Double(candidate.distance))
            weightSum += w
            weightedSum += w * candidate.difficulty
        }

        return weightedSum / weightSum
    }

}
