import Testing
@testable import Peach

@Suite("TimingOffsetDetectionOffsetNotePositionSettingsSection — cell classification")
struct TimingOffsetDetectionOffsetNotePositionSettingsSectionTests {

    typealias Section = TimingOffsetDetectionOffsetNotePositionSettingsSection

    // MARK: - anchor cell label

    @Test("anchor cell label reads the locked Accent + not-selectable hint form")
    func anchorCellLabelReadsLockedForm() {
        #expect(Section.anchorCellLabel == String(localized: "Accent, not selectable"))
    }

    // MARK: - pattern_01 (no rests, every audible position pickable except anchor)

    @Test("pattern_01 grid 0 classifies as anchor")
    func pattern01Anchor() {
        let kind = Section.cellKind(for: .pattern01, gridIndex: 0)
        #expect(kind == .anchor)
    }

    @Test("pattern_01 grid 1-3 classify as pickable with audible positions 2-4")
    func pattern01PickableCells() {
        for (gridIndex, expectedAudible) in [(1, 2), (2, 3), (3, 4)] {
            let kind = Section.cellKind(for: .pattern01, gridIndex: gridIndex)
            #expect(kind == .pickable(OffsetNotePosition(expectedAudible)))
        }
    }

    // MARK: - pattern_02 (one rest, two pickable)

    @Test("pattern_02 classifies (anchor, rest, pickable(2), pickable(3))")
    func pattern02AllCells() {
        let pattern = TimingOffsetDetectionPattern.pattern02
        let kinds = (0..<pattern.subdivisions.count).map { Section.cellKind(for: pattern, gridIndex: $0) }
        #expect(kinds == [
            .anchor,
            .rest,
            .pickable(OffsetNotePosition(2)),
            .pickable(OffsetNotePosition(3)),
        ])
    }

    // MARK: - pattern_03 (early-audible mapping; rest at midpoint)

    @Test("pattern_03 classifies (anchor, pickable(2), rest, pickable(3))")
    func pattern03AllCells() {
        let pattern = TimingOffsetDetectionPattern.pattern03
        let kinds = (0..<pattern.subdivisions.count).map { Section.cellKind(for: pattern, gridIndex: $0) }
        #expect(kinds == [
            .anchor,
            .pickable(OffsetNotePosition(2)),
            .rest,
            .pickable(OffsetNotePosition(3)),
        ])
    }

    // MARK: - pattern_04 (single pickable)

    @Test("pattern_04 (single-pickable) classifies (anchor, rest, pickable(2), rest)")
    func pattern04AllCells() {
        let pattern = TimingOffsetDetectionPattern.pattern04
        let kinds = (0..<pattern.subdivisions.count).map { Section.cellKind(for: pattern, gridIndex: $0) }
        #expect(kinds == [
            .anchor,
            .rest,
            .pickable(OffsetNotePosition(2)),
            .rest,
        ])
    }

    // MARK: - pattern_05 (single-pickable; anchor + tail)

    @Test("pattern_05 (single-pickable, anchor + tail) classifies (anchor, rest, rest, pickable(2))")
    func pattern05AllCells() {
        let pattern = TimingOffsetDetectionPattern.pattern05
        let kinds = (0..<pattern.subdivisions.count).map { Section.cellKind(for: pattern, gridIndex: $0) }
        #expect(kinds == [
            .anchor,
            .rest,
            .rest,
            .pickable(OffsetNotePosition(2)),
        ])
    }

    // MARK: - pickableCellLabel — K is audible count, not grid count

    @Test("pickableCellLabel uses audible count as K")
    func pickableCellLabelUsesAudibleCount() {
        // pattern_01 has audibleCount == 4: cells read "Note N of 4".
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(2), audibleCount: 4) == String(localized: "Note \(2) of \(4)"))
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(3), audibleCount: 4) == String(localized: "Note \(3) of \(4)"))
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(4), audibleCount: 4) == String(localized: "Note \(4) of \(4)"))

        // pattern_02 has audibleCount == 3 (not grid 4): audible pos 3 reads
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
