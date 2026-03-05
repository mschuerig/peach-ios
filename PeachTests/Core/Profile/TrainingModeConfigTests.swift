import Testing
import Foundation
@testable import Peach

@Suite("TrainingModeConfig Tests")
struct TrainingModeConfigTests {

    @Test("unison comparison has expected parameters")
    func unisonComparison() async {
        let config = TrainingModeConfig.unisonComparison
        #expect(config.optimalBaseline == Cents(8.0))
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval comparison has expected parameters")
    func intervalComparison() async {
        let config = TrainingModeConfig.intervalComparison
        #expect(config.optimalBaseline == Cents(12.0))
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("unison matching has expected parameters")
    func unisonMatching() async {
        let config = TrainingModeConfig.unisonMatching
        #expect(config.optimalBaseline == Cents(5.0))
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval matching has expected parameters")
    func intervalMatching() async {
        let config = TrainingModeConfig.intervalMatching
        #expect(config.optimalBaseline == Cents(8.0))
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("all four configurations have unique display names")
    func uniqueDisplayNames() async {
        let configs = [
            TrainingModeConfig.unisonComparison,
            TrainingModeConfig.intervalComparison,
            TrainingModeConfig.unisonMatching,
            TrainingModeConfig.intervalMatching
        ]
        let names = Set(configs.map(\.displayName))
        #expect(names.count == 4)
    }
}
