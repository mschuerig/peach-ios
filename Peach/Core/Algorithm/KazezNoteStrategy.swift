import Foundation
import OSLog

/// Adaptive pitch comparison selection using the Kazez difficulty adjustment formula.
///
/// After a correct answer the cent difference narrows; after an incorrect answer it widens.
/// The adjustment is non-linear: `p * (1 +/- k * sqrt(p))`, where `k` is a coefficient
/// that produces larger absolute changes at higher difficulties and gentler changes near
/// threshold.
///
/// Reference:
///   Kazez, D., Kazez, B., Zembar, M. J., & Andrews, D. (2001).
///   A Computer Program for Testing (and Improving?) Pitch Perception.
///   College Music Society National Conference.
final class KazezNoteStrategy: NextPitchComparisonStrategy {

    // MARK: - Algorithm Parameters

    /// Coefficient for narrowing (making harder) after a correct answer.
    /// Formula: `p * (1.0 - k * sqrt(p))` where k = 0.05.
    private static let narrowingCoefficient: Double = 0.05

    /// Coefficient for widening (making easier) after an incorrect answer.
    /// Formula: `p * (1.0 + k * sqrt(p))` where k = 0.09.
    private static let wideningCoefficient: Double = 0.09

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.peach.app", category: "KazezNoteStrategy")

    // MARK: - Initialization

    init() {
        logger.info("KazezNoteStrategy initialized")
    }

    // MARK: - NextPitchComparisonStrategy Protocol

    func nextPitchComparison(
        profile: PitchComparisonProfile,
        settings: TrainingSettings,
        lastPitchComparison: CompletedPitchComparison?,
        interval: DirectedInterval
    ) -> PitchComparison {
        let magnitude: Double

        let difficultyRange = settings.minCentDifference.rawValue...settings.maxCentDifference.rawValue

        if let last = lastPitchComparison {
            let p = last.pitchComparison.targetNote.offset.magnitude
            magnitude = last.isCorrect
                ? kazezNarrow(p: p).clamped(to: difficultyRange)
                : kazezWiden(p: p).clamped(to: difficultyRange)
        } else if let profileMean = profile.overallMean {
            magnitude = profileMean.rawValue.clamped(to: difficultyRange)
        } else {
            magnitude = settings.maxCentDifference.rawValue
        }

        let signed = Bool.random() ? magnitude : -magnitude

        let minNote: MIDINote
        let maxNote: MIDINote
        if interval.direction == .up {
            minNote = settings.noteRange.lowerBound
            maxNote = MIDINote(min(settings.noteRange.upperBound.rawValue, MIDINote.validRange.upperBound - interval.interval.semitones))
        } else {
            minNote = MIDINote(max(settings.noteRange.lowerBound.rawValue, MIDINote.validRange.lowerBound + interval.interval.semitones))
            maxNote = settings.noteRange.upperBound
        }
        let note = MIDINote.random(in: minNote...maxNote)
        let targetBaseNote = note.transposed(by: interval)

        logger.info("note=\(note.rawValue), interval=\(interval.interval.semitones), target=\(targetBaseNote.rawValue), offset=\(magnitude, format: .fixed(precision: 1))")

        return PitchComparison(
            referenceNote: note,
            targetNote: DetunedMIDINote(note: targetBaseNote, offset: Cents(signed))
        )
    }

    // MARK: - Kazez Formulas

    private func kazezNarrow(p: Double) -> Double {
        p * (1.0 - Self.narrowingCoefficient * p.squareRoot())
    }

    private func kazezWiden(p: Double) -> Double {
        p * (1.0 + Self.wideningCoefficient * p.squareRoot())
    }
}
