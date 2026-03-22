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
        let key1 = StatisticsKey.rhythm(.rhythmOffsetDetection, .slow, .early)
        let key2 = StatisticsKey.rhythm(.rhythmOffsetDetection, .fast, .early)
        #expect(key1 != key2)
    }

    @Test("rhythm keys with different directions are distinct")
    func rhythmKeysDistinctByDirection() async {
        let key1 = StatisticsKey.rhythm(.rhythmOffsetDetection, .fast, .early)
        let key2 = StatisticsKey.rhythm(.rhythmOffsetDetection, .fast, .late)
        #expect(key1 != key2)
    }

    @Test("identical keys are equal")
    func identicalKeysEqual() async {
        let key1 = StatisticsKey.rhythm(.continuousRhythmMatching, .medium, .late)
        let key2 = StatisticsKey.rhythm(.continuousRhythmMatching, .medium, .late)
        #expect(key1 == key2)
    }

    @Test("statisticsConfig returns mode config")
    func configLookup() async {
        let pitchKey = StatisticsKey.pitch(.unisonPitchDiscrimination)
        #expect(pitchKey.statisticsConfig.ewmaHalflife == TrainingDisciplineConfig.unisonPitchDiscrimination.statistics.ewmaHalflife)

        let rhythmKey = StatisticsKey.rhythm(.rhythmOffsetDetection, .fast, .early)
        #expect(rhythmKey.statisticsConfig.ewmaHalflife == TrainingDisciplineConfig.rhythmOffsetDetection.statistics.ewmaHalflife)
    }
}
