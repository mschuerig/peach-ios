import Testing
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionOffsetNotePositionSettingsSection — cell classification")
struct TimingOffsetDetectionOffsetNotePositionSettingsSectionTests {

    typealias Section = TimingOffsetDetectionOffsetNotePositionSettingsSection

    // MARK: - pattern_1111 (no rests, every audible position pickable except anchor)

    @Test("pattern_1111 grid 0 classifies as anchor")
    func pattern1111Anchor() {
        let kind = Section.cellKind(for: .pattern1111, gridIndex: 0)
        #expect(kind == .anchor)
    }

    @Test("pattern_1111 grid 1-3 classify as pickable with audible positions 2-4")
    func pattern1111PickableCells() {
        for (gridIndex, expectedAudible) in [(1, 2), (2, 3), (3, 4)] {
            let kind = Section.cellKind(for: .pattern1111, gridIndex: gridIndex)
            #expect(kind == .pickable(OffsetNotePosition(expectedAudible)))
        }
    }

    // MARK: - pattern_test_1011 (one rest, two pickable)

    @Test("pattern_test_1011 classifies (anchor, rest, pickable(2), pickable(3))")
    func pattern1011AllCells() {
        let pattern = TimingOffsetDetectionPatternFixtures.pattern1011
        let kinds = (0..<pattern.subdivisions.count).map { Section.cellKind(for: pattern, gridIndex: $0) }
        #expect(kinds == [
            .anchor,
            .rest,
            .pickable(OffsetNotePosition(2)),
            .pickable(OffsetNotePosition(3)),
        ])
    }

    // MARK: - pattern_test_1010 (single pickable)

    @Test("pattern_test_1010 (single-pickable) classifies (anchor, rest, pickable(2), rest)")
    func pattern1010AllCells() {
        let pattern = TimingOffsetDetectionPatternFixtures.pattern1010
        let kinds = (0..<pattern.subdivisions.count).map { Section.cellKind(for: pattern, gridIndex: $0) }
        #expect(kinds == [
            .anchor,
            .rest,
            .pickable(OffsetNotePosition(2)),
            .rest,
        ])
    }

    // MARK: - pickableCellLabel — K is audible count, not grid count

    @Test("pickableCellLabel uses audible count as K")
    func pickableCellLabelUsesAudibleCount() {
        // pattern_1111 has audibleCount == 4: cells read "Note N of 4".
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(2), audibleCount: 4) == String(localized: "Note \(2) of \(4)"))
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(3), audibleCount: 4) == String(localized: "Note \(3) of \(4)"))
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(4), audibleCount: 4) == String(localized: "Note \(4) of \(4)"))

        // pattern_test_1011 has audibleCount == 3 (not grid 4): audible pos 3 reads
        // "Note 3 of 3", NOT "Note 3 of 4" — guards the audible-vs-grid mismatch
        // for the slot picker's accessibility label.
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(2), audibleCount: 3) == String(localized: "Note \(2) of \(3)"))
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(3), audibleCount: 3) == String(localized: "Note \(3) of \(3)"))

        // Locale-independent sanity: the formatted string must contain the two
        // values, in the right order (position before count).
        let label24 = Section.pickableCellLabel(position: OffsetNotePosition(2), audibleCount: 4)
        #expect(label24.range(of: "2")?.lowerBound ?? label24.endIndex
                < label24.range(of: "4")?.lowerBound ?? label24.endIndex)
    }
}
#endif
