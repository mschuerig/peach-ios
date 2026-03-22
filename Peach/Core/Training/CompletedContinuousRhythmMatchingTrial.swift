import Foundation

struct GapResult: Sendable {
    let position: StepPosition
    let offset: RhythmOffset?
    var isHit: Bool { offset != nil }
}

struct PositionStats: Sendable {
    let hitCount: Int
    let missCount: Int
    let meanOffsetMs: Double
}

struct CompletedContinuousRhythmMatchingTrial: Sendable {
    let tempo: TempoBPM
    let gapResults: [GapResult]
    let meanOffsetMs: Double
    let hitRate: Double
    let gapPositionBreakdown: [StepPosition: PositionStats]
    let timestamp: Date

    init(tempo: TempoBPM, gapResults: [GapResult], timestamp: Date = Date()) {
        self.tempo = tempo
        self.gapResults = gapResults
        self.timestamp = timestamp

        let hits = gapResults.filter(\.isHit)
        self.hitRate = gapResults.isEmpty ? 0 : Double(hits.count) / Double(gapResults.count)

        let absoluteMs = hits.compactMap { $0.offset?.absoluteMilliseconds }
        self.meanOffsetMs = absoluteMs.isEmpty ? 0 : absoluteMs.reduce(0, +) / Double(absoluteMs.count)

        var breakdown: [StepPosition: PositionStats] = [:]
        let grouped = Dictionary(grouping: gapResults, by: \.position)
        for (position, results) in grouped {
            let positionHits = results.filter(\.isHit)
            let positionOffsets = positionHits.compactMap { $0.offset?.absoluteMilliseconds }
            let mean = positionOffsets.isEmpty ? 0 : positionOffsets.reduce(0, +) / Double(positionOffsets.count)
            breakdown[position] = PositionStats(
                hitCount: positionHits.count,
                missCount: results.count - positionHits.count,
                meanOffsetMs: mean
            )
        }
        self.gapPositionBreakdown = breakdown
    }
}
