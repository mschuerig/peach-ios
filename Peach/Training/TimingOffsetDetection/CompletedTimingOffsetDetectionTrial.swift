import Foundation

struct CompletedTimingOffsetDetectionTrial: Sendable {
    let tempo: TempoBPM
    let offset: TimingOffset
    let isCorrect: Bool
    let timestamp: Date

    nonisolated init(tempo: TempoBPM, offset: TimingOffset, isCorrect: Bool, timestamp: Date = Date()) {
        self.tempo = tempo
        self.offset = offset
        self.isCorrect = isCorrect
        self.timestamp = timestamp
    }
}
