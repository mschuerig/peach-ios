import Testing
import Foundation
@testable import Peach

@Suite("TrainingDisciplineConfig Tests")
struct TrainingDisciplineConfigTests {

    @Test("unison comparison has expected parameters")
    func unisonComparison() async {
        let config = TrainingDisciplineConfig.unisonPitchDiscrimination
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval comparison has expected parameters")
    func intervalComparison() async {
        let config = TrainingDisciplineConfig.intervalPitchDiscrimination
        #expect(config.optimalBaseline == 12.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("unison matching has expected parameters")
    func unisonMatching() async {
        let config = TrainingDisciplineConfig.unisonPitchMatching
        #expect(config.optimalBaseline == 5.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval matching has expected parameters")
    func intervalMatching() async {
        let config = TrainingDisciplineConfig.intervalPitchMatching
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("rhythm offset detection has expected parameters")
    func rhythmOffsetDetection() async {
        let config = TrainingDisciplineConfig.rhythmOffsetDetection
        #expect(config.optimalBaseline == 15.0)
        #expect(config.unitLabel == "ms")
    }

    @Test("all configurations have unique display names")
    func uniqueDisplayNames() async {
        let configs = TrainingDiscipline.allCases.map(\.config)
        let names = Set(configs.map(\.displayName))
        #expect(names.count == TrainingDiscipline.allCases.count)
    }
}
