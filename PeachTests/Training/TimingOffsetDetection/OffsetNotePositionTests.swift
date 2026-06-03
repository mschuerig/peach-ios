import Testing
@testable import Peach

#if PEACH_RESEARCH
@Suite("OffsetNotePosition Tests")
struct OffsetNotePositionTests {

    @Test("valid values 1...4 round-trip through rawValue")
    func validValuesRoundTrip() {
        for raw in OffsetNotePosition.validRange {
            #expect(OffsetNotePosition(raw).rawValue == raw)
        }
    }

    @Test(
        "zeroBasedIndex equals rawValue - 1",
        arguments: [1, 2, 3, 4]
    )
    func zeroBasedIndexMatchesRawValue(raw: Int) {
        #expect(OffsetNotePosition(raw).zeroBasedIndex == raw - 1)
    }

    @Test("default exposes position 3")
    func defaultIsThree() {
        #expect(OffsetNotePosition.default.rawValue == 3)
        #expect(OffsetNotePosition.default.zeroBasedIndex == 2)
    }

    @Test("validRange is 1...4")
    func validRangeIsOneThroughFour() {
        #expect(OffsetNotePosition.validRange == 1...4)
    }

    @Test(
        "init(clamping:) accepts valid values verbatim",
        arguments: [1, 2, 3, 4]
    )
    func clampingPassesValidValues(raw: Int) {
        #expect(OffsetNotePosition(clamping: raw) == OffsetNotePosition(raw))
    }

    @Test(
        "init(clamping:) replaces out-of-range values with the default",
        arguments: [0, -1, 5, 99, Int.min, Int.max]
    )
    func clampingReplacesInvalidValuesWithDefault(raw: Int) {
        #expect(OffsetNotePosition(clamping: raw) == .default)
    }

    @Test("equal positions compare equal")
    func equality() {
        #expect(OffsetNotePosition(2) == OffsetNotePosition(2))
        #expect(OffsetNotePosition(1) != OffsetNotePosition(4))
    }
}
#endif
