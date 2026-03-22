import Foundation
import Testing
@testable import Peach

@Suite("GapPositionEncoding")
struct GapPositionEncodingTests {

    @Test("encodes all four positions as sorted comma-separated string")
    func encodesAllPositions() async {
        let positions: Set<StepPosition> = [.first, .second, .third, .fourth]
        let encoded = GapPositionEncoding.encode(positions)
        #expect(encoded == "0,1,2,3")
    }

    @Test("encodes subset of positions")
    func encodesSubset() async {
        let positions: Set<StepPosition> = [.first, .third]
        let encoded = GapPositionEncoding.encode(positions)
        #expect(encoded == "0,2")
    }

    @Test("encodes single position")
    func encodesSingle() async {
        let positions: Set<StepPosition> = [.fourth]
        let encoded = GapPositionEncoding.encode(positions)
        #expect(encoded == "3")
    }

    @Test("encodes empty set as empty string")
    func encodesEmpty() async {
        let positions: Set<StepPosition> = []
        let encoded = GapPositionEncoding.encode(positions)
        #expect(encoded == "")
    }

    @Test("decodes comma-separated string to positions")
    func decodesString() async {
        let decoded = GapPositionEncoding.decode("0,1,2,3")
        #expect(decoded == Set(StepPosition.allCases))
    }

    @Test("decodes subset string")
    func decodesSubset() async {
        let decoded = GapPositionEncoding.decode("1,3")
        #expect(decoded == [.second, .fourth])
    }

    @Test("decodes single value")
    func decodesSingle() async {
        let decoded = GapPositionEncoding.decode("2")
        #expect(decoded == [.third])
    }

    @Test("decodes empty string to empty set")
    func decodesEmpty() async {
        let decoded = GapPositionEncoding.decode("")
        #expect(decoded.isEmpty)
    }

    @Test("ignores invalid values during decode")
    func ignoresInvalidValues() async {
        let decoded = GapPositionEncoding.decode("0,5,abc,2")
        #expect(decoded == [.first, .third])
    }

    @Test("round-trip preserves all positions", arguments: [
        Set<StepPosition>([.first]),
        Set<StepPosition>([.second, .fourth]),
        Set<StepPosition>([.first, .second, .third]),
        Set(StepPosition.allCases),
    ])
    func roundTrip(positions: Set<StepPosition>) async {
        let encoded = GapPositionEncoding.encode(positions)
        let decoded = GapPositionEncoding.decode(encoded)
        #expect(decoded == positions)
    }
}
