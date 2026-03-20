import Testing
import Foundation
@testable import Peach

@Suite("TrainingModeConfig Tests")
struct TrainingModeConfigTests {

    @Test("unison comparison has expected parameters")
    func unisonComparison() async {
        let config = TrainingModeConfig.unisonPitchComparison
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval comparison has expected parameters")
    func intervalComparison() async {
        let config = TrainingModeConfig.intervalPitchComparison
        #expect(config.optimalBaseline == 12.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("unison matching has expected parameters")
    func unisonMatching() async {
        let config = TrainingModeConfig.unisonMatching
        #expect(config.optimalBaseline == 5.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval matching has expected parameters")
    func intervalMatching() async {
        let config = TrainingModeConfig.intervalMatching
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("rhythm comparison has expected parameters")
    func rhythmComparison() async {
        let config = TrainingModeConfig.rhythmComparison
        #expect(config.optimalBaseline == 15.0)
        #expect(config.unitLabel == "ms")
    }

    @Test("rhythm matching has expected parameters")
    func rhythmMatching() async {
        let config = TrainingModeConfig.rhythmMatching
        #expect(config.optimalBaseline == 20.0)
        #expect(config.unitLabel == "ms")
    }

    @Test("all configurations have unique display names")
    func uniqueDisplayNames() async {
        let configs = TrainingMode.allCases.map(\.config)
        let names = Set(configs.map(\.displayName))
        #expect(names.count == TrainingMode.allCases.count)
    }
}
