import Testing
import Foundation
@testable import Peach

@Suite("TrainingModeConfig Tests")
struct TrainingModeConfigTests {

    @Test("unison comparison has expected parameters")
    func unisonComparison() async {
        let config = TrainingModeConfig.unisonComparison
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflifeDays == 7.0)
        #expect(config.coldStartThreshold == 20)
        #expect(config.trendThreshold == 100)
        #expect(config.unitLabel == "cents")
        #expect(config.trendChangeThreshold == 0.05)
        #expect(config.sessionGapSeconds == 1800)
    }

    @Test("interval comparison has expected parameters")
    func intervalComparison() async {
        let config = TrainingModeConfig.intervalComparison
        #expect(config.optimalBaseline == 12.0)
        #expect(config.ewmaHalflifeDays == 7.0)
        #expect(config.coldStartThreshold == 20)
        #expect(config.trendThreshold == 100)
        #expect(config.unitLabel == "cents")
        #expect(config.trendChangeThreshold == 0.05)
        #expect(config.sessionGapSeconds == 1800)
    }

    @Test("unison matching has expected parameters")
    func unisonMatching() async {
        let config = TrainingModeConfig.unisonMatching
        #expect(config.optimalBaseline == 5.0)
        #expect(config.ewmaHalflifeDays == 7.0)
        #expect(config.coldStartThreshold == 20)
        #expect(config.trendThreshold == 100)
        #expect(config.unitLabel == "cents")
        #expect(config.trendChangeThreshold == 0.05)
        #expect(config.sessionGapSeconds == 1800)
    }

    @Test("interval matching has expected parameters")
    func intervalMatching() async {
        let config = TrainingModeConfig.intervalMatching
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflifeDays == 7.0)
        #expect(config.coldStartThreshold == 20)
        #expect(config.trendThreshold == 100)
        #expect(config.unitLabel == "cents")
        #expect(config.trendChangeThreshold == 0.05)
        #expect(config.sessionGapSeconds == 1800)
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
