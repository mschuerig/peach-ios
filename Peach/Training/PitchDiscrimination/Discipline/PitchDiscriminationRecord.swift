import Foundation
import SwiftData

extension SchemaV1 {

    @Model
    final class PitchDiscriminationRecord {
        /// Reference note - always an exact MIDI note (0-127)
        var referenceNote: Int

        /// Target MIDI note (equals referenceNote for unison, different for intervals)
        var targetNote: Int

        /// Signed cent offset applied to target note (positive = higher, negative = lower)
        /// Fractional precision with 0.1 cent resolution
        var centOffset: Double

        /// Did the user answer correctly?
        var isCorrect: Bool

        /// When the discrimination was answered
        var timestamp: Date

        /// Interval between reference and target notes (stored as semitone count)
        var interval: Int

        /// Tuning system used for the discrimination (stored as string identifier)
        var tuningSystem: String

        init(referenceNote: Int, targetNote: Int, centOffset: Double, isCorrect: Bool, interval: Int, tuningSystem: String, timestamp: Date = Date()) {
            self.referenceNote = referenceNote
            self.targetNote = targetNote
            self.centOffset = centOffset
            self.isCorrect = isCorrect
            self.interval = interval
            self.tuningSystem = tuningSystem
            self.timestamp = timestamp
        }
    }
}

/// Top-level alias — points at the current schema version's nested type.
/// Update this when adding a new schema version.
typealias PitchDiscriminationRecord = SchemaV1.PitchDiscriminationRecord

extension PitchDiscriminationRecord: Timestamped {}
