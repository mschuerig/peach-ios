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

    // MARK: - Trial Aggregation

    @Test("trial with all hits computes correct hit rate")
    func allHitsComputesCorrectHitRate() async {
        let results = (0..<16).map { _ in
            GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(5)))
        }
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: results)
        #expect(trial.hitRate == 1.0)
    }

    @Test("trial with all misses computes zero hit rate")
    func allMissesComputesZeroHitRate() async {
        let results = (0..<16).map { _ in
            GapResult(position: .fourth, offset: nil)
        }
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: results)
        #expect(trial.hitRate == 0.0)
    }

    @Test("trial with mixed results computes correct hit rate")
    func mixedResultsComputesCorrectHitRate() async {
        var results: [GapResult] = []
        for i in 0..<16 {
            if i < 12 {
                results.append(GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(10))))
            } else {
                results.append(GapResult(position: .fourth, offset: nil))
            }
        }
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: results)
        #expect(trial.hitRate == 0.75)
    }

    @Test("mean offset computed from hits only")
    func meanOffsetComputedFromHitsOnly() async {
        let results = [
            GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(10))),
            GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(20))),
            GapResult(position: .fourth, offset: nil),
        ]
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: results)
        #expect(trial.meanOffsetMs == 15.0)
    }

    @Test("mean offset uses absolute values for early hits")
    func meanOffsetUsesAbsoluteValues() async {
        let results = [
            GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(-10))),
            GapResult(position: .fourth, offset: RhythmOffset(.milliseconds(20))),
        ]
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: results)
        #expect(trial.meanOffsetMs == 15.0)
    }

    @Test("position breakdown groups by step position")
    func positionBreakdownGroupsByStepPosition() async {
        let results = [
            GapResult(position: .first, offset: RhythmOffset(.milliseconds(10))),
            GapResult(position: .first, offset: nil),
            GapResult(position: .third, offset: RhythmOffset(.milliseconds(20))),
            GapResult(position: .third, offset: RhythmOffset(.milliseconds(30))),
        ]
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: results)

        let firstStats = trial.gapPositionBreakdown[.first]
        #expect(firstStats?.hitCount == 1)
        #expect(firstStats?.missCount == 1)
        #expect(firstStats?.meanOffsetMs == 10.0)

        let thirdStats = trial.gapPositionBreakdown[.third]
        #expect(thirdStats?.hitCount == 2)
        #expect(thirdStats?.missCount == 0)
        #expect(thirdStats?.meanOffsetMs == 25.0)
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

    @Test("conforms to Sendable")
    func conformsToSendable() async {
        let trial = CompletedContinuousRhythmMatchingTrial(
            tempo: TempoBPM(120),
            gapResults: []
        )
        let sendable: any Sendable = trial
        #expect(sendable is CompletedContinuousRhythmMatchingTrial)
    }

    @Test("empty gap results produce zero stats")
    func emptyGapResultsProduceZeroStats() async {
        let trial = CompletedContinuousRhythmMatchingTrial(tempo: TempoBPM(120), gapResults: [])
        #expect(trial.hitRate == 0.0)
        #expect(trial.meanOffsetMs == 0.0)
        #expect(trial.gapPositionBreakdown.isEmpty)
    }
}
