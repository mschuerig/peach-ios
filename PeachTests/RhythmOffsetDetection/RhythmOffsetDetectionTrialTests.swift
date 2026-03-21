import Testing
import Foundation
@testable import Peach

@Suite("RhythmOffsetDetectionTrial Tests")
struct RhythmOffsetDetectionTrialTests {

    @Test("stores tempo and offset")
    func storesTempoAndOffset() async {
        let tempo = TempoBPM(120)
        let offset = RhythmOffset(.milliseconds(50))
        let trial = RhythmOffsetDetectionTrial(tempo: tempo, offset: offset)

        #expect(trial.tempo == tempo)
        #expect(trial.offset == offset)
    }

    @Test("offset direction reflects sign — early for negative")
    func earlyOffsetDirection() async {
        let trial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.zero - .milliseconds(30))
        )

        #expect(trial.offset.direction == .early)
    }

    @Test("offset direction reflects sign — late for positive")
    func lateOffsetDirection() async {
        let trial = RhythmOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: RhythmOffset(.milliseconds(30))
        )

        #expect(trial.offset.direction == .late)
    }
}
