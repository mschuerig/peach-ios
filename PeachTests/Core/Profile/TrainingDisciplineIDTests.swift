import Testing
@testable import Peach

@Suite("TrainingDisciplineID Tests")
struct TrainingDisciplineTests {

    // MARK: - Slug

    @Test("slug returns pitch-comparison for unison pitch comparison")
    func slugUnisonPitchDiscriminationTrial() async {
        #expect(TrainingDisciplineID.unisonPitchDiscrimination.slug == "pitch-discrimination")
    }

    @Test("slug returns interval-comparison for interval pitch comparison")
    func slugIntervalPitchDiscriminationTrial() async {
        #expect(TrainingDisciplineID.intervalPitchDiscrimination.slug == "interval-discrimination")
    }

    @Test("slug returns pitch-matching for unison matching")
    func slugUnisonMatching() async {
        #expect(TrainingDisciplineID.unisonPitchMatching.slug == "pitch-matching")
    }

    @Test("slug returns interval-matching for interval matching")
    func slugIntervalMatching() async {
        #expect(TrainingDisciplineID.intervalPitchMatching.slug == "interval-matching")
    }

    @Test("slug returns rhythm-offset-detection for rhythm offset detection")
    func slugRhythmOffsetDetection() async {
        #expect(TrainingDisciplineID.rhythmOffsetDetection.slug == "rhythm-offset-detection")
    }

    // MARK: - statisticsKeys

    @Test("pitch modes return single key")
    func pitchModesReturnSingleKey() async {
        for mode in [TrainingDisciplineID.unisonPitchDiscrimination, .intervalPitchDiscrimination, .unisonPitchMatching, .intervalPitchMatching] {
            #expect(mode.statisticsKeys.count == 1)
            #expect(mode.statisticsKeys.first == .pitch(mode))
        }
    }

    @Test("rhythm modes return 6 keys (3 tempo ranges x 2 directions)")
    func rhythmModesReturn6Keys() async {
        for mode in [TrainingDisciplineID.rhythmOffsetDetection, .continuousRhythmMatching] {
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
