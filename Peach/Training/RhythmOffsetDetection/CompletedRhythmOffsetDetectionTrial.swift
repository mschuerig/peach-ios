import Foundation

struct CompletedRhythmOffsetDetectionTrial: Sendable {
    let tempo: TempoBPM
    let offset: RhythmOffset
    let isCorrect: Bool
    let timestamp: Date

    nonisolated init(tempo: TempoBPM, offset: RhythmOffset, isCorrect: Bool, timestamp: Date = Date()) {
        self.tempo = tempo
        self.offset = offset
        self.isCorrect = isCorrect
        self.timestamp = timestamp
    }
}
