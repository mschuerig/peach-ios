import Testing
import Foundation
@testable import Peach

@Suite("TimingOffsetDetectionTrial Tests")
struct TimingOffsetDetectionTrialTests {

    @Test("stores tempo and offset")
    func storesTempoAndOffset() async {
        let tempo = TempoBPM(120)
        let offset = TimingOffset(.milliseconds(50))
        let trial = TimingOffsetDetectionTrial(tempo: tempo, offset: offset)

        #expect(trial.tempo == tempo)
        #expect(trial.offset == offset)
    }

    @Test("offset direction reflects sign — early for negative")
    func earlyOffsetDirection() async {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.zero - .milliseconds(30))
        )

        #expect(trial.offset.direction == .early)
    }

    @Test("offset direction reflects sign — late for positive")
    func lateOffsetDirection() async {
        let trial = TimingOffsetDetectionTrial(
            tempo: TempoBPM(80),
            offset: TimingOffset(.milliseconds(30))
        )

        #expect(trial.offset.direction == .late)
    }
}
