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
        lastComparison: CompletedComparison?,
        interval: Interval
    ) -> Comparison {
        let magnitude: Double

        let difficultyRange = settings.minCentDifference.rawValue...settings.maxCentDifference.rawValue

        if let last = lastComparison {
            let p = last.comparison.targetNote.offset.magnitude
            magnitude = last.isCorrect
                ? kazezNarrow(p: p).clamped(to: difficultyRange)
                : kazezWiden(p: p).clamped(to: difficultyRange)
        } else if let profileMean = profile.overallMean {
            magnitude = profileMean.clamped(to: difficultyRange)
        } else {
            magnitude = settings.maxCentDifference.rawValue
        }

        let signed = Bool.random() ? magnitude : -magnitude
        let maxNote = MIDINote(min(settings.noteRangeMax.rawValue, 127 - interval.semitones))
        let note = MIDINote.random(in: settings.noteRangeMin...maxNote)
        let targetBaseNote = note.transposed(by: interval)

        logger.info("note=\(note.rawValue), interval=\(interval.semitones), target=\(targetBaseNote.rawValue), offset=\(magnitude, format: .fixed(precision: 1))")

        return Comparison(
            referenceNote: note,
            targetNote: DetunedMIDINote(note: targetBaseNote, offset: Cents(signed))
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
