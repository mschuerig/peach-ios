import SwiftData
import Foundation

@Model
final class ComparisonRecord {
    /// Reference note - always an exact MIDI note (0-127)
    var referenceNote: Int

    /// Target note - same MIDI note as referenceNote
    var targetNote: Int

    /// Signed cent offset applied to target note (positive = higher, negative = lower)
    /// Fractional precision with 0.1 cent resolution
    var centOffset: Double

    /// Did the user answer correctly?
    var isCorrect: Bool

    /// When the comparison was answered
    var timestamp: Date

    /// Creates a new comparison record
    /// - Parameters:
    ///   - referenceNote: Reference MIDI note (0-127)
    ///   - targetNote: Target MIDI note (0-127)
    ///   - centOffset: Cent offset applied to target note (fractional precision)
    ///   - isCorrect: Whether the user's answer was correct
    ///   - timestamp: When the comparison occurred (defaults to now)
    init(referenceNote: Int, targetNote: Int, centOffset: Double, isCorrect: Bool, timestamp: Date = Date()) {
        self.referenceNote = referenceNote
        self.targetNote = targetNote
        self.centOffset = centOffset
        self.isCorrect = isCorrect
        self.timestamp = timestamp
    }
}
