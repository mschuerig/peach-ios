import Testing
@testable import Peach

@Suite("TrainingDiscipline Tests")
struct TrainingDisciplineTests {

    // MARK: - Slug

    @Test("slug returns pitch-comparison for unison pitch comparison")
    func slugUnisonPitchDiscriminationTrial() async {
        #expect(TrainingDiscipline.unisonPitchDiscrimination.slug == "pitch-discrimination")
    }

    @Test("slug returns interval-comparison for interval pitch comparison")
    func slugIntervalPitchDiscriminationTrial() async {
        #expect(TrainingDiscipline.intervalPitchDiscrimination.slug == "interval-discrimination")
    }

    @Test("slug returns pitch-matching for unison matching")
    func slugUnisonMatching() async {
        #expect(TrainingDiscipline.unisonPitchMatching.slug == "pitch-matching")
    }

    @Test("slug returns interval-matching for interval matching")
    func slugIntervalMatching() async {
        #expect(TrainingDiscipline.intervalPitchMatching.slug == "interval-matching")
    }

    @Test("slug returns rhythm-offset-detection for rhythm offset detection")
    func slugRhythmOffsetDetection() async {
        #expect(TrainingDiscipline.rhythmOffsetDetection.slug == "rhythm-offset-detection")
    }

    // MARK: - statisticsKeys

    @Test("pitch modes return single key")
    func pitchModesReturnSingleKey() async {
        for mode in [TrainingDiscipline.unisonPitchDiscrimination, .intervalPitchDiscrimination, .unisonPitchMatching, .intervalPitchMatching] {
            #expect(mode.statisticsKeys.count == 1)
            #expect(mode.statisticsKeys.first == .pitch(mode))
        }
    }

    @Test("rhythm modes return 6 keys (3 tempo ranges x 2 directions)")
    func rhythmModesReturn6Keys() async {
        for mode in [TrainingDiscipline.rhythmOffsetDetection, .continuousRhythmMatching] {
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
