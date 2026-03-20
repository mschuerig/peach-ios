import Testing
@testable import Peach

@Suite("PitchBendValue Tests")
struct PitchBendValueTests {

    @Test("Creates valid pitch bend at boundaries")
    func validBoundaries() async {
        let low = PitchBendValue(0)
        let high = PitchBendValue(16383)

        #expect(low.rawValue == 0)
        #expect(high.rawValue == 16383)
    }

    @Test("Center value is 8192")
    func center() async {
        #expect(PitchBendValue.center.rawValue == 8192)
    }

    @Test("Integer literal creates PitchBendValue")
    func integerLiteral() async {
        let bend: PitchBendValue = 8192
        #expect(bend.rawValue == 8192)
    }

    @Test("Equal values have same hash")
    func hashable() async {
        let set: Set<PitchBendValue> = [PitchBendValue(0), PitchBendValue(0), PitchBendValue(8192)]
        #expect(set.count == 2)
    }
}
