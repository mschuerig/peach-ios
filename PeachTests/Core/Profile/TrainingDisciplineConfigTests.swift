import Testing
import Foundation
@testable import Peach

@Suite("TrainingDisciplineConfig Tests")
struct TrainingDisciplineConfigTests {

    @Test("unison comparison has expected parameters")
    func unisonComparison() async {
        let config = TrainingDisciplineID.unisonPitchDiscrimination.config
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval comparison has expected parameters")
    func intervalComparison() async {
        let config = TrainingDisciplineID.intervalPitchDiscrimination.config
        #expect(config.optimalBaseline == 12.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("unison matching has expected parameters")
    func unisonMatching() async {
        let config = TrainingDisciplineID.unisonPitchMatching.config
        #expect(config.optimalBaseline == 5.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("interval matching has expected parameters")
    func intervalMatching() async {
        let config = TrainingDisciplineID.intervalPitchMatching.config
        #expect(config.optimalBaseline == 8.0)
        #expect(config.ewmaHalflife == .seconds(7 * 86400))
        #expect(config.sessionGap == .seconds(1800))
    }

    @Test("rhythm offset detection has expected parameters")
    func rhythmOffsetDetection() async {
        let config = TrainingDisciplineID.timingOffsetDetection.config
        #expect(config.optimalBaseline == 15.0)
        // Comparing `config.unitLabel` against `String(localized: "milliseconds")`
        // would compare the production expression to itself and could only
        // catch a key rename. Assert the properties that carry meaning instead:
        // the two forms differ, and the spoken one is the longer, spelled-out
        // form rather than the abbreviation.
        #expect(config.unitLabel != config.unitSymbol)
        #expect(config.unitLabel.count > config.unitSymbol.count)
        #expect(config.unitSymbol == String(localized: "ms"))
    }

    @Test("all configurations have unique display names")
    func uniqueDisplayNames() async {
        let disciplines = TrainingDisciplineRegistry.shared.all
        let names = Set(disciplines.map(\.config.displayName))
        #expect(names.count == disciplines.count)
    }
}
