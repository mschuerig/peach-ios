import Foundation
import Testing
@testable import Peach

@Suite("CompletedContinuousRhythmMatchingTrial")
struct CompletedContinuousRhythmMatchingTrialTests {

    // MARK: - GapResult

    @Test("gap result with offset is a hit")
    func gapResultWithOffsetIsHit() async {
        let result = GapResult(position: .first, offset: RhythmOffset(.milliseconds(10)))
        #expect(result.isHit)
    }

    @Test("gap result without offset is a miss")
    func gapResultWithoutOffsetIsMiss() async {
        let result = GapResult(position: .second, offset: nil)
        #expect(!result.isHit)
    }

    // MARK: - Trial as Container

    @Test("trial stores tempo and gap results")
    func trialStoresTempoAndGapResults() async {
        let results = [
            GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(5))),
            GapResult(position: .second, offset: nil),
        ]
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: results)

        #expect(trial.tempo == TempoBPM(120))
        #expect(trial.gapResults.count == 2)
        #expect(trial.gapResults[0].isHit)
        #expect(!trial.gapResults[1].isHit)
    }

    @Test("default timestamp is populated")
    func defaultTimestampIsPopulated() async {
        let before = Date()
        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(120),
            gapResults: [GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(5)))]
        )
        let after = Date()

        #expect(trial.timestamp >= before)
        #expect(trial.timestamp <= after)
    }

    @Test("custom timestamp is used")
    func customTimestampIsUsed() async {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(120),
            gapResults: [],
            timestamp: date
        )
        #expect(trial.timestamp == date)
    }

    @Test("conforms to Sendable")
    func conformsToSendable() async {
        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(120),
            gapResults: []
        )
        let sendable: any Sendable = trial
        #expect(sendable is CompletedContinuousRhythmMatchingTrial)
    }

    @Test("gap results preserve offset direction")
    func gapResultsPreserveOffsetDirection() async {
        let early = GapResult(position: .first, offset: RhythmOffset(.milliseconds(-15)))
        let late = GapResult(position: .second, offset: RhythmOffset(.milliseconds(20)))
        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(120),
            gapResults: [early, late]
        )

        #expect(trial.gapResults[0].offset?.direction == .early)
        #expect(trial.gapResults[1].offset?.direction == .late)
    }
}
