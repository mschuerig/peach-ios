import SwiftData
import Foundation

struct PositionBreakdown: Codable, Sendable {
    let position: Int
    let count: Int
    let meanOffsetMs: Double
}

@Model
final class ContinuousRhythmMatchingRecord {
    var tempoBPM: Int
    var meanOffsetMs: Double
    var gapPositionBreakdownJSON: Data
    var timestamp: Date

    init(
        tempoBPM: Int,
        meanOffsetMs: Double,
        gapPositionBreakdownJSON: Data,
        timestamp: Date = Date()
    ) {
        self.tempoBPM = tempoBPM
        self.meanOffsetMs = meanOffsetMs
        self.gapPositionBreakdownJSON = gapPositionBreakdownJSON
        self.timestamp = timestamp
    }
}
