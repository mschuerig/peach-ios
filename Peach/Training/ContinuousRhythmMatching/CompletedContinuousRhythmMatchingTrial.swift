import Foundation

struct GapResult: Sendable {
    let position: StepPosition
    let offset: TimingOffset
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

    var meanOffsetPercentage: Double? {
        guard !gapResults.isEmpty else { return nil }
        let totalPercentage = gapResults.reduce(0.0) { sum, result in
            sum + result.offset.percentageOfSixteenthNote(at: tempo)
        }
        return totalPercentage / Double(gapResults.count)
    }

    var meanOffsetMs: Double? {
        guard !gapResults.isEmpty else { return nil }
        let totalMs = gapResults.reduce(0.0) { $0 + $1.offset.statisticalValue }
        return totalMs / Double(gapResults.count)
    }
}
