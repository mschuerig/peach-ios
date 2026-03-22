import Foundation

struct GapResult: Sendable {
    let position: StepPosition
    let offset: RhythmOffset?
    var isHit: Bool { offset != nil }
}

struct CompletedContinuousRhythmMatchingTrial: Sendable {
    let tempo: TempoBPM
    let gapResults: [GapResult]
    let timestamp: Date

    init(tempo: TempoBPM, gapResults: [GapResult], timestamp: Date = Date()) {
        self.tempo = tempo
        self.gapResults = gapResults
        self.timestamp = timestamp
    }

    var hitCount: Int {
        gapResults.filter(\.isHit).count
    }

    var hitRate: Double {
        guard !gapResults.isEmpty else { return 0 }
        return Double(hitCount) / Double(gapResults.count) * 100.0
    }

    var meanOffsetPercentage: Double? {
        let hits = gapResults.compactMap(\.offset)
        guard !hits.isEmpty else { return nil }
        let totalPercentage = hits.reduce(0.0) { sum, offset in
            sum + offset.percentageOfSixteenthNote(at: tempo)
        }
        return totalPercentage / Double(hits.count)
    }

    var meanOffsetMs: Double? {
        let hits = gapResults.compactMap(\.offset)
        guard !hits.isEmpty else { return nil }
        let totalMs = hits.reduce(0.0) { $0 + $1.statisticalValue }
        return totalMs / Double(hits.count)
    }
}
