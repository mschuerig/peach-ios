import SwiftData
import Foundation

@Model
final class ContinuousRhythmMatchingRecord {
    var tempoBPM: Int
    var meanOffsetMs: Double
    var meanOffsetMsPosition0: Double?
    var meanOffsetMsPosition1: Double?
    var meanOffsetMsPosition2: Double?
    var meanOffsetMsPosition3: Double?
    var timestamp: Date

    init(
        tempoBPM: Int,
        meanOffsetMs: Double,
        meanOffsetMsPosition0: Double? = nil,
        meanOffsetMsPosition1: Double? = nil,
        meanOffsetMsPosition2: Double? = nil,
        meanOffsetMsPosition3: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.tempoBPM = tempoBPM
        self.meanOffsetMs = meanOffsetMs
        self.meanOffsetMsPosition0 = meanOffsetMsPosition0
        self.meanOffsetMsPosition1 = meanOffsetMsPosition1
        self.meanOffsetMsPosition2 = meanOffsetMsPosition2
        self.meanOffsetMsPosition3 = meanOffsetMsPosition3
        self.timestamp = timestamp
    }
}
