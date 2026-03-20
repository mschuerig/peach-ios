import Testing
@testable import Peach

@Suite("RhythmTempoStats")
struct RhythmTempoStatsTests {

    @Test("Stored properties are accessible and correct")
    func storedProperties() async {
        let mean = RhythmOffset(.milliseconds(10))
        let stdDev = RhythmOffset(.milliseconds(5))
        let sampleCount = 42
        let currentDifficulty = RhythmOffset(.milliseconds(20))

        let stats = RhythmTempoStats(
            mean: mean,
            stdDev: stdDev,
            sampleCount: sampleCount,
            currentDifficulty: currentDifficulty
        )

        #expect(stats.mean == mean)
        #expect(stats.stdDev == stdDev)
        #expect(stats.sampleCount == sampleCount)
        #expect(stats.currentDifficulty == currentDifficulty)
    }

    @Test("Sendable conformance compiles")
    func sendable() async {
        let stats = RhythmTempoStats(
            mean: RhythmOffset(.milliseconds(10)),
            stdDev: RhythmOffset(.milliseconds(5)),
            sampleCount: 10,
            currentDifficulty: RhythmOffset(.milliseconds(20))
        )

        let sendableValue: any Sendable = stats
        #expect(sendableValue is RhythmTempoStats)
    }
}
