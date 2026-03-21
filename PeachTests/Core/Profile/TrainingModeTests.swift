import Testing
@testable import Peach

@Suite("TrainingMode Tests")
struct TrainingModeTests {

    // MARK: - Slug

    @Test("slug returns pitch-comparison for unison pitch comparison")
    func slugUnisonPitchComparison() async {
        #expect(TrainingMode.unisonPitchComparison.slug == "pitch-comparison")
    }

    @Test("slug returns interval-comparison for interval pitch comparison")
    func slugIntervalPitchComparison() async {
        #expect(TrainingMode.intervalPitchComparison.slug == "interval-comparison")
    }

    @Test("slug returns pitch-matching for unison matching")
    func slugUnisonMatching() async {
        #expect(TrainingMode.unisonMatching.slug == "pitch-matching")
    }

    @Test("slug returns interval-matching for interval matching")
    func slugIntervalMatching() async {
        #expect(TrainingMode.intervalMatching.slug == "interval-matching")
    }

    @Test("slug returns rhythm-comparison for rhythm comparison")
    func slugRhythmComparison() async {
        #expect(TrainingMode.rhythmComparison.slug == "rhythm-comparison")
    }

    @Test("slug returns rhythm-matching for rhythm matching")
    func slugRhythmMatching() async {
        #expect(TrainingMode.rhythmMatching.slug == "rhythm-matching")
    }

    // MARK: - statisticsKeys

    @Test("pitch modes return single key")
    func pitchModesReturnSingleKey() async {
        for mode in [TrainingMode.unisonPitchComparison, .intervalPitchComparison, .unisonMatching, .intervalMatching] {
            #expect(mode.statisticsKeys.count == 1)
            #expect(mode.statisticsKeys.first == .pitch(mode))
        }
    }

    @Test("rhythm modes return 6 keys (3 tempo ranges x 2 directions)")
    func rhythmModesReturn6Keys() async {
        for mode in [TrainingMode.rhythmComparison, .rhythmMatching] {
            let keys = mode.statisticsKeys
            #expect(keys.count == 6)
            for range in TempoRange.defaultRanges {
                for direction in RhythmDirection.allCases {
                    #expect(keys.contains(.rhythm(mode, range, direction)))
                }
            }
        }
    }
}
