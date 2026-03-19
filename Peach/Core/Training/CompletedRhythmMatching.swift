import Foundation

struct CompletedRhythmMatching: Sendable {
    let tempo: TempoBPM
    let expectedOffset: RhythmOffset
    let userOffset: RhythmOffset
    let timestamp: Date

    nonisolated init(tempo: TempoBPM, expectedOffset: RhythmOffset, userOffset: RhythmOffset, timestamp: Date = Date()) {
        self.tempo = tempo
        self.expectedOffset = expectedOffset
        self.userOffset = userOffset
        self.timestamp = timestamp
    }
}
