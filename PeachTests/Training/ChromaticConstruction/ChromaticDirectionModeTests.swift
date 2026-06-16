import Testing
@testable import Peach

@Suite("ChromaticDirectionMode resolves to Set<DirectedInterval>")
struct ChromaticDirectionModeTests {

    @Test("ascending mode resolves to a single .up interval")
    func ascendingResolvesToUpOnly() {
        #expect(ChromaticDirectionMode.ascending.outerIntervals(for: .perfectFifth) == [.up(.perfectFifth)])
    }

    @Test("descending mode resolves to a single .down interval")
    func descendingResolvesToDownOnly() {
        #expect(ChromaticDirectionMode.descending.outerIntervals(for: .perfectFifth) == [.down(.perfectFifth)])
    }

    @Test("mix mode resolves to both .up and .down")
    func mixResolvesToBoth() {
        #expect(ChromaticDirectionMode.mix.outerIntervals(for: .perfectFifth) == [.up(.perfectFifth), .down(.perfectFifth)])
    }

    @Test("all modes work for every legal outer interval")
    func allModesProduceNonEmptySets() {
        let allowed: [Interval] = [
            .majorSecond, .minorThird, .majorThird, .perfectFourth, .tritone,
            .perfectFifth, .minorSixth, .majorSixth, .minorSeventh, .majorSeventh, .octave,
        ]
        for interval in allowed {
            for mode in ChromaticDirectionMode.allCases {
                #expect(mode.outerIntervals(for: interval).isEmpty == false)
            }
        }
    }
}
