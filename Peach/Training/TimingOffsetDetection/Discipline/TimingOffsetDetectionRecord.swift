import Foundation
import SwiftData

extension SchemaV1 {

    @Model
    final class RhythmOffsetDetectionRecord {
        var tempoBPM: Int

        /// Signed offset in milliseconds: negative = early, positive = late
        var offsetMs: Double

        var isCorrect: Bool
        var timestamp: Date

        init(tempoBPM: Int, offsetMs: Double, isCorrect: Bool, timestamp: Date = Date()) {
            self.tempoBPM = tempoBPM
            self.offsetMs = offsetMs
            self.isCorrect = isCorrect
            self.timestamp = timestamp
        }
    }
}

/// Maps the renamed public type to the unchanged SwiftData entity name,
/// avoiding a schema migration for a purely cosmetic rename.
typealias TimingOffsetDetectionRecord = SchemaV1.RhythmOffsetDetectionRecord

extension TimingOffsetDetectionRecord: Timestamped {}
