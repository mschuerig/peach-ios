import Foundation
import SwiftData

extension SchemaV1 {

    @Model
    final class PitchMatchingRecord {
        var referenceNote: Int
        var targetNote: Int
        var initialCentOffset: Double
        var userCentError: Double
        var interval: Int
        var tuningSystem: String
        var timestamp: Date

        init(referenceNote: Int, targetNote: Int, initialCentOffset: Double, userCentError: Double, interval: Int, tuningSystem: String, timestamp: Date = Date()) {
            self.referenceNote = referenceNote
            self.targetNote = targetNote
            self.initialCentOffset = initialCentOffset
            self.userCentError = userCentError
            self.interval = interval
            self.tuningSystem = tuningSystem
            self.timestamp = timestamp
        }
    }
}

/// Top-level alias — points at the current schema version's nested type.
/// Update this when adding a new schema version.
typealias PitchMatchingRecord = SchemaV1.PitchMatchingRecord

extension PitchMatchingRecord: Timestamped {}
