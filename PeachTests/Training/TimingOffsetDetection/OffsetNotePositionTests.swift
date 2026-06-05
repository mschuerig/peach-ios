import Testing
@testable import Peach

@Suite("OffsetNotePosition Tests")
struct OffsetNotePositionTests {

    @Test("valid values 1...6 round-trip through rawValue")
    func validValuesRoundTrip() {
        for raw in OffsetNotePosition.validRange {
            #expect(OffsetNotePosition(raw).rawValue == raw)
        }
    }

    @Test(
        "zeroBasedIndex equals rawValue - 1",
        arguments: [1, 2, 3, 4, 5, 6]
    )
    func zeroBasedIndexMatchesRawValue(raw: Int) {
        #expect(OffsetNotePosition(raw).zeroBasedIndex == raw - 1)
    }

    @Test("default exposes position 3")
    func defaultIsThree() {
        #expect(OffsetNotePosition.default.rawValue == 3)
        #expect(OffsetNotePosition.default.zeroBasedIndex == 2)
    }

    @Test("validRange is 1...6 — covers every catalog audibleCount through Epic 84 (pattern_sextuplet_01 sextuplet has 6 audibles)")
    func validRangeIsOneThroughSix() {
        #expect(OffsetNotePosition.validRange == 1...6)
    }

    @Test("validRange contains every audible position in every catalog pattern's pickable set")
    func validRangeCoversEveryCatalogPickablePosition() {
        for pattern in TimingOffsetDetectionPatternCatalog.all {
            for raw in pattern.pickable {
                #expect(
                    OffsetNotePosition.validRange.contains(raw),
                    "Pattern \(pattern.id) lists pickable position \(raw) outside OffsetNotePosition.validRange \(OffsetNotePosition.validRange)"
                )
            }
        }
    }

    @Test(
        "clampedOffsetNotePosition for pattern_sextuplet_01 accepts every audible position 2–6",
        arguments: [2, 3, 4, 5, 6]
    )
    func clampedPositionAcceptsPattern15Audibles(raw: Int) {
        let pattern = TimingOffsetDetectionPattern.pattern_sextuplet_01
        #expect(pattern.clampedOffsetNotePosition(raw) == OffsetNotePosition(raw))
    }

    @Test("equal positions compare equal")
    func equality() {
        #expect(OffsetNotePosition(2) == OffsetNotePosition(2))
        #expect(OffsetNotePosition(1) != OffsetNotePosition(4))
    }
}
