import Testing
@testable import Peach

@Suite("TimingOffsetDetectionOffsetNotePositionSettingsSection — accessibility labels")
struct TimingOffsetDetectionOffsetNotePositionSettingsSectionTests {

    typealias Section = TimingOffsetDetectionOffsetNotePositionSettingsSection

    // MARK: - anchor cell label

    @Test("anchor cell label reads the locked Accent + not-selectable hint form")
    func anchorCellLabelReadsLockedForm() {
        #expect(Section.anchorCellLabel == String(localized: "Accent, not selectable"))
    }

    // MARK: - pickableCellLabel — K is audible count, not grid count

    @Test("pickableCellLabel uses audible count as K")
    func pickableCellLabelUsesAudibleCount() {
        // pattern_straight16ths_01 has audibleCount == 4: cells read "Note N of 4".
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(2), audibleCount: 4) == String(localized: "Note \(2) of \(4)"))
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(3), audibleCount: 4) == String(localized: "Note \(3) of \(4)"))
        #expect(Section.pickableCellLabel(position: OffsetNotePosition(4), audibleCount: 4) == String(localized: "Note \(4) of \(4)"))

        // pattern_gapped16ths_01 has audibleCount == 3 (not grid 4): audible pos 3 reads
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
