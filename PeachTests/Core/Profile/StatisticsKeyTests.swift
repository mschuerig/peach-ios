import Testing
import Foundation
@testable import Peach

@Suite("StatisticsKey")
struct StatisticsKeyTests {

    @Test("pitch keys are hashable and distinct")
    func pitchKeysDistinct() async {
        let key1 = StatisticsKey.pitch(.unisonPitchDiscrimination)
        let key2 = StatisticsKey.pitch(.intervalPitchDiscrimination)
        #expect(key1 != key2)
    }

    @Test("rhythm keys with different ranges are distinct")
    func rhythmKeysDistinctByRange() async {
        let key1 = StatisticsKey.rhythm(.timingOffsetDetection, .slow, .early)
        let key2 = StatisticsKey.rhythm(.timingOffsetDetection, .fast, .early)
        #expect(key1 != key2)
    }

    @Test("rhythm keys with different directions are distinct")
    func rhythmKeysDistinctByDirection() async {
        let key1 = StatisticsKey.rhythm(.timingOffsetDetection, .fast, .early)
        let key2 = StatisticsKey.rhythm(.timingOffsetDetection, .fast, .late)
        #expect(key1 != key2)
    }

    @Test("identical keys are equal")
    func identicalKeysEqual() async {
        let key1 = StatisticsKey.rhythm(.continuousRhythmMatching, .moderate, .late)
        let key2 = StatisticsKey.rhythm(.continuousRhythmMatching, .moderate, .late)
        #expect(key1 == key2)
    }

    @Test("statisticsConfig returns mode config")
    func configLookup() async {
        let pitchKey = StatisticsKey.pitch(.unisonPitchDiscrimination)
        #expect(pitchKey.statisticsConfig.ewmaHalflife == TrainingDisciplineID.unisonPitchDiscrimination.config.statistics.ewmaHalflife)

        let rhythmKey = StatisticsKey.rhythm(.timingOffsetDetection, .fast, .early)
        #expect(rhythmKey.statisticsConfig.ewmaHalflife == TrainingDisciplineID.timingOffsetDetection.config.statistics.ewmaHalflife)
    }
}
