import Testing
@testable import Peach

#if PEACH_RESEARCH
@Suite("TimingOffsetDetectionPatternPickerSettingsSection — accessibility label derivation")
struct TimingOffsetDetectionPatternPickerSettingsSectionTests {

    private static let accent = String(localized: "Accent")
    private static let note = String(localized: "Note")
    private static let rest = String(localized: "Rest")

    @Test("pattern_1111 label reads every audible position as a single-word token")
    func labelForPattern1111() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern1111
        )
        #expect(label == [Self.accent, Self.note, Self.note, Self.note].joined(separator: ", "))
    }

    @Test("rest-bearing pattern label substitutes the Rest token at silent grid positions")
    func labelForRestBearingPattern() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern1011
        )
        #expect(label == [Self.accent, Self.rest, Self.note, Self.note].joined(separator: ", "))
    }

    @Test("single-pickable pattern label preserves grid order")
    func labelForSinglePickablePattern() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern1010
        )
        #expect(label == [Self.accent, Self.rest, Self.note, Self.rest].joined(separator: ", "))
    }

    @Test("rest-in-the-middle pattern label keeps the rest token in its grid position")
    func labelForPattern1101() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern1101
        )
        #expect(label == [Self.accent, Self.note, Self.rest, Self.note].joined(separator: ", "))
    }

    @Test("anchor-plus-tail pattern label reads two rests between the audible bookends")
    func labelForPattern1001() {
        let label = TimingOffsetDetectionPatternPickerSettingsSection.patternRowAccessibilityLabel(
            for: .pattern1001
        )
        #expect(label == [Self.accent, Self.rest, Self.rest, Self.note].joined(separator: ", "))
    }

    // MARK: - cascadeWrites(forNewId:)

    @Test("cascade writes resolve to (catalog id, pattern default) for a known id")
    func cascadeWritesForKnownId() {
        let resolved = TimingOffsetDetectionPatternPickerSettingsSection.cascadeWrites(
            forNewId: TimingOffsetDetectionPatternCatalog.defaultPatternId
        )
        let pattern = TimingOffsetDetectionPatternCatalog.defaultPattern
        #expect(resolved.selectedPatternId == pattern.id)
        #expect(resolved.offsetNotePosition == pattern.defaultOffsetNotePosition.rawValue)
    }

    @Test("cascade writes rewrite an unknown id to the catalog default's id")
    func cascadeWritesForUnknownId() {
        let resolved = TimingOffsetDetectionPatternPickerSettingsSection.cascadeWrites(
            forNewId: "pattern_does_not_exist"
        )
        let pattern = TimingOffsetDetectionPatternCatalog.defaultPattern
        // Storage must not retain the unknown id — the binding writes the
        // resolved pattern's id so subsequent reads round-trip consistently.
        #expect(resolved.selectedPatternId == pattern.id)
        #expect(resolved.offsetNotePosition == pattern.defaultOffsetNotePosition.rawValue)
    }
}
#endif
