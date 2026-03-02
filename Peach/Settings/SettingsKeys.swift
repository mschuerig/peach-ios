import Foundation

enum SettingsKeys {
    // MARK: - @AppStorage Key Names

    static let noteRangeMin = "noteRangeMin"
    static let noteRangeMax = "noteRangeMax"
    static let noteDuration = "noteDuration"
    static let referencePitch = "referencePitch"
    static let soundSource = "soundSource"
    static let varyLoudness = "varyLoudness"
    static let intervals = "intervals"
    static let tuningSystem = "tuningSystem"

    // MARK: - Default Values (matching TrainingSettings defaults)

    static let defaultNoteRangeMin: Int = 36
    static let defaultNoteRangeMax: Int = 84
    static let defaultNoteDuration: Double = 1.0
    static let defaultReferencePitch: Double = 440.0
    static let defaultSoundSource: String = "sf2:8:80"
    static let defaultVaryLoudness: Double = 0.0
    static let defaultTuningSystem: String = "equalTemperament"

    // MARK: - Note Range Constants

    static let minimumNoteGap: Int = 12
    static let absoluteMinNote: Int = 21   // A0
    static let absoluteMaxNote: Int = 108  // C8

    /// Computes the allowed range for the lower bound Stepper
    /// Ensures lower bound stays at least `minimumNoteGap` below upper bound
    static func lowerBoundRange(noteRangeMax: Int) -> ClosedRange<Int> {
        absoluteMinNote...(noteRangeMax - minimumNoteGap)
    }

    /// Computes the allowed range for the upper bound Stepper
    /// Ensures upper bound stays at least `minimumNoteGap` above lower bound
    static func upperBoundRange(noteRangeMin: Int) -> ClosedRange<Int> {
        (noteRangeMin + minimumNoteGap)...absoluteMaxNote
    }
}
