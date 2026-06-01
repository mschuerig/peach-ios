import Testing
@testable import Peach

#if PEACH_RESEARCH
@Suite("BeatPosition")
struct BeatPositionTests {

    @Test("BeatPosition has four cases with raw values 0–3")
    func rawValues() async {
        #expect(BeatPosition.first.rawValue == 0)
        #expect(BeatPosition.second.rawValue == 1)
        #expect(BeatPosition.third.rawValue == 2)
        #expect(BeatPosition.fourth.rawValue == 3)
    }

    @Test("BeatPosition allCases contains exactly four positions")
    func allCases() async {
        #expect(BeatPosition.allCases.count == 4)
        #expect(BeatPosition.allCases == [.first, .second, .third, .fourth])
    }

    @Test("BeatPosition is Sendable and Hashable")
    func conformances() async {
        let set: Set<BeatPosition> = [.first, .second, .first]
        #expect(set.count == 2)

        let _: any Sendable = BeatPosition.first
    }
}
#endif
