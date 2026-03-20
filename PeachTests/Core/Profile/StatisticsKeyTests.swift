import Testing
import Foundation
@testable import Peach

@Suite("StatisticsKey")
struct StatisticsKeyTests {

    @Test("pitch keys are hashable and distinct")
    func pitchKeysDistinct() async {
        let key1 = StatisticsKey.pitch(.unisonPitchComparison)
        let key2 = StatisticsKey.pitch(.intervalPitchComparison)
        #expect(key1 != key2)
    }

    @Test("rhythm keys with different ranges are distinct")
    func rhythmKeysDistinctByRange() async {
        let key1 = StatisticsKey.rhythm(.rhythmComparison, .slow, .early)
        let key2 = StatisticsKey.rhythm(.rhythmComparison, .fast, .early)
        #expect(key1 != key2)
    }

    @Test("rhythm keys with different directions are distinct")
    func rhythmKeysDistinctByDirection() async {
        let key1 = StatisticsKey.rhythm(.rhythmComparison, .fast, .early)
        let key2 = StatisticsKey.rhythm(.rhythmComparison, .fast, .late)
        #expect(key1 != key2)
    }

    @Test("identical keys are equal")
    func identicalKeysEqual() async {
        let key1 = StatisticsKey.rhythm(.rhythmMatching, .medium, .late)
        let key2 = StatisticsKey.rhythm(.rhythmMatching, .medium, .late)
        #expect(key1 == key2)
    }

    @Test("statisticsConfig returns mode config")
    func configLookup() async {
        let pitchKey = StatisticsKey.pitch(.unisonPitchComparison)
        #expect(pitchKey.statisticsConfig.ewmaHalflife == TrainingModeConfig.unisonPitchComparison.statistics.ewmaHalflife)

        let rhythmKey = StatisticsKey.rhythm(.rhythmComparison, .fast, .early)
        #expect(rhythmKey.statisticsConfig.ewmaHalflife == TrainingModeConfig.rhythmComparison.statistics.ewmaHalflife)
    }
}
