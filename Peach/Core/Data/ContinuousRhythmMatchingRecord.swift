import SwiftData
import Foundation

struct PositionBreakdown: Codable, Sendable {
    let position: Int
    let hitCount: Int
    let missCount: Int
    let meanOffsetMs: Double
}

@Model
final class ContinuousRhythmMatchingRecord {
    var tempoBPM: Int
    var meanOffsetMs: Double
    var hitRate: Double
    var gapPositionBreakdownJSON: Data
    var cycleCount: Int
    var timestamp: Date

    init(
        tempoBPM: Int,
        meanOffsetMs: Double,
        hitRate: Double,
        gapPositionBreakdownJSON: Data,
        cycleCount: Int,
        timestamp: Date = Date()
    ) {
        self.tempoBPM = tempoBPM
        self.meanOffsetMs = meanOffsetMs
        self.hitRate = hitRate
        self.gapPositionBreakdownJSON = gapPositionBreakdownJSON
        self.cycleCount = cycleCount
        self.timestamp = timestamp
    }
}
