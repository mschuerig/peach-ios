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
}
