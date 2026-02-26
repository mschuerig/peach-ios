import Foundation
import OSLog

final class KazezNoteStrategy: NextComparisonStrategy {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.peach.app", category: "KazezNoteStrategy")

    // MARK: - Initialization

    init() {
        logger.info("KazezNoteStrategy initialized")
    }

    // MARK: - NextComparisonStrategy Protocol

    func nextComparison(
        profile: PitchDiscriminationProfile,
        settings: TrainingSettings,
        lastComparison: CompletedComparison?
    ) -> Comparison {
        let magnitude: Double

        let difficultyRange = settings.minCentDifference.rawValue...settings.maxCentDifference.rawValue

        if let last = lastComparison {
            let p = last.comparison.centDifference.magnitude
            magnitude = last.isCorrect
                ? kazezNarrow(p: p).clamped(to: difficultyRange)
                : kazezWiden(p: p).clamped(to: difficultyRange)
        } else if let profileMean = profile.overallMean {
            magnitude = profileMean.clamped(to: difficultyRange)
        } else {
            magnitude = settings.maxCentDifference.rawValue
        }

        let signed = Bool.random() ? magnitude : -magnitude
        let note = MIDINote.random(in: settings.noteRangeMin...settings.noteRangeMax)

        logger.info("note=\(note.rawValue), centDiff=\(magnitude, format: .fixed(precision: 1))")

        return Comparison(
            note1: note,
            note2: note,
            centDifference: Cents(signed)
        )
    }

    // MARK: - Kazez Formulas

    private func kazezNarrow(p: Double) -> Double {
        p * (1.0 - 0.05 * p.squareRoot())
    }

    private func kazezWiden(p: Double) -> Double {
        p * (1.0 + 0.09 * p.squareRoot())
    }
}
